#import "GPUDownloadBenchmarkAppDelegate.h"



#define TESTWARMUP 10
#define TESTMAXCOUNT 1000




@implementation GPUDownloadBenchmarkAppDelegate


- (id) init	{
	if (self = [super init])	{
		sharedContext = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:nil];
		[VVBufferPool createGlobalVVBufferPoolWithSharedContext:sharedContext];
		
		testInProgress = NO;
		testCount = 0;
		testSwatch = [[VVStopwatch alloc] init];
		testRes = NSMakeSize(1920,1080);
		testMethod = DownloadMethod_TexRange;
		testTexTarget = DownloadTexTarget_Rect;
		testColorFormat = DownloadPixelFormat_BGRA;
		testInternalFormat = DownloadInternalFormat_RGBA8;
		testPixelType = DownloadPixelType_8888;
		testSrcBuffer = nil;
		
		srcImgScene = [[ISFGLScene alloc] initWithSharedContext:sharedContext pixelFormat:[GLScene defaultPixelFormat] sized:testRes];
		[srcImgScene useFile:[[NSBundle mainBundle] pathForResource:@"Checkerboard" ofType:@"fs"]];
		//[srcImgScene setNSObjectVal:VVDEVCOLOR(1.,0.,0.,1.) forInputKey:@"color1"];
		[srcImgScene setNSObjectVal:VVDEVCOLOR(0.,1.,0.,1.) forInputKey:@"color1"];
		[srcImgScene setNSObjectVal:VVDEVCOLOR(1.,0.,0.,1.) forInputKey:@"color2"];
		
		pboStreamer = [[PBOGLCPUStreamer alloc] init];
		
		trStreamer = [[TexRangeGLCPUStreamer alloc] init];
		return self;
	}
	[self release];
	return nil;
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[widthField setStringValue:@"1920"];
	[heightField setStringValue:@"1080"];
	[pboVsRangeMatrix selectCellAtRow:1 column:0];
	[resultsLabel setStringValue:@"Ready"];
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {
}


- (IBAction) startTestClicked:(id)sender	{
	if (testInProgress)	{
		NSLog(@"\t\terr: bailing, test already in progress, %s",__func__);
		return;
	}
	
	//	need to make sure the size in the UI is valid, have to bail early if it isn't 
	NSString	*widthString = [widthField stringValue];
	NSString	*heightString = [heightField stringValue];
	if (widthString==nil || heightString==nil)	{
		NSLog(@"\t\terr: width/height string nil, bailing, %s",__func__);
		return;
	}
	NSSize		newSize = NSMakeSize([[widthString numberByEvaluatingString] floatValue], [[heightString numberByEvaluatingString] floatValue]);
	if (newSize.width<1 || newSize.height<1)	{
		NSLog(@"\t\terr: size parsed from fields is invalid (%f x %f), bailing, %s", newSize.width, newSize.height, __func__);
		return;
	}
	
	//	get vals from the UI, save them locally for use during testing
	testInProgress = YES;
	testCount = 0;
	testRes = newSize;
	testMethod = (int)[pboVsRangeMatrix selectedRow];
	testTexTarget = (int)[targetMatrix selectedRow];
	testColorFormat = (int)[pixelFormatMatrix selectedRow];
	testInternalFormat = (int)[internalFormatMatrix selectedRow];
	testPixelType = (int)[pixelTypeMatrix selectedRow];
	
	//	clear the streamers
	[pboStreamer clearStream];
	[trStreamer clearStream];
	
	[resultsLabel setStringValue:@"TEST IN PROGRESS"];
	
	//	call the work method in a bit, which gets stuff started
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		[self workMethod];
	});
	
}
- (void) workMethod	{
	//NSLog(@"%s",__func__);
	if (!testInProgress)
		return;
	
	//	alloc the buffer to download
	VVBuffer		*dlMe = [self _allocBufferToDownload];
	VVBuffer		*cpuBuffer = nil;
	
	switch (testMethod)	{
	case DownloadMethod_PBO:
		[pboStreamer setNextTexBufferForStream:dlMe];
		cpuBuffer = [pboStreamer copyAndGetPBOBufferForStream];
		//NSLog(@"\t\tusing PBO, cpu buffer is %@",cpuBuffer);
		break;
	case DownloadMethod_TexRange:
		[trStreamer setNextTexBufferForStream:dlMe];
		cpuBuffer = [trStreamer copyAndGetCPUBackedBufferForStream];
		//NSLog(@"\t\tusing tex range, cpu buffer is %@",cpuBuffer);
		break;
	}
	
	VVRELEASE(cpuBuffer);
	VVRELEASE(dlMe);
	
	BOOL		callAgain = YES;
	++testCount;
	if (testCount==TESTWARMUP)
		[testSwatch start];
	else if (testCount == (TESTWARMUP+TESTMAXCOUNT))	{
		callAgain = NO;
		
	}
	
	if (callAgain)	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self workMethod];
		});
	}
	else	{
		double		time = [testSwatch timeSinceStart];
		double		FPS = (TESTMAXCOUNT)/time;
		//NSLog(@"\t\ttest over, FPS was %f",FPS);
		dispatch_async(dispatch_get_main_queue(), ^{
			[resultsLabel setStringValue:VVFMTSTRING(@"Complete: %0.2f FPS",FPS)];
		});
		
		NSLog(@"********************\t\tTest Complete: %0.2f FPS",FPS);
		NSLog(@"\t\tres was %d x %d",(int)testRes.width, (int)testRes.height);
		NSLog(@"\t\t%d iterations",TESTMAXCOUNT);
		switch (testTexTarget)	{
		case DownloadTexTarget_Rect:
			NSLog(@"\t\tRECT target");
			break;
		case DownloadTexTarget_2D:
			NSLog(@"\t\t2D target");
			break;
		case DownloadTexTarget_NPOT2D:
			NSLog(@"\t\tNPOT 2D target");
			break;
		}
		
		switch (testColorFormat)	{
		case DownloadPixelFormat_RGBA:
			NSLog(@"\t\tRGBA pixel format");
			break;
		case DownloadPixelFormat_BGRA:
			NSLog(@"\t\tBGRA pixel format");
			break;
		}
		
		switch (testMethod)	{
		case DownloadMethod_PBO:
			NSLog(@"\t\tPBO method");
			break;
		case DownloadMethod_TexRange:
			NSLog(@"\t\ttexture range method");
			break;
		}
		
		switch (testInternalFormat)	{
		case DownloadInternalFormat_RGBA:
			NSLog(@"\t\tGL_RGBA internal format");
			break;
		case DownloadInternalFormat_RGBA8:
			NSLog(@"\t\tGL_RGBA8 internal format");
			break;
		}
		
		switch (testPixelType)	{
		case DownloadPixelType_UB:
			NSLog(@"\t\tGL_UNSIGNED_BYTE pixel type");
			break;
		case DownloadPixelType_8888_REV:
			NSLog(@"\t\tGL_UNSIGNED_INT_8_8_8_8_REV pixel type");
			break;
		case DownloadPixelType_8888:
			NSLog(@"\t\tGL_UNSIGNED_INT_8_8_8_8 pixel type");
			break;
		}
		
		testInProgress = NO;
	}
}


- (IBAction) checkClicked:(id)sender	{
	NSLog(@"%s",__func__);
	//	need to make sure the size in the UI is valid, have to bail early if it isn't 
	NSString	*widthString = [widthField stringValue];
	NSString	*heightString = [heightField stringValue];
	if (widthString==nil || heightString==nil)	{
		NSLog(@"\t\terr: width/height string nil, bailing, %s",__func__);
		return;
	}
	NSSize		newSize = NSMakeSize([[widthString numberByEvaluatingString] floatValue], [[heightString numberByEvaluatingString] floatValue]);
	if (newSize.width<1 || newSize.height<1)	{
		NSLog(@"\t\terr: size parsed from fields is invalid (%f x %f), bailing, %s", newSize.width, newSize.height, __func__);
		return;
	}
	
	//	get vals from the UI, save them locally for use during testing
	testInProgress = YES;
	testCount = 0;
	testRes = newSize;
	testMethod = (int)[pboVsRangeMatrix selectedRow];
	testTexTarget = (int)[targetMatrix selectedRow];
	testColorFormat = (int)[pixelFormatMatrix selectedRow];
	testInternalFormat = (int)[internalFormatMatrix selectedRow];
	testPixelType = (int)[pixelTypeMatrix selectedRow];
	
	//	clear the streamers
	[pboStreamer clearStream];
	[trStreamer clearStream];
	
	//	alloc the buffer to download
	VVBuffer		*dlMe = [self _allocBufferToDownload];
	NSLog(@"\t\tdlMe is %@",dlMe);
	VVBuffer		*cpuBuffer = nil;
	switch (testMethod)	{
	case DownloadMethod_PBO:
		cpuBuffer = [pboStreamer allocCPUBufferForTexBuffer:dlMe];
		//NSLog(@"\t\tusing PBO, cpu buffer is %@",cpuBuffer);
		break;
	case DownloadMethod_TexRange:
		[trStreamer setNextTexBufferForStream:dlMe];
		cpuBuffer = [trStreamer copyAndGetCPUBackedBufferForStream];
		VVRELEASE(cpuBuffer);
		cpuBuffer = [trStreamer copyAndGetCPUBackedBufferForStream];
		//NSLog(@"\t\tusing tex range, cpu buffer is %@",cpuBuffer);
		break;
	}
	
	//	make an NSImage from the cpu buffer, draw the NSImage in the image view
	if (cpuBuffer!=nil)	{
		//	make a bitmap image rep
		NSBitmapImageRep	*newRep = [[NSBitmapImageRep alloc]
			initWithBitmapDataPlanes:nil
			pixelsWide:testRes.width
			pixelsHigh:testRes.height
			bitsPerSample:8
			samplesPerPixel:4
			hasAlpha:YES
			isPlanar:NO
			colorSpaceName:NSDeviceRGBColorSpace
			bitmapFormat:0	//	premultiplied, alpha last
			bytesPerRow:32/8*testRes.width
			bitsPerPixel:32];
		if (newRep != nil)	{
			//	copy data from the CPU-based buffer i rendered into, to the bitmap image rep
			unsigned char		*repData = [newRep bitmapData];
			NSSize				cpuRes = [cpuBuffer size];
			unsigned long		rBytesPerRow = cpuRes.width*32/8;
			unsigned long		wBytesPerRow = testRes.width*32/8;
			unsigned char		*rPtr = (void *)[cpuBuffer pixels];
			unsigned char		*wPtr = repData;
			/*
			for (int y=0; y<testRes.height; ++y)	{
				for (int x=0; x<testRes.width; ++x)	{
					unsigned char			*charPtr = (unsigned char *)rPtr;
					if (*(charPtr+0)!=0	||
					*(charPtr+1)!=255	||
					*(charPtr+2)!=0 ||
					*(charPtr+3)!=255)	{
						NSLog(@"\t\terr: color val off (%d %d %d %d) at coord (%d, %d)",*(charPtr+0),*(charPtr+1),*(charPtr+2),*(charPtr+3),x,y);
					}
					rPtr += (sizeof(unsigned char)*4);
				}
			}
			*/
			rPtr = (void *)[cpuBuffer pixels];
			
			for (int y=0; y<testRes.height; ++y)	{
				memcpy(wPtr, rPtr, wBytesPerRow);
				wPtr += wBytesPerRow;
				rPtr += rBytesPerRow;
			}
			
			//	make an NSImage, pass it to the NSImageView
			NSImage			*newImg = [[NSImage alloc] initWithSize:testRes];
			if (newImg != nil)	{
				[newImg addRepresentation:newRep];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[checkImgView setImage:newImg];
				});
				
				VVRELEASE(newImg);
			}
			else
				NSLog(@"\t\terr: couldn't make img");
			
			VVRELEASE(newRep);
		}
		else
			NSLog(@"\t\terr: couldn't make image rep");
		
		VVRELEASE(cpuBuffer);
	}
	
	//	draw the buffer i'm downloading
	[checkGLView drawBuffer:dlMe];
	
	VVRELEASE(dlMe);
	
	testInProgress = NO;
}


- (VVBuffer *) _allocBufferToDownload	{
	//NSLog(@"%s",__func__);
	//	make sure the testSrcBuffer is the appropriate resolution
	if (testSrcBuffer!=nil && !NSEqualSizes([testSrcBuffer srcRect].size, testRes))
		VVRELEASE(testSrcBuffer);
	if (testSrcBuffer==nil)	{
		[srcImgScene setSize:testRes];
		testSrcBuffer = [srcImgScene allocAndRenderABuffer];
		//NSLog(@"\t\tmade a new testSrcBuffer, %@",testSrcBuffer);
	}
	
	//	populate a buffer descriptor based on the test properties
	VVBufferDescriptor		desc;
	NSSize					dlBufferSize = testRes;
	void					*cpuBufferMemory = NULL;
	
	desc.type = VVBufferType_Tex;
	//desc.target = ???;
	//desc.internalFormat = ???;
	//desc.pixelFormat = ???;
	//desc.pixelType = ???;
	//desc.cpuBackingType = ???;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	//desc.texRangeFlag = ???;
	//desc.texClientStorageFlag = ???;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	
	switch (testTexTarget)	{
	case DownloadTexTarget_Rect:
		//NSLog(@"\t\tRECT target");
		desc.target = GL_TEXTURE_RECTANGLE_EXT;
		break;
	case DownloadTexTarget_2D:
		//NSLog(@"\t\t2D target");
		{
		desc.target = GL_TEXTURE_2D;
		int		tmpInt = 1;
		while (tmpInt < testRes.width)
			tmpInt <<= 1;
		dlBufferSize.width = tmpInt;
		tmpInt = 1;
		while (tmpInt < testRes.height)
			tmpInt <<= 1;
		dlBufferSize.height = tmpInt;
		}
		break;
	case DownloadTexTarget_NPOT2D:
		//NSLog(@"\t\tNPOT 2D target");
		desc.target = GL_TEXTURE_2D;
		break;
	}
	
	switch (testColorFormat)	{
	case DownloadPixelFormat_RGBA:
		//NSLog(@"\t\tRGBA pixel format");
		desc.pixelFormat = VVBufferPF_RGBA;
		break;
	case DownloadPixelFormat_BGRA:
		//NSLog(@"\t\tBGRA pixel format");
		desc.pixelFormat = VVBufferPF_BGRA;
		break;
	}
	
	switch (testMethod)	{
	case DownloadMethod_PBO:
		//NSLog(@"\t\tPBO method");
		desc.cpuBackingType = VVBufferCPUBack_None;
		desc.texRangeFlag = NO;
		desc.texClientStorageFlag = NO;
		break;
	case DownloadMethod_TexRange:
		//NSLog(@"\t\ttexture range method");
		desc.cpuBackingType = VVBufferCPUBack_Internal;
		desc.texRangeFlag = YES;
		desc.texClientStorageFlag = YES;
		break;
	}
	
	switch (testInternalFormat)	{
	case DownloadInternalFormat_RGBA:
		//NSLog(@"\t\tGL_RGBA internal format");
		desc.internalFormat = VVBufferIF_RGBA;
		break;
	case DownloadInternalFormat_RGBA8:
		//NSLog(@"\t\tGL_RGBA8 internal format");
		desc.internalFormat = VVBufferIF_RGBA8;
		break;
	}
	
	switch (testPixelType)	{
	case DownloadPixelType_UB:
		//NSLog(@"\t\tGL_UNSIGNED_BYTE pixel type");
		desc.pixelType = VVBufferPT_U_Byte;
		break;
	case DownloadPixelType_8888_REV:
		//NSLog(@"\t\tGL_UNSIGNED_INT_8_8_8_8_REV pixel type");
		desc.pixelType = VVBufferPT_U_Int_8888_Rev;
		break;
	case DownloadPixelType_8888:
		//NSLog(@"\t\tGL_UNSIGNED_INT_8_8_8_8 pixel type");
		desc.pixelType = GL_UNSIGNED_INT_8_8_8_8;
		break;
	}
	
	//	make a buffer from the descriptor
	VVBuffer		*returnMe = [_globalVVBufferPool copyFreeBufferMatchingDescriptor:&desc sized:dlBufferSize];
	if (returnMe==nil)	{
		if (testMethod==DownloadMethod_TexRange)	{
			NSLog(@"\t\tmalloc()ing cpu backing");
			cpuBufferMemory = malloc(VVBufferDescriptorCalculateCPUBackingForSize(&desc,dlBufferSize));
		}
		returnMe = [_globalVVBufferPool allocBufferForDescriptor:&desc sized:dlBufferSize backingPtr:cpuBufferMemory backingSize:testRes];
		if (testMethod==DownloadMethod_TexRange)	{
			[returnMe setBackingID:VVBufferBackID_Pixels];
			[returnMe setBackingReleaseCallback:VVBuffer_ReleasePixelsCallback];
			[returnMe setBackingReleaseCallbackContext:cpuBufferMemory];
		}
	}
	//NSLog(@"\t\treturnMe is %@",returnMe);
	
	//	copy the src buffer to the buffer i'm going to want to download
	//NSLog(@"\t\tshould be copying %@ to %@",testSrcBuffer,returnMe);
	[_globalVVBufferCopier ignoreSizeCopyThisBuffer:testSrcBuffer toThisBuffer:returnMe];
	[returnMe setSrcRect:[testSrcBuffer srcRect]];
	
	return returnMe;
}


@end

#import "GPUUploadBenchmarkAppDelegate.h"




#define TESTWARMUP 10
#define TESTMAXCOUNT 1000




@implementation GPUUploadBenchmarkAppDelegate


- (id) init	{
	if (self = [super init])	{
		sharedContext = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:nil];
		[VVBufferPool createGlobalVVBufferPoolWithSharedContext:sharedContext];
		
		testInProgress = NO;
		testCount = 0;
		testSwatch = [[VVStopwatch alloc] init];
		testRes = NSMakeSize(1920,1080);
		testMethod = UploadMethod_TexRange;
		testTexTarget = UploadTexTarget_Rect;
		testColorFormat = UploadPixelFormat_BGRA;
		testInternalFormat = UploadInternalFormat_RGBA8;
		testPixelType = UploadPixelType_8888;
		testSrcBuffer = nil;
		
		pboStreamer = [[PBOCPUGLStreamer alloc] init];
		
		trStreamer = [[TexRangeCPUGLStreamer alloc] init];
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
	
	//	load the test src buffer
	[self _populateTestSrcBuffer];
	
	//	clear the streamers
	[pboStreamer clearStream];
	//[trStreamer clearStream];	//	not actually a streamer, nothing to clear
	
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
	
	//	alloc the buffer i'll be uploading, upload it
	VVBuffer			*ulMe = nil;
	VVBuffer			*uploaded = nil;
	switch (testMethod)	{
	case UploadMethod_PBO:
		ulMe = [_globalVVBufferPool
			allocRGBAPBOForTarget:GL_PIXEL_UNPACK_BUFFER_ARB
			usage:GL_STREAM_DRAW_ARB
			sized:testRes
			data:[testSrcBuffer cpuBackingPtr]];
		[ulMe setFlipped:YES];
		[pboStreamer setNextPBOForStream:ulMe];
		uploaded = [pboStreamer copyAndGetTexBufferForStream];
		if (uploaded==nil)
			uploaded = [pboStreamer copyAndGetTexBufferForStream];
		break;
	case UploadMethod_TexRange:
		ulMe = [_globalVVBufferPool allocRGBACPUBackedTexRangeSized:testRes];
		[ulMe setFlipped:YES];
		uint8_t				*rPtr = [testSrcBuffer cpuBackingPtr];
		uint8_t				*wPtr = [ulMe cpuBackingPtr];
		unsigned long		bytesPerRow = 32/8*testRes.width;
		for (int i=0; i<testRes.height; ++i)	{
			memcpy(wPtr, rPtr, bytesPerRow);
			wPtr += bytesPerRow;
			rPtr += bytesPerRow;
		}
		[trStreamer pushTexRangeBufferRAMtoVRAM:ulMe];
		uploaded = [ulMe retain];
		break;
	}
	
	
	VVRELEASE(uploaded);
	VVRELEASE(ulMe);
	
	
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
		case UploadTexTarget_Rect:
			NSLog(@"\t\tRECT target");
			break;
		case UploadTexTarget_2D:
			NSLog(@"\t\t2D target");
			break;
		case UploadTexTarget_NPOT2D:
			NSLog(@"\t\tNPOT 2D target");
			break;
		}
		
		switch (testColorFormat)	{
		case UploadPixelFormat_RGBA:
			NSLog(@"\t\tRGBA pixel format");
			break;
		case UploadPixelFormat_BGRA:
			NSLog(@"\t\tBGRA pixel format");
			break;
		}
		
		switch (testMethod)	{
		case UploadMethod_PBO:
			NSLog(@"\t\tPBO method");
			break;
		case UploadMethod_TexRange:
			NSLog(@"\t\ttexture range method");
			break;
		}
		
		switch (testInternalFormat)	{
		case UploadInternalFormat_RGBA:
			NSLog(@"\t\tGL_RGBA internal format");
			break;
		case UploadInternalFormat_RGBA8:
			NSLog(@"\t\tGL_RGBA8 internal format");
			break;
		}
		
		switch (testPixelType)	{
		case UploadPixelType_UB:
			NSLog(@"\t\tGL_UNSIGNED_BYTE pixel type");
			break;
		case UploadPixelType_8888_REV:
			NSLog(@"\t\tGL_UNSIGNED_INT_8_8_8_8_REV pixel type");
			break;
		case UploadPixelType_8888:
			NSLog(@"\t\tGL_UNSIGNED_INT_8_8_8_8 pixel type");
			break;
		}
		
		testInProgress = NO;
	}
	
}


- (IBAction) checkClicked:(id)sender	{
	NSLog(@"%s",__func__);
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
	
	//	load the test src buffer
	[self _populateTestSrcBuffer];
	
	//	make a bitmap rep from the src buffer, then an NSImage from the bitmap rep
	NSBitmapImageRep		*newRep = [[NSBitmapImageRep alloc]
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
	if (newRep==nil)	{
		NSLog(@"\t\terr: newRep nil in %s, bailing",__func__);
		VVRELEASE(newRep);
		return;
	}
	uint8_t					*rPtr = [testSrcBuffer cpuBackingPtr];
	uint8_t					*wPtr = [newRep bitmapData];
	if (rPtr==nil || wPtr==nil)	{
		NSLog(@"\t\terr: wPtr or rPtr nil in %s, bailing",__func__);
		VVRELEASE(newRep);
		return;
	}
	unsigned long			bytesPerRow = 32/8*testRes.width;
	for (int i=0; i<testRes.height; ++i)	{
		memcpy(wPtr, rPtr, bytesPerRow);
		wPtr += bytesPerRow;
		rPtr += bytesPerRow;
	}
	NSImage					*newImg = [[NSImage alloc] initWithSize:testRes];
	[newImg addRepresentation:newRep];
	//	draw the NSImage, then get rid of the image and the bitmap rep
	[checkImgView setImage:newImg];
	VVRELEASE(newImg);
	VVRELEASE(newRep);
	
	//	clear the streamers
	[pboStreamer clearStream];
	//[trStreamer clearStream];	//	not actually a streamer, nothing to clear
	
	//	alloc the buffer i'll be uploading, upload it
	VVBuffer			*ulMe = nil;
	VVBuffer			*uploaded = nil;
	switch (testMethod)	{
	case UploadMethod_PBO:
		ulMe = [_globalVVBufferPool
			allocRGBAPBOForTarget:GL_PIXEL_UNPACK_BUFFER_ARB
			usage:GL_STREAM_DRAW_ARB
			sized:testRes
			data:[testSrcBuffer cpuBackingPtr]];
		[ulMe setFlipped:[testSrcBuffer flipped]];
		[pboStreamer setNextPBOForStream:ulMe];
		uploaded = [pboStreamer copyAndGetTexBufferForStream];
		if (uploaded==nil)
			uploaded = [pboStreamer copyAndGetTexBufferForStream];
		break;
	case UploadMethod_TexRange:
		ulMe = [_globalVVBufferPool allocRGBACPUBackedTexRangeSized:testRes];
		[ulMe setFlipped:[testSrcBuffer flipped]];
		uint8_t				*rPtr = [testSrcBuffer cpuBackingPtr];
		uint8_t				*wPtr = [ulMe cpuBackingPtr];
		unsigned long		bytesPerRow = 32/8*testRes.width;
		for (int i=0; i<testRes.height; ++i)	{
			memcpy(wPtr, rPtr, bytesPerRow);
			wPtr += bytesPerRow;
			rPtr += bytesPerRow;
		}
		[trStreamer pushTexRangeBufferRAMtoVRAM:ulMe];
		uploaded = [ulMe retain];
		break;
	}
	//	draw the texture i uploaded to in the gl view
	[checkGLView drawBuffer:uploaded];
	
	VVRELEASE(uploaded);
	VVRELEASE(ulMe);
	
	testInProgress = NO;
	
}


- (void) _populateTestSrcBuffer	{
	NSLog(@"%s",__func__);
	//	get rid of the old buffer, make a new one of the appropriate resolution
	VVRELEASE(testSrcBuffer);
	testSrcBuffer = [_globalVVBufferPool allocRGBACPUBufferSized:testRes];
	[testSrcBuffer setFlipped:YES];
	//	make an image from the jpg included with the app
	NSImage					*origImg = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"IMG_0885" ofType:@"JPG"]];
	if (origImg==nil)	{
		NSLog(@"\t\terr: couldn't load image in %s, bailing",__func__);
		return;
	}
	//	make an NSBitmapImageRep of the appropriate size
	NSBitmapImageRep		*tmpRep = [[NSBitmapImageRep alloc]
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
	if (tmpRep==nil)	{
		NSLog(@"\t\terr: couldn't make bitmap rep in %s, bailing",__func__);
		return;
	}
	//	make a graphics context from the bitmap rep- use that to draw the image into the bitmap rep
	NSGraphicsContext		*origCtx = [NSGraphicsContext currentContext];
	[origCtx retain];
	NSGraphicsContext		*newCtx = [NSGraphicsContext graphicsContextWithBitmapImageRep:tmpRep];
	if (newCtx==nil)	{
		NSLog(@"\t\terr: couldn't make new ctx in %s, bailing",__func__);
		VVRELEASE(tmpRep);
		VVRELEASE(origImg);
		return;
	}
	
	[NSGraphicsContext setCurrentContext:newCtx];
	
	NSRect			imgRect = NSMakeRect(0,0,0,0);
	imgRect.size = [origImg size];
	NSRectLog(@"\t\timgRect is",imgRect);
	NSRect			testResRect = NSMakeRect(0,0,testRes.width,testRes.height);
	NSRectLog(@"\t\ttestResRect is",testResRect);
	NSRect			drawRect = [VVSizingTool rectThatFitsRect:imgRect inRect:testResRect sizingMode:VVSizingModeFill];
	NSRectLog(@"\t\tdrawRect is",drawRect);
	[origImg
		drawInRect:drawRect
		fromRect:imgRect
	 operation:NSCompositingOperationCopy
		fraction:1.0];
	[newCtx flushGraphics];
	
	[NSGraphicsContext setCurrentContext:origCtx];
	
	//	copy the data in the bitmap rep into the test src buffer's memory
	uint8_t				*rPtr = [tmpRep bitmapData];
	uint8_t				*wPtr = [testSrcBuffer cpuBackingPtr];
	if (rPtr==nil || wPtr==nil)	{
		NSLog(@"\t\terr: rPtr or wPtr nil, bailing, %s",__func__);
		VVRELEASE(tmpRep);
		VVRELEASE(origImg);
		return;
	}
	/*
	for (int y=0; y<testRes.height; ++y)	{
		for (int x=0; x<testRes.width; ++x)	{
			for (int c=0; c<4; ++c)	{
				switch (c)	{
				case 0:
					*wPtr = 255;
					break;
				case 1:
					*wPtr = 0;
					break;
				case 2:
					*wPtr = 0;
					break;
				case 3:
					*wPtr = 255;
					break;
				}
				++wPtr;
			}
		}
	}
	*/
	unsigned long		bytesPerRow = 32/8*testRes.width;
	for (int i=0; i<testRes.height; ++i)	{
		memcpy(wPtr, rPtr, bytesPerRow);
		wPtr += bytesPerRow;
		rPtr += bytesPerRow;
	}
	
	
	//	release the bitmap rep and the image!
	[tmpRep release];
	[origImg release];
}
- (VVBuffer *) _allocBufferToUpload	{
	//NSLog(@"%s",__func__);
	
	
	
	
	
	/*
	//	make sure the testSrcBuffer is the appropriate resolution
	if (testSrcBuffer!=nil && !NSEqualSizes([testSrcBuffer srcRect].size, testRes))
		VVRELEASE(testSrcBuffer);
	if (testSrcBuffer==nil)	{
		[self _populateTestSrcBuffer];
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
	case UploadTexTarget_Rect:
		//NSLog(@"\t\tRECT target");
		desc.target = GL_TEXTURE_RECTANGLE_EXT;
		break;
	case UploadTexTarget_2D:
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
	case UploadTexTarget_NPOT2D:
		//NSLog(@"\t\tNPOT 2D target");
		desc.target = GL_TEXTURE_2D;
		break;
	}
	
	switch (testColorFormat)	{
	case UploadPixelFormat_RGBA:
		//NSLog(@"\t\tRGBA pixel format");
		desc.pixelFormat = VVBufferPF_RGBA;
		break;
	case UploadPixelFormat_BGRA:
		//NSLog(@"\t\tBGRA pixel format");
		desc.pixelFormat = VVBufferPF_BGRA;
		break;
	}
	
	switch (testMethod)	{
	case UploadMethod_PBO:
		//NSLog(@"\t\tPBO method");
		desc.cpuBackingType = VVBufferCPUBack_None;
		desc.texRangeFlag = NO;
		desc.texClientStorageFlag = NO;
		break;
	case UploadMethod_TexRange:
		//NSLog(@"\t\ttexture range method");
		desc.cpuBackingType = VVBufferCPUBack_Internal;
		desc.texRangeFlag = YES;
		desc.texClientStorageFlag = YES;
		break;
	}
	
	switch (testInternalFormat)	{
	case UploadInternalFormat_RGBA:
		//NSLog(@"\t\tGL_RGBA internal format");
		desc.internalFormat = VVBufferIF_RGBA;
		break;
	case UploadInternalFormat_RGBA8:
		//NSLog(@"\t\tGL_RGBA8 internal format");
		desc.internalFormat = VVBufferIF_RGBA8;
		break;
	}
	
	switch (testPixelType)	{
	case UploadPixelType_UB:
		//NSLog(@"\t\tGL_UNSIGNED_BYTE pixel type");
		desc.pixelType = VVBufferPT_U_Byte;
		break;
	case UploadPixelType_8888_REV:
		//NSLog(@"\t\tGL_UNSIGNED_INT_8_8_8_8_REV pixel type");
		desc.pixelType = VVBufferPT_U_Int_8888_Rev;
		break;
	case UploadPixelType_8888:
		//NSLog(@"\t\tGL_UNSIGNED_INT_8_8_8_8 pixel type");
		desc.pixelType = GL_UNSIGNED_INT_8_8_8_8;
		break;
	}
	
	//	make a buffer from the descriptor
	VVBuffer		*returnMe = [_globalVVBufferPool copyFreeBufferMatchingDescriptor:&desc sized:dlBufferSize];
	if (returnMe==nil)	{
		if (testMethod==UploadMethod_TexRange)	{
			NSLog(@"\t\tmalloc()ing cpu backing");
			cpuBufferMemory = malloc(VVBufferDescriptorCalculateCPUBackingForSize(&desc,dlBufferSize));
		}
		returnMe = [_globalVVBufferPool allocBufferForDescriptor:&desc sized:dlBufferSize backingPtr:cpuBufferMemory backingSize:testRes];
		if (testMethod==UploadMethod_TexRange)	{
			[returnMe setBackingID:VVBufferBackID_Pixels];
			[returnMe setBackingReleaseCallback:VVBuffer_ReleasePixelsCallback];
			[returnMe setBackingReleaseCallbackContext:cpuBufferMemory];
		}
	}
	//NSLog(@"\t\treturnMe is %@",returnMe);
	
	//	copy the src buffer to the buffer i'm going to want to download
	[_globalVVBufferCopier ignoreSizeCopyThisBuffer:testSrcBuffer toThisBuffer:returnMe];
	[returnMe setSrcRect:[testSrcBuffer srcRect]];
	
	return returnMe;
	*/
	return nil;
}


@end

#import "TexRangeGLtoCPUtoGLAppDelegate.h"




@implementation TexRangeGLtoCPUtoGLAppDelegate


- (id) init	{
	if (self = [super init])	{
		//	make a shared GL context, then make a buffer pool that uses it
		sharedContext = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:nil];
		[VVBufferPool createGlobalVVBufferPoolWithSharedContext:sharedContext];
		
		//	set up the CoreImage backend to work with the shared context
		[CIGLScene prepCommonCIBackendToRenderOnContext:sharedContext pixelFormat:[GLScene defaultPixelFormat]];
		[QCGLScene prepCommonQCBackendToRenderOnContext:sharedContext pixelFormat:[GLScene defaultPixelFormat]];
		
		//	load the included QC composition, which came from apple
		qcScene = [[QCGLScene alloc] initCommonBackendSceneSized:NSMakeSize(640,480)];
		[qcScene useFile:[[NSBundle mainBundle] pathForResource:@"Blue" ofType:@"qtz"]];
		
		swatch = [[VVStopwatch alloc] init];
		[swatch start];
		
		//	make the swizzle node
		//swizzleNode = [[SwizzleNode alloc] init];
		//[swizzleNode setSwizzleMode:ColorSwiz_RGBAtoGRAB];
		//[swizzleNode setCopyAndResize:NO];
		//[swizzleNode setCopyAndFlip:YES];
		
		//	create the scenes that move data between the GPU and CPU using PBOs
		glToCPU = [[TexRangeGLCPUStreamer alloc] init];
		
		//	make the displaylink, which will drive rendering
		CVReturn				err = kCVReturnSuccess;
		CGOpenGLDisplayMask		totalDisplayMask = 0;
		GLint					virtualScreen = 0;
		GLint					displayMask = 0;
		NSOpenGLPixelFormat		*format = [GLScene defaultPixelFormat];
		
		for (virtualScreen=0; virtualScreen<[format numberOfVirtualScreens]; ++virtualScreen)	{
			[format getValues:&displayMask forAttribute:NSOpenGLPFAScreenMask forVirtualScreen:virtualScreen];
			totalDisplayMask |= displayMask;
		}
		err = CVDisplayLinkCreateWithOpenGLDisplayMask(totalDisplayMask, &displayLink);
		if (err)	{
			NSLog(@"\t\terr %d creating display link in %s",err,__func__);
			displayLink = NULL;
		}
		else	{
			CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, self);
			CVDisplayLinkStart(displayLink);
		}
		return self;
	}
	[self release];
	return nil;
}
- (void) awakeFromNib	{
	[rawGLView setSharedGLContext:sharedContext];
}


- (void) renderCallback	{
	double		newSpeed = fmod([swatch timeSinceStart], 3.0) / 3.0;
	
	//	create an FBO and a GL texture that i'll be rendering into
	VVBuffer	*fbo = [_globalVVBufferPool allocFBO];
	VVBuffer	*depth = [_globalVVBufferPool allocDepthSized:NSMakeSize(640,480)];
	//	the GL texture we're going to render into is a CPU-backed texture range.  we could use a normal (non-backed) texture too, but then the TexRangeGLCPUStreamer would have to copy it to a texture range internally anyway
	VVBuffer	*startTex = [_globalVVBufferPool allocBGRTexSized:NSMakeSize(640,480)];
	
	//	render the QC scene into the CPU-backed texture range.
	[[qcScene renderer] setValue:[NSNumber numberWithDouble:newSpeed] forInputKey:@"_protocolInput_Pace"];
	[qcScene renderInFBO:[fbo name] colorTex:[startTex name] depthTex:[depth name]];
	//	draw the GL texture i just rendered into in the buffer view
	[rawGLView drawBuffer:startTex];
	
	
	//	pass the swizzled GL texture to the GL to CPU streamer
	[glToCPU setNextTexBufferForStream:startTex];
	
	//	try to get a CPU-based buffer
	VVBuffer		*cpuBuffer = [glToCPU copyAndGetCPUBackedBufferForStream];
	if (cpuBuffer != nil)	{
		//	make a bitmap image rep
		NSBitmapImageRep	*newRep = [[NSBitmapImageRep alloc]
			initWithBitmapDataPlanes:nil
			pixelsWide:640
			pixelsHigh:480
			bitsPerSample:8
			samplesPerPixel:4
			hasAlpha:YES
			isPlanar:NO
			colorSpaceName:NSDeviceRGBColorSpace
			bitmapFormat:NSAlphaFirstBitmapFormat
			bytesPerRow:32/8*640
			bitsPerPixel:32];
		if (newRep != nil)	{
			//	copy data from the CPU-based buffer i rendered into, to the bitmap image rep
			unsigned char		*repData = [newRep bitmapData];
			unsigned char		*rPtr = (unsigned char *)[cpuBuffer pixels];
			unsigned char		*wPtr = repData;
			//NSLog(@"\t\trPtr is %p, wPtr is %p",rPtr,wPtr);
			for (int y=0;y<480;++y)	{
				for (int x=0;x<640;++x)	{
					for (int channel=0; channel<4; ++channel)	{
						*wPtr = *rPtr;
						++wPtr;
						++rPtr;
					}
				}
			}
			
			//	make an NSImage, pass it to the NSImageView
			NSImage			*newImg = [[NSImage alloc] initWithSize:NSMakeSize(640,480)];
			if (newImg != nil)	{
				[newImg addRepresentation:newRep];
				
				NSRunLoop		*rl = [NSRunLoop mainRunLoop];
				[rl cancelPerformSelectorsWithTarget:cpuImageWell];
				[cpuImageWell performSelectorOnMainThread:@selector(setImage:) withObject:newImg waitUntilDone:NO];
				//NSLog(@"\t\tcpuImageWell is %@",cpuImageWell);
				//NSLog(@"\t\timg is %@",newImg);
				
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
	else
		NSLog(@"\t\terr: cpu-backed buffer nil");
	
	
	//	free the FBO and GL textures i created earlier
	VVRELEASE(startTex);
	VVRELEASE(depth);
	VVRELEASE(fbo);
}


@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, 
	const CVTimeStamp *inNow, 
	const CVTimeStamp *inOutputTime, 
	CVOptionFlags flagsIn, 
	CVOptionFlags *flagsOut, 
	void *displayLinkContext)
{
	//NSLog(@"%s",__func__);
	NSAutoreleasePool		*pool =[[NSAutoreleasePool alloc] init];
	[(TexRangeGLtoCPUtoGLAppDelegate *)displayLinkContext renderCallback];
	[pool release];
	return kCVReturnSuccess;
}

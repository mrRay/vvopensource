#import "PBOGLtoCPUtoGLAppDelegate.h"
#import <VVBufferPool/CIGLScene.h>




@implementation PBOGLtoCPUtoGLAppDelegate


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
		
		//	create the scenes that move data between the GPU and CPU using PBOs
		glToCPU = [[PBOGLCPUStreamer alloc] init];
		cpuToGL = [[PBOCPUGLStreamer alloc] init];
		
		return self;
	}
	[self release];
	return nil;
}
- (void) awakeFromNib	{
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
}


- (void) renderCallback	{
	double		newSpeed = fmod([swatch timeSinceStart], 3.0) / 3.0;
	
	//	create an FBO and a GL texture that i'll be rendering into
	VVBuffer	*fbo = [_globalVVBufferPool allocFBO];
	VVBuffer	*depth = [_globalVVBufferPool allocDepthSized:NSMakeSize(640,480)];
	VVBuffer	*startTex = [_globalVVBufferPool allocBGRTexSized:NSMakeSize(640,480)];
	
	[[qcScene renderer] setValue:[NSNumber numberWithDouble:newSpeed] forInputKey:@"_protocolInput_Pace"];
	[qcScene renderInFBO:[fbo name] colorTex:[startTex name] depthTex:[depth name]];
	//	draw the GL texture i just rendered into in the buffer view
	[rawGLView drawBuffer:startTex];
	
	
	//	pass the starting GL texture to the GL to CPU streamer
	[glToCPU setNextTexBufferForStream:startTex];
	
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
	//	try to copy data from the PBO to the bitmap image rep's raw data
	unsigned char		*repData = [newRep bitmapData];
	if (![glToCPU copyPBOFromStreamToRawDataBuffer:repData sized:NSMakeSize(640,480)])
		NSLog(@"\t\terr, couldn't copy PBO data from stream");
	//	else i succeeded in copying data from the PBO...
	else	{
		
		//	make an NSImage, pass it to the NSImageView
		NSImage			*newImg = [[NSImage alloc] initWithSize:NSMakeSize(640,480)];
		if (newImg != nil)	{
			[newImg addRepresentation:newRep];
			
			NSRunLoop		*rl = [NSRunLoop mainRunLoop];
			[rl cancelPerformSelectorsWithTarget:cpuImageWell];
			[cpuImageWell performSelectorOnMainThread:@selector(setImage:) withObject:newImg waitUntilDone:NO];
			
			VVRELEASE(newImg);
		}
		
		
		//	make a PBO from the data in the bitmap image rep
		VVBuffer		*pbo = [_globalVVBufferPool
			allocBGRAPBOForTarget:GL_PIXEL_UNPACK_BUFFER_ARB
			usage:GL_STREAM_DRAW_ARB
			sized:NSMakeSize(640,480)
			data:repData];
		if (pbo != nil)	{
			//	pass the (CPU-based) PBO to the CPU to GL scene
			[cpuToGL setNextPBOForStream:pbo];
			
			//	try to get a GPU-based buffer (a texture) from the CPU to GL scene
			VVBuffer		*reconstitutedBuffer = [cpuToGL copyAndGetTexBufferForStream];
			if (reconstitutedBuffer != nil)	{
				[reconstitutedGLView drawBuffer:reconstitutedBuffer];
				
				VVRELEASE(reconstitutedBuffer);
			}
			
			VVRELEASE(pbo);
		}
		
	}
	VVRELEASE(newRep);
	
	//	free the FBO and GL texture i created earlier
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
	[(PBOGLtoCPUtoGLAppDelegate *)displayLinkContext renderCallback];
	[pool release];
	return kCVReturnSuccess;
}

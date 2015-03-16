#import "AppDelegate.h"
#import <OpenGL/CGLMacro.h>




@implementation AppDelegate


- (id) init	{
	if (self = [super init])	{
		//	make a shared GL context.  other GL contexts created to share this one may share resources (textures, buffers, etc).
		sharedContext = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:nil];
		
		//	create the global buffer pool from the shared context
		[VVBufferPool createGlobalVVBufferPoolWithSharedContext:sharedContext];
		//	...other stuff in the VVBufferPool framework- like the views, the buffer copier, etc- will 
		//	automatically use the global buffer pool's shared context to set themselves up to function with the pool.
		
		
		//	set up the CoreImage backend to work with the shared context.  using this approach, the CIGLScene will actually use 'sharedContext' (or whatever context you pass in its place) to do rendering, rather than creating a new GL context reserved solely for CI
		[CIGLScene prepCommonCIBackendToRenderOnContext:sharedContext pixelFormat:[GLScene defaultPixelFormat]];
		//	make a CIGLScene.  this is a GL context that will be used to render CIImages to GL textures.
		ciScene = [[CIGLScene alloc] initCommonBackendSceneSized:NSMakeSize(640,480)];
		/*
		//	make a CIGLScene.  this is a GL context that will be used to render CIImages to GL textures.  using this approach, the CIGLScene will create its own GL context, and use that to do rendering.
		ciScene = [[CIGLScene alloc] initWithSharedContext:sharedContext];
		[ciScene setSize:NSMakeSize(640,480)];	//	this sets the render resolution...
		*/
		
		
		//	make a checkerboard CIFilter, set its defaults
		checkerboardSrc = [[CIFilter filterWithName:@"CICheckerboardGenerator"] retain];
		[checkerboardSrc setDefaults];
		
		//	make a stopwatch that we'll use to crudely animate the size of the checkerboard
		swatch = [[VVStopwatch alloc] init];
		[swatch start];
		return self;
	}
	[self release];
	return nil;
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification	{
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
//	this method is called from the displaylink callback
- (void) renderCallback	{
	
	//	determine the size of the square based on the stopwatch, apply it to the CIFilter
	double		squareSize = (fmod([swatch timeSinceStart], 5.0) / 5.0) * 64.0;
	[checkerboardSrc setValue:[NSNumber numberWithDouble:squareSize] forKey:@"inputWidth"];
	
	//	get a CIImage from the CIFilter
	CIImage		*startImg = [checkerboardSrc valueForKey:@"outputImage"];
	
	//	tell the CI scene to render a buffer from the CIImage (this renders the CIImage to a GL texture)
	VVBuffer	*newTex = [ciScene allocAndRenderBufferFromImage:startImg];
	
	//	draw the GL texture i just rendered in the buffer view
	[bufferView drawBuffer:newTex];
	
	//	don't forget to release the buffer we allocated!
	VVRELEASE(newTex);
	
	//	tell the buffer pool to do its housekeeping (releases any "old" resources in the pool that have been sticking around for a while)
	[[VVBufferPool globalVVBufferPool] housekeeping];
}


@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, 
	const CVTimeStamp *inNow, 
	const CVTimeStamp *inOutputTime, 
	CVOptionFlags flagsIn, 
	CVOptionFlags *flagsOut, 
	void *displayLinkContext)
{
	NSAutoreleasePool		*pool =[[NSAutoreleasePool alloc] init];
	[(AppDelegate *)displayLinkContext renderCallback];
	[pool release];
	return kCVReturnSuccess;
}

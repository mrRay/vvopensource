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
		
		//	load the included ISF test file
		isfScene = [[ISFGLScene alloc] initWithSharedContext:sharedContext];
		[isfScene setSize:NSMakeSize(640,480)];
		[isfScene useFile:[[NSBundle mainBundle] pathForResource:@"ISFSupportTest" ofType:@"fs"]];
		
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
	double		tmpLevel = fmod([swatch timeSinceStart], 5.0) / 5.0;
	[isfScene setNSObjectVal:[NSNumber numberWithDouble:tmpLevel] forInputKey:@"level"];
	
	//	tell the ISF scene to render a buffer (this renders to a GL texture)
	VVBuffer		*newTex = [isfScene allocAndRenderABuffer];
	
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

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
		
		//	load the image buffer included with this app
		NSImage			*tmpImg = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SampleImg" ofType:@"png"]];
		imgBuffer = [[VVBufferPool globalVVBufferPool] allocBufferForNSImage:tmpImg];
		[tmpImg release];
		tmpImg = nil;
		
		//	make a GLScene.  this is a GL context with a callback- it handles all the "render to texture" stuff, lets me focus on just drawing commands
		glScene = [[GLScene alloc] initWithSharedContext:sharedContext];
		[glScene setSize:NSMakeSize(640,480)];	//	this sets the render resolution...
		[glScene setRenderTarget:self];
		[glScene setRenderSelector:@selector(renderGLSceneCallback:)];
		//	make a stopwatch that we'll use to crudely animate the clear color
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
	//	tell the GL scene to allocate and render itself to a buffer
	VVBuffer	*newTex = [glScene allocAndRenderABuffer];
	
	//	draw the GL texture i just rendered in the buffer view
	[bufferView drawBuffer:newTex];
	
	//	don't forget to release the buffer we allocated!
	VVRELEASE(newTex);
	
	//	tell the buffer pool to do its housekeeping (releases any "old" resources in the pool that have been sticking around for a while)
	[[VVBufferPool globalVVBufferPool] housekeeping];
}
//	i'm the GLScene's renderTarget, and i set this as the scene's renderSelector
- (void) renderGLSceneCallback:(GLScene *)s	{
	//	have to set the cgl_ctx before issuing any drawing commands (remember, we're using CGLMacro
	CGLContextObj	cgl_ctx = [s CGLContextObj];
	glClearColor(1,1,1,1);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	/*
	double			tmpLevel = fmod([swatch timeSinceStart], 5.0) / 5.0;
	glClearColor(tmpLevel, tmpLevel, tmpLevel, 1.0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	 */
	NSSize			sceneSize = [s size];
	if (imgBuffer != nil)	{
		glEnable(GL_TEXTURE_RECTANGLE_EXT);
		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
		GLDRAWTEXQUADMACRO([imgBuffer name],[imgBuffer target],[imgBuffer flipped],[imgBuffer glReadySrcRect],NSMakeRect(0,0,sceneSize.width,sceneSize.height));
	}
	double			tmpLevel = fmod([swatch timeSinceStart], 5.0) / 5.0;
	glColor4f(0,0,0,tmpLevel);
	GLDRAWRECT(NSMakeRect(0,0,sceneSize.width,sceneSize.height));
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

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
		
		
		//	set up the QC backend to use the shared context to render
		[QCGLScene prepCommonQCBackendToRenderOnContext:sharedContext pixelFormat:[GLScene defaultPixelFormat]];
		qcScene = [[QCGLScene alloc] initCommonBackendSceneSized:NSMakeSize(320,240)];
		msaaQCScene = [[QCGLScene alloc] initCommonBackendSceneSized:NSMakeSize(320,240)];
		/*
		//	set up the QC backend such taht each scene will create its own context, all of which share the shared context
		qcScene = [[QCGLScene alloc] initWithSharedContext:sharedContext pixelFormat:[GLScene defaultPixelFormat] sized:NSMakeSize(320,240)];
		msaaQCScene = [[QCGLScene alloc] initWithSharedContext:sharedContext pixelFormat:[GLScene defaultPixelFormat] sized:NSMakeSize(320,240)];
		*/
		
		
		//	load the included QC composition, which was created by apple and is included in the app bundle
		NSString		*compPath = [[NSBundle mainBundle] pathForResource:@"Blue" ofType:@"qtz"];
		[qcScene useFile:compPath];
		[msaaQCScene useFile:compPath];
		//	make a stopwatch that we'll use to crudely animate the speed of the composition
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
	//	determine the new speed, pass its value to the QCRenderer instance in the QC scene
	double		newSpeed = fmod([swatch timeSinceStart], 3.0) / 3.0;
	NSNumber	*tmpNum = [NSNumber numberWithDouble:newSpeed];
	[[qcScene renderer] setValue:tmpNum forInputKey:@"_protocolInput_Pace"];
	[[msaaQCScene renderer] setValue:tmpNum forInputKey:@"_protocolInput_Pace"];
	
	//	first we're going do a simple, straightforward render-to-texture on the first QC scene.
	VVBuffer		*newTex = [qcScene allocAndRenderABuffer];
	//	draw the GL texture i just rendered in the buffer view
	[bufferView drawBuffer:newTex];
	//	don't forget to release the buffer we allocated!
	VVRELEASE(newTex);	//	the 'VVRELEASE' macro calls release on an id, and then sets it to nil.  defined in VVBasics.
	
	
	//	now tell the QC scene to render an MSAA buffer, which should produce a smoother image.  this workflow is slightly more complicated, but allows more control- first we create the resources, then we explicitly tell the QC scene to render using those resources.
	NSSize			renderSize = [msaaQCScene size];
	VVBufferPool	*bp = [VVBufferPool globalVVBufferPool];	//	get a reference to the global buffer pool
	VVBuffer		*msaaFbo = [bp allocFBO];	//	allocate an FBO.  this FBO will have MSAA renderbuffers bound to it....
	VVBuffer		*msaaColor = [bp allocMSAAColorSized:renderSize numOfSamples:[VVBufferPool msaaMaxSamples]];	//	allocate a buffer containing an MSAA renderbuffer used as a color attachment
	VVBuffer		*msaaDepth = [bp allocMSAADepthSized:renderSize numOfSamples:[VVBufferPool msaaMaxSamples]];	//	allocate a buffer containing an MSAA renderbuffer used as a depth attachment
	VVBuffer		*fbo = [bp allocFBO];	//	allocate another FBO.  this FBO will have a color texture attachment; the MSAA RB will be copied here, producing a smoother image
	newTex = [bp allocBGRTexSized:renderSize];	//	this texture will be the color attachment for the second FBO
	//	using the resources i just created, tell the MSAA QC scene to render.  after this call, 'newTex' will have the final image.
	[msaaQCScene
		renderInMSAAFBO:[msaaFbo name]
		colorRB:[msaaColor name]
		depthRB:[msaaDepth name]
		fbo:[fbo name]
		colorTex:[newTex name]
		depthTex:0	//	don't need a depth texture for this; just blitting the MSAA RB to a tex
		target:[newTex target]];
	//	draw 'newTex' in the other buffer view
	[msaaBufferView drawBuffer:newTex];
	//	release the resources i just allocated!
	VVRELEASE(newTex);
	VVRELEASE(fbo);
	VVRELEASE(msaaDepth);
	VVRELEASE(msaaColor);
	VVRELEASE(msaaFbo);
	
	
	//	tell the buffer pool to do its housekeeping (releases any "old" resources in the pool that have been sticking around for a while)
	[bp housekeeping];
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

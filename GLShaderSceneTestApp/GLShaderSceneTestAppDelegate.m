#import "GLShaderSceneTestAppDelegate.h"
#import <OpenGL/CGLMacro.h>




@implementation GLShaderSceneTestAppDelegate


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
		
		//	make a GLSLShaderScene, tell it to load the frag + vert shaders included with this app
		NSBundle		*mb = [NSBundle mainBundle];
		glslScene = [[GLShaderScene alloc] initWithSharedContext:sharedContext sized:VVMAKESIZE(640,480)];
		[glslScene setVertexShaderString:[NSString stringWithContentsOfFile:[mb pathForResource:@"passthru" ofType:@"vs"] encoding:NSUTF8StringEncoding error:nil]];
		[glslScene setFragmentShaderString:[NSString stringWithContentsOfFile:[mb pathForResource:@"mblur" ofType:@"fs"] encoding:NSUTF8StringEncoding error:nil]];
		[glslScene setRenderTarget:self];
		[glslScene setRenderSelector:@selector(shaderSceneCallback:)];
		
		ciBuffer = nil;
		accumBuffer = nil;
		
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
	//	we're going to need an FBO, we're going to render to a couple textures before display
	VVBuffer	*fbo = [[VVBufferPool globalVVBufferPool] allocFBO];
	
	//	get a CIImage from the CIFilter
	CIImage		*startImg = [checkerboardSrc valueForKey:@"outputImage"];
	//	tell the CI scene to render a buffer from the CIImage (this renders the CIImage to a GL texture).  note that we're explicitly rendering into a 2D texture...
	VVRELEASE(ciBuffer);
	ciBuffer = [[VVBufferPool globalVVBufferPool] allocBGR2DTexSized:VVMAKESIZE(640,480)];
	[ciScene renderCIImage:startImg inFBO:[fbo name] colorTex:[ciBuffer name] target:[ciBuffer target]];
	if (ciBuffer == nil)	{
		NSLog(@"\t\terr: ciBuffer nil in %s",__func__);
		return;
	}
	
	//	if there's no accumulator buffer, make one by duplicating the buffer from the CI scene.  again, we're explicitly rendering to a 2D texture...
	if (accumBuffer == nil)	{
		accumBuffer = [[VVBufferPool globalVVBufferPool] allocBGR2DTexSized:VVMAKESIZE(640,480)];
		[[VVBufferCopier globalBufferCopier] copyThisBuffer:ciBuffer toThisBuffer:accumBuffer];
	}
	
	//	tell the shader scene to render a buffer.  this calls the shader scene callback, which is where we pass values to the shader!
	VVBuffer	*newGLSLBuffer = [[VVBufferPool globalVVBufferPool] allocBGR2DTexSized:VVMAKESIZE(640,480)];
	[glslScene renderInMSAAFBO:0 colorRB:0 depthRB:0 fbo:[fbo name] colorTex:[newGLSLBuffer name] depthTex:0 target:[newGLSLBuffer target]];
		
	//	draw something!
	[bufferView drawBuffer:newGLSLBuffer];
	
	//	update the accumBuffer (get rid of the old, use the new buffer rendered by the glsl scene)
	VVRELEASE(accumBuffer);
	accumBuffer = [newGLSLBuffer retain];
	
	//	release the buffers we allocated
	VVRELEASE(newGLSLBuffer);
	VVRELEASE(ciBuffer);
	VVRELEASE(fbo);
	
	//	tell the buffer pool to do its housekeeping (releases any "old" resources in the pool that have been sticking around for a while)
	[[VVBufferPool globalVVBufferPool] housekeeping];
}
//	this method is called when you tell "glslScene" to render- in it we pass values to the shader and then draw a quad
- (void) shaderSceneCallback:(GLScene *)scene	{
	//NSLog(@"%s",__func__);
	NSOpenGLContext		*context = [scene context];
	if (context == nil)
		return;
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	
	//	pass values (textures & data that describes the textures) to the GLSL program
	GLenum				glslProgram = [(GLShaderScene *)scene program];
	if (glslProgram > 0)	{
		GLint				samplerLoc = 0;
		VVRECT				tmpRect;
		VVSIZE				tmpSize;
		
		samplerLoc = glGetUniformLocation(glslProgram,"inputTexture");
		if (samplerLoc >= 0)	{
			glActiveTexture(GL_TEXTURE0);
			glBindTexture([ciBuffer target], [ciBuffer name]);
			glUniform1i(samplerLoc,0);
		}
		else
			NSLog(@"\t\terr: couldn't locate inputTexture sampler, %s",__func__);
		
		samplerLoc = glGetUniformLocation(glslProgram,"accumTexture");
		if (samplerLoc >= 0)	{
			glActiveTexture(GL_TEXTURE1);
			glBindTexture([accumBuffer target], [accumBuffer name]);
			glUniform1i(samplerLoc,1);
		}
		else
			NSLog(@"\t\terr: couldn't locate accumTexture sampler, %s",__func__);
		
		samplerLoc = glGetUniformLocation(glslProgram,"blurAmount");
		if (samplerLoc >= 0)	{
			glUniform1f(samplerLoc, 0.95);
		}
		else
			NSLog(@"\t\terr: couldn't locate blurAmount uniform, %s",__func__);
		
		samplerLoc = glGetUniformLocation(glslProgram,"inputCropRect");
		if (samplerLoc >= 0)	{
			tmpRect = [ciBuffer glReadySrcRect];
			glUniform4f(samplerLoc, tmpRect.origin.x, tmpRect.origin.y, tmpRect.size.width, tmpRect.size.height);
		}
		else
			NSLog(@"\t\terr: couldn't locate inputCropRect sampler, %s",__func__);
		
		samplerLoc = glGetUniformLocation(glslProgram,"accumCropRect");
		if (samplerLoc >= 0)	{
			tmpRect = [accumBuffer glReadySrcRect];
			glUniform4f(samplerLoc, tmpRect.origin.x, tmpRect.origin.y, tmpRect.size.width, tmpRect.size.height);
		}
		else
			NSLog(@"\t\terr: couldn't locate accumCropRect sampler, %s",__func__);
		
		samplerLoc = glGetUniformLocation(glslProgram,"flipFlag");
		if (samplerLoc >= 0)	{
			glUniform2f(samplerLoc, ([ciBuffer flipped]?1.0:0.0), ([accumBuffer flipped]?1.0:0.0));
		}
		else
			NSLog(@"\t\terr: couldn't locate flipFlag sampler, %s",__func__);
		
		tmpSize = [scene size];
		samplerLoc = glGetUniformLocation(glslProgram,"canvasSize");
		if (samplerLoc >= 0)	{
			glUniform2f(samplerLoc, tmpSize.width, tmpSize.height);
		}
		else
			NSLog(@"\t\terr: couldn't locate canvasSize sampler, %s",__func__);
	}
	else
		NSLog(@"\t\terr: can't pass vals to shader, %s",__func__);
	
	//	draw a quad
	glActiveTexture(GL_TEXTURE0);
	
	NSSize			s = [scene size];
	NSRect			r = NSMakeRect(0,0,s.width,s.height);
	
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	GLDRAWTEXQUADMACRO([ciBuffer name], [ciBuffer target], [ciBuffer flipped], [ciBuffer glReadySrcRect], r);
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
	[(GLShaderSceneTestAppDelegate *)displayLinkContext renderCallback];
	[pool release];
	return kCVReturnSuccess;
}

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#if !TARGET_OS_IPHONE
#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLMacro.h>
#import <Quartz/Quartz.h>
#else
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/glext.h>
#endif
#import <VVBasics/VVBasics.h>
#import "GLScene.h"




@protocol CIGLSceneCleanup
- (void) cleanupCIGLScene:(id)scene;
@end




//	sometime around 10.10, all CIContexts must be created from the same GL context or your machine will lock up and/or your GPU will crash.
extern pthread_mutex_t			_globalCIContextLock;
#if !TARGET_OS_IPHONE
extern NSOpenGLContext			*_globalCIContextGLContext;
extern NSOpenGLContext			*_globalCIContextSharedContext;
extern NSOpenGLPixelFormat		*_globalCIContextPixelFormat;
#else
extern EAGLContext				*_globalCIContextGLContext;
#endif



///	Subclass of GLScene for working with CoreImage resources.  As written, the API renders CIImages to VVBuffers (typically textures of some sort), since this seems to be the easiest way to work with CI resources.  Can be easily modified to render directly in a view.
/**
\ingroup VVBufferPool
*/
@interface CIGLScene : GLScene {
	CGColorSpaceRef			workingColorSpace;
	CGColorSpaceRef			outputColorSpace;
	CIContext				*ciContext;
	
	id <CIGLSceneCleanup>	cleanupDelegate;	//	nil, NOT RETAINED
}

///	If you want all instances of CIGLScene to use a single specific OpenGL context to render (CGLLockContext()/CGLUnlockContext() will be called before any rendering is performed), you need to call this method and pass it the context and pixel format you'll be using to do all the rendering.  Once you've called this, instances of CIGLScene that use the common backend can be instantiated via -[CIGLScene initCommonBackendSceneSized:].
#if !TARGET_OS_IPHONE
+ (void) prepCommonCIBackendToRenderOnContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p;
#else
+ (void) prepCommonCIBackendToRenderOnContext:(EAGLContext *)c;
+ (void) prepCommonCIBackendToRenderOnSharegroup:(EAGLSharegroup *)s;
#endif
///	If you create a CIGLScene using this method, the scene won't allocate its own OpenGL context- instead, it will create its local CIContext instance from the common backend's GL context.  This is worth noting because by default, GLScene and all subclasses of it create and use their own GL contexts as a general rule.  You MUST call +[CIGLScene prepCommonCIBackendToRenderOnContext:pixelFormat:] before calling this method!
- (id) initCommonBackendSceneSized:(VVSIZE)n;

//	these are the standard init methods for subclasses of GLScene- they produce instances that each have their own GL context.  they are deprecated because of a CoreImage bug i'm aware of- they still work, i just wouldn't recommend using them unless necessary.
#if !TARGET_OS_IPHONE
- (id) initWithSharedContext:(NSOpenGLContext *)c __deprecated;
- (id) initWithSharedContext:(NSOpenGLContext *)c sized:(VVSIZE)s __deprecated;
- (id) initWithSharedContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p __deprecated;
- (id) initWithSharedContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p sized:(VVSIZE)s __deprecated;
#else
- (id) initWithSharegroup:(EAGLSharegroup *)g sized:(VVSIZE)s __deprecated;
- (id) initWithSharegroup:(EAGLSharegroup *)g __deprecated;
- (id) initWithContext:(EAGLContext *)c __deprecated;
- (id) initWithContext:(EAGLContext *)c sized:(VVSIZE)s __deprecated;
#endif

///	Allocates a VVBuffer for a GL texture at the current size of this scene, then renders the passed CIImage into this texture
- (VVBuffer *) allocAndRenderBufferFromImage:(CIImage *)i;
- (void) renderCIImage:(CIImage *)i;
- (void) renderCIImage:(CIImage *)i inFBO:(GLuint)f colorTex:(GLuint)t;
///	this is the more low-level method for rendering a CIImage into explicitly-provided GL resources
/**
@param i the CIImage you wish to render to a GL resource
@param f the name of the fbo to which we'll be attaching the gl resources you want to render into
@param t the name of a GL texture that will be used as a color attachment to FBO f
@param tt the texture target of 't' (GL_TEXTURE_2D or GL_TEXTURE_RECTANGLE_EXT)
*/
- (void) renderCIImage:(CIImage *)i inFBO:(GLuint)f colorTex:(GLuint)t target:(GLuint)tt;

@property (readonly) CGColorSpaceRef workingColorSpace;
@property (readonly) CGColorSpaceRef outputColorSpace;
@property (readonly) CIContext *ciContext;
@property (assign,readwrite) id <CIGLSceneCleanup> cleanupDelegate;

@end

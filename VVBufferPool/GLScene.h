#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLMacro.h>
#import <VVBasics/VVBasics.h>
#import "VVBuffer.h"




extern OSSpinLock		_glSceneStatLock;
extern NSMutableArray	*_glGPUVendorArray;
extern NSMutableArray	*_hwGPUVendorArray;
extern BOOL				_integratedGPUFlag;	//	whether or not the scene is rendering on an integrated GPU
extern BOOL				_nvidiaGPUFlag;	//	whether or not the scene is rendering on an NVIDIA GPU
extern BOOL				_hasIntegratedAndDiscreteGPUsFlag;

typedef NS_ENUM(NSInteger, VVGLFlushMode)	{
	VVGLFlushModeGL = 0,	//	glFlush()
	VVGLFlushModeCGL = 1,	//	CGLFlushDrawable()
	VVGLFlushModeNS = 2,	//	[context flushBuffer]
	VVGLFlushModeApple = 3,	//	glFlushRenderAPPLE()
	VVGLFlushModeFinish = 4	//	glFinish()
};



///	Wrapper around a GL context with the intent of standardizing the more common render-to-texture operations while also making it easier to write customizable rendering code that doesn't necessarily require a different subclass for every purpose.  Most of the rendering classes I write either use an instance of GLScene to do their rendering or descend directly from it (GLScene's nature- a discrete GL context with built-in render-to-texture- makes it a good choice of superclass when adding support for other hardware-accelerated APIs).
/**
\ingroup VVBufferPool
much of the gl stuff i do is two-dimensional (using gl or gl-backed frameworks to process images/video), frequently in a multi-threaded environment (multiple GL contexts are rendering simultaneously on different threads and sharing resources- all in a threadsafe manner).

this class is basically a wrapper for a gl context.  it gives me a simple, reusable interface for rendering into a passed fbo/texture, and lets me treat it as a two-dimensional resource- this dovetails nicely with VVBuffer/VVBufferPool, which gives me a retain/release interface for managing these resources.

while this class is part of the VVBufferPool framework, the low-level methods for rendering take simple GL texture/renderbuffer names.  there's a higher-level method that returns a VVBuffer instance- but this class itself can be used with GL resources created outside this framework, as well.  likewise, subclasses of GLScene can generally be used with GL resources created outside this framework...
*/
@interface GLScene : NSObject {
	BOOL					deleted;
	BOOL					initialized;
	BOOL					needsReshape;
	OSSpinLock				renderThreadLock;	//	used to serialize access to "renderThreadDeleteArray", making it thread-safe
	MutLockArray			*renderThreadDeleteArray;	//	NOT RETAINED!  weak ref to an array you can add items to such that the items will be released on the thread that renders the scene.  useful if you need to ensure that rendering resources are released on the same thread that did the rendering.  only non-nil if this scene is being rendered on a thread created by a RenderThread class
	
	NSOpenGLContext			*sharedContext;	//	NOT retained! weak ref to the shared context, which is assumed to be retained elsewhere.
	NSOpenGLContext			*context;	//	RETAINED- the context i render into!
	NSOpenGLPixelFormat		*customPixelFormat;	//	the pixel format used by my context
	CGColorSpaceRef			colorSpace;
	
	id						renderTarget;	//	NOT RETAINED- the target of my render method
	SEL						renderSelector;	//	this method gets called when i render; ONLY does the actual drawing- does NOT do setup/cleanup (use _renderPrep and _renderCleanup)!
	OSSpinLock				renderBlockLock;
	void					(^renderBlock)(void);	//	RETAINED.  if you don't want to use a delegate/callback method for specifying drawing commands, you can use this block instead- it will get called when this scene is told to render
	
	GLuint					fbo;	//	the framebuffer my context renders into- only valid when the render method is called!
	GLuint					tex;	//	the fbo renders into this texture- only valid when the render method is called!
	GLuint					texTarget;	//	either GL_TEXTURE_RECTANGLE_EXT or GL_TEXTURE_2D.  both 'tex' and 'depth' much be using this target!
	GLuint					depth;	//	the depth buffer for context- only valid when the render method is called!
	
	GLuint					fboMSAA;	//	this fbo has renderbuffers which support MSAA attached to it- only valid when the render method is called!
	GLuint					colorMSAA;	//	the color renderbuffer attached to the msaa fbo- only valid when the render method is called!
	GLuint					depthMSAA;	//	the depth renderbuffer attached to the msaa fbo- only valid when the render method is called!
	
	NSSize					size;	//	the size of the this scene/the texture/framebuffer/viewport/etc
	BOOL					flipped;	//	whether or not the context renders upside-down.  NO by default, but some subclasses just render upside-down...
	
	BOOL					performClear;
	GLfloat					clearColor[4];
	BOOL					clearColorUpdated;
	VVGLFlushMode			flushMode;	//	0=glFlush(), 1=CGLFlushDrawable(), 2=[context flushBuffer]
	int						swapInterval;
}

///	Returns an array of the GPUs currently accessible by the renderer accessible being used with this process
+ (NSMutableArray *) gpuVendorArray;
///	Returns a YES if you're using an integrated GPU
+ (BOOL) integratedGPUFlag;
///	Returns a YES if you're using an NVIDIA GPU
+ (BOOL) nvidiaGPUFlag;
///	Returns a GL display mask that encompassess all your screens
+ (GLuint) glDisplayMaskForAllScreens;
///	Returns a default NSOpenGLPixelFormat instance.  If you don't explicitly set a pixel format when creating your instances of GLScene (and its subclasses), this is the pixel format that will be used
+ (NSOpenGLPixelFormat *) defaultPixelFormat;
+ (NSOpenGLPixelFormat *) doubleBufferPixelFormat;
+ (NSOpenGLPixelFormat *) defaultQTPixelFormat;
+ (NSOpenGLPixelFormat *) fsaaPixelFormat;
+ (NSOpenGLPixelFormat *) doubleBufferFSAAPixelFormat;

///	Init an instance of GLScene using the passed shared context.
- (id) initWithSharedContext:(NSOpenGLContext *)c;
///	Init an instance of GLScene using the passed shared context.  The GLScene will automatically be configured to render at the passed size.
- (id) initWithSharedContext:(NSOpenGLContext *)c sized:(NSSize)s;
///	Init an instance of GLScene using the passed shared context and pixel format
- (id) initWithSharedContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p;
///	Init an instance of GLScene using the passed shared context and pixel format.  The GLScene will automatically be configured to render at the passed size.
- (id) initWithSharedContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p sized:(NSSize)s;

- (id) initWithContext:(NSOpenGLContext *)c;
- (id) initWithContext:(NSOpenGLContext *)c sharedContext:(NSOpenGLContext *)sc;
- (id) initWithContext:(NSOpenGLContext *)c sized:(NSSize)s;
- (id) initWithContext:(NSOpenGLContext *)c sharedContext:(NSOpenGLContext *)sc sized:(NSSize)s;

- (void) generalInit;
- (void) prepareToBeDeleted;

///	Allocate a VVBuffer of the appropriate size, renders into this buffer, and then return it.  Probably the "main" rendering method.
- (VVBuffer *) allocAndRenderABuffer;
- (void) render;
- (void) renderInFBO:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d;
- (void) renderInMSAAFBO:(GLuint)mf colorRB:(GLuint)mc depthRB:(GLuint)md fbo:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d;
///	This is the low-level rendering method- if you want to fool around with MSAA or build a leaner interface, you'll probably want to use this.
/**
@param mf the name of an FBO that will be used for the MSAA rendering, or 0
@param mc the name of a renderbuffer that can be used as a color attachment for the mf FBO (this will be the image that you render- but not the "final" image), or 0
@param md the name of a renderbuffer that can be used as a depth attachment for the mf FBO, or 0
@param f the name of an FBO that will be used to blit the MSAA renderbuffer to a texture, or 0
@param t the name of a texture that can be used as a color attachment for the f FBO (this is probably going to be the texture that you want to work with), or 0
@param d the name of a texture that can be used as a depth attachment for the f FBO, or 0
@param texTarget the target of the textures used as attachments in t and d (2D or RECT)
*/
- (void) renderInMSAAFBO:(GLuint)mf colorRB:(GLuint)mc depthRB:(GLuint)md fbo:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d target:(GLuint)texTarget;
- (void) renderBlackFrameInFBO:(GLuint)f colorTex:(GLuint)t target:(GLuint)tt;
- (void) renderOpaqueBlackFrameInFBO:(GLuint)f colorTex:(GLuint)t target:(GLuint)tt;
- (void) renderRedFrameInFBO:(GLuint)f colorTex:(GLuint)t target:(GLuint)tt;
- (void) _renderPrep;
- (void) _initialize;
- (void) _reshape;
- (void) _renderCleanup;

- (NSOpenGLContext *) sharedContext;
- (NSOpenGLContext *) context;
- (CGLContextObj) CGLContextObj;
- (NSOpenGLPixelFormat *) customPixelFormat;
- (CGColorSpaceRef) colorSpace;
///	Set the size at which this scene should render
@property (assign,readwrite) NSSize size;
- (void) setFlipped:(BOOL)n;
- (BOOL) flipped;

- (void) setPerformClear:(BOOL)n;
///	Set the clear color from the passed NSColor
- (void) setClearNSColor:(NSColor *)c;
///	Set the clear color from the passed array of GLfloats
- (void) setClearColor:(GLfloat *)c;
///	Set the clear color from the passed color values
- (void) setClearColors:(GLfloat)r :(GLfloat)g :(GLfloat)b :(GLfloat)a;

@property (assign,readwrite) BOOL initialized;
///	Every time this scene renders, the "renderSelector" is called on "renderTarget"
@property (assign, readwrite) id renderTarget;
///	Every time this scene renders, the "renderSelector" is called on "renderTarget".  You put your drawing code in the "renderSelector".
@property (assign, readwrite) SEL renderSelector;
///	Every time this scene renders, the "renderBlock" is executed.  You put your drawing code in this block.
- (void) setRenderBlock:(void (^)(void))n;
@property (assign, readwrite) VVGLFlushMode flushMode;
@property (assign, readwrite) int swapInterval;

@end

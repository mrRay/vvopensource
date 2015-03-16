#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLMacro.h>
#import <Quartz/Quartz.h>
#import <VVBufferPool/VVBufferPool.h>
@class VVQCComposition;
#import <pthread.h>




extern BOOL					_QCGLSceneInitialized;
extern pthread_mutex_t			universalInitializeLock;	//	used because QC's backend is NOT threadsafe when creating compositions when there are 3rd-party QC plugins installed!
extern BOOL					_safeQCRenderFlag;	//	YES by default.  if YES, uses try/catch/throw exception handler around render calls to the QCRenderer (if there's a problem, this prevents the QC from getting "stuck")

//	sometime around 10.10, all CIContexts must be created from the same GL context or your machine will lock up and/or your GPU will crash when executing some CIFilters (or some combinations of CIFilters).
extern NSOpenGLContext			*_globalQCContextGLContext;
extern NSOpenGLContext			*_globalQCContextSharedContext;
extern NSOpenGLPixelFormat		*_globalQCContextPixelFormat;
extern pthread_mutex_t			_globalQCContextLock;




///	Subclass of GLScene for working with QC compositions
/**
\ingroup VVBufferPool
*/
@interface QCGLScene : GLScene {
	NSString			*filePath;
	VVQCComposition		*comp;		//	RETAINED!
	QCRenderer			*renderer;	//	RETAINED!
	VVStopwatch			*stopwatch;
	//MutLockDict			*mouseEventDict;	//	used to pass mouse event info to this scene/renderer from another thread!
	MutLockArray		*mouseEventArray;	//	fills up with dicts which are passed to the renderer on the render thread
	pthread_mutex_t		renderLock;
}

///	If you want all instances of QCGLScene to use a single specific OpenGL context to render (CGLLockContext()/CGLUnlockContext() will be called before any rendering is performed), you need to call this method and pass it the context and pixel format you'll be using to do all the rendering.  Once you've called this, instances of QCGLScene that use the common backend can be instantiated via -[QCGLScene initCommonBackendSceneSized:].
+ (void) prepCommonQCBackendToRenderOnContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p;
///	If you create a QCGLScene using this method, the scene won't allocate its own OpenGL context- instead, it will create its local CIContext instance from the common backend's GL context.  This is worth noting because by default, GLScene and all subclasses of it create and use their own GL contexts as a general rule.  You MUST call +[QCGLScene prepCommonQCBackendToRenderOnContext:pixelFormat:] before calling this method!
- (id) initCommonBackendSceneSized:(NSSize)n;

//	these are the standard init methods for subclasses of GLScene- they produce instances that each have their own GL context.  they are deprecated because of a CoreImage bug i'm aware of- they still work, i just wouldn't recommend using them unless necessary.  (and no, this isn't a typo- i know this is documentation for QCGLScene, but QC uses CoreImage extensively in its backend and is subject to CoreImage-based bugs).
- (id) initWithSharedContext:(NSOpenGLContext *)c __deprecated;
- (id) initWithSharedContext:(NSOpenGLContext *)c sized:(NSSize)s __deprecated;
- (id) initWithSharedContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p __deprecated;
- (id) initWithSharedContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p sized:(NSSize)s __deprecated;

/**
@brief Load the QC composition at the passed path. Threadsafe- this method doesn't invoke the QC runtime, instead it creates a VVQCComposition instance for the passed path so you can check out the basic properties of the composition.  The QCRenderer/QC runtime doesn't get created until you render a frame (or explicitly create a renderer)
@param p an NSString with the full path to a QC composition
*/
- (void) useFile:(NSString *)p;
- (void) useFile:(NSString *)p resetTimer:(BOOL)t;
- (void) _actuallyDisplayVidInAlertForFile:(NSString *)p;

///	when you first load a file, the QCRenderer instance is nil (the QC runtime should only be initialized on the same thread it's rendered on, else it will leak resources).  by default, the QCRenderer is initialized during rendering- if you reeeeeally want access to the renderer, you can call this method to force creation of the QCRenderer.  please be careful with this method- you should only call it on the same thread you'll be using to render the QC composition, and this thread should probably be a RenderThread!
- (void) prepareRendererIfNeeded;

///	the currently loaded file path
- (NSString *) filePath;
///	the VVQCComposition for the currently-loaded file
- (VVQCComposition *) comp;
///	the QCRenderer for the currently-loaded file.  this is nil when you first load a file- the QCRenderer will be nil until you tell the scene to render, or explicitly create the renderer via the prepareRendererIfNeeded method
- (QCRenderer *) renderer;
- (MutLockArray *) mouseEventArray;

- (void) _renderLock;
- (void) _renderUnlock;

@end

#import <Cocoa/Cocoa.h>
#import <OpenGL/CGLMacro.h>
#import "VVBuffer.h"
#import <pthread.h>
#import "VVSizingTool.h"
#import <libkern/OSAtomic.h>




///	subclass of NSOpenGLView, fastest and easiest way to display a VVBuffer.  automatically sizes the buffer proportionally to fit.
/**
\ingroup VVBufferPool
*/
@interface VVBufferGLView : NSOpenGLView {
	BOOL		initialized;
	pthread_mutex_t			renderLock;
	
	VVSizingMode	sizingMode;
	
	BOOL			retainDraw;
	OSSpinLock		retainDrawLock;
	VVBuffer		*retainDrawBuffer;
	
	BOOL			onlyDrawNewStuff;	//	NO by default. if YES, only draws buffers with content timestamps different from the timestamp of the last buffer displayed
	OSSpinLock		onlyDrawNewStuffLock;
	struct timeval	onlyDrawNewStuffTimestamp;
}

- (void) redraw;
///	Draws the passd buffer
- (void) drawBuffer:(VVBuffer *)b;
///	Sets the GL context to share- this is generally done automatically (using the global buffer pool's shared context), but if you want to override it and use a different context...this is how.
- (void) setSharedGLContext:(NSOpenGLContext *)c;

@property (assign,readwrite) BOOL initialized;
@property (assign,readwrite) VVSizingMode sizingMode;
- (void) setRetainDraw:(BOOL)n;
- (void) setRetainDrawBuffer:(VVBuffer *)n;
@property (assign,readwrite) BOOL onlyDrawNewStuff;

@end

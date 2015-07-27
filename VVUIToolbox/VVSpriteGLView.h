
#import <Cocoa/Cocoa.h>
#import "VVSpriteManager.h"
#import <OpenGL/OpenGL.h>
#import <libkern/OSAtomic.h>
#import "VVView.h"




#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
typedef NS_ENUM(NSInteger, VVFenceMode)	{
	VVFenceModeEveryRefresh = 0,	//	every time a display callback runs, drawing commands are sent to the GPU.
	VVFenceModeDBSkip = 1,	//	the apple gl fence extension is used to make sure that drawing commands for the back buffer have finished before more drawing commands are sent to the back buffer (the front buffer can receive commands, though)
	VVFenceModeSBSkip = 2,	//	the apple gl fence extension is used to make sure that drawing commands for the single buffer have finished before more drawing commands are sent to it
	VVFenceModeFinish = 3	//	glFinish is used instead of glFlush
};
typedef NS_ENUM(NSInteger, VVFlushMode)	{
	VVFlushModeGL = 0,	//	glFlush()
	VVFlushModeCGL = 1,	//	CGLFlushDrawable()
	VVFlushModeNS = 2,	//	[context flushBuffer]
	VVFlushModeApple = 3,	//	glFlushRenderAPPLE()
	VVFlushModeFinish = 4	//	glFinish()
};
#else
typedef enum VVFenceMode	{
	VVFenceModeEveryRefresh = 0,	//	every time a display callback runs, drawing commands are sent to the GPU.
	VVFenceModeDBSkip = 1,	//	the apple gl fence extension is used to make sure that drawing commands for the back buffer have finished before more drawing commands are sent to the back buffer (the front buffer can receive commands, though)
	VVFenceModeSBSkip = 2,	//	the apple gl fence extension is used to make sure that drawing commands for the single buffer have finished before more drawing commands are sent to it
	VVFenceModeFinish = 3	//	glFinish is used instead of glFlush
} VVFenceMode;
typedef enum VVFlushMode	{
	VVFlushModeGL = 0,	//	glFlush()
	VVFlushModeCGL = 1,	//	CGLFlushDrawable()
	VVFlushModeNS = 2,	//	[context flushBuffer]
	VVFlushModeApple = 3,	//	glFlushRenderAPPLE()
	VVFlushModeFinish = 4	//	glFinish()
} VVFlushMode;
#endif


//	i need a simple (read: fast) var describing which OS this is
extern long			_spriteGLViewSysVers;
//	this protocol eliminates warnings- this class is typically compiled against the 10.6 SDK, and this method for NSOpenGLView first appears in the 10.7 SDK.
@protocol HiddenNSOpenGLViewAdditions
- (VVRECT) convertRectToBacking:(VVRECT)n;
- (void) setWantsBestResolutionOpenGLSurface:(BOOL)n;
- (BOOL) wantsBestResolutionOpenGLSurface;
@end




@interface VVSpriteGLView : NSOpenGLView {
	BOOL					deleted;
	
	BOOL					initialized;
	//BOOL					needsReshape;
	pthread_mutex_t			glLock;
	BOOL					flipped;	//	whether or not the context renders upside-down.  NO by default, but some subclasses just render upside-down...
	double					localToBackingBoundsMultiplier;
	MutLockArray			*vvSubviews;
	id						dragNDropSubview;	//	NOT RETAINED
	
	VVSpriteManager			*spriteManager;
	BOOL					spritesNeedUpdate;
	NSEvent					*lastMouseEvent;
	GLfloat					clearColor[4];
	BOOL					drawBorder;
	GLfloat					borderColor[4];
	
	long					mouseDownModifierFlags;
	VVSpriteEventType		mouseDownEventType;
	long					modifierFlags;
	BOOL					mouseIsDown;
	VVView					*clickedSubview;	//	NOT RETAINED
	
	VVFlushMode				flushMode;
	
	VVFenceMode				fenceMode;
	GLuint					fenceA;
	GLuint					fenceB;
	BOOL					waitingForFenceA;
	BOOL					fenceADeployed;
	BOOL					fenceBDeployed;
	OSSpinLock				fenceLock;
}

- (void) generalInit;
- (void) prepareToBeDeleted;

- (void) performDrawing:(VVRECT)r;
- (void) initializeGL;
- (void) finishedDrawing;
//- (void) reshapeGL;
- (void) updateSprites;
- (VVRECT) backingBounds;	//	GL views don't respect NSView's "bounds", even if the GL view is on a retina machine and its bounds are of a different dpi than the frame.  this returns the # of pixels this view is rendering.
- (double) localToBackingBoundsMultiplier;

- (void) _lock;
- (void) _unlock;
//- (void) lockSetOpenGLContext:(NSOpenGLContext *)n;
- (void) addVVSubview:(id)n;
- (void) removeVVSubview:(id)n;
- (BOOL) containsSubview:(id)n;
- (id) vvSubviewHitTest:(VVPOINT)p;
- (void) reconcileVVSubviewDragTypes;

@property (readonly) BOOL deleted;
@property (assign,readwrite) BOOL initialized;
- (BOOL) flipped;
- (void) setFlipped:(BOOL)n;
@property (readonly) double localToBackingBoundsMultiplier;
@property (readonly) MutLockArray *vvSubviews;
@property (assign, readwrite) BOOL spritesNeedUpdate;
- (void) setSpritesNeedUpdate;
@property (readonly) NSEvent *lastMouseEvent;
@property (retain,readwrite) NSColor *clearColor;
- (void) setClearColors:(GLfloat)r :(GLfloat)g :(GLfloat)b :(GLfloat)a;
@property (assign,readwrite) BOOL drawBorder;
@property (retain,readwrite) NSColor *borderColor;
@property (readonly) VVSpriteManager *spriteManager;
@property (readonly) long mouseDownModifierFlags;
@property (assign,readwrite) VVSpriteEventType mouseDownEventType;
@property (readonly) long modifierFlags;
@property (readonly) BOOL mouseIsDown;
- (void) _setMouseIsDown:(BOOL)n;	//	used to work around the fact that NSViews don't get a "mouseUp" when they open a contextual menu
@property (assign, readwrite) VVFlushMode flushMode;

@end

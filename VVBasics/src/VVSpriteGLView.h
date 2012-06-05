
#import <Cocoa/Cocoa.h>
#import "VVSpriteManager.h"
#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLMacro.h>
#import <libkern/OSAtomic.h>




typedef enum	{
	VVFenceModeEveryRefresh = 0,	//	every time a display callback runs, drawing commands are sent to the GPU.
	VVFenceModeDBSkip = 1,	//	the apple gl fence extension is used to make sure that drawing commands for the back buffer have finished before more drawing commands are sent to the back buffer (the front buffer can receive commands, though)
	VVFenceModeSBSkip = 2,	//	the apple gl fence extension is used to make sure that drawing commands for the single buffer have finished before more drawing commands are sent to it
	VVFenceModeFinish = 3	//	glFinish is used instead of glFlush
} VVFenceMode;

typedef enum	{
	VVFlushModeGL = 0,	//	glFlush()
	VVFlushModeCGL = 1,	//	CGLFlushDrawable()
	VVFlushModeNS = 2,	//	[context flushBuffer]
	VVFlushModeApple = 3,	//	glFlushRenderAPPLE()
	VVFlushModeFinish = 4	//	glFinish()
} VVFlushMode;




@interface VVSpriteGLView : NSOpenGLView {
	BOOL					deleted;
	
	BOOL					initialized;
	//BOOL					needsReshape;
	pthread_mutex_t			glLock;
	BOOL					flipped;	//	whether or not the context renders upside-down.  NO by default, but some subclasses just render upside-down...
	
	VVSpriteManager			*spriteManager;
	BOOL					spritesNeedUpdate;
	NSEvent					*lastMouseEvent;
	GLfloat					clearColor[4];
	BOOL					drawBorder;
	GLfloat					borderColor[4];
	
	long					mouseDownModifierFlags;
	BOOL					mouseIsDown;
	NSView					*clickedSubview;	//	NOT RETAINED
	
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

- (void) initializeGL;
- (void) finishedDrawing;
//- (void) reshapeGL;
- (void) updateSprites;

- (void) _lock;
- (void) _unlock;
//- (void) lockSetOpenGLContext:(NSOpenGLContext *)n;

@property (readonly) BOOL deleted;
@property (assign,readwrite) BOOL initialized;
@property (assign,readwrite) BOOL flipped;
@property (assign, readwrite) BOOL spritesNeedUpdate;
- (void) setSpritesNeedUpdate;
@property (readonly) NSEvent *lastMouseEvent;
@property (retain,readwrite) NSColor *clearColor;
@property (assign,readwrite) BOOL drawBorder;
@property (retain,readwrite) NSColor *borderColor;
@property (readonly) VVSpriteManager *spriteManager;
@property (readonly) BOOL mouseIsDown;
@property (assign, readwrite) VVFlushMode flushMode;

@end

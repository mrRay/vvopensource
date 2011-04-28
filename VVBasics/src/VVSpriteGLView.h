
#import <Cocoa/Cocoa.h>
#import "VVSpriteManager.h"
#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLMacro.h>
#import <libkern/OSAtomic.h>




@interface VVSpriteGLView : NSOpenGLView {
	BOOL					deleted;
	
	BOOL					initialized;
	//BOOL					needsReshape;
	pthread_mutex_t			glLock;
	
	VVSpriteManager			*spriteManager;
	BOOL					spritesNeedUpdate;
	NSEvent					*lastMouseEvent;
	GLfloat					clearColor[4];
	int						mouseDownModifierFlags;
	BOOL					mouseIsDown;
	NSView					*clickedSubview;	//	NOT RETAINED
	
	int						flushMode;	//	0=glFlush(), 1=CGLFlushDrawable(), 2=[context flushBuffer]
	
	BOOL					fenceOutput;
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
@property (assign, readwrite) BOOL spritesNeedUpdate;
- (void) setSpritesNeedUpdate;
@property (readonly) NSEvent *lastMouseEvent;
@property (retain,readwrite) NSColor *clearColor;
@property (readonly) VVSpriteManager *spriteManager;
@property (readonly) BOOL mouseIsDown;
@property (assign, readwrite) int flushMode;

@end

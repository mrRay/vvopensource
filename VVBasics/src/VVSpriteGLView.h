
#import <Cocoa/Cocoa.h>
#import "VVSpriteManager.h"
#import <OpenGL/CGLMacro.h>




@interface VVSpriteGLView : NSOpenGLView {
	BOOL					deleted;
	
	BOOL					initialized;
	//BOOL					needsReshape;
	pthread_mutex_t			glLock;
	
	VVSpriteManager			*spriteManager;
	BOOL					spritesNeedUpdate;
	NSEvent					*lastMouseEvent;
	int						mouseDownModifierFlags;
	BOOL					mouseIsDown;
	NSView					*clickedSubview;	//	NOT RETAINED
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
@property (readonly) VVSpriteManager *spriteManager;
@property (readonly) BOOL mouseIsDown;

@end

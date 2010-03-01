
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
}

- (void) generalInit;
- (void) prepareToBeDeleted;

- (void) initializeGL;
//- (void) reshapeGL;
- (void) updateSprites;

@property (assign, readwrite) BOOL spritesNeedUpdate;
@property (readonly) NSEvent *lastMouseEvent;
@property (readonly) VVSpriteManager *spriteManager;

@end

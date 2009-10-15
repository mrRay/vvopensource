
#import <Cocoa/Cocoa.h>
#import "VVSpriteManager.h"
#import <OpenGL/CGLMacro.h>




@interface VVSpriteGLView : NSOpenGLView {
	BOOL					deleted;
	
	BOOL					initialized;
	//BOOL					needsReshape;
	
	VVSpriteManager			*spriteManager;
	BOOL					spritesNeedUpdate;
	NSEvent					*lastMouseEvent;
}

- (void) generalInit;
- (void) prepareToBeDeleted;

- (void) initializeGL;
//- (void) reshapeGL;
- (void) updateSprites;

@property (assign, readwrite) BOOL spritesNeedUpdate;
@property (readonly) NSEvent *lastMouseEvent;

@end

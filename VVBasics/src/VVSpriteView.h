
#import <Cocoa/Cocoa.h>
#import "VVSpriteManager.h"




@interface VVSpriteView : NSView {
	BOOL					deleted;
	VVSpriteManager			*spriteManager;
	BOOL					spritesNeedUpdate;
	NSEvent					*lastMouseEvent;
}

- (void) generalInit;

- (void) prepareToBeDeleted;
- (void) updateSprites;

@property (readonly) VVSpriteManager *spriteManager;
@property (assign, readwrite) BOOL spritesNeedUpdate;
@property (readonly) NSEvent *lastMouseEvent;

@end

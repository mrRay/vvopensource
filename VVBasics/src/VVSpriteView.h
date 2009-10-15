
#import <Cocoa/Cocoa.h>
#import "VVSpriteManager.h"




@interface VVSpriteView : NSView {
	BOOL					deleted;
	VVSpriteManager			*spriteManager;
	BOOL					spritesNeedUpdate;
	NSEvent					*lastMouseEvent;
}

- (void) prepareToBeDeleted;
- (void) updateSprites;

@property (assign, readwrite) BOOL spritesNeedUpdate;
@property (readonly) NSEvent *lastMouseEvent;

@end

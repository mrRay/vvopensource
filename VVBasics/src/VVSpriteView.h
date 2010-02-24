
#import <Cocoa/Cocoa.h>
#import "VVSpriteManager.h"




@interface VVSpriteView : NSView {
	BOOL					deleted;
	VVSpriteManager			*spriteManager;
	BOOL					spritesNeedUpdate;
	NSEvent					*lastMouseEvent;
	NSColor					*clearColor;
	int						mouseDownModifierFlags;
}

- (void) generalInit;

- (void) prepareToBeDeleted;
- (void) updateSprites;

@property (readonly) VVSpriteManager *spriteManager;
@property (assign, readwrite) BOOL spritesNeedUpdate;
@property (readonly) NSEvent *lastMouseEvent;
@property (retain,readwrite) NSColor *clearColor;

@end

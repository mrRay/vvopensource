
#import <Cocoa/Cocoa.h>
#import "VVSpriteManager.h"
#include <libkern/OSAtomic.h>




extern int					_maxSpriteControlCount;
extern int					_spriteControlCount;




@interface VVSpriteControl : NSControl {
	BOOL					deleted;
	VVSpriteManager			*spriteManager;
	BOOL					spritesNeedUpdate;
	
	OSSpinLock				propertyLock;
	NSEvent					*lastMouseEvent;
	NSColor					*clearColor;
	BOOL					drawBorder;
	NSColor					*borderColor;
	
	long					mouseDownModifierFlags;
	BOOL					mouseIsDown;
	NSView					*clickedSubview;	//	NOT RETAINED
}

- (void) generalInit;

- (void) prepareToBeDeleted;

- (void) finishedDrawing;

- (void) updateSprites;

@property (readonly) BOOL deleted;
@property (readonly) VVSpriteManager *spriteManager;
@property (assign, readwrite) BOOL spritesNeedUpdate;
- (void) setSpritesNeedUpdate;
@property (readonly) NSEvent *lastMouseEvent;
@property (retain,readwrite) NSColor *clearColor;
@property (assign,readwrite) BOOL drawBorder;
@property (retain,readwrite) NSColor *borderColor;
@property (readonly) BOOL mouseIsDown;

@end

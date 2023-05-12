
#import <Cocoa/Cocoa.h>
#import "VVSpriteManager.h"
#include <libkern/OSAtomic.h>
#import "VVView.h"




extern int				_spriteViewCount;




@interface VVSpriteView : NSView <VVViewContainer>	{
	BOOL					deleted;
	VVSpriteManager			*spriteManager;
	BOOL					spritesNeedUpdate;
	
	VVLock				propertyLock;
	NSEvent					*lastMouseEvent;
	NSColor					*clearColor;
	BOOL					drawBorder;
	NSColor					*borderColor;
	
	long					mouseDownModifierFlags;
	VVSpriteEventType		mouseDownEventType;
	long					modifierFlags;
	BOOL					mouseIsDown;
	__weak NSView			*clickedSubview;	//	NOT RETAINED
	
	MutLockArray			*vvSubviews;
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
@property (strong,readwrite) NSColor *clearColor;
@property (assign,readwrite) BOOL drawBorder;
@property (strong,readwrite) NSColor *borderColor;
@property (readonly) long mouseDownModifierFlags;
@property (assign,readwrite) VVSpriteEventType mouseDownEventType;
@property (readonly) long modifierFlags;
@property (readonly) BOOL mouseIsDown;

- (void) addVVSubview:(VVView *)n;
- (void) removeVVSubview:(VVView *)n;
- (BOOL) containsSubview:(VVView *)n;
- (VVView *) vvSubviewHitTest:(VVPOINT)p;

@end

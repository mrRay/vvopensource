#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "VVSprite.h"
#import <VVBasics/VVBasics.h>




extern BOOL			_spriteManagerInitialized;
extern MutLockArray		*_spriteManagerArray;




@interface VVSpriteManager : NSObject {
	BOOL					deleted;
	BOOL					allowMultiSpriteInteraction;	//	NO by default- if YES, clicking/dragging/etc works with multiple sprites!
	BOOL					multiSpriteExecutesOnMultipleSprites;	//	only relevant if multi-sprite interaction is YES.  this is NO by default- if it's YES all sprites in "spritesInUse" will receive an action callback when any of them get an action method.  if this is NO then only the sprite that "caught" the interaction will receive an action callback!
	MutLockArray			*spriteArray;	//	searched from beginning to end, so order is like z-index!
#if IPHONE
	MutNRLockDict			*perTouchSpritesInUse;	//	key is UITouch instance, value is ObjectHolder (with a ZWR) pointing to the VVSprite the UITouch should be forwarded to
	MutLockDict				*perTouchMultiSpritesInUse;	//	same idea as above, but only used if "allowMultiSpriteInteraction" is YES.  insted of an ObjectHolder for the val, there's a MutLockArray (which contains the ObjectHolders for sprites, each of which should be sent the UITouch values received on interaction)
#else
	VVSprite				*spriteInUse;	//	array of VVSprite objects currently tracking drag info
	MutLockArray			*spritesInUse;	//	ONLY VALID IF MULTI SPRITE INTERACTION IS YES! array of VVSprite o
#endif
	long					spriteIndexCount;
}

- (void) prepareToBeDeleted;

#if IPHONE
//	returns a YES if the down occurred on one or more sprites
- (BOOL) receivedDownEvent:(VVSpriteEventType)e forTouch:(UITouch *)t atPoint:(VVPOINT)p visibleOnly:(BOOL)v;
- (void) receivedOtherEvent:(VVSpriteEventType)e forTouch:(UITouch *)t atPoint:(VVPOINT)p;
- (BOOL) localTouch:(UITouch *)t downAtPoint:(VVPOINT)p;
- (BOOL) localTouch:(UITouch *)t visibleDownAtPoint:(VVPOINT)p;
- (void) localTouch:(UITouch *)t draggedAtPoint:(VVPOINT)p;
- (void) localTouch:(UITouch *)t upAtPoint:(VVPOINT)p;
- (void) terminateTouch:(UITouch *)t;
#else
//	return YES if the mousedown occurred on one or more sprites
- (BOOL) receivedMouseDownEvent:(VVSpriteEventType)e atPoint:(VVPOINT)p withModifierFlag:(long)m visibleOnly:(BOOL)v;
- (void) receivedOtherEvent:(VVSpriteEventType)e atPoint:(VVPOINT)p withModifierFlag:(long)m;
- (BOOL) localMouseDown:(VVPOINT)p modifierFlag:(long)m;
- (BOOL) localVisibleMouseDown:(VVPOINT)p modifierFlag:(long)m;
- (BOOL) localRightMouseDown:(VVPOINT)p modifierFlag:(long)m;
- (BOOL) localVisibleRightMouseDown:(VVPOINT)p modifierFlag:(long)m;
- (void) localRightMouseUp:(VVPOINT)p;
- (void) localMouseDragged:(VVPOINT)p;
- (void) localMouseUp:(VVPOINT)p;
- (void) terminatePresentMouseSession;	//	call this and sprites will stop responding to the mouse until it is clicked again
#endif

- (id) makeNewSpriteAtBottomForRect:(VVRECT)r;
- (id) makeNewSpriteAtTopForRect:(VVRECT)r;
- (long) getUniqueSpriteIndex;

- (VVSprite *) spriteAtPoint:(VVPOINT)p;
- (NSMutableArray *) spritesAtPoint:(VVPOINT)p;
- (VVSprite *) visibleSpriteAtPoint:(VVPOINT)p;
- (VVSprite *) spriteForIndex:(long)i;
- (void) removeSpriteForIndex:(long)i;
- (void) removeSprite:(id)z;
- (void) removeSpritesFromArray:(NSArray *)array;
- (void) removeAllSprites;
//- (void) moveSpriteToFront:(VVSprite *)z;

- (void) draw;
- (void) drawRect:(VVRECT)r;
#if !IPHONE
- (void) drawInContext:(CGLContextObj)cgl_ctx;
- (void) drawRect:(VVRECT)r inContext:(CGLContextObj)cgl_ctx;
#endif

#if !IPHONE
- (VVSprite *) spriteInUse;
- (void) setSpriteInUse:(VVSprite *)z;
#endif

@property (assign,readwrite) BOOL allowMultiSpriteInteraction;
@property (assign,readwrite) BOOL multiSpriteExecutesOnMultipleSprites;
@property (readonly) MutLockArray *spriteArray;
#if !IPHONE
@property (readonly) MutLockArray *spritesInUse;
#endif

@end

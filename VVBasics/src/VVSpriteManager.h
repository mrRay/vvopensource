
#import <Cocoa/Cocoa.h>
#import "VVSprite.h"
#import "MutLockArray.h"




extern BOOL			_spriteManagerInitialized;
MutLockArray		*_spriteManagerArray;




@interface VVSpriteManager : NSObject {
	BOOL					deleted;
	BOOL					allowMultiSpriteInteraction;	//	NO by default- if YES, clicking/dragging/etc works with multiple sprites!
	BOOL					multiSpriteExecutesOnMultipleSprites;	//	only relevant if multi-sprite interaction is YES.  this is NO by default- if it's YES all sprites in "spritesInUse" will receive an action callback when any of them get an action method.  if this is NO then only the sprite that "caught" the interaction will receive an action callback!
	MutLockArray			*spriteArray;	//	searched from beginning to end, so order is like z-index!
	VVSprite				*spriteInUse;	//	array of VVSprite objects currently tracking drag info
	MutLockArray			*spritesInUse;	//	ONLY VALID IF MULTI SPRITE INTERACTION IS YES! array of VVSprite o
	long					spriteIndexCount;
}

- (void) prepareToBeDeleted;

//	return YES if the mousedown occurred on one or more sprites
- (BOOL) receivedMouseDownEvent:(VVSpriteEventType)e atPoint:(NSPoint)p withModifierFlag:(long)m visibleOnly:(BOOL)v;
- (void) receivedOtherEvent:(VVSpriteEventType)e atPoint:(NSPoint)p withModifierFlag:(long)m;
- (BOOL) localMouseDown:(NSPoint)p modifierFlag:(long)m;
- (BOOL) localVisibleMouseDown:(NSPoint)p modifierFlag:(long)m;
- (BOOL) localRightMouseDown:(NSPoint)p modifierFlag:(long)m;
- (BOOL) localVisibleRightMouseDown:(NSPoint)p modifierFlag:(long)m;
- (void) localRightMouseUp:(NSPoint)p;
- (void) localMouseDragged:(NSPoint)p;
- (void) localMouseUp:(NSPoint)p;
- (void) terminatePresentMouseSession;	//	call this and sprites will stop responding to the mouse until it is clicked again

- (id) newSpriteAtBottomForRect:(NSRect)r;
- (id) newSpriteAtTopForRect:(NSRect)r;
- (long) getUniqueSpriteIndex;

- (VVSprite *) spriteAtPoint:(NSPoint)p;
- (NSMutableArray *) spritesAtPoint:(NSPoint)p;
- (VVSprite *) visibleSpriteAtPoint:(NSPoint)p;
- (VVSprite *) spriteForIndex:(long)i;
- (void) removeSpriteForIndex:(long)i;
- (void) removeSprite:(id)z;
- (void) removeSpritesFromArray:(NSArray *)array;
- (void) removeAllSprites;
//- (void) moveSpriteToFront:(VVSprite *)z;

- (void) draw;
- (void) drawRect:(NSRect)r;

- (VVSprite *) spriteInUse;
- (void) setSpriteInUse:(VVSprite *)z;

@property (assign,readwrite) BOOL allowMultiSpriteInteraction;
@property (assign,readwrite) BOOL multiSpriteExecutesOnMultipleSprites;
@property (readonly) MutLockArray *spriteArray;
@property (readonly) MutLockArray *spritesInUse;

@end

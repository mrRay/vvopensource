
#import <Cocoa/Cocoa.h>
#import "VVSprite.h"
#import "MutLockArray.h"




@interface VVSpriteManager : NSObject {
	BOOL					deleted;
	MutLockArray			*spriteArray;	//	searched from beginning to end, so order is like z-index!
	VVSprite				*spriteInUse;	//	array of VVSprite objects currently tracking drag info
	long					spriteIndexCount;
}

- (void) prepareToBeDeleted;

- (BOOL) localMouseDown:(NSPoint)p;
- (BOOL) localRightMouseDown:(NSPoint)p;
- (void) localRightMouseUp:(NSPoint)p;
- (void) localMouseDragged:(NSPoint)p;
- (void) localMouseUp:(NSPoint)p;

- (id) newSpriteAtBottomForRect:(NSRect)r;
- (id) newSpriteAtTopForRect:(NSRect)r;
- (long) getUniqueSpriteIndex;

- (VVSprite *) spriteAtPoint:(NSPoint)p;
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

@property (readonly) MutLockArray *spriteArray;

@end


#import <Cocoa/Cocoa.h>
#import "VVSprite.h"
#import "MutLockArray.h"




@interface VVSpriteManager : NSObject {
	BOOL					deleted;
	MutLockArray			*zoneArray;	//	searched from beginning to end, so order is like z-index!
	VVSprite					*zoneInUse;	//	array of VVSprite objects currently tracking drag info
	long					zoneIndexCount;
}

- (void) prepareToBeDeleted;

- (BOOL) localMouseDown:(NSPoint)p;
- (void) localMouseDragged:(NSPoint)p;
- (void) localMouseUp:(NSPoint)p;

- (id) newZoneAtBottomForRect:(NSRect)r;
- (id) newZoneAtTopForRect:(NSRect)r;
- (long) getUniqueZoneIndex;

- (VVSprite *) zoneAtPoint:(NSPoint)p;
- (VVSprite *) zoneForIndex:(long)i;
- (void) removeZoneForIndex:(long)i;
- (void) removeZone:(id)z;
- (void) removeAllZones;

- (void) draw;
- (void) drawRect:(NSRect)r;

- (VVSprite *) zoneInUse;
- (void) setZoneInUse:(VVSprite *)z;

@property (readonly) MutLockArray *zoneArray;

@end

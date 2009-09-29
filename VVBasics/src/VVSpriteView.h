
#import <Cocoa/Cocoa.h>
#import "VVSpriteManager.h"




@interface VVSpriteView : NSView {
	BOOL					deleted;
	VVSpriteManager			*spriteManager;
	BOOL					pathsAndZonesNeedUpdate;
	NSEvent					*lastMouseEvent;
}

- (void) prepareToBeDeleted;
- (void) updatePathsAndZones;

@property (assign, readwrite) BOOL pathsAndZonesNeedUpdate;
@property (readonly) NSEvent *lastMouseEvent;

@end

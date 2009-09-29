
#import <Cocoa/Cocoa.h>
#import "VVSpriteManager.h"
#import <OpenGL/CGLMacro.h>




@interface VVSpriteGLView : NSOpenGLView {
	BOOL					deleted;
	
	BOOL					initialized;
	BOOL					needsReshape;
	
	VVSpriteManager			*spriteManager;
	BOOL					pathsAndZonesNeedUpdate;
	NSEvent					*lastMouseEvent;
}

- (void) generalInit;
- (void) prepareToBeDeleted;

- (void) initializeGL;
- (void) reshapeGL;
- (void) updatePathsAndZones;

@property (assign, readwrite) BOOL pathsAndZonesNeedUpdate;
@property (readonly) NSEvent *lastMouseEvent;

@end

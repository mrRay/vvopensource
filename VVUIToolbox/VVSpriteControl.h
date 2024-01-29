
#import <Cocoa/Cocoa.h>
#import <VVUIToolbox/VVSpriteManager.h>
#include <libkern/OSAtomic.h>




extern int					_maxSpriteControlCount;
extern int					_spriteControlCount;




@interface VVSpriteControl : NSControl {
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
	__weak NSView					*clickedSubview;	//	NOT RETAINED
}

- (void) generalInit;

- (void) prepareToBeDeleted;

- (void) finishedDrawing;

- (void) updateSprites;

@property (readonly) BOOL deleted;
@property (readwrite) double localToBackingBoundsMultiplier;
@property (readonly) VVSpriteManager *spriteManager;
@property (assign, readwrite) BOOL spritesNeedUpdate;
- (void) setSpritesNeedUpdate;
@property (readonly) NSEvent *lastMouseEvent;
@property (strong,strong) NSColor *clearColor;
@property (assign,readwrite) BOOL drawBorder;
@property (strong,strong) NSColor *borderColor;
@property (readonly) long mouseDownModifierFlags;
@property (assign,readwrite) VVSpriteEventType mouseDownEventType;
@property (readonly) long modifierFlags;
@property (readonly) BOOL mouseIsDown;
- (void) _setMouseIsDown:(BOOL)n;	//	used to work around the fact that NSViews don't get a "mouseUp" when they open a contextual menu

//	local, thread-safe version of NSView's 'boundsRotation' property (and other properties)
@property (atomic,readwrite) CGFloat localBoundsRotation;
@property (atomic,readwrite) NSRect localBounds;
@property (atomic,readwrite) NSRect localBackingBounds;
@property (atomic,readwrite) NSRect localFrame;
//@property (atomic,readwrite) NSSize localFrameSize;
@property (atomic,readwrite,weak) NSWindow * localWindow;
@property (atomic,readwrite) BOOL localHidden;
@property (atomic,readwrite) NSRect localVisibleRect;	//	updated on setNeedsDisplay and on changes to bounds or frame
- (VVRECT) convertRectToLocalBackingBounds:(VVRECT)n;

@end

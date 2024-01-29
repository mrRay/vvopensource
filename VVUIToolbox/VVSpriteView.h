
#import <Cocoa/Cocoa.h>
#import <VVUIToolbox/VVSpriteManager.h>
#include <libkern/OSAtomic.h>
#import <VVUIToolbox/VVView.h>




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
@property (readwrite) double localToBackingBoundsMultiplier;
@property (readonly) NSEvent *lastMouseEvent;
@property (strong,readwrite) NSColor *clearColor;
@property (assign,readwrite) BOOL drawBorder;
@property (strong,readwrite) NSColor *borderColor;
@property (readonly) long mouseDownModifierFlags;
@property (assign,readwrite) VVSpriteEventType mouseDownEventType;
@property (readonly) long modifierFlags;
@property (readonly) BOOL mouseIsDown;

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

- (void) addVVSubview:(VVView *)n;
- (void) removeVVSubview:(VVView *)n;
- (BOOL) containsSubview:(VVView *)n;
- (VVView *) vvSubviewHitTest:(VVPOINT)p;

@end

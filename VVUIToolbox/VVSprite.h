
/*				Always with the sprites...
		
		sprite |sprīt|
		noun
		1 an elf or fairy.
		2 a computer graphic that may be moved on-screen and otherwise manipulated as a single entity.
		3 a faint flash, typically red, sometimes emitted in the upper atmosphere over a thunderstorm owing to the collision of high-energy electrons with air molecules.
		ORIGIN Middle English : alteration of sprit, a contraction of spirit .			*/

#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <VVBasics/VVBasics.h>
#include <libkern/OSAtomic.h>




#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
typedef NS_ENUM(NSInteger, VVSpriteEventType)	{
	VVSpriteEventNULL = 0,
	VVSpriteEventDown = 1,
	VVSpriteEventDrag = 2,
	VVSpriteEventUp = 3,
	VVSpriteEventDouble = 4,
	VVSpriteEventRightDown = 5,
	VVSpriteEventRightUp = 6
};
#else
typedef enum VVSpriteEventType	{
	VVSpriteEventNULL = 0,
	VVSpriteEventDown = 1,
	VVSpriteEventDrag = 2,
	VVSpriteEventUp = 3,
	VVSpriteEventDouble = 4,
	VVSpriteEventRightDown = 5,
	VVSpriteEventRightUp = 6
} VVSpriteEventType;
#endif




@interface VVSprite : NSObject {
	BOOL			deleted;
	BOOL			locked;				//	whether or not i should respond to mouse input.  DOESN'T AFFECT ANYTHING IN THIS CLASS!  variable exists for the user's convenience, and is otherwise superfluous!
	BOOL			hidden;				//	whether or not the sprite should draw.  DOESN'T AFFECT ANYTHING IN THIS CLASS!  variable exists for the user's convenience, and is otherwise superfluous!
	BOOL			dropFromMultiSpriteActions;	//	only valid if sprite manager's allowMultiSpriteInteraction' is YES.  NO by default.  if YES, then if you mousedown on this and any other sprite, this sprite gets dropped from the mousedown.  used for allowing multi-sprite interaction to prevent clicks from hitting "background" sprites (which have this set to YES)
	long			spriteIndex;
	id				manager;			//	the VVSpriteManager i exist within- NOT retained!
	id				delegate;			//	NOT retained!
	SEL				drawCallback;		//	delegate method; passed a ptr to this sprite!
	SEL				actionCallback;		//	delegate method; passed a ptr to this sprite!
#if !IPHONE
	CGLContextObj	glDrawContext;		//	NOT retained! if "drawInContext:" is called, this is set to the passed context- so my delegate can retrieve it and use it for GL drawing!
#endif
	
	VVRECT			rect;				//	the sprite i'm tracking
#if IPHONE
	UIBezierPath	*bezierPath;		//	retained.  nil by default, set to nil if you call setRect: on this instance.  if non-nil, this path is used isntead of "rect" for determining mouse action and drawing intersection!
#else
	NSBezierPath	*bezierPath;		//	retained.  nil by default, set to nil if you call setRect: on this instance.  if non-nil, this path is used instead of "rect" for determining mouse action and drawing intersection!
#endif
	OSSpinLock		pathLock;
	
	int				lastActionType;		//	updated whenever an action is received
	VVPOINT			lastActionCoords;	//	coords at which last action took place
	BOOL			lastActionInBounds;	//	whether or not the last action was within my bounds
	BOOL			trackingFlag;		//	whether or not i'm tracking stuff
	VVPOINT			mouseDownCoords;	//	absolute coords of mousedown
	VVPOINT			lastActionDelta;	//	change between most-recently-received action coords and last received coords
	VVPOINT			mouseDownDelta;		//	change between mousedown loc and most-recently received coords
	long			mouseDownModifierFlags;
	
	id				userInfo;		//	RETAINED!  for storing a random thing...
	id				NRUserInfo;		//	NOT RETAINED!  for storing something that *shouldn't* be retained...
	id				safeString;	//	nil on init- many sprites need formatted text, this is a convenience variable...
}

+ (id) createWithRect:(VVRECT)r inManager:(id)m;
- (id) initWithRect:(VVRECT)r inManager:(id)m;

- (void) prepareToBeDeleted;

- (BOOL) checkPoint:(VVPOINT)p;
- (BOOL) checkRect:(VVRECT)r;

- (void) receivedEvent:(VVSpriteEventType)e atPoint:(VVPOINT)p withModifierFlag:(long)m;
- (void) mouseDown:(VVPOINT)p modifierFlag:(long)m;
- (void) rightMouseDown:(VVPOINT)p modifierFlag:(long)m;
- (void) rightMouseUp:(VVPOINT)p;
- (void) mouseDragged:(VVPOINT)p;
- (void) mouseUp:(VVPOINT)p;
- (void) draw;
#if !IPHONE
- (void) drawInContext:(CGLContextObj)cgl_ctx;
#endif

- (void) bringToFront;
- (void) sendToBack;

@property (assign, readwrite) BOOL locked;
@property (assign, readwrite) BOOL hidden;
@property (assign, readwrite) BOOL dropFromMultiSpriteActions;
@property (readonly) long spriteIndex;
@property (readonly) id manager;
@property (assign, readwrite) id delegate;
@property (assign, readwrite) SEL drawCallback;
@property (assign, readwrite) SEL actionCallback;
#if !IPHONE
@property (readonly) CGLContextObj glDrawContext;
#endif

@property (assign, readwrite) VVRECT rect;
//@property (retain,readwrite) NSBezierPath *path;
#if IPHONE
- (void) setBezierPath:(UIBezierPath *)n;
- (UIBezierPath *) copyBezierPath;
#else
- (void) setBezierPath:(NSBezierPath *)n;
- (NSBezierPath *) copyBezierPath;
#endif
- (VVRECT) spriteBounds;	//	special method- either returns "rect" or (if path is non-nil) the bounds of the bezier path!
@property (readonly) VVSpriteEventType lastActionType;
@property (readonly) VVPOINT lastActionCoords;
@property (readonly) BOOL lastActionInBounds;
@property (readonly) BOOL trackingFlag;
@property (readonly) VVPOINT mouseDownCoords;
@property (readonly) VVPOINT lastActionDelta;
@property (readonly) VVPOINT mouseDownDelta;
@property (readonly) long mouseDownModifierFlags;
@property (assign,readwrite) id userInfo;
@property (assign,readwrite) id NRUserInfo;
@property (assign,readwrite) id safeString;

@end

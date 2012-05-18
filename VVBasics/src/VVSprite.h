
/*				Always with the sprites...
		
		sprite |sprīt|
		noun
		1 an elf or fairy.
		2 a computer graphic that may be moved on-screen and otherwise manipulated as a single entity.
		3 a faint flash, typically red, sometimes emitted in the upper atmosphere over a thunderstorm owing to the collision of high-energy electrons with air molecules.
		ORIGIN Middle English : alteration of sprit, a contraction of spirit .			*/

#import <Cocoa/Cocoa.h>
#include <libkern/OSAtomic.h>




typedef enum _VVSpriteEventType	{
	VVSpriteEventNULL = 0,
	VVSpriteEventDown = 1,
	VVSpriteEventDrag = 2,
	VVSpriteEventUp = 3,
	VVSpriteEventDouble = 4,
	VVSpriteEventRightDown = 5,
	VVSpriteEventRightUp = 6
} VVSpriteEventType;




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
	
	NSRect			rect;				//	the sprite i'm tracking
	NSBezierPath	*bezierPath;		//	retained.  nil by default, set to nil if you call setRect: on this instance.  if non-nil, this path is used instead of "rect" for determining mouse action and drawing intersection!
	OSSpinLock		pathLock;
	
	int				lastActionType;		//	updated whenever an action is received
	NSPoint			lastActionCoords;	//	coords at which last action took place
	BOOL			lastActionInBounds;	//	whether or not the last action was within my bounds
	BOOL			trackingFlag;		//	whether or not i'm tracking stuff
	NSPoint			mouseDownCoords;	//	absolute coords of mousedown
	NSPoint			lastActionDelta;	//	change between most-recently-received action coords and last received coords
	NSPoint			mouseDownDelta;		//	change between mousedown loc and most-recently received coords
	long			mouseDownModifierFlags;
	
	id				userInfo;		//	RETAINED!  for storing a random thing...
	id				NRUserInfo;		//	NOT RETAINED!  for storing something that *shouldn't* be retained...
	id				safeString;	//	nil on init- many sprites need formatted text, this is a convenience variable...
}

+ (id) createWithRect:(NSRect)r inManager:(id)m;
- (id) initWithRect:(NSRect)r inManager:(id)m;

- (void) prepareToBeDeleted;

- (BOOL) checkPoint:(NSPoint)p;
- (BOOL) checkRect:(NSRect)r;

- (void) receivedEvent:(VVSpriteEventType)e atPoint:(NSPoint)p withModifierFlag:(long)m;
- (void) mouseDown:(NSPoint)p modifierFlag:(long)m;
- (void) rightMouseDown:(NSPoint)p modifierFlag:(long)m;
- (void) rightMouseUp:(NSPoint)p;
- (void) mouseDragged:(NSPoint)p;
- (void) mouseUp:(NSPoint)p;
- (void) draw;

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

@property (assign, readwrite) NSRect rect;
//@property (retain,readwrite) NSBezierPath *path;
- (void) setBezierPath:(NSBezierPath *)n;
- (NSBezierPath *) safelyGetBezierPath;
- (NSRect) spriteBounds;	//	special method- either returns "rect" or (if path is non-nil) the bounds of the bezier path!
@property (readonly) VVSpriteEventType lastActionType;
@property (readonly) NSPoint lastActionCoords;
@property (readonly) BOOL lastActionInBounds;
@property (readonly) BOOL trackingFlag;
@property (readonly) NSPoint mouseDownCoords;
@property (readonly) NSPoint lastActionDelta;
@property (readonly) NSPoint mouseDownDelta;
@property (readonly) long mouseDownModifierFlags;
@property (assign,readwrite) id userInfo;
@property (assign,readwrite) id NRUserInfo;
@property (assign,readwrite) id safeString;

@end


#import <Cocoa/Cocoa.h>




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
	long			spriteIndex;
	id				manager;			//	the VVSpriteManager i exist within- NOT retained!
	id				delegate;			//	NOT retained!
	SEL				drawCallback;		//	delegate method; passed a ptr to this sprite!
	SEL				actionCallback;		//	delegate method; passed a ptr to this sprite!
	
	NSRect			rect;				//	the sprite i'm tracking
	int				lastActionType;		//	updated whenever an action is received
	NSPoint			lastActionCoords;	//	coords at which last action took place
	BOOL			lastActionInBounds;	//	whether or not the last action was within my bounds
	BOOL			trackingFlag;		//	whether or not i'm tracking stuff
	NSPoint			mouseDownCoords;	//	absolute coords of mousedown
	NSPoint			lastActionDelta;	//	change between most-recently-received action coords and last received coords
	NSPoint			mouseDownDelta;		//	change between mousedown loc and most-recently received coords
	
	id				userInfo;		//	RETAINED!  for storing a random thing...
	id				NRUserInfo;		//	NOT RETAINED!  for storing something that *shouldn't* be retained...
	id				safeString;	//	nil on init- many sprites need formatted text, this is a convenience variable...
}

+ (id) createWithRect:(NSRect)r inManager:(id)m;
- (id) initWithRect:(NSRect)r inManager:(id)m;

- (void) prepareToBeDeleted;

- (BOOL) checkPoint:(NSPoint)p;

- (void) mouseDown:(NSPoint)p;
- (void) rightMouseDown:(NSPoint)p;
- (void) rightMouseUp:(NSPoint)p;
- (void) mouseDragged:(NSPoint)p;
- (void) mouseUp:(NSPoint)p;
- (void) draw;

- (void) bringToFront;
- (void) sendToBack;

@property (assign, readwrite) BOOL locked;
@property (assign, readwrite) BOOL hidden;
@property (readonly) long spriteIndex;
@property (readonly) id manager;
@property (assign, readwrite) id delegate;
@property (assign, readwrite) SEL drawCallback;
@property (assign, readwrite) SEL actionCallback;

@property (assign, readwrite) NSRect rect;
@property (readonly) VVSpriteEventType lastActionType;
@property (readonly) NSPoint lastActionCoords;
@property (readonly) BOOL lastActionInBounds;
@property (readonly) BOOL trackingFlag;
@property (readonly) NSPoint mouseDownCoords;
@property (readonly) NSPoint lastActionDelta;
@property (readonly) NSPoint mouseDownDelta;
@property (assign,readwrite) id userInfo;
@property (assign,readwrite) id NRUserInfo;
@property (assign,readwrite) id safeString;

@end

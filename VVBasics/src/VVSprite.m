
#import "VVSprite.h"
#import "VVSpriteManager.h"
#import "VVBasicMacros.h"




@implementation VVSprite


/*===================================================================================*/
#pragma mark --------------------- create/destroy
/*------------------------------------*/
+ (id) createWithRect:(NSRect)r inManager:(id)m	{
	VVSprite		*returnMe = [[VVSprite alloc] initWithRect:r inManager:m];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithRect:(NSRect)r inManager:(id)m	{
	if ((m==nil)||(r.size.width==0)||(r.size.height==0)||(r.origin.x==NSNotFound)||(r.origin.y==NSNotFound))	{
		[self release];
		return nil;
	}
	if (self = [super init])	{
		deleted = NO;
		locked = NO;
		hidden = NO;
		dropFromMultiSpriteActions = NO;
		spriteIndex = -1;
		manager = m;
		spriteIndex = [manager getUniqueSpriteIndex];
		delegate = nil;
		drawCallback = nil;
		actionCallback = nil;
		glDrawContext = NULL;
		
		rect = r;
		bezierPath = nil;
		pathLock = OS_SPINLOCK_INIT;
		lastActionType = VVSpriteEventNULL;
		lastActionCoords = NSMakePoint(NSNotFound,NSNotFound);
		lastActionInBounds = NO;
		trackingFlag = NO;
		mouseDownCoords = NSMakePoint(NSNotFound,NSNotFound);
		lastActionDelta = NSMakePoint(NSNotFound,NSNotFound);
		mouseDownDelta = NSMakePoint(NSNotFound,NSNotFound);
		mouseDownModifierFlags = 0;
		
		userInfo = nil;
		NRUserInfo = nil;
		safeString = nil;
		return self;
	}
	[self release];
	return nil;
}
- (void) prepareToBeDeleted	{
	//NSLog(@"%s",__func__);
	deleted = YES;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (!deleted)
		[self prepareToBeDeleted];
	
	manager = nil;
	VVRELEASE(userInfo);
	VVRELEASE(safeString);
	VVRELEASE(bezierPath);
	[super dealloc];
}

/*===================================================================================*/
#pragma mark --------------------- action and draw
/*------------------------------------*/

- (BOOL) checkPoint:(NSPoint)p	{
	//NSLog(@"%s",__func__);
	//NSPointLog(@"\t\tchecking point",p);
	//NSRectLog(@"\t\tagainst rect",rect);
	BOOL		returnMe = NO;
	OSSpinLockLock(&pathLock);
	if (bezierPath==nil)	{
		OSSpinLockUnlock(&pathLock);
		returnMe = NSPointInRect(p,rect);
	}
	else	{
		returnMe = [bezierPath containsPoint:p];
		OSSpinLockUnlock(&pathLock);
	}
	return returnMe;
}
- (BOOL) checkRect:(NSRect)r	{
	BOOL		returnMe = NO;
	OSSpinLockLock(&pathLock);
	if (bezierPath==nil)	{
		OSSpinLockUnlock(&pathLock);
		returnMe = NSIntersectsRect(rect,r);
	}
	else	{
		returnMe = NSIntersectsRect([bezierPath bounds],r);
		OSSpinLockUnlock(&pathLock);
	}
	return returnMe;
}


- (void) receivedEvent:(VVSpriteEventType)e atPoint:(NSPoint)p withModifierFlag:(long)m	{
	if (deleted)
		return;
	
	switch (e)	{
		case VVSpriteEventUp:
		case VVSpriteEventRightUp:
			trackingFlag = NO;
		case VVSpriteEventDrag:
			//	calculate the deltas
			if (lastActionType == VVSpriteEventDown)	{
				lastActionDelta = NSMakePoint(p.x-mouseDownCoords.x, p.y-mouseDownCoords.y);
				mouseDownDelta = NSMakePoint(p.x-mouseDownCoords.x, p.y-mouseDownCoords.y);
			}
			else	{
				lastActionDelta = NSMakePoint(p.x-lastActionCoords.x, p.y-lastActionCoords.y);
				mouseDownDelta = NSMakePoint(p.x-mouseDownCoords.x, p.y-mouseDownCoords.y);
			}
			break;
		case VVSpriteEventDown:
		case VVSpriteEventDouble:
		case VVSpriteEventRightDown:
			trackingFlag = NO;
			mouseDownCoords = p;
			lastActionDelta = NSMakePoint(0,0);
			mouseDownDelta = NSMakePoint(0,0);
			mouseDownModifierFlags = m;
			break;
		case VVSpriteEventNULL:
			break;
	}
	
	if (e == VVSpriteEventDown)
		trackingFlag = YES;
	
	//	update the action type and coords
	lastActionType = e;
	lastActionCoords = p;
	
	if ([self checkPoint:p])
		lastActionInBounds = YES;
	else
		lastActionInBounds = NO;
	
	//	if there's a delegate and it has an action callback, call it
	if ((delegate!=nil)&&(actionCallback!=nil)&&([delegate respondsToSelector:actionCallback]))
		[delegate performSelector:actionCallback withObject:self];
}
- (void) mouseDown:(NSPoint)p modifierFlag:(long)m	{
	[self receivedEvent:VVSpriteEventDown atPoint:p withModifierFlag:m];
}
- (void) rightMouseDown:(NSPoint)p modifierFlag:(long)m	{
	[self receivedEvent:VVSpriteEventRightDown atPoint:p withModifierFlag:m];
}
- (void) rightMouseUp:(NSPoint)p	{
	[self receivedEvent:VVSpriteEventRightUp atPoint:p withModifierFlag:0];
}
- (void) mouseDragged:(NSPoint)p	{
	[self receivedEvent:VVSpriteEventDrag atPoint:p withModifierFlag:0];
}
- (void) mouseUp:(NSPoint)p	{
	[self receivedEvent:VVSpriteEventUp atPoint:p withModifierFlag:0];
}


- (void) draw	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(delegate==nil)||(drawCallback==nil)||(![delegate respondsToSelector:drawCallback]))
		return;
	glDrawContext = NULL;
	[delegate performSelector:drawCallback withObject:self];
}
- (void) drawInContext:(CGLContextObj)cgl_ctx	{
	if ((deleted)||(delegate==nil)||(drawCallback==nil)||(![delegate respondsToSelector:drawCallback]))
		return;
	glDrawContext = cgl_ctx;
	[delegate performSelector:drawCallback withObject:self];
	glDrawContext = NULL;
}
- (void) bringToFront	{
	//NSLog(@"%s",__func__);
	if ((deleted) || (manager==nil))
		return;
	//	get my manager's sprite array- if it's nil or has < 2 items, bail (nothing to do)
	MutLockArray		*managerSpriteArray = [manager spriteArray];
	if ((managerSpriteArray==nil) || ([managerSpriteArray count]<2))
		return;
	//	get a write-lock on the array, i'll be changing its order
	[managerSpriteArray wrlock];
		//	retain me so i don't get released during any of this silliness
		[self retain];
		//	remove me from my manager's sprite array
		[managerSpriteArray removeIdenticalPtr:self];
		//	add me to my manager's sprite array at the "top"
		[managerSpriteArray insertObject:self atIndex:0];
		//	autorelease me, so the impact on my retain count has been a net 0
		[self autorelease];
	//	unlock the array
	[managerSpriteArray unlock];
}
- (void) sendToBack	{
	//NSLog(@"%s",__func__);
	if ((deleted) || (manager==nil))
		return;
	//	get my manager's sprite array- if it's nil or has < 2 items, bail (nothing to do)
	MutLockArray		*managerSpriteArray = [manager spriteArray];
	if ((managerSpriteArray==nil) || ([managerSpriteArray count]<2))
		return;
	//	get a write-lock on the array, i'll be changing its order
	[managerSpriteArray wrlock];
		//	retain me so i don't get released during any of this silliness
		[self retain];
		//	remove me from my manager's sprite array
		[managerSpriteArray removeIdenticalPtr:self];
		//	add me to my manager's sprite array at the "bottom"
		[managerSpriteArray addObject:self];
		//	autorelease me, so the impact on my retain count has been a net 0
		[self autorelease];
	//	unlock the array
	[managerSpriteArray unlock];
}

/*===================================================================================*/
#pragma mark --------------------- key/value
/*------------------------------------*/

- (void) setLocked:(BOOL)n	{
	locked = n;
}
- (BOOL) locked	{
	return locked;
}
- (void) setHidden:(BOOL)n	{
	hidden = n;
}
- (BOOL) hidden	{
	return hidden;
}
- (void) setDropFromMultiSpriteActions:(BOOL)n	{
	dropFromMultiSpriteActions = n;
}
- (BOOL) dropFromMultiSpriteActions	{
	return dropFromMultiSpriteActions;
}
- (long) spriteIndex	{
	return spriteIndex;
}
- (id) manager	{
	return manager;
}
- (void) setDelegate:(id)t	{
	delegate = t;
}
- (id) delegate	{
	return delegate;
}
- (void) setDrawCallback:(SEL)n	{
	drawCallback = n;
}
- (SEL) drawCallback	{
	return drawCallback;
}
- (void) setActionCallback:(SEL)n	{
	actionCallback = n;
}
- (SEL) actionCallback	{
	return actionCallback;
}
- (CGLContextObj) glDrawContext	{
	return glDrawContext;
}


- (void) setRect:(NSRect)n	{
	//NSLog(@"%s ... %ld",__func__,spriteIndex);
	//NSRectLog(@"\trect",n);
	NSRect		oldRect = rect;
	NSPoint		delta = NSMakePoint(n.origin.x-oldRect.origin.x, n.origin.y-oldRect.origin.y);
	rect = n;
	lastActionCoords = NSMakePoint(lastActionCoords.x+delta.x, lastActionCoords.y+delta.y);
	mouseDownCoords = NSMakePoint(mouseDownCoords.x+delta.x, mouseDownCoords.y+delta.y);
	
	OSSpinLockLock(&pathLock);
	VVRELEASE(bezierPath);
	OSSpinLockUnlock(&pathLock);
}
- (NSRect) rect	{
	return rect;
}
- (void) setBezierPath:(NSBezierPath *)n	{
	OSSpinLockLock(&pathLock);
	VVRELEASE(bezierPath);
	if (n != nil)
		bezierPath = [n retain];
	OSSpinLockUnlock(&pathLock);
}
- (NSBezierPath *) safelyGetBezierPath	{
	NSBezierPath		*returnMe = nil;
	OSSpinLockLock(&pathLock);
	if (bezierPath != nil)
		returnMe = [bezierPath copy];
	OSSpinLockUnlock(&pathLock);
	return returnMe;
}
- (NSRect) spriteBounds	{
	NSRect		returnMe = NSZeroRect;
	OSSpinLockLock(&pathLock);
	if (bezierPath==nil)
		returnMe = rect;
	else
		returnMe = [bezierPath bounds];
	OSSpinLockUnlock(&pathLock);
	return returnMe;
}
- (VVSpriteEventType) lastActionType	{
	return lastActionType;
}
- (NSPoint) lastActionCoords	{
	return lastActionCoords;
}
- (BOOL) lastActionInBounds	{
	return lastActionInBounds;
}
- (BOOL) trackingFlag	{
	return trackingFlag;
}
- (NSPoint) mouseDownCoords	{
	return mouseDownCoords;
}
- (NSPoint) lastActionDelta	{
	return lastActionDelta;
}
- (NSPoint) mouseDownDelta	{
	return mouseDownDelta;
}
@synthesize mouseDownModifierFlags;
- (void) setUserInfo:(id)n	{
	//NSLog(@"%s ... %@",__func__,n);
	VVRELEASE(userInfo);
	if (n != nil)
		userInfo = [n retain];
}
- (id) userInfo	{
	return userInfo;
}
@synthesize NRUserInfo;
- (void) setSafeString:(id)n	{
	VVRELEASE(safeString);
	if (n != nil)
		safeString = [n retain];
}
- (id) safeString	{
	return safeString;
}


@end

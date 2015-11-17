//
//  VVView.m
//  VVOpenSource
//
//  Created by bagheera on 11/1/12.
//
//

#import "VVView.h"
#import "VVBasicMacros.h"
#if !IPHONE
#import <OpenGL/CGLMacro.h>
#import "VVSpriteGLView.h"
#endif
#import "VVScrollView.h"
#import <tgmath.h>



//	macro for performing a bitmask and returning a BOOL
#define VVBITMASKCHECK(mask,flagToCheck) ((mask & flagToCheck) == flagToCheck) ? ((BOOL)YES) : ((BOOL)NO)




@implementation VVView


/*===================================================================================*/
#pragma mark --------------------- init/dealloc
/*------------------------------------*/


- (id) initWithFrame:(VVRECT)n	{
	if (self = [super init])	{
		[self generalInit];
		_frame = n;
		//_bounds = VVMAKERECT(0,0,_frame.size.width,_frame.size.height);
		[self initComplete];
		return self;
	}
	[self release];
	return nil;
}
- (void) generalInit	{
	deleted = NO;
	spriteManager = [[VVSpriteManager alloc] init];
	spritesNeedUpdate = YES;
	
	pthread_mutexattr_t		attr;
	pthread_mutexattr_init(&attr);
	//pthread_mutexattr_settype(&attr,PTHREAD_MUTEX_NORMAL);
	pthread_mutexattr_settype(&attr,PTHREAD_MUTEX_RECURSIVE);
	pthread_mutex_init(&spritesUpdateLock,&attr);
	pthread_mutexattr_destroy(&attr);
	
#if !IPHONE
	spriteCtx = NULL;
#endif
	needsDisplay = YES;
	_frame = VVMAKERECT(0,0,1,1);
	minFrameSize = VVMAKESIZE(1.0,1.0);
	localToBackingBoundsMultiplier = 1.0;
	//_bounds = _frame;
	_boundsOrigin = VVMAKEPOINT(0.0, 0.0);
	_boundsOrientation = VVViewBOBottom;
	//_boundsRotation = 0.0;
#if IPHONE
	boundsProjectionEffectLock = OS_SPINLOCK_INIT;
	boundsProjectionEffect = nil;
	boundsProjectionEffectNeedsUpdate = YES;
#else
	trackingAreas = [[MutLockArray alloc] init];
#endif
	_superview = nil;
	_containerView = nil;
	subviews = [[MutLockArray alloc] init];
	autoresizesSubviews = YES;
	autoresizingMask = VVViewResizeMaxXMargin | VVViewResizeMinYMargin;
	propertyLock = OS_SPINLOCK_INIT;
#if !IPHONE
	lastMouseEvent = nil;
#endif
	isOpaque = NO;
	for (int i=0;i<4;++i)	{
		clearColor[i] = 0.0;
		borderColor[i] = 0.0;
	}
	drawBorder = NO;
	mouseDownModifierFlags = 0;
	mouseDownEventType = VVSpriteEventNULL;
	modifierFlags = 0;
	mouseIsDown = NO;
	clickedSubview = nil;
	dragTypes = [[MutLockArray alloc] init];
}
- (void) initComplete	{

}
- (void) prepareToBeDeleted	{
	NSMutableArray		*subCopy = [subviews lockCreateArrayCopy];
	if (subCopy != nil)	{
		[subCopy retain];
		for (id subview in subCopy)
			[self removeSubview:subview];
		[subCopy removeAllObjects];
		[subCopy release];
		subCopy = nil;
	}
	
	if (_superview != nil)
		[_superview removeSubview:self];
	else if (_containerView != nil)
		[_containerView removeVVSubview:self];
	
	pthread_mutex_destroy(&spritesUpdateLock);
	if (spriteManager != nil)
		[spriteManager prepareToBeDeleted];
	spritesNeedUpdate = NO;
	deleted = YES;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(subviews);
	OSSpinLockLock(&propertyLock);
#if !IPHONE
	VVRELEASE(lastMouseEvent);
#endif
	OSSpinLockUnlock(&propertyLock);
	VVRELEASE(dragTypes);
#if IPHONE
	OSSpinLockLock(&boundsProjectionEffectLock);
	VVRELEASE(boundsProjectionEffect);
	boundsProjectionEffectNeedsUpdate = NO;
	OSSpinLockUnlock(&boundsProjectionEffectLock);
#else
	VVRELEASE(trackingAreas);
#endif
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- first responder stuff
/*------------------------------------*/





/*===================================================================================*/
#pragma mark --------------------- touch interaction via UITouch
/*------------------------------------*/


#if IPHONE
- (void) touchBegan:(UITouch *)touch withEvent:(UIEvent *)event	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	VVRECT			containerBounds = (_containerView==nil) ? VVMAKERECT(0,0,1,1) : [_containerView bounds];
	VVPOINT			containerPoint = [touch locationInView:_containerView];
	containerPoint.y = containerBounds.size.height-containerPoint.y;
	VVPOINT			localPoint = [self convertPointFromContainerViewCoords:containerPoint];
	//VVPointLog(@"\t\tlocalPoint A is",localPoint);
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	//VVPointLog(@"\t\tlocalPoint B is",localPoint);
	[spriteManager localTouch:touch downAtPoint:localPoint];
}
- (void) touchMoved:(UITouch *)touch withEvent:(UIEvent *)event	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	VVRECT			containerBounds = (_containerView==nil) ? VVMAKERECT(0,0,1,1) : [_containerView bounds];
	VVPOINT			containerPoint = [touch locationInView:_containerView];
	containerPoint.y = containerBounds.size.height-containerPoint.y;
	VVPOINT			localPoint = [self convertPointFromContainerViewCoords:containerPoint];
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	[spriteManager localTouch:touch draggedAtPoint:localPoint];
}
- (void) touchEnded:(UITouch *)touch withEvent:(UIEvent *)event	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	VVRECT			containerBounds = (_containerView==nil) ? VVMAKERECT(0,0,1,1) : [_containerView bounds];
	VVPOINT			containerPoint = [touch locationInView:_containerView];
	containerPoint.y = containerBounds.size.height-containerPoint.y;
	VVPOINT			localPoint = [self convertPointFromContainerViewCoords:containerPoint];
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	[spriteManager localTouch:touch upAtPoint:localPoint];
}
- (void) touchCancelled:(UITouch *)touch withEvent:(UIEvent *)event	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	VVRECT			containerBounds = (_containerView==nil) ? VVMAKERECT(0,0,1,1) : [_containerView bounds];
	VVPOINT			containerPoint = [touch locationInView:_containerView];
	containerPoint.y = containerBounds.size.height-containerPoint.y;
	VVPOINT			localPoint = [self convertPointFromContainerViewCoords:containerPoint];
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	[spriteManager terminateTouch:touch];
}
#endif


/*===================================================================================*/
#pragma mark --------------------- mouse & key interaction via NSEvent
/*------------------------------------*/


#if !IPHONE
- (void) mouseDown:(NSEvent *)e	{
	//NSLog(@"%s ... %@",__func__,self);
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
	mouseIsDown = YES;
	VVPOINT		locationInWindow = [e locationInWindow];
	//VVPointLog(@"\t\tlocationInWindow is",locationInWindow);
	VVPOINT		localPoint = [self convertPointFromWinCoords:locationInWindow];
	//VVPointLog(@"\t\tlocalPoint A is",localPoint);
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	//VVPointLog(@"\t\tlocalPoint B is",localPoint);
	mouseDownModifierFlags = [e modifierFlags];
	modifierFlags = mouseDownModifierFlags;
	if ((mouseDownModifierFlags&NSControlKeyMask)==NSControlKeyMask)	{
		mouseDownEventType = VVSpriteEventRightDown;
		[spriteManager localRightMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
	}
	else	{
		mouseDownEventType = VVSpriteEventDown;
		[spriteManager localMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
	}
}
- (void) rightMouseDown:(NSEvent *)e	{
	//NSLog(@"%s ... %@",__func__,self);
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
	mouseDownModifierFlags = [e modifierFlags];
	mouseDownEventType = VVSpriteEventRightDown;
	modifierFlags = mouseDownModifierFlags;
	mouseIsDown = YES;
	VVPOINT		locationInWindow = [e locationInWindow];
	VVPOINT		localPoint = [self convertPointFromWinCoords:locationInWindow];
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	[spriteManager localRightMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
}
- (void) mouseDragged:(NSEvent *)e	{
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
	modifierFlags = [e modifierFlags];
	VVPOINT		localPoint = [self convertPointFromWinCoords:[e locationInWindow]];
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	[spriteManager localMouseDragged:localPoint];
}
- (void) rightMouseDragged:(NSEvent *)e	{
	[self mouseDragged:e];
}
- (void) mouseUp:(NSEvent *)e	{
	if (deleted)
		return;
	
	if (mouseDownEventType == VVSpriteEventRightDown)	{
		[self rightMouseUp:e];
		return;
	}
	
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
	modifierFlags = [e modifierFlags];
	mouseIsDown = NO;
	VVPOINT		localPoint = [self convertPointFromWinCoords:[e locationInWindow]];
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	[spriteManager localMouseUp:localPoint];
}
- (void) rightMouseUp:(NSEvent *)e	{
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
	modifierFlags = [e modifierFlags];
	mouseIsDown = NO;
	VVPOINT		localPoint = [self convertPointFromWinCoords:[e locationInWindow]];
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	[spriteManager localRightMouseUp:localPoint];
}
//	entered & exited are sent if the view is using tracking objects!
- (void) mouseEntered:(NSEvent *)e	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
}
- (void) mouseExited:(NSEvent *)e	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
}
- (void) mouseMoved:(NSEvent *)e	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
}
- (void) scrollWheel:(NSEvent *)e	{
	if (deleted)
		return;
	//	don't bother doing anything with "lastMouseEvent", this is a scroll action
	//	find the first superview which is an instance of the "VVScrollView" class, tell it to scroll
	if ([e type] != NSScrollWheel)
		NSLog(@"\t\terr: event wasn't of type NSScrollWheel in %s",__func__);
	else	{
		id		scrollView = [self enclosingScrollView];
		if (_spriteGLViewSysVers >= 7)	{
			if (scrollView != nil)
				[scrollView scrollByAmount:VVMAKEPOINT([e scrollingDeltaX],[e scrollingDeltaY])];
		}
	}
}
- (void) keyDown:(NSEvent *)e	{
	NSLog(@"%s ... %@",__func__,e);
}
- (void) keyUp:(NSEvent *)e	{
	NSLog(@"%s ... %@",__func__,e);
}
- (NSDraggingSession *) beginDraggingSessionWithItems:(NSArray *)items event:(NSEvent *)event source:(id<NSDraggingSource>)source	{
	if (deleted)
		return nil;
	NSDraggingSession		*returnMe = nil;
	if (_containerView != nil)	{
		returnMe = [_containerView
			beginDraggingSessionWithItems:items
			event:event
			source:source];
	}
	return returnMe;
}
#endif


/*===================================================================================*/
#pragma mark --------------------- geometry- rect/point intersect & conversion
/*------------------------------------*/


//	the point it's passed is in coords local to the superview- i need to see if the coords are in my frame!
- (id) vvSubviewHitTest:(VVPOINT)superviewPoint	{
	//NSLog(@"%s ... %@- (%0.2f, %0.2f)",__func__,self,superviewPoint.x,superviewPoint.y);
	if (deleted)
		return nil;
	if (!VVPOINTINRECT(superviewPoint, _frame))	{
		return nil;
	}
	
	/*		if i'm here, the passed point was within my frame- check to 
			see if it's hitting any of my subviews, otherwise return self!		*/
	
	VVPOINT			localPoint = superviewPoint;
	localPoint.x -= _frame.origin.x;
	localPoint.y -= _frame.origin.y;
	
#if IPHONE
	CGAffineTransform	trans = CGAffineTransformIdentity;
#else
	NSAffineTransform	*trans = [NSAffineTransform transform];
#endif
	VVPOINT				tmpPoint;
	switch (_boundsOrientation)	{
		case VVViewBOBottom:
			//[trans rotateByDegrees:0.0];
			//localPoint = [trans transformPoint:localPoint];
			localPoint = VVADDPOINT(localPoint, _boundsOrigin);
			break;
		case VVViewBORight:
#if IPHONE
			trans = CGAffineTransformMakeRotation(-90.0*(M_PI/180.0));
			localPoint = CGPointApplyAffineTransform(localPoint, trans);
#else
			[trans rotateByDegrees:-90.0];
			localPoint = [trans transformPoint:localPoint];
#endif
			tmpPoint = VVMAKEPOINT(0.0, _frame.size.width);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			localPoint = VVADDPOINT(tmpPoint, localPoint);
			break;
		case VVViewBOTop:
#if IPHONE
			trans = CGAffineTransformMakeRotation(-180.0*(M_PI/180.0));
			localPoint = CGPointApplyAffineTransform(localPoint, trans);
#else
			[trans rotateByDegrees:-180.0];
			localPoint = [trans transformPoint:localPoint];
#endif
			tmpPoint = VVMAKEPOINT(_frame.size.width,_frame.size.height);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			localPoint = VVADDPOINT(tmpPoint, localPoint);
			break;
		case VVViewBOLeft:
#if IPHONE
			trans = CGAffineTransformMakeRotation(-270.0*(M_PI/180.0));
			localPoint = CGPointApplyAffineTransform(localPoint, trans);
#else
			[trans rotateByDegrees:-270.0];
			localPoint = [trans transformPoint:localPoint];
#endif
			tmpPoint = VVMAKEPOINT(_frame.size.height, 0.0);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			localPoint = VVADDPOINT(tmpPoint, localPoint);
			break;
	}
	
	id			returnMe = nil;
	[subviews rdlock];
	for (VVView *viewPtr in [subviews array])	{
		//NSLog(@"\t\tview %@ checking view %@",self,viewPtr);
		returnMe = [viewPtr vvSubviewHitTest:localPoint];
		if (returnMe != nil)
			break;
	}
	[subviews unlock];
	//	if the passed point isn't within any of my subviews, return self!
	if (returnMe == nil)
		returnMe = self;
	return returnMe;
}
- (BOOL) checkRect:(VVRECT)n	{
	return VVINTERSECTSRECT(n,_frame);
}
- (VVPOINT) convertPoint:(VVPOINT)viewCoords fromView:(id)view	{
	if (deleted || _containerView==nil)
		return viewCoords;
	id			otherContainerView = (view==nil) ? nil : [view containerView];
	if (otherContainerView==nil)
		return viewCoords;
	if (_containerView == otherContainerView)	{
		VVPOINT		containerCoords = [view convertPointToContainerViewCoords:viewCoords];
		return [self convertPointFromContainerViewCoords:containerCoords];
	}
	else	{
		//	convert the point to absolute (display) coords
		VVPOINT		displayCoords = [view convertPointToDisplayCoords:viewCoords];
		//	now convert the display coords to my coordinate space!
		return [self convertPointFromDisplayCoords:displayCoords];
	}
}
- (VVPOINT) convertPointFromContainerViewCoords:(VVPOINT)pointInContainer	{
	VVPOINT				returnMe = pointInContainer;
	NSMutableArray		*transArray = [self _locationTransformsToContainerView];
	NSEnumerator		*it = [transArray reverseObjectEnumerator];
#if IPHONE
	NSValue				*transVal = nil;
	//	now convert from the container to me
	while (transVal = [it nextObject])	{
		CGAffineTransform	invTrans = CGAffineTransformInvert([transVal CGAffineTransformValue]);
		returnMe = CGPointApplyAffineTransform(returnMe, invTrans);
	}
#else
	NSAffineTransform	*trans = nil;
	//	now convert from the container to me
	while (trans = [it nextObject])	{
		[trans invert];
		returnMe = [trans transformPoint:returnMe];
	}
#endif
	return returnMe;
}
- (VVPOINT) convertPointFromWinCoords:(VVPOINT)pointInWindow	{
	VVPOINT				returnMe = pointInWindow;
	//	convert the point from window coords to the coords local to the container view
#if IPHONE
	UIWindow			*containerWin = (_containerView==nil) ? nil : [_containerView window];
	UIView				*winContentView = (containerWin==nil) ? nil : [[containerWin rootViewController] view];
#else
	NSWindow			*containerWin = (_containerView==nil) ? nil : [_containerView window];
	NSView				*winContentView = (containerWin==nil) ? nil : [containerWin contentView];
#endif
	if (winContentView!=nil && winContentView!=_containerView)	{
		returnMe = [_containerView convertPoint:returnMe fromView:winContentView];
	}
	
	//	convert from container view local coords to coords local to me
	returnMe = [self convertPointFromContainerViewCoords:returnMe];
	
	return returnMe;
}
- (VVPOINT) convertPointFromDisplayCoords:(VVPOINT)displayPoint	{
	VVPOINT			returnMe = displayPoint;
	//	convert the point from display coords to window coords
#if IPHONE
	UIWindow		*containerWin = (_containerView==nil) ? nil : [_containerView window];
#else
	NSWindow		*containerWin = (_containerView==nil) ? nil : [_containerView window];
#endif
	if (containerWin != nil)	{
		VVRECT			containerWinFrame = [containerWin frame];
		returnMe = VVMAKEPOINT(displayPoint.x-containerWinFrame.origin.x, displayPoint.y-containerWinFrame.origin.y);
	}
	//	now convert the point from the win coords to coords local to me
	returnMe = [self convertPointFromWinCoords:returnMe];
	return returnMe;
}
- (VVRECT) convertRectFromContainerViewCoords:(VVRECT)rectInContainer	{
	VVRECT				returnMe = rectInContainer;
	NSMutableArray		*transArray = [self _locationTransformsToContainerView];
	NSEnumerator		*it = [transArray reverseObjectEnumerator];
#if IPHONE
	NSValue				*transVal = nil;
	//	convert from the container view coords to my coords
	while (transVal = [it nextObject])	{
		CGAffineTransform	invTrans = CGAffineTransformInvert([transVal CGAffineTransformValue]);
		returnMe.origin = CGPointApplyAffineTransform(returnMe.origin, invTrans);
		returnMe.size = CGSizeApplyAffineTransform(returnMe.size, invTrans);
	}
#else
	NSAffineTransform	*trans = nil;
	//	convert from the container view coords to my coords
	while (trans = [it nextObject])	{
		[trans invert];
		returnMe.origin = [trans transformPoint:returnMe.origin];
		returnMe.size = [trans transformSize:returnMe.size];
	}
#endif
	return returnMe;
}


- (VVPOINT) convertPointToContainerViewCoords:(VVPOINT)localCoords	{
	NSMutableArray		*transArray = [self _locationTransformsToContainerView];
	VVPOINT				returnMe = localCoords;
#if IPHONE
	for (NSValue *transVal in transArray)	{
		CGAffineTransform	trans = [transVal CGAffineTransformValue];
		returnMe = CGPointApplyAffineTransform(returnMe, trans);
	}
#else
	for (NSAffineTransform *trans in transArray)	{
		returnMe = [trans transformPoint:returnMe];
	}
#endif
	return returnMe;
}
- (VVPOINT) convertPointToWinCoords:(VVPOINT)localCoords	{
	VVPOINT				returnMe = [self convertPointToContainerViewCoords:localCoords];
	//	now that i've converted the local point to coords local to the container view, convert that to window coords
#if IPHONE
	UIWindow		*containerWin = (_containerView==nil) ? nil : [_containerView window];
	UIView			*winContentView = (containerWin==nil) ? nil : [[containerWin rootViewController] view];
#else
	NSWindow		*containerWin = (_containerView==nil) ? nil : [_containerView window];
	NSView			*winContentView = (containerWin==nil) ? nil : [containerWin contentView];
#endif
	if (winContentView != nil)	{
		returnMe = [winContentView convertPoint:returnMe fromView:_containerView];
	}
	return returnMe;
}
- (VVPOINT) convertPointToDisplayCoords:(VVPOINT)localCoords	{
	VVPOINT			returnMe = [self convertPointToWinCoords:localCoords];
#if IPHONE
	UIWindow		*containerWin = (_containerView==nil) ? nil : [_containerView window];
#else
	NSWindow		*containerWin = (_containerView==nil) ? nil : [_containerView window];
#endif
	if (containerWin != nil)	{
		VVRECT			containerWinFrame = [containerWin frame];
		returnMe = VVMAKEPOINT(returnMe.x+containerWinFrame.origin.x, returnMe.y+containerWinFrame.origin.y);
	}
	return returnMe;
}
- (VVRECT) convertRectToContainerViewCoords:(VVRECT)localRect	{
	NSMutableArray		*transArray = [self _locationTransformsToContainerView];
	VVRECT				returnMe = localRect;
#if IPHONE
	for (NSValue *transVal in transArray)	{
		CGAffineTransform		trans = [transVal CGAffineTransformValue];
		returnMe.origin = CGPointApplyAffineTransform(returnMe.origin, trans);
		returnMe.size = CGSizeApplyAffineTransform(returnMe.size, trans);
	}
#else
	for (NSAffineTransform *trans in transArray)	{
		//returnMe = [trans transformRect:returnMe];
		returnMe.origin = [trans transformPoint:returnMe.origin];
		returnMe.size = [trans transformSize:returnMe.size];
	}
#endif
	return returnMe;
}
- (VVPOINT) winCoordsOfLocalPoint:(VVPOINT)n	{
	//NSLog(@"%s ... (%0.2f, %0.2f)",__func__,n.x,n.y);
	return [self convertPointToWinCoords:n];
}
- (VVPOINT) displayCoordsOfLocalPoint:(VVPOINT)n	{
	//NSLog(@"%s ... (%0.2f, %0.2f)",__func__,n.x,n.y);
	return [self convertPointToDisplayCoords:n];
}
- (NSMutableArray *) _locationTransformsToContainerView	{
	//NSLog(@"%s ... %@",__func__,self);
	VVView				*viewPtr = self;
	VVView				*theSuperview = [viewPtr superview];
	VVRECT				viewFrame;
	VVViewBoundsOrientation		viewBO;
	VVPOINT						viewOrigin;
#if IPHONE
	CGAffineTransform	trans = CGAffineTransformIdentity;
#else
	NSAffineTransform	*trans = nil;
#endif
	NSMutableArray		*returnMe = MUTARRAY;
	VVPOINT				tmpPoint;
	
	while (1)	{
		//NSLog(@"\t\tviewPtr is %@",viewPtr);
		viewFrame = [viewPtr frame];
		viewBO = [viewPtr boundsOrientation];
		viewOrigin = [viewPtr boundsOrigin];
		//	compensate for the view's bounds (including any bounds offsets caused by orientation/rotation)
		switch (viewBO)	{
			case VVViewBOBottom:
				//tmpPoint = VVMAKEPOINT(0.0, 0.0);
				viewOrigin = VVMAKEPOINT(-1.0*viewOrigin.x, -1.0*viewOrigin.y);
				break;
			case VVViewBORight:
				tmpPoint = VVMAKEPOINT(0.0, -1.0*viewFrame.size.width);
				viewOrigin = VVSUBPOINT(tmpPoint, viewOrigin);
				break;
			case VVViewBOTop:
				tmpPoint = VVMAKEPOINT(-1.0*viewFrame.size.width, -1.0*viewFrame.size.height);
				viewOrigin = VVSUBPOINT(tmpPoint, viewOrigin);
				break;
			case VVViewBOLeft:
				tmpPoint = VVMAKEPOINT(-1.0*viewFrame.size.height, 0.0);
				viewOrigin = VVSUBPOINT(tmpPoint, viewOrigin);
				break;
		}
		
		//	the 'frame' is the rect the view occupies in the superview's coordinate space
		//	the 'bounds' is the coordinate space visible in the view
		
		//	goal: to make transforms that convert from local in this view's bounds to local to the superview's bounds
		
		//	first compensate for any offset from the view's bounds
		//	then compensate for any bound rotation (use the bounds here- not the frame- to move the origin back!)
		//	finally, compensate for the view's frame (its position within its superview) to obtain the coordinates (relative to the enclosing superview)
		
		//VVPointLog(@"\t\tviewOrigin is",viewOrigin);
#if IPHONE
		if (viewOrigin.x!=0.0 || viewOrigin.y!=0.0)	{
			trans = CGAffineTransformIdentity;
			[returnMe addObject:[NSValue valueWithCGAffineTransform:CGAffineTransformTranslate(trans,viewOrigin.x, viewOrigin.y)]];
		}
		if (viewBO != VVViewBOBottom)	{
			trans = CGAffineTransformIdentity;
			switch (viewBO)	{
				case VVViewBOBottom:
					break;
				case VVViewBORight:
					trans = CGAffineTransformRotate(trans, 90.0*(M_PI/180.0));
					break;
				case VVViewBOTop:
					trans = CGAffineTransformRotate(trans, 180.0*(M_PI/180.0));
					break;
				case VVViewBOLeft:
					trans = CGAffineTransformRotate(trans, 270.0*(M_PI/180.0));
					break;
			}
			[returnMe addObject:[NSValue valueWithCGAffineTransform:trans]];
		}
		
		if (viewFrame.origin.x!=0 || viewFrame.origin.y!=0)	{
			//VVPointLog(@"\t\tcompensating for frame origin, ",viewFrame.origin);
			trans = CGAffineTransformIdentity;
			trans = CGAffineTransformTranslate(trans, viewFrame.origin.x, viewFrame.origin.y);
			[returnMe addObject:[NSValue valueWithCGAffineTransform:trans]];
		}
#else
		if (viewOrigin.x!=0.0 || viewOrigin.y!=0.0)	{
			trans = [NSAffineTransform transform];
			[trans translateXBy:viewOrigin.x yBy:viewOrigin.y];
			[returnMe addObject:trans];
		}
		if (viewBO != VVViewBOBottom)	{
			trans = [NSAffineTransform transform];
			switch (viewBO)	{
				case VVViewBOBottom:
					break;
				case VVViewBORight:
					[trans rotateByDegrees:90.0];
					break;
				case VVViewBOTop:
					[trans rotateByDegrees:180.0];
					break;
				case VVViewBOLeft:
					[trans rotateByDegrees:270.0];
					break;
			}
			[returnMe addObject:trans];
		}
		
		if (viewFrame.origin.x!=0 || viewFrame.origin.y!=0)	{
			//VVPointLog(@"\t\tcompensating for frame origin, ",viewFrame.origin);
			trans = [NSAffineTransform transform];
			[trans translateXBy:viewFrame.origin.x yBy:viewFrame.origin.y];
			[returnMe addObject:trans];
		}
#endif
		
		
		theSuperview = [viewPtr superview];
		if (theSuperview==nil)
			break;
		else
			viewPtr = theSuperview;
	}
	return returnMe;
}


/*===================================================================================*/
#pragma mark --------------------- frame & bounds-related
/*------------------------------------*/


- (VVRECT) frame	{
	return _frame;
}
- (void) setFrame:(VVRECT)n	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	BOOL		changed = (VVEQUALRECTS(n,_frame)) ? NO : YES;
	[self _setFrame:n];
	if (changed)	{
#if !IPHONE
		[self updateTrackingAreas];
#endif
		if (_superview != nil)
			[_superview setNeedsDisplay:YES];
		else if (_containerView != nil)
			[_containerView setNeedsDisplay:YES];
	}
}
- (void) _setFrame:(VVRECT)n	{
	//NSLog(@"%s ... (%f, %f) : %f x %f",__func__,n.origin.x,n.origin.y,n.size.width,n.size.height);
	if (deleted)
		return;
	if (VVEQUALRECTS(n,_frame))
		return;
	[self _setFrameSize:n.size];
	[self _setFrameOrigin:n.origin];
}
- (void) setFrameSize:(VVSIZE)n	{
	if (deleted)
		return;
	BOOL			changed = (VVEQUALSIZES(n,_frame.size)) ? NO : YES;
	[self _setFrameSize:n];
	if (changed)	{
#if !IPHONE
		[self updateTrackingAreas];
#endif
		if (_superview != nil)
			[_superview setNeedsDisplay:YES];
		else if (_containerView != nil)
			[_containerView setNeedsDisplay:YES];
	}
}
- (void) _setFrameSize:(VVSIZE)proposedSize	{
	//NSLog(@"%s ... %@, (%0.2f x %0.2f)",__func__,self,proposedSize.width,proposedSize.height);
	VVSIZE			oldSize = _frame.size;
	//VVSizeLog(@"\t\toldSize is",oldSize);
	VVSIZE			n = VVMAKESIZE(fmax(minFrameSize.width,proposedSize.width),fmax(minFrameSize.height,proposedSize.height));
	BOOL			changed = (VVEQUALSIZES(oldSize,n)) ? NO : YES;
	
	if (changed)	{
		if ([self autoresizesSubviews])	{
			double		widthDelta = n.width - oldSize.width;
			double		heightDelta = n.height - oldSize.height;
			[subviews rdlock];
			for (VVView *viewPtr in [subviews array])	{
				VVViewResizeMask	viewResizeMask = [viewPtr autoresizingMask];
				//NSLog(@"\t\tresizing subview %@ with mask %d",viewPtr,viewResizeMask);
				VVRECT				viewNewFrame = [viewPtr frame];
				//VVRectLog(@"\t\torig viewNewFrame is",viewNewFrame);
				int					hSubDivs = 0;
				int					vSubDivs = 0;
				if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMinXMargin))
					++hSubDivs;
				if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMaxXMargin))
					++hSubDivs;
				if (VVBITMASKCHECK(viewResizeMask,VVViewResizeWidth))
					++hSubDivs;
				
				if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMinYMargin))
					++vSubDivs;
				if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMaxYMargin))
					++vSubDivs;
				if (VVBITMASKCHECK(viewResizeMask,VVViewResizeHeight))
					++vSubDivs;
				//NSLog(@"\t\thSubDivs = %d, vSubDivs = %d",hSubDivs,vSubDivs);
				if (hSubDivs>0 || vSubDivs>0)	{
					if (hSubDivs>0 && VVBITMASKCHECK(viewResizeMask,VVViewResizeWidth))
						viewNewFrame.size.width += widthDelta/hSubDivs;
					if (vSubDivs>0 && VVBITMASKCHECK(viewResizeMask,VVViewResizeHeight))
						viewNewFrame.size.height += heightDelta/vSubDivs;
					if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMinXMargin))
						viewNewFrame.origin.x += widthDelta/hSubDivs;
					if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMinYMargin))
						viewNewFrame.origin.y += heightDelta/vSubDivs;
				}
				//VVRectLog(@"\t\tmod viewNewFrame is",viewNewFrame);
				[viewPtr _setFrame:viewNewFrame];
			}
			[subviews unlock];
		}
		
		_frame.size = n;
		
		//if (changed)	{
			pthread_mutex_lock(&spritesUpdateLock);
			spritesNeedUpdate = YES;
			pthread_mutex_unlock(&spritesUpdateLock);
		//}
	}
}
- (void) setFrameOrigin:(VVPOINT)n	{
	if (deleted)
		return;
	BOOL		changed = (!VVEQUALPOINTS(n,_frame.origin)) ? YES : NO;
	[self _setFrameOrigin:n];
	if (changed)	{
#if !IPHONE
		[self updateTrackingAreas];
#endif
		if (_superview != nil)
			[_superview setNeedsDisplay:YES];
		else if (_containerView != nil)
			[_containerView setNeedsDisplay:YES];
	}
}
- (void) _setFrameOrigin:(VVPOINT)n	{
	//NSLog(@"%s ... %@, (%0.2f, %0.2f)",__func__,self,n.x,n.y);
	_frame.origin = n;
}
- (VVRECT) bounds	{
	switch (_boundsOrientation)	{
		case VVViewBOBottom:
		case VVViewBOTop:
			return VVMAKERECT(_boundsOrigin.x, _boundsOrigin.y, _frame.size.width, _frame.size.height);
		case VVViewBORight:
		case VVViewBOLeft:
			return VVMAKERECT(_boundsOrigin.x, _boundsOrigin.y, _frame.size.height, _frame.size.width);
	}
	return VVMAKERECT(0,0,0,0);
}
- (VVRECT) backingBounds	{
	switch (_boundsOrientation)	{
		case VVViewBOBottom:
		case VVViewBOTop:
			return VVMAKERECT(_boundsOrigin.x*localToBackingBoundsMultiplier, _boundsOrigin.y*localToBackingBoundsMultiplier, _frame.size.width*localToBackingBoundsMultiplier, _frame.size.height*localToBackingBoundsMultiplier);
		case VVViewBORight:
		case VVViewBOLeft:
			return VVMAKERECT(_boundsOrigin.x*localToBackingBoundsMultiplier, _boundsOrigin.y*localToBackingBoundsMultiplier, _frame.size.height*localToBackingBoundsMultiplier, _frame.size.width*localToBackingBoundsMultiplier);
	}
	return VVMAKERECT(0,0,0,0);
}
- (void) setBoundsOrigin:(VVPOINT)n	{
	BOOL		changed = (!VVEQUALPOINTS(n,_boundsOrigin)) ? YES : NO;
	_boundsOrigin = n;
	if (changed)	{
#if !IPHONE
		[self updateTrackingAreas];
#endif
		if (_superview != nil)
			[_superview setNeedsDisplay:YES];
		else if (_containerView != nil)
			[_containerView setNeedsDisplay:YES];
	}
}
- (VVPOINT) boundsOrigin	{
	return _boundsOrigin;
}
- (VVViewBoundsOrientation) boundsOrientation	{
	return _boundsOrientation;
}
- (void) setBoundsOrientation:(VVViewBoundsOrientation)n	{
	BOOL		changed = (n==_boundsOrientation) ? NO : YES;
	_boundsOrientation = n;
	if (changed)	{
#if !IPHONE
		[self updateTrackingAreas];
#endif
		if (_superview != nil)
			[_superview setNeedsDisplay:YES];
		else if (_containerView != nil)
			[_containerView setNeedsDisplay:YES];
	}
}


#if IPHONE
- (GLKBaseEffect *) safelyGetBoundsProjectionEffect	{
	GLKBaseEffect		*returnMe = nil;
	OSSpinLockLock(&boundsProjectionEffectLock);
	returnMe = (boundsProjectionEffect==nil) ? nil : [boundsProjectionEffect retain];
	OSSpinLockUnlock(&boundsProjectionEffectLock);
	return returnMe;
}
#else
- (void) updateTrackingAreas	{
	if (deleted)
		return;
	VVRECT		myVisibleBounds = [self visibleRect];
	//	run through my tracking areas, removing the apple parts from the container view
	[trackingAreas rdlock];
	for (VVTrackingArea *ta in [trackingAreas array])	{
		VVRECT			localRect = VVINTERSECTIONRECT(myVisibleBounds, [ta rect]);
		VVRECT			containerRect = [self convertRectToContainerViewCoords:localRect];
		[ta updateAppleTrackingAreaWithContainerView:_containerView containerViewRect:containerRect];
	}
	[trackingAreas unlock];
	//	tell my subviews to update their tracking areas recursively
	[subviews rdlock];
	for (VVView *viewPtr in [subviews array])	{
		[viewPtr updateTrackingAreas];
	}
	[subviews unlock];
}
- (void) addTrackingArea:(VVTrackingArea *)n	{
	if (deleted || n==nil)
		return;
	VVRECT			containerRect = [self convertRectToContainerViewCoords:[n rect]];
	if (_containerView != nil)
		[n updateAppleTrackingAreaWithContainerView:_containerView containerViewRect:containerRect];
	[trackingAreas lockAddObject:n];
}
- (void) removeTrackingArea:(VVTrackingArea *)n	{
	if (deleted || n==nil)
		return;
	if (_containerView != nil)
		[n removeAppleTrackingAreaFromContainerView:_containerView];
	[trackingAreas lockRemoveIdenticalPtr:n];
}
- (void) _clearAppleTrackingAreas	{
	if (deleted)
		return;
	
	[trackingAreas rdlock];
	for (VVTrackingArea *ta in [trackingAreas array])	{
		[ta removeAppleTrackingAreaFromContainerView:_containerView];
	}
	[trackingAreas unlock];
}
- (void) _refreshAppleTrackingAreas	{
	if (deleted)
		return;
	if (_containerView == nil)
		return;
	
	[trackingAreas rdlock];
	for (VVTrackingArea *ta in [trackingAreas array])	{
		VVRECT		localRect = [ta rect];
		VVRECT		containerRect = [self convertRectToContainerViewCoords:localRect];
		[ta updateAppleTrackingAreaWithContainerView:_containerView containerViewRect:containerRect];
	}
	[trackingAreas unlock];
}
#endif


//	returns the visible rect in this view's LOCAL COORDINATE SPACE (bounds), just like NSView
- (VVRECT) visibleRect	{
	//NSLog(@"%s ... %@",__func__,self);
	VVRECT		tmpRect = [self _visibleRect];
	VVRECT		returnMe = VVZERORECT;
	if (!VVEQUALRECTS(tmpRect, VVZERORECT))	{
		returnMe.origin.x = VVMINX(tmpRect);
		returnMe.size.width = VVMAXX(tmpRect)-returnMe.origin.x;
		returnMe.origin.y = VVMINY(tmpRect);
		returnMe.size.height = VVMAXY(tmpRect)-returnMe.origin.y;
	}
	return returnMe;
}
- (VVRECT) _visibleRect	{
	//NSLog(@"%s ... %@",__func__,self);
	if (deleted || (_superview==nil && _containerView==nil))	{
		NSLog(@"\t\terr: bailing, %s",__func__);
		return VVZERORECT;
	}
	//	i need my superview's visible rect (in my superview's local coords)
	VVRECT		superviewVisRect = VVZERORECT;
	//	if my superview's nil, i'm a top-level VVView
	if (_superview==nil)	{
		//	get the container view's visible rect (its visible bounds)
		superviewVisRect = [_containerView visibleRect];
		if (VVISZERORECT(superviewVisRect))
			return VVZERORECT;
		
		VVRECT		tmpBounds = [_containerView bounds];
		superviewVisRect.origin.x += tmpBounds.origin.x;
		superviewVisRect.origin.y += tmpBounds.origin.y;
	}
	//	else get my superview's visible rect
	else	{
		superviewVisRect = [_superview visibleRect];
		if (VVISZERORECT(superviewVisRect))
			return VVZERORECT;
	}
	//VVRectLog(@"\t\tsuperviewVisRect is",superviewVisRect);
	//	get the intersect rect with my superview's visible rect and my frame- this is my visible rect
	VVRECT		myVisibleFrame = VVINTERSECTIONRECT(superviewVisRect,_frame);
	if (VVISZERORECT(myVisibleFrame))
		return VVZERORECT;
	myVisibleFrame.origin = VVMAKEPOINT(myVisibleFrame.origin.x-_frame.origin.x, myVisibleFrame.origin.y-_frame.origin.y);
	//VVRectLog(@"\t\tmyVisibleFrame is",myVisibleFrame);
	//	convert the intersect rect (my visible frame) to my local coordinate space (bounds)
	
	
	VVRECT				returnMe = myVisibleFrame;
#if IPHONE
	CGAffineTransform	trans = CGAffineTransformIdentity;
	switch (_boundsOrientation)	{
		case VVViewBOBottom:
			returnMe.origin = VVADDPOINT(returnMe.origin, _boundsOrigin);
			break;
		case VVViewBORight:
			trans = CGAffineTransformRotate(trans, -90.0*(M_PI/180.0));
			returnMe.origin = CGPointApplyAffineTransform(returnMe.origin, trans);
			returnMe.size = CGSizeApplyAffineTransform(returnMe.size, trans);
			returnMe.origin = VVADDPOINT(returnMe.origin, _boundsOrigin);
			break;
		case VVViewBOTop:
			trans = CGAffineTransformRotate(trans, -180.0*(M_PI/180.0));
			returnMe.origin = CGPointApplyAffineTransform(returnMe.origin, trans);
			returnMe.size = CGSizeApplyAffineTransform(returnMe.size, trans);
			returnMe.origin = VVADDPOINT(returnMe.origin, _boundsOrigin);
			break;
		case VVViewBOLeft:
			trans = CGAffineTransformRotate(trans, -270.0*(M_PI/180.0));
			returnMe.origin = CGPointApplyAffineTransform(returnMe.origin, trans);
			returnMe.size = CGSizeApplyAffineTransform(returnMe.size, trans);
			returnMe.origin = VVADDPOINT(returnMe.origin, _boundsOrigin);
			break;
	}
#else
	NSAffineTransform	*trans = nil;
	switch (_boundsOrientation)	{
		case VVViewBOBottom:
			returnMe.origin = VVADDPOINT(returnMe.origin, _boundsOrigin);
			break;
		case VVViewBORight:
			trans = [NSAffineTransform transform];
			[trans rotateByDegrees:-90.0];
			returnMe.origin = [trans transformPoint:returnMe.origin];
			returnMe.size = [trans transformSize:returnMe.size];
			returnMe.origin = VVADDPOINT(returnMe.origin, _boundsOrigin);
			break;
		case VVViewBOTop:
			trans = [NSAffineTransform transform];
			[trans rotateByDegrees:-180.0];
			returnMe.origin = [trans transformPoint:returnMe.origin];
			returnMe.size = [trans transformSize:returnMe.size];
			returnMe.origin = VVADDPOINT(returnMe.origin, _boundsOrigin);
			break;
		case VVViewBOLeft:
			trans = [NSAffineTransform transform];
			[trans rotateByDegrees:-270.0];
			returnMe.origin = [trans transformPoint:returnMe.origin];
			returnMe.size = [trans transformSize:returnMe.size];
			returnMe.origin = VVADDPOINT(returnMe.origin, _boundsOrigin);
			break;
	}
#endif
	returnMe.size = VVMAKESIZE(fabs(returnMe.size.width),fabs(returnMe.size.height));
	//VVRectLog(@"\t\treturning",returnMe);
	return returnMe;
}


/*===================================================================================*/
#pragma mark --------------------- mimicing behavior of other NSView-related classes
/*------------------------------------*/


- (void) _viewDidMoveToWindow	{
	if (deleted)
		return;
	//	first call the user-facing version of this method (to match behavior of NSView)
	[self viewDidMoveToWindow];
	//	now run through my subviews, calling this method recursively
	if (subviews==nil || [subviews count]<1)
		return;
	[subviews rdlock];
	for (VVView *viewPtr in [subviews array])	{
		[viewPtr _viewDidMoveToWindow];
	}
	[subviews unlock];
}
- (void) viewDidMoveToWindow	{
	
}
//	returns YES if at least one of its views has a window and a non-zero visible rect
- (BOOL) hasVisibleView	{
	if (_containerView==nil)
		return NO;
	BOOL			returnMe = NO;
	if ([_containerView window] != nil)	{
		VVRECT		visRect = [self visibleRect];
		if (!(VVISZERORECT(visRect)))	{
			returnMe = YES;
		}
	}
	return returnMe;
}


/*===================================================================================*/
#pragma mark --------------------- dragging setup
/*------------------------------------*/


- (void) registerForDraggedTypes:(NSArray *)a	{
	if (deleted || a==nil || [a count]<1)
		return;
	BOOL		dragTypeChanged = NO;
	for (NSString *tmpDragType in a)	{
		[dragTypes rdlock];
		if (![dragTypes containsObject:tmpDragType])	{
			dragTypeChanged = YES;
			[dragTypes addObject:tmpDragType];
		}
		[dragTypes unlock];
	}
	if (dragTypeChanged && _containerView!=nil)
		[_containerView reconcileVVSubviewDragTypes];
}
- (void) _collectDragTypesInArray:(NSMutableArray *)n	{
	if (deleted || n==nil)
		return;
	[dragTypes rdlock];
	for (NSString *tmpString in [dragTypes array])	{
		if (![n containsObject:tmpString])
			[n addObject:tmpString];
	}
	[dragTypes unlock];
	
	if (subviews != nil)	{
		[subviews rdlock];
		for (VVView *viewPtr in [subviews array])	{
			[viewPtr _collectDragTypesInArray:n];
		}
		[subviews unlock];
	}
}
- (MutLockArray *) dragTypes	{
	if (deleted)
		return nil;
	return dragTypes;
}


/*===================================================================================*/
#pragma mark --------------------- NSDraggingDestination protocol
/*------------------------------------*/


#if !IPHONE
- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	return NSDragOperationNone;
}
- (NSDragOperation) draggingUpdated:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	return NSDragOperationCopy;
}
- (void) draggingExited:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
}
- (void) draggingEnded:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
}
- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	return YES;
}
- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	return YES;
}
- (void) concludeDragOperation:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
}
#endif


/*===================================================================================*/
#pragma mark --------------------- subviews & related methods
/*------------------------------------*/


- (void) setAutoresizesSubviews:(BOOL)n	{
	autoresizesSubviews = n;
}
- (BOOL) autoresizesSubviews	{
	return autoresizesSubviews;
}
- (void) setAutoresizingMask:(VVViewResizeMask)n	{
	autoresizingMask = n;
}
- (VVViewResizeMask) autoresizingMask	{
	return autoresizingMask;
}
- (void) addSubview:(id)n	{
	if (deleted || n==nil || subviews==nil)
		return;
	[subviews wrlock];
	if (![subviews containsIdenticalPtr:n])	{
		[subviews insertObject:n atIndex:0];
		[n _setSuperview:self];
		[n setContainerView:_containerView];
		if (_containerView != nil)
			[_containerView setNeedsDisplay:YES];
	}
	[subviews unlock];
	//	if the subviews i'm adding have any drag types, tell the container view to reconcile its drag types
	NSMutableArray		*tmpArray = MUTARRAY;
	[n _collectDragTypesInArray:tmpArray];
	if ([tmpArray count]>0 && _containerView!=nil)
		[_containerView reconcileVVSubviewDragTypes];
}
- (void) removeSubview:(id)n	{
	if (deleted || n==nil || subviews==nil)
		return;
	[subviews lockRemoveIdenticalPtr:n];
	[n _setSuperview:nil];
	[n setContainerView:nil];
	if (_containerView != nil)
		[_containerView setNeedsDisplay:YES];
	
	//	if the subview i'm removing has any drag types, tell the container view to reconcile its drag types
	NSMutableArray		*tmpArray = MUTARRAY;
	[n _collectDragTypesInArray:tmpArray];
	if ([tmpArray count]>0 && _containerView!=nil)
		[_containerView reconcileVVSubviewDragTypes];
}
- (void) removeFromSuperview	{
	if (deleted)
		return;
	//NSLog(@"%s - ERR",__func__);
	if (_superview != nil)	{
		[_superview removeSubview:self];
	}
	else if (_containerView != nil)	{
		[_containerView removeVVSubview:self];
	}
}
- (BOOL) containsSubview:(id)n	{
	if (deleted || n==nil)
		return NO;
	BOOL		returnMe = NO;
	[subviews rdlock];
	for (VVView *viewPtr in [subviews array])	{
		if (viewPtr==n || [viewPtr containsSubview:n])	{
			returnMe = YES;
			break;
		}
	}
	[subviews unlock];
	return returnMe;
}
- (void) _setSuperview:(id)n	{
	_superview = n;
}
- (id) superview	{
	return _superview;
}
- (id) enclosingScrollView	{
	id			viewPtr = _superview;
	while (viewPtr!=nil && ![viewPtr isKindOfClass:[VVScrollView class]])
		viewPtr = [viewPtr superview];
	return viewPtr;
}
- (VVRECT) superBounds	{
	if (deleted)
		return VVZERORECT;
	if (_superview!=nil)
		return [_superview bounds];
	else if (_containerView!=nil)
		return [_containerView bounds];
	else
		return VVZERORECT;
}
- (VVRECT) subviewFramesUnion	{
	//NSLog(@"%s ... %@",__func__,self);
	VVRECT		returnMe = VVMAKERECT(0,0,0,0);
	[subviews rdlock];
	for (VVView *subview in [subviews array])	{
		//NSLog(@"\t\tsubview is %@",subview);
		VVRECT		tmpFrame = [subview frame];
		//VVRectLog(@"\t\tsubview frame is",tmpFrame);
		if (tmpFrame.size.width>0.0 && tmpFrame.size.height>0.0)
			returnMe = VVUNIONRECT(returnMe,tmpFrame);
	}
	[subviews unlock];
	return returnMe;
}
- (void) setContainerView:(id)n	{
	BOOL			changed = (_containerView != n) ? YES : NO;
	if (changed && _containerView!=nil)	{
#if !IPHONE
		[self _clearAppleTrackingAreas];
#endif
	}
	
	_containerView = n;
	
	if (changed && _containerView!=nil)	{
#if !IPHONE
		[self _refreshAppleTrackingAreas];
#endif
	}
	
	if (subviews!=nil && [subviews count]>0)	{
		[subviews lockMakeObjectsPerformSelector:@selector(setContainerView:) withObject:n];
	}
	//	use the localToBackingBoundsMultiplier from the container view!
	if (_containerView != nil)	{
		localToBackingBoundsMultiplier = [_containerView localToBackingBoundsMultiplier];
	}
}
- (id) containerView	{
	return _containerView;
}
- (MutLockArray *) subviews	{
	return subviews;
}
- (id) window	{
	if (deleted || _containerView==nil)
		return nil;
	return [_containerView window];
}


/*===================================================================================*/
#pragma mark --------------------- drawing & related
/*------------------------------------*/


- (void) drawRect:(VVRECT)r	{
	//NSLog(@"ERR: %s",__func__);
	/*		this method should never be called or used, ever.		*/
}
#if !IPHONE
- (void) drawRect:(VVRECT)r inContext:(CGLContextObj)cgl_ctx	{
	//NSLog(@"ERR: %s, %@",__func__,self);
	//VVRectLog(@"\t\trect is",r);
	/*		this method should be used by subclasses.  put the simple drawing code in here (origin is the bottom-left corner of me!)		*/
}
#endif

#if !IPHONE
- (void) _drawRect:(VVRECT)r inContext:(CGLContextObj)cgl_ctx
#else
- (void) _drawRect:(VVRECT)r
#endif
{
	//NSLog(@"%s ... %@",__func__,self);
	//VVRectLog(@"\t\trect is",r);
	//VVRectLog(@"\t\tclipRect is",c);
	if (deleted)
		return;
	
#if IPHONE
	//	lock, check to see if i need a new projection effect (or it needs to be updated)
	BOOL			needsNewProjectionEffect = NO;
	OSSpinLockLock(&boundsProjectionEffectLock);
	if (boundsProjectionEffect==nil || boundsProjectionEffectNeedsUpdate)	{
		needsNewProjectionEffect = YES;
	}
	else	{
		[boundsProjectionEffect prepareToDraw];
	}
	OSSpinLockUnlock(&boundsProjectionEffectLock);
	//	if i need to update the projection effect...
	if (needsNewProjectionEffect)	{
		//	update my projection effect by getting my superview's projection effect- which must exist at this point, and has the cumulative transform matrices for all the views above it in the hierarchy- and modifying it by concatenating my local transform matrix.
		GLKBaseEffect				*superProjEffect = (_superview==nil) ? nil : [_superview safelyGetBoundsProjectionEffect];
		GLKEffectPropertyTransform	*superProjEffectTrans = (superProjEffect==nil) ? nil : [superProjEffect transform];
		GLKMatrix4					superEffectModelMatrix = (superProjEffectTrans==nil) ? GLKMatrix4Identity : [superProjEffectTrans modelviewMatrix];
		GLKMatrix4					superEffectProjectionMatrix;
		VVPOINT						tmpPoint;
		//	account for my frame origin
		tmpPoint = VVMAKEPOINT(_frame.origin.x*localToBackingBoundsMultiplier, _frame.origin.y*localToBackingBoundsMultiplier);
		superEffectModelMatrix = GLKMatrix4Translate(superEffectModelMatrix, tmpPoint.x, tmpPoint.y, 0.0);
		//	account for my bounds origin and orientation
		switch (_boundsOrientation)	{
			case VVViewBOBottom:
				tmpPoint = _boundsOrigin;
				tmpPoint = VVMAKEPOINT(-1.0*tmpPoint.x*localToBackingBoundsMultiplier, -1.0*tmpPoint.y*localToBackingBoundsMultiplier);
				//glTranslatef(tmpPoint.x, tmpPoint.y, 0.0);
				superEffectModelMatrix = GLKMatrix4Translate(superEffectModelMatrix, tmpPoint.x, tmpPoint.y, 0.0);
				break;
			case VVViewBORight:
				//glRotatef(90.0, 0, 0, 1);
				superEffectModelMatrix = GLKMatrix4RotateZ(superEffectModelMatrix, 90.0*(M_PI/180.0));
				tmpPoint = VVMAKEPOINT(0.0, _frame.size.width);
				tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
				tmpPoint = VVMAKEPOINT(-1.0*tmpPoint.x*localToBackingBoundsMultiplier, -1.0*tmpPoint.y*localToBackingBoundsMultiplier);
				//glTranslatef(tmpPoint.x, tmpPoint.y, 0.0);
				superEffectModelMatrix = GLKMatrix4Translate(superEffectModelMatrix, tmpPoint.x, tmpPoint.y, 0.0);
				break;
			case VVViewBOTop:
				//glRotatef(180.0, 0, 0, 1);
				superEffectModelMatrix = GLKMatrix4RotateZ(superEffectModelMatrix, 180.0*(M_PI/180.0));
				tmpPoint = VVMAKEPOINT(_frame.size.width,_frame.size.height);
				tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
				tmpPoint = VVMAKEPOINT(-1.0*tmpPoint.x*localToBackingBoundsMultiplier, -1.0*tmpPoint.y*localToBackingBoundsMultiplier);
				//glTranslatef(tmpPoint.x, tmpPoint.y, 0.0);
				superEffectModelMatrix = GLKMatrix4Translate(superEffectModelMatrix, tmpPoint.x, tmpPoint.y, 0.0);
				break;
			case VVViewBOLeft:
				//glRotatef(270.0, 0, 0, 1);
				superEffectModelMatrix = GLKMatrix4RotateZ(superEffectModelMatrix, 270.0*(M_PI/180.0));
				tmpPoint = VVMAKEPOINT(_frame.size.height, 0.0);
				tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
				tmpPoint = VVMAKEPOINT(-1.0*tmpPoint.x*localToBackingBoundsMultiplier, -1.0*tmpPoint.y*localToBackingBoundsMultiplier);
				//glTranslatef(tmpPoint.x, tmpPoint.y, 0.0);
				superEffectModelMatrix = GLKMatrix4Translate(superEffectModelMatrix, tmpPoint.x, tmpPoint.y, 0.0);
				break;
		}
		if (superProjEffectTrans != nil)
			superEffectProjectionMatrix = [superProjEffectTrans projectionMatrix];
		else	{
			VVRECT				containerBounds = [_containerView backingBounds];
			superEffectProjectionMatrix = ([_containerView flipped])
				?	GLKMatrix4MakeOrtho(containerBounds.origin.x, containerBounds.origin.x+containerBounds.size.width, containerBounds.origin.y+containerBounds.size.height, containerBounds.origin.y, 1.0, -1.0)
				:	GLKMatrix4MakeOrtho(containerBounds.origin.x, containerBounds.origin.x+containerBounds.size.width, containerBounds.origin.y, containerBounds.origin.y+containerBounds.size.height, 1.0, -1.0);
		}
		
		
		
		OSSpinLockLock(&boundsProjectionEffectLock);
		//	if there's no effect, make one
		if (boundsProjectionEffect == nil)
			boundsProjectionEffect = [[GLKBaseEffect alloc] init];
		//	apply the model matrix (which should always be "good")
		GLKEffectPropertyTransform		*trans = [boundsProjectionEffect transform];
		[trans setModelviewMatrix:superEffectModelMatrix];
		[trans setProjectionMatrix:superEffectProjectionMatrix];
		[boundsProjectionEffect prepareToDraw];
		OSSpinLockUnlock(&boundsProjectionEffectLock);
		
		
		//	don't forget to release this!
		VVRELEASE(superProjEffect);
	}
#else
	spriteCtx = cgl_ctx;
#endif
	
	pthread_mutex_lock(&spritesUpdateLock);
	if (spritesNeedUpdate)
		[self updateSprites];
	pthread_mutex_unlock(&spritesUpdateLock);
	
	//	configure glScissor so it's clipping to my visible rect (bail if i don't have a visible rect)
	VVRECT			clipRect = [self visibleRect];
	if (VVISZERORECT(clipRect))	{
		//NSLog(@"\t\terr: bailing, clipRect zero %s",__func__);
		return;
	}
	//VVRectLog(@"\t\tclipRect in local coords is",clipRect);
	clipRect = [self convertRectToContainerViewCoords:clipRect];
	//VVRectLog(@"\t\tfirst-pass container coords are",clipRect);
	//	make sure the passed clip rect has positive dimensions (adjust origin if dimensions are negative to compensate)
	VVRECT			tmpClipRect;
	tmpClipRect.origin.x = round(VVMINX(clipRect));
	tmpClipRect.size.width = round(VVMAXX(clipRect)-tmpClipRect.origin.x);
	tmpClipRect.origin.y = round(VVMINY(clipRect));
	tmpClipRect.size.height = round(VVMAXY(clipRect)-tmpClipRect.origin.y);
	//VVRectLog(@"\t\tclipRect in container coords is",tmpClipRect);
	//	use scissor to clip drawing to the passed rect
	glScissor(tmpClipRect.origin.x*localToBackingBoundsMultiplier, tmpClipRect.origin.y*localToBackingBoundsMultiplier, tmpClipRect.size.width*localToBackingBoundsMultiplier, tmpClipRect.size.height*localToBackingBoundsMultiplier);
	
	//	do the rotation & translation for the bounds now, AFTER i filled in the background/clear color
#if !IPHONE
	VVPOINT			tmpPoint;
	switch (_boundsOrientation)	{
		case VVViewBOBottom:
			tmpPoint = _boundsOrigin;
			tmpPoint = VVMAKEPOINT(-1.0*tmpPoint.x*localToBackingBoundsMultiplier, -1.0*tmpPoint.y*localToBackingBoundsMultiplier);
			glTranslatef(tmpPoint.x, tmpPoint.y, 0.0);
			break;
		case VVViewBORight:
			glRotatef(90.0, 0, 0, 1);
			tmpPoint = VVMAKEPOINT(0.0, _frame.size.width);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			tmpPoint = VVMAKEPOINT(-1.0*tmpPoint.x*localToBackingBoundsMultiplier, -1.0*tmpPoint.y*localToBackingBoundsMultiplier);
			//VVPointLog(@"\t\ttranslating",tmpPoint);
			glTranslatef(tmpPoint.x, tmpPoint.y, 0.0);
			break;
		case VVViewBOTop:
			glRotatef(180.0, 0, 0, 1);
			tmpPoint = VVMAKEPOINT(_frame.size.width,_frame.size.height);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			tmpPoint = VVMAKEPOINT(-1.0*tmpPoint.x*localToBackingBoundsMultiplier, -1.0*tmpPoint.y*localToBackingBoundsMultiplier);
			//VVPointLog(@"\t\ttranslating",tmpPoint);
			glTranslatef(tmpPoint.x, tmpPoint.y, 0.0);
			break;
		case VVViewBOLeft:
			glRotatef(270.0, 0, 0, 1);
			tmpPoint = VVMAKEPOINT(_frame.size.height, 0.0);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			tmpPoint = VVMAKEPOINT(-1.0*tmpPoint.x*localToBackingBoundsMultiplier, -1.0*tmpPoint.y*localToBackingBoundsMultiplier);
			//VVPointLog(@"\t\ttranslating",tmpPoint);
			glTranslatef(tmpPoint.x, tmpPoint.y, 0.0);
			break;
	}
#endif
	
	
	//	get the local bounds- zero out the origin before clearing
	VVRECT		localBounds = [self backingBounds];
	//VVRectLog(@"\t\tlocalBounds is",localBounds);
	//	if i'm opaque, fill my bounds
	OSSpinLockLock(&propertyLock);
	/*
	if (isOpaque)	{
		glClearColor(clearColor[0], clearColor[1], clearColor[2], 1.0);
		glClear(GL_COLOR_BUFFER_BIT);
	}
	else if (clearColor[3]!=0.0)	{
		glClearColor(clearColor[0], clearColor[1], clearColor[2], clearColor[3]);
		glClear(GL_COLOR_BUFFER_BIT);
	}
	*/
#if IPHONE
	if (isOpaque)	{
		VVRECT		tmpRect = VVMAKERECT(0,0,localBounds.size.width, localBounds.size.height);
		//NSRectLog(@"\t\tclearing background in rect",tmpRect);
		GLDRAWRECT_TRISTRIP_COLOR(tmpRect, clearColor[0], clearColor[1], clearColor[2], 1.0);
	}
	else if (clearColor[3]!=0.0)	{
		VVRECT		tmpRect = VVMAKERECT(0,0,localBounds.size.width, localBounds.size.height);
		//NSRectLog(@"\t\tclearing background in rect",tmpRect);
		GLDRAWRECT_TRISTRIP_COLOR(tmpRect, clearColor[0], clearColor[1], clearColor[2], clearColor[3]);
	}
#else
	if (isOpaque)	{
		glColor4f(clearColor[0], clearColor[1], clearColor[2], 1.0);
		GLDRAWRECT(VVMAKERECT(0,0,localBounds.size.width, localBounds.size.height));
	}
	else if (clearColor[3]!=0.0)	{
		glColor4f(clearColor[0], clearColor[1], clearColor[2], clearColor[3]);
		GLDRAWRECT(VVMAKERECT(0,0,localBounds.size.width, localBounds.size.height));
	}
#endif
	OSSpinLockUnlock(&propertyLock);
	
	
	//	tell the sprite manager to draw
	if (spriteManager != nil)	{
#if IPHONE
		[spriteManager draw];
#else
		[spriteManager drawInContext:cgl_ctx];
#endif
	}
	
	//	...now call the "meat" of my drawing method (where most drawing code will be handled)
#if IPHONE
	[self drawRect:r];
#else
	[self drawRect:r inContext:cgl_ctx];
#endif
	
	//	if there's a border, draw it now
	OSSpinLockLock(&propertyLock);
	if (drawBorder)	{
#if IPHONE
		GLSTROKERECT_COLOR(localBounds,borderColor[0],borderColor[1],borderColor[2],borderColor[3]);
#else
		glColor4f(borderColor[0], borderColor[1], borderColor[2], borderColor[3]);
		GLSTROKERECT(localBounds);
#endif
	}
	OSSpinLockUnlock(&propertyLock);
	
	//	call 'finishedDrawing' so subclasses of me have a chance to perform post-draw cleanup
	[self finishedDrawing];
	
	
	//	if i have subviews, tell them to draw now- back to front...
	if (subviews!=nil && [subviews count]>0)	{
		[subviews rdlock];
		
		NSEnumerator	*it = [[subviews array] reverseObjectEnumerator];
		VVView			*viewPtr = nil;
		while (viewPtr = [it nextObject])	{
			//NSLog(@"\t\tview is %@",viewPtr);
			VVPOINT			viewBoundsOrigin = [viewPtr boundsOrigin];
			VVRECT			viewFrameInMyLocalBounds = [viewPtr frame];
			//VVRectLog(@"\t\tviewFrameInMyLocalBounds is",viewFrameInMyLocalBounds);
			VVRECT			intersectRectInMyLocalBounds = VVINTERSECTIONRECT(r,viewFrameInMyLocalBounds);
			if (intersectRectInMyLocalBounds.size.width>0 && intersectRectInMyLocalBounds.size.height>0)	{
				//VVRectLog(@"\t\tintersectRectInMyLocalBounds is",intersectRectInMyLocalBounds);
				//	apply transformation matrices so that when the view draws, its origin in GL is the correct location in the context (the view will have to correct for its own bounds rotation & bounds offset, but that's beyond the scope of this instance)
#if !IPHONE
				glMatrixMode(GL_MODELVIEW);
				glPushMatrix();
				glTranslatef(viewFrameInMyLocalBounds.origin.x*localToBackingBoundsMultiplier, viewFrameInMyLocalBounds.origin.y*localToBackingBoundsMultiplier, 0.0);
#endif
				//	calculate the rect (in the view's local coordinate space) of the are of the view i'm going to ask to draw
				VVRECT					viewBoundsToDraw = intersectRectInMyLocalBounds;
				//viewBoundsToDraw.origin = VVMAKEPOINT(viewBoundsToDraw.origin.x-viewFrameInMyLocalBounds.origin.x, viewBoundsToDraw.origin.y-viewFrameInMyLocalBounds.origin.y);
				viewBoundsToDraw.origin = VVSUBPOINT(viewBoundsToDraw.origin, viewFrameInMyLocalBounds.origin);
				viewBoundsToDraw.origin = VVADDPOINT(viewBoundsToDraw.origin, viewBoundsOrigin);
				//NSRectLog(@"\t\tbefore rotation, viewBoundsToDraw was",viewBoundsToDraw);
				VVViewBoundsOrientation	viewBO = [viewPtr boundsOrientation];
				if (viewBO != VVViewBOBottom)	{
#if IPHONE
					CGAffineTransform		trans = CGAffineTransformIdentity;
					switch (viewBO)	{
						case VVViewBORight:
							CGAffineTransformRotate(trans, -90.0*(M_PI/180.0));
							break;
						case VVViewBOTop:
							CGAffineTransformRotate(trans, -180.0*(M_PI/180.0));
							break;
						case VVViewBOLeft:
							CGAffineTransformRotate(trans, -270.0*(M_PI/180.0));
							break;
						case VVViewBOBottom:
							break;
					}
					viewBoundsToDraw.origin = CGPointApplyAffineTransform(viewBoundsToDraw.origin, trans);
					viewBoundsToDraw.size = CGSizeApplyAffineTransform(viewBoundsToDraw.size, trans);
					//NSRectLog(@"\t\tafter rotation, viewBoundsToDraw was",viewBoundsToDraw);
#else
					NSAffineTransform		*rotTrans = [NSAffineTransform transform];
					switch (viewBO)	{
						case VVViewBORight:
							[rotTrans rotateByDegrees:-90.0];
							break;
						case VVViewBOTop:
							[rotTrans rotateByDegrees:-180.0];
							break;
						case VVViewBOLeft:
							[rotTrans rotateByDegrees:-270.0];
							break;
						case VVViewBOBottom:
							break;
					}
					viewBoundsToDraw.origin = [rotTrans transformPoint:viewBoundsToDraw.origin];
					viewBoundsToDraw.size = [rotTrans transformSize:viewBoundsToDraw.size];
#endif
					//	...make sure the size is valid.  i don't understand why this step is necessary- i think it's a sign i may be doing something wrong.
					viewBoundsToDraw.size = VVMAKESIZE(fabs(viewBoundsToDraw.size.width), fabs(viewBoundsToDraw.size.height));
					//NSRectLog(@"\t\tafter post-rotation size adjust, viewBoundsToDraw was",viewBoundsToDraw);
				}
				
				//	now tell the view to do its drawing!
#if !IPHONE
				[viewPtr _drawRect:viewBoundsToDraw inContext:cgl_ctx];
				glMatrixMode(GL_MODELVIEW);
				glPopMatrix();
#else
				[viewPtr _drawRect:viewBoundsToDraw];
#endif
			}
		}
		
		[subviews unlock];
	}
	
#if !IPHONE
	spriteCtx = NULL;
#endif
}

- (BOOL) isOpaque	{
	return isOpaque;
}
- (void) setIsOpaque:(BOOL)n	{
	isOpaque = n;
	[self setNeedsDisplay:YES];
}
- (void) finishedDrawing	{
	
}
//	you MUST LOCK 'spritesUpdateLock' BEFORE CALLING THIS METHOD
- (void) updateSprites	{
	spritesNeedUpdate = NO;
}

- (double) localToBackingBoundsMultiplier	{
	return localToBackingBoundsMultiplier;
}
- (void) setLocalToBackingBoundsMultiplier:(double)n	{
	localToBackingBoundsMultiplier = n;
	[subviews rdlock];
	for (VVView *viewPtr in [subviews array])	{
		[viewPtr setLocalToBackingBoundsMultiplier:n];
	}
	[subviews unlock];
}


/*===================================================================================*/
#pragma mark --------------------- misc backend- mostly key-val
/*------------------------------------*/


@synthesize deleted;
@synthesize spriteManager;
@synthesize spritesNeedUpdate;
- (void) setSpritesNeedUpdate:(BOOL)n	{
	pthread_mutex_lock(&spritesUpdateLock);
	spritesNeedUpdate = n;
	pthread_mutex_unlock(&spritesUpdateLock);
}
- (BOOL) spritesNeedUpdate	{
	BOOL		returnMe = NO;
	pthread_mutex_lock(&spritesUpdateLock);
	returnMe = spritesNeedUpdate;
	pthread_mutex_unlock(&spritesUpdateLock);
	return returnMe;
}
- (void) setSpritesNeedUpdate	{
	pthread_mutex_lock(&spritesUpdateLock);
	spritesNeedUpdate = YES;
	pthread_mutex_unlock(&spritesUpdateLock);
}
- (void) setNeedsDisplay:(BOOL)n	{
	needsDisplay = n;
	if (needsDisplay)	{
		if (_superview != nil)
			[_superview setNeedsDisplay:YES];
		else if (_containerView != nil)
			[_containerView setNeedsDisplay:YES];
	}
}
- (BOOL) needsDisplay	{
	return needsDisplay;
}
- (void) setNeedsDisplay	{
	[self setNeedsDisplay:YES];
}
- (void) setNeedsRender:(BOOL)n	{
	if (n)
		[self setNeedsDisplay:YES];
}
- (void) setNeedsRender	{
	[self setNeedsDisplay:YES];
}
- (BOOL) needsRender	{
	return needsDisplay;
}
#if !IPHONE
@synthesize lastMouseEvent;
#endif
#if IPHONE
- (void) setClearColor:(UIColor *)n	{
	if (n != nil)	{
		[n
			getRed:(CGFloat *)(clearColor+0)
			green:(CGFloat *)(clearColor+1)
			blue:(CGFloat *)(clearColor+2)
			alpha:(CGFloat *)(clearColor+3)];
	}
}
#else
- (void) setClearColor:(NSColor *)n	{
	NSColor				*devColor = nil;
	NSColorSpace		*devCS = [NSColorSpace deviceRGBColorSpace];
	CGFloat				tmpColor[4];
	devColor = ([n colorSpace]==devCS) ? n : [n colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	if (devColor != nil)	{
		[devColor getComponents:tmpColor];
		for (int i=0; i<4; ++i)
			clearColor[i] = tmpColor[i];
	}
}
#endif
- (void) setClearColors:(GLfloat)r :(GLfloat)g :(GLfloat)b :(GLfloat)a	{
	clearColor[0] = r;
	clearColor[1] = g;
	clearColor[2] = b;
	clearColor[3] = a;
}
#if IPHONE
- (void) setBorderColor:(UIColor *)n	{
	if (n != nil)	{
		[n
			getRed:(CGFloat *)(borderColor+0)
			green:(CGFloat *)(borderColor+1)
			blue:(CGFloat *)(borderColor+2)
			alpha:(CGFloat *)(borderColor+3)];
	}
}
#else
- (void) setBorderColor:(NSColor *)n	{
	NSColor				*devColor = nil;
	NSColorSpace		*devCS = [NSColorSpace deviceRGBColorSpace];
	CGFloat				tmpColor[4];
	devColor = ([n colorSpace]==devCS) ? n : [n colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	if (devColor != nil)	{
		[devColor getComponents:tmpColor];
		for (int i=0; i<4; ++i)
			borderColor[i] = tmpColor[i];
	}
}
#endif
- (void) setBorderColors:(GLfloat)r :(GLfloat)g :(GLfloat)b :(GLfloat)a	{
	borderColor[0] = r;
	borderColor[1] = g;
	borderColor[2] = b;
	borderColor[3] = a;
}
@synthesize drawBorder;
@synthesize mouseDownModifierFlags;
@synthesize mouseDownEventType;
@synthesize modifierFlags;
@synthesize mouseIsDown;
- (void) _setMouseIsDown:(BOOL)n	{
	if (deleted)
		return;
	mouseIsDown = n;
	if (_superview != nil)
		[_superview _setMouseIsDown:n];
	else if (_containerView != nil)
		[_containerView _setMouseIsDown:n];
}
@synthesize dragTypes;


@end

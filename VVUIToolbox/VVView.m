//
//  VVView.m
//  VVOpenSource
//
//  Created by bagheera on 11/1/12.
//
//

#import "VVView.h"
#import "VVBasicMacros.h"
#import <OpenGL/CGLMacro.h>
#import "VVSpriteGLView.h"
#import "VVScrollView.h"
#import <tgmath.h>
#import "VVSpriteMTLViewShaderTypes.h"




//	macro for performing a bitmask and returning a BOOL
#define VVBITMASKCHECK(mask,flagToCheck) ((mask & flagToCheck) == flagToCheck) ? ((BOOL)YES) : ((BOOL)NO)
#define LOCK VVLockLock
#define UNLOCK VVLockUnlock




/*	the passed array is expected to contain only rotation- or translation-type transforms.  the function concatenates 
adjacent-type transforms (concatenates all the adjacent translation transforms into a single translation transform, 
and all the adjacent rotation transforms into a single rotation transform).  the returned array, when processed 
serially, should produce the same result as the input array when processed serially on the same data.		*/
NSMutableArray<NSAffineTransform*> * VVViewMinimizeTransformsInArray(NSMutableArray<NSAffineTransform*> *inArray);




@implementation VVView


/*===================================================================================*/
#pragma mark --------------------- init/dealloc
/*------------------------------------*/


- (instancetype) initWithFrame:(VVRECT)n	{
	if (self = [super init])	{
		[self generalInit];
		_frame = n;
		//_bounds = VVMAKERECT(0,0,_frame.size.width,_frame.size.height);
		[self initComplete];
		return self;
	}
	VVRELEASE(self);
	return self;
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
	
	spriteCtx = NULL;
	needsDisplay = YES;
	_frame = VVMAKERECT(0,0,1,1);
	minFrameSize = VVMAKESIZE(1.0,1.0);
	localToBackingBoundsMultiplier = 1.0;
	//_bounds = _frame;
	_boundsOrigin = VVMAKEPOINT(0.0, 0.0);
	_boundsOrientation = VVViewBOBottom;
	//_boundsRotation = 0.0;
	trackingAreas = [[MutLockArray alloc] init];
	mvpBuffer = nil;
	_superview = nil;
	_containerView = nil;
	subviews = [[MutLockArray alloc] init];
	autoresizesSubviews = YES;
	autoresizingMask = VVViewResizeMaxXMargin | VVViewResizeMinYMargin;
	_propertyLock = VV_LOCK_INIT;
	lastMouseEvent = nil;
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
		for (id subview in subCopy)
			[self removeSubview:subview];
		[subCopy removeAllObjects];
		VVRELEASE(subCopy);
	}
	
	if (_superview != nil)
		[_superview removeSubview:self];
	else if (_containerView != nil)
		[(id<VVViewContainer>)_containerView removeVVSubview:self];
	
	deleted = YES;
	
	pthread_mutex_destroy(&spritesUpdateLock);
	if (spriteManager != nil)
		[spriteManager prepareToBeDeleted];
	spritesNeedUpdate = NO;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(subviews);
	LOCK(&_propertyLock);
	VVRELEASE(lastMouseEvent);
	UNLOCK(&_propertyLock);
	VVRELEASE(dragTypes);
	VVRELEASE(trackingAreas);
	mvpBuffer = nil;
	VVRELEASE(spriteManager);
}


/*===================================================================================*/
#pragma mark --------------------- first responder stuff
/*------------------------------------*/




/*===================================================================================*/
#pragma mark --------------------- mouse & key interaction via NSEvent
/*------------------------------------*/


- (void) mouseDown:(NSEvent *)e	{
	//NSLog(@"%s ... %@",__func__,self);
	if (deleted)
		return;
	LOCK(&_propertyLock);
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = e;
	UNLOCK(&_propertyLock);
	
	mouseIsDown = YES;
	VVPOINT		locationInWindow = [e locationInWindow];
	//VVPointLog(@"\t\tlocationInWindow is",locationInWindow);
	VVPOINT		localPoint = [self convertPointFromWinCoords:locationInWindow];
	//VVPointLog(@"\t\tlocalPoint A is",localPoint);
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	//VVPointLog(@"\t\tlocalPoint B is",localPoint);
	mouseDownModifierFlags = [e modifierFlags];
	modifierFlags = mouseDownModifierFlags;
	if ((mouseDownModifierFlags&NSEventModifierFlagControl)==NSEventModifierFlagControl)	{
		mouseDownEventType = VVSpriteEventRightDown;
		[spriteManager localRightMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
	}
	else	{
		if ([e clickCount]>=2)	{
			mouseDownEventType = VVSpriteEventDouble;
			[spriteManager localMouseDoubleDown:localPoint modifierFlag:mouseDownModifierFlags];
		}
		else	{
			mouseDownEventType = VVSpriteEventDown;
			[spriteManager localMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
		}
	}
}
- (void) rightMouseDown:(NSEvent *)e	{
	//NSLog(@"%s ... %@",__func__,self);
	if (deleted)
		return;
	LOCK(&_propertyLock);
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = e;
	UNLOCK(&_propertyLock);
	
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
	LOCK(&_propertyLock);
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = e;
	UNLOCK(&_propertyLock);
	
	modifierFlags = [e modifierFlags];
	VVPOINT		localPoint = [self convertPointFromWinCoords:[e locationInWindow]];
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	[spriteManager localMouseDragged:localPoint];
}
- (void) rightMouseDragged:(NSEvent *)e	{
	if (deleted)
		return;
	LOCK(&_propertyLock);
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = e;
	UNLOCK(&_propertyLock);
	
	modifierFlags = [e modifierFlags];
	VVPOINT		localPoint = [self convertPointFromWinCoords:[e locationInWindow]];
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	[spriteManager localMouseDragged:localPoint];
}
- (void) mouseUp:(NSEvent *)e	{
	if (deleted)
		return;
	
	if (mouseDownEventType == VVSpriteEventRightDown)	{
		[self rightMouseUp:e];
		return;
	}
	
	LOCK(&_propertyLock);
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = e;
	UNLOCK(&_propertyLock);
	
	modifierFlags = [e modifierFlags];
	mouseIsDown = NO;
	VVPOINT		localPoint = [self convertPointFromWinCoords:[e locationInWindow]];
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	[spriteManager localMouseUp:localPoint];
}
- (void) rightMouseUp:(NSEvent *)e	{
	if (deleted)
		return;
	LOCK(&_propertyLock);
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = e;
	UNLOCK(&_propertyLock);
	
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
	LOCK(&_propertyLock);
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = e;
	UNLOCK(&_propertyLock);
}
- (void) mouseExited:(NSEvent *)e	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	LOCK(&_propertyLock);
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = e;
	UNLOCK(&_propertyLock);
}
- (void) mouseMoved:(NSEvent *)e	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	LOCK(&_propertyLock);
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = e;
	UNLOCK(&_propertyLock);
}
- (void) scrollWheel:(NSEvent *)e	{
	if (deleted)
		return;
	//	don't bother doing anything with "lastMouseEvent", this is a scroll action
	//	find the first superview which is an instance of the "VVScrollView" class, tell it to scroll
	if ([e type] != NSEventTypeScrollWheel)
		NSLog(@"\t\terr: event wasn't of type NSScrollWheel in %s",__func__);
	else	{
		if ([self isKindOfClass:[VVScrollView class]])
			[(VVScrollView *)self scrollByAmount:VVMAKEPOINT([e scrollingDeltaX],[e scrollingDeltaY])];
		else	{
			if (_spriteGLViewSysVers >= 7)	{
				id		scrollView = [self enclosingScrollView];
				if (scrollView != nil)	{
					[scrollView scrollByAmount:VVMAKEPOINT([e scrollingDeltaX],[e scrollingDeltaY])];
					//[scrollView scrollWheel:e];
				}
			}
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


/*===================================================================================*/
#pragma mark --------------------- geometry- rect/point intersect & conversion
/*------------------------------------*/


//	the point it's passed is in coords local to the superview- i need to see if the coords are in my frame!
- (VVView *) vvSubviewHitTest:(VVPOINT)superviewPoint	{
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
	
	NSAffineTransform	*trans = [NSAffineTransform transform];
	VVPOINT				tmpPoint;
	switch (_boundsOrientation)	{
		case VVViewBOBottom:
			//[trans rotateByDegrees:0.0];
			//localPoint = [trans transformPoint:localPoint];
			localPoint = VVADDPOINT(localPoint, _boundsOrigin);
			break;
		case VVViewBORight:
			[trans rotateByDegrees:-90.0];
			localPoint = [trans transformPoint:localPoint];
			tmpPoint = VVMAKEPOINT(0.0, _frame.size.width);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			localPoint = VVADDPOINT(tmpPoint, localPoint);
			break;
		case VVViewBOTop:
			[trans rotateByDegrees:-180.0];
			localPoint = [trans transformPoint:localPoint];
			tmpPoint = VVMAKEPOINT(_frame.size.width,_frame.size.height);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			localPoint = VVADDPOINT(tmpPoint, localPoint);
			break;
		case VVViewBOLeft:
			[trans rotateByDegrees:-270.0];
			localPoint = [trans transformPoint:localPoint];
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
	//NSMutableArray		*transArray = [self _locationTransformsToContainerView];
	NSMutableArray		*transArray = [self localToContainerCoordinateSpaceDrawTransforms];
	NSEnumerator		*it = [transArray reverseObjectEnumerator];
	NSAffineTransform	*trans = nil;
	//	now convert from the container to me
	while (trans = [it nextObject])	{
		[trans invert];
		returnMe = [trans transformPoint:returnMe];
	}
	return returnMe;
}
- (VVPOINT) convertPointFromWinCoords:(VVPOINT)pointInWindow	{
	VVPOINT				returnMe = pointInWindow;
	//	convert the point from window coords to the coords local to the container view
	NSWindow			*containerWin = (_containerView==nil) ? nil : [_containerView window];
	NSView				*winContentView = (containerWin==nil) ? nil : [containerWin contentView];
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
	NSWindow		*containerWin = (_containerView==nil) ? nil : [_containerView window];
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
	//NSMutableArray		*transArray = [self _locationTransformsToContainerView];
	NSMutableArray		*transArray = [self localToContainerCoordinateSpaceDrawTransforms];
	NSEnumerator		*it = [transArray reverseObjectEnumerator];
	NSAffineTransform	*trans = nil;
	//	convert from the container view coords to my coords
	while (trans = [it nextObject])	{
		[trans invert];
		returnMe.origin = [trans transformPoint:returnMe.origin];
		returnMe.size = [trans transformSize:returnMe.size];
	}
	return returnMe;
}
- (VVRECT) convertRectFromSuperviewCoords:(VVRECT)rectInSuperview	{
	VVRECT				returnMe = rectInSuperview;
	NSMutableArray		*transArray = [self localToSuperviewCoordinateSpaceDrawTransforms];
	NSEnumerator		*it = [transArray reverseObjectEnumerator];
	NSAffineTransform	*trans = nil;
	//	convert from the container view coords to my coords
	while (trans = [it nextObject])	{
		[trans invert];
		returnMe.origin = [trans transformPoint:returnMe.origin];
		returnMe.size = [trans transformSize:returnMe.size];
	}
	return returnMe;
}


- (VVPOINT) convertPointToContainerViewCoords:(VVPOINT)localCoords	{
	//NSMutableArray		*transArray = [self _locationTransformsToContainerView];
	NSMutableArray		*transArray = [self localToContainerCoordinateSpaceDrawTransforms];
	VVPOINT				returnMe = localCoords;
	for (NSAffineTransform *trans in transArray)	{
		returnMe = [trans transformPoint:returnMe];
	}
	return returnMe;
}
- (VVPOINT) convertPointToWinCoords:(VVPOINT)localCoords	{
	VVPOINT				returnMe = [self convertPointToContainerViewCoords:localCoords];
	//	now that i've converted the local point to coords local to the container view, convert that to window coords
	NSWindow		*containerWin = (_containerView==nil) ? nil : [_containerView window];
	NSView			*winContentView = (containerWin==nil) ? nil : [containerWin contentView];
	if (winContentView != nil)	{
		returnMe = [winContentView convertPoint:returnMe fromView:_containerView];
	}
	return returnMe;
}
- (VVPOINT) convertPointToDisplayCoords:(VVPOINT)localCoords	{
	VVPOINT			returnMe = [self convertPointToWinCoords:localCoords];
	NSWindow		*containerWin = (_containerView==nil) ? nil : [_containerView window];
	if (containerWin != nil)	{
		VVRECT			containerWinFrame = [containerWin frame];
		returnMe = VVMAKEPOINT(returnMe.x+containerWinFrame.origin.x, returnMe.y+containerWinFrame.origin.y);
	}
	return returnMe;
}
- (VVRECT) convertRectToContainerViewCoords:(VVRECT)localRect	{
	//NSMutableArray		*transArray = [self _locationTransformsToContainerView];
	NSMutableArray		*transArray = [self localToContainerCoordinateSpaceDrawTransforms];
	VVRECT				returnMe = localRect;
	for (NSAffineTransform *trans in transArray)	{
		//returnMe = [trans transformRect:returnMe];
		returnMe.origin = [trans transformPoint:returnMe.origin];
		returnMe.size = [trans transformSize:returnMe.size];
	}
	return returnMe;
}
- (VVRECT) convertRectToSuperviewCoords:(VVRECT)localRect	{
	NSMutableArray		*transArray = [self localToSuperviewCoordinateSpaceDrawTransforms];
	VVRECT				returnMe = localRect;
	for (NSAffineTransform *trans in transArray)	{
		//returnMe = [trans transformRect:returnMe];
		returnMe.origin = [trans transformPoint:returnMe.origin];
		returnMe.size = [trans transformSize:returnMe.size];
	}
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
	VVView				*theSuperview = nil;
	VVRECT				viewFrame;
	VVViewBoundsOrientation		viewBO;
	VVPOINT						viewOrigin;
	NSAffineTransform	*trans = nil;
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
		
		
		theSuperview = [viewPtr superview];
		if (theSuperview==nil)
			break;
		else
			viewPtr = theSuperview;
	}
	return returnMe;
}


- (NSMutableArray<NSAffineTransform*> *) localToSuperviewCoordinateSpaceDrawTransforms	{
	//	adjust for the view's bounds translation
	NSAffineTransform	*boundsTrans = nil;
	if (_boundsOrigin.x != 0. || _boundsOrigin.y != 0.)	{
		boundsTrans = [NSAffineTransform transform];
		[boundsTrans translateXBy:-_boundsOrigin.x yBy:-_boundsOrigin.y];
	}
	
	//	adjust for the view's bounds rotation (which consists of a translation to re-center the origin after 
	//the rotation, so in this context we need to apply the translation first, and then the rotation...).  this 
	//is a RIGHT-handed coordinate system, so positive rotation is COUNTER- clockwise around the axis.  this 
	//transform is going from LOCAL to default (botom bounds orientation) coordinate space.
	NSAffineTransform	*orientationTrans = nil;
	NSAffineTransform	*orientationRot = nil;
	switch (_boundsOrientation)	{
	case VVViewBOBottom:
		break;
	case VVViewBORight:
		orientationRot = [NSAffineTransform transform];
		[orientationRot rotateByDegrees:90];
		orientationTrans = [NSAffineTransform transform];
		[orientationTrans translateXBy:0 yBy:-_frame.size.width];
		break;
	case VVViewBOTop:
		orientationRot = [NSAffineTransform transform];
		[orientationRot rotateByDegrees:180];
		orientationTrans = [NSAffineTransform transform];
		[orientationTrans translateXBy:-_frame.size.width yBy:-_frame.size.height];
		break;
	case VVViewBOLeft:
		orientationRot = [NSAffineTransform transform];
		[orientationRot rotateByDegrees:270];
		orientationTrans = [NSAffineTransform transform];
		[orientationTrans translateXBy:-_frame.size.height yBy:0];
		break;
	}
	
	//	adjust for the view's frame translation
	NSAffineTransform	*frameTrans = nil;
	if (_frame.origin.x != 0. || _frame.origin.y != 0.)	{
		frameTrans = [NSAffineTransform transform];
		[frameTrans translateXBy:_frame.origin.x yBy:_frame.origin.y];
	}
	
	NSMutableArray		*returnMe = [[NSMutableArray alloc] init];
	if (boundsTrans != nil)
		[returnMe addObject:boundsTrans];
	if (orientationTrans != nil)
		[returnMe addObject:orientationTrans];
	if (orientationRot != nil)
		[returnMe addObject:orientationRot];
	if (frameTrans != nil)
		[returnMe addObject:frameTrans];
	
	return returnMe;
}
- (NSMutableArray<NSAffineTransform*> *) localToContainerCoordinateSpaceDrawTransforms	{
	NSMutableArray		*tmpArray = [[NSMutableArray alloc] init];
	VVView				*tmpView = self;
	while (tmpView != nil)	{
		NSMutableArray		*tmpTransforms = [tmpView localToSuperviewCoordinateSpaceDrawTransforms];
		
		//NSEnumerator		*it = [tmpTransforms reverseObjectEnumerator];
		//while (VVView *tmpTransform = [it nextObject])	{
		//	[tmpArray insertObject:tmpTransform atIndex:0];
		//}
		
		[tmpArray addObjectsFromArray:tmpTransforms];
		
		tmpView = [tmpView superview];
	}
	
	//	don't forget to account for any changes to the bounds in the container view itself!
	if (_containerView != nil)	{
		NSRect					tmpBounds;
		if ([_containerView respondsToSelector:@selector(localBounds)])	{
			tmpBounds = [(VVSpriteMTLView*)_containerView localBounds];
		}
		else	{
			tmpBounds = _containerView.bounds;
		}
		NSAffineTransform		*boundsTrans = [NSAffineTransform transform];
		[boundsTrans translateXBy:-tmpBounds.origin.x yBy:-tmpBounds.origin.y];
		[tmpArray addObject:boundsTrans];
	}
	
	//NSLog(@"** temp disabled transform flatten optimization, %s",__func__);
	NSMutableArray		*returnMe = VVViewMinimizeTransformsInArray(tmpArray);
	return returnMe;
	
	//return tmpArray;
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
		[self updateTrackingAreas];
		if (_superview != nil)
			[_superview setNeedsDisplay:YES];
		else if (_containerView != nil)	{
			ObjectHolder		*_containerViewHolder = [[ObjectHolder alloc] initWithZWRObject:_containerView];
			void		(^tmpBlock)(void) = ^(void)	{
				id			localContainerView = [_containerViewHolder object];
				if (localContainerView != nil)	{
					[localContainerView setNeedsDisplay:YES];
				}
			};
			APPKIT_TMPBLOCK_MAINTHREAD
		}
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
		[self updateTrackingAreas];
		mvpBuffer = nil;
		if (_superview != nil)
			[_superview setNeedsDisplay:YES];
		else if (_containerView != nil)	{
			ObjectHolder		*_containerViewHolder = [[ObjectHolder alloc] initWithZWRObject:_containerView];
			void		(^tmpBlock)(void) = ^(void)	{
				id			localContainerView = [_containerViewHolder object];
				if (localContainerView != nil)	{
					[localContainerView setNeedsDisplay:YES];
				}
			};
			APPKIT_TMPBLOCK_MAINTHREAD
		}
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
			//pthread_mutex_lock(&spritesUpdateLock);
			//spritesNeedUpdate = YES;
			//pthread_mutex_unlock(&spritesUpdateLock);
			[self setSpritesNeedUpdate];
		//}
	}
}
- (void) setFrameOrigin:(VVPOINT)n	{
	if (deleted)
		return;
	BOOL		changed = (!VVEQUALPOINTS(n,_frame.origin)) ? YES : NO;
	[self _setFrameOrigin:n];
	if (changed)	{
		[self updateTrackingAreas];
		mvpBuffer = nil;
		if (_superview != nil)
			[_superview setNeedsDisplay:YES];
		else if (_containerView != nil)	{
			ObjectHolder		*_containerViewHolder = [[ObjectHolder alloc] initWithZWRObject:_containerView];
			void		(^tmpBlock)(void) = ^(void)	{
				id			localContainerView = [_containerViewHolder object];
				if (localContainerView != nil)	{
					[localContainerView setNeedsDisplay:YES];
				}
			};
			APPKIT_TMPBLOCK_MAINTHREAD
		}
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
		[self updateTrackingAreas];
		mvpBuffer = nil;
		if (_superview != nil)
			[_superview setNeedsDisplay:YES];
		else if (_containerView != nil)	{
			ObjectHolder		*_containerViewHolder = [[ObjectHolder alloc] initWithZWRObject:_containerView];
			void		(^tmpBlock)(void) = ^(void)	{
				id			localContainerView = [_containerViewHolder object];
				if (localContainerView != nil)	{
					[localContainerView setNeedsDisplay:YES];
				}
			};
			APPKIT_TMPBLOCK_MAINTHREAD
		}
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
		[self updateTrackingAreas];
		mvpBuffer = nil;
		if (_superview != nil)
			[_superview setNeedsDisplay:YES];
		else if (_containerView != nil)	{
			ObjectHolder		*_containerViewHolder = [[ObjectHolder alloc] initWithZWRObject:_containerView];
			void		(^tmpBlock)(void) = ^(void)	{
				id			localContainerView = [_containerViewHolder object];
				if (localContainerView != nil)	{
					[localContainerView setNeedsDisplay:YES];
				}
			};
			APPKIT_TMPBLOCK_MAINTHREAD
		}
	}
}


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
		//NSLog(@"\t\terr: bailing, %s",__func__);
		return VVZERORECT;
	}
	//	i need my superview's visible rect (in my superview's local coords)
	VVRECT		superviewVisRect = VVZERORECT;
	//	if my superview's nil, i'm a top-level VVView
	if (_superview==nil)	{
		//	get the container view's visible rect (its visible bounds)
		if (_containerView!=nil && [(VVSpriteMTLView*)_containerView respondsToSelector:@selector(localVisibleRect)])	{
			superviewVisRect = [(VVSpriteMTLView*)_containerView localVisibleRect];
			if (VVISZERORECT(superviewVisRect))
				return VVZERORECT;
			VVRECT		tmpBounds = [(VVSpriteMTLView*)_containerView localBounds];
			superviewVisRect.origin.x += tmpBounds.origin.x;
			superviewVisRect.origin.y += tmpBounds.origin.y;
		}
		else	{
			superviewVisRect = [_containerView visibleRect];
			if (VVISZERORECT(superviewVisRect))
				return VVZERORECT;
			VVRECT		tmpBounds = [_containerView bounds];
			superviewVisRect.origin.x += tmpBounds.origin.x;
			superviewVisRect.origin.y += tmpBounds.origin.y;
		}
		
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
	returnMe.size = VVMAKESIZE(fabs(returnMe.size.width),fabs(returnMe.size.height));
	//VVRectLog(@"\t\treturning",returnMe);
	return returnMe;
}
- (VVRECT) localVisibleRect	{
	return [self visibleRect];
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
	//if (dragTypeChanged && _containerView!=nil)
	//	[_containerView reconcileVVSubviewDragTypes];
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
	//NSLog(@"%s ... %@, %@",__func__,self,n);
	if (deleted || n==nil || subviews==nil)
		return;
	[subviews wrlock];
	if (![subviews containsIdenticalPtr:n])	{
		[subviews insertObject:n atIndex:0];
		[n _setSuperview:self];
		[n setContainerView:_containerView];
		if (_containerView != nil)	{
			ObjectHolder		*_containerViewHolder = [[ObjectHolder alloc] initWithZWRObject:_containerView];
			void		(^tmpBlock)(void) = ^(void)	{
				id			localContainerView = [_containerViewHolder object];
				if (localContainerView != nil)	{
					[localContainerView setNeedsDisplay:YES];
				}
			};
			APPKIT_TMPBLOCK_MAINTHREAD
		}
	}
	[subviews unlock];
	//	if the subviews i'm adding have any drag types, tell the container view to reconcile its drag types
	NSMutableArray		*tmpArray = MUTARRAY;
	[n _collectDragTypesInArray:tmpArray];
	if ([tmpArray count]>0 && _containerView!=nil)
		[(id<VVViewContainer>)_containerView reconcileVVSubviewDragTypes];
}
- (void) removeSubview:(id)n	{
	if (deleted || n==nil || subviews==nil)
		return;
	[subviews lockRemoveIdenticalPtr:n];
	[n _setSuperview:nil];
	[n setContainerView:nil];
	if (_containerView != nil)	{
		ObjectHolder		*_containerViewHolder = [[ObjectHolder alloc] initWithZWRObject:_containerView];
		void		(^tmpBlock)(void) = ^(void)	{
			id			localContainerView = [_containerViewHolder object];
			if (localContainerView != nil)	{
				[localContainerView setNeedsDisplay:YES];
			}
		};
		APPKIT_TMPBLOCK_MAINTHREAD
	}
	
	//	if the subview i'm removing has any drag types, tell the container view to reconcile its drag types
	NSMutableArray		*tmpArray = MUTARRAY;
	[n _collectDragTypesInArray:tmpArray];
	if ([tmpArray count]>0 && _containerView!=nil)
		[(id<VVViewContainer>)_containerView reconcileVVSubviewDragTypes];
}
- (void) removeFromSuperview	{
	if (deleted)
		return;
	//NSLog(@"%s - ERR",__func__);
	if (_superview != nil)	{
		[_superview removeSubview:self];
	}
	else if (_containerView != nil)	{
		[(id<VVViewContainer>)_containerView removeVVSubview:self];
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
- (void) setContainerView:(NSView *)n	{
	BOOL			changed = (_containerView != n) ? YES : NO;
	if (changed && _containerView!=nil)	{
		[self _clearAppleTrackingAreas];
	}
	
	_containerView = n;
	
	if (changed && _containerView!=nil)	{
		[self _refreshAppleTrackingAreas];
	}
	
	if (subviews!=nil && [subviews count]>0)	{
		[subviews lockMakeObjectsPerformSelector:@selector(setContainerView:) withObject:n];
	}
	//	use the localToBackingBoundsMultiplier from the container view!
	if (_containerView != nil)	{
		//localToBackingBoundsMultiplier = [_containerView localToBackingBoundsMultiplier];
		[self setLocalToBackingBoundsMultiplier:[(id<VVViewContainer>)_containerView localToBackingBoundsMultiplier]];
	}
}
- (NSView *) containerView	{
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
	
	
}
- (void) _drawRect:(VVRECT)r	{
	//NSLog(@"%s ... %@",__func__,NSStringFromRect(r));
	NSGraphicsContext		*ctx = [NSGraphicsContext currentContext];
	CGContextRef			cgCtx = [ctx CGContext];
	if (cgCtx == NULL)
		return;
	
	//	make a block that applies all of the appropriate transforms in order
	//NSArray<NSAffineTransform*>			*localTransforms = [self localToContainerCoordinateSpaceDrawTransforms];
	//NSRect (^ApplyTransformToRect)(NSRect) = ^(NSRect inRect)	{
	//	NSRect			returnMe = inRect;
	//	for (NSAffineTransform *localTransform in localTransforms)	{
	//		returnMe.origin = [localTransform transformPoint:returnMe.origin];
	//		returnMe.size = [localTransform transformSize:returnMe.size];
	//	}
	//	return returnMe;
	//};
	
	//	save the state before we alter any transform matrices or clipping paths
	CGContextSaveGState(cgCtx);
	
	//	clip all drawing to within my frame
	NSRect			tmpBounds = [self bounds];
	//NSRect			clipNSRect = ApplyTransformToRect( [self bounds] );
	NSRect			clipNSRect = NSPositiveDimensionsRect([self convertRectToContainerViewCoords:tmpBounds]);
	//NSLog(@"\t\ttmpBounds are %@",NSStringFromRect(tmpBounds));
	//NSLog(@"\t\tclipNSRect is %@",NSStringFromRect(clipNSRect));
	CGRect			clipRect = NSRectToCGRect( clipNSRect );
	CGContextClipToRect(cgCtx, clipRect);
	//NSLog(@"** clipping temp disabled %s",__func__);
	
	//	clear the background by filling the frame (note: this is still before we apply the transform matrix to adjust for my geometry- we're doing the clipping path & clearing in the superview's coordinate space!)
	if (clearColor[3] > 0.)	{
		[[NSColor colorWithDeviceRed:clearColor[0] green:clearColor[1] blue:clearColor[2] alpha:clearColor[3]] set];
		NSRectFill(clipRect);
	}
	
	
	//	tell the sprite manager to draw
	if (spriteManager != nil)	{
		//[spriteManager drawRect:r];
		[spriteManager draw];
	}
	
	//	do my drawing (just call a method that subclasses of me can override)
	[self drawRect:r];
	
	//	tell my subviews (if there are any) to draw
	NSArray<VVView*>	*localSubviews = [subviews lockCreateArrayCopy];
	for (VVView * subview in localSubviews)	{
		[subview _drawRect:[subview bounds]];
	}
	
	//	restore the graphics state (which will take care of both the transform matrix and clipping path)
	CGContextRestoreGState(cgCtx);
	
	//	if there's a border, draw it now...
	LOCK(&_propertyLock);
	if (drawBorder)	{
		[[NSColor colorWithDeviceRed:borderColor[0] green:borderColor[1] blue:borderColor[2] alpha:borderColor[3]] set];
		NSFrameRect(clipRect);
	}
	UNLOCK(&_propertyLock);
}
- (void) drawRect:(VVRECT)r inContext:(CGLContextObj)cgl_ctx	{
	//NSLog(@"ERR: %s, %@",__func__,self);
	//VVRectLog(@"\t\trect is",r);
	/*		this method should be used by subclasses.  put the simple drawing code in here (origin is the bottom-left corner of me!)		*/
}
- (void) drawRect:(VVRECT)r inEncoder:(id<MTLRenderCommandEncoder>)inEnc commandBuffer:(id<MTLCommandBuffer>)cb	{
	//NSLog(@"ERR: %s, %@",__func__,self);
	//VVRectLog(@"\t\trect is",r);
	/*		this method should be used by subclasses.  put the simple drawing code in here (origin is the bottom-left corner of me!)		*/
}


- (void) _drawRect:(VVRECT)r inEncoder:(id<MTLRenderCommandEncoder>)inEnc commandBuffer:(id<MTLCommandBuffer>)cb	{
	//NSLog(@"%s",__func__);
	//NSLog(@"%s ... %@, %@",__func__,self,NSStringFromRect(r));
	
	VVRECT			drawRectInContainerView = r;
	VVRECT			frameInContainerView = [self bounds];
	//	these are the transforms we need to apply to the geometry so they draw correctly
	NSMutableArray<NSAffineTransform*>		*transforms = [self localToContainerCoordinateSpaceDrawTransforms];
	for (NSAffineTransform *transform in transforms)	{
		frameInContainerView.origin = [transform transformPoint:frameInContainerView.origin];
		frameInContainerView.size = [transform transformSize:frameInContainerView.size];
		drawRectInContainerView.origin = [transform transformPoint:drawRectInContainerView.origin];
		drawRectInContainerView.size = [transform transformSize:drawRectInContainerView.size];
	}
	//VVRECT			scissorRect = NSPositiveDimensionsRect(drawRectInContainerView);
	VVRECT			scissorRect = NSIntegralPositiveDimensionsRect(drawRectInContainerView);
	//NSLog(@"\t\tscissor rect (in container view coords) is %@",NSStringFromRect(scissorRect));
	//VVRECT			bigScissorRect = NSInsetRect(scissorRect, -1, -1);
	MTLScissorRect		tmpScissorRect;
	
	VVSpriteMTLViewVertex		verts[4];
	verts[0].position = simd_make_float2( frameInContainerView.origin.x, frameInContainerView.origin.y + frameInContainerView.size.height );
	verts[1].position = simd_make_float2( frameInContainerView.origin.x, frameInContainerView.origin.y );
	verts[2].position = simd_make_float2( frameInContainerView.origin.x + frameInContainerView.size.width, frameInContainerView.origin.y + frameInContainerView.size.height );
	verts[3].position = simd_make_float2( frameInContainerView.origin.x + frameInContainerView.size.width, frameInContainerView.origin.y );
	
	for (int i=0; i<4; ++i)	{
		verts[i].color = simd_make_float4(clearColor[0], clearColor[1], clearColor[2], clearColor[3]);
		verts[i].texIndex = -1;
	}
	
	//	apply the small scissor rect
	tmpScissorRect.x = fabs(scissorRect.origin.x);
	tmpScissorRect.y = fabs(scissorRect.origin.y);
	tmpScissorRect.width = fabs(scissorRect.size.width);
	tmpScissorRect.height = fabs(scissorRect.size.height);
	//	i do not understand why this isn't working at all, the math here looks fine?  like, counting the pixels onscreen of the above coords clearly describes the desirable scissor rect, but....it doesn't render out that way?
	//[inEnc setScissorRect:tmpScissorRect];
	
	//	draw the fill
	[inEnc
		setVertexBytes:verts
		length:sizeof(verts)
		atIndex:VVSpriteMTLView_VS_Idx_Verts];
	[inEnc
		drawPrimitives:MTLPrimitiveTypeTriangleStrip
		vertexStart:0
		vertexCount:4];
	
	//	call the method subclasses may be overriding
	[self drawRect:r inEncoder:inEnc commandBuffer:cb];
	
	//	apply the big scissor rect
	//tmpScissorRect.x = bigScissorRect.origin.x;
	//tmpScissorRect.y = bigScissorRect.origin.y;
	//tmpScissorRect.width = bigScissorRect.size.width;
	//tmpScissorRect.height = bigScissorRect.size.height;
	//[inEnc setScissorRect:tmpScissorRect];
	//	draw the stroke
	//[inEnc
	//	drawPrimitives:MTLPrimitiveTypeLineStrip
	//	vertexStart:0
	//	vertexCount:4];
	
	//	call 'finishedDrawing' so subclasses of me have a chance to perform post-draw cleanup
	[self finishedDrawing];
	
	
	//	if i have subviews, tell them to draw now- back to front...
	if (subviews!=nil && [subviews count]>0)	{
		[subviews rdlock];
		
		NSEnumerator	*it = [[subviews array] reverseObjectEnumerator];
		VVView			*viewPtr = nil;
		while (viewPtr = [it nextObject])	{
			//NSLog(@"\t\tview is %@",viewPtr);
			//VVPOINT			viewBoundsOrigin = [viewPtr boundsOrigin];
			VVRECT			viewFrameInMyLocalBounds = [viewPtr frame];
			//NSLog(@"\t\tsubview %@ has frame %@",viewPtr,NSStringFromRect(viewFrameInMyLocalBounds));
			VVRECT			intersectRectInMyLocalBounds = VVINTERSECTIONRECT(r,viewFrameInMyLocalBounds);
			//NSLog(@"\t\tintersectRectInMyLocalBounds is %@",NSStringFromRect(intersectRectInMyLocalBounds));
			if (intersectRectInMyLocalBounds.size.width>0 && intersectRectInMyLocalBounds.size.height>0)	{
				VVRECT			viewBoundsToDraw = [viewPtr convertRectFromSuperviewCoords:intersectRectInMyLocalBounds];
				//viewBoundsToDraw = NSPositiveDimensionsRect(viewBoundsToDraw);
				viewBoundsToDraw = NSIntegralPositiveDimensionsRect(viewBoundsToDraw);
				
				//	now tell the view to do its drawing!
				[viewPtr _drawRect:viewBoundsToDraw inEncoder:inEnc commandBuffer:cb];
			}
		}
		
		[subviews unlock];
	}
}


- (void) _drawRect:(VVRECT)r inContext:(CGLContextObj)cgl_ctx
{
	//NSLog(@"%s ... %@",__func__,self);
	//NSLog(@"%s ... %@, %@",__func__,self,NSStringFromRect(r));
	//VVRectLog(@"\t\trect is",r);
	//VVRectLog(@"\t\tclipRect is",c);
	if (deleted)
		return;
	
	spriteCtx = cgl_ctx;
	
	pthread_mutex_lock(&spritesUpdateLock);
	BOOL		lSpritesNeedUpdate = spritesNeedUpdate;
	pthread_mutex_unlock(&spritesUpdateLock);
	if (lSpritesNeedUpdate)
		[self updateSprites];
	
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
	
	
	//	get the local bounds- zero out the origin before clearing
	VVRECT		localBounds = [self backingBounds];
	//VVRectLog(@"\t\tlocalBounds is",localBounds);
	//	if i'm opaque, fill my bounds
	LOCK(&_propertyLock);
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
	if (isOpaque)	{
		glDisableClientState(GL_COLOR_ARRAY);
		glEnableClientState(GL_VERTEX_ARRAY);
		glDisableClientState(GL_TEXTURE_COORD_ARRAY);
		
		glColor4f(clearColor[0], clearColor[1], clearColor[2], 1.0);
		GLDRAWRECT(VVMAKERECT(0,0,localBounds.size.width, localBounds.size.height));
	}
	else if (clearColor[3]!=0.0)	{
		glDisableClientState(GL_COLOR_ARRAY);
		glEnableClientState(GL_VERTEX_ARRAY);
		glDisableClientState(GL_TEXTURE_COORD_ARRAY);
		
		glColor4f(clearColor[0], clearColor[1], clearColor[2], clearColor[3]);
		GLDRAWRECT(VVMAKERECT(0,0,localBounds.size.width, localBounds.size.height));
	}
	UNLOCK(&_propertyLock);
	
	
	//	tell the sprite manager to draw
	if (spriteManager != nil)	{
		[spriteManager drawInContext:cgl_ctx];
	}
	
	//	...now call the "meat" of my drawing method (where most drawing code will be handled)
	[self drawRect:r inContext:cgl_ctx];
	
	//	if there's a border, draw it now
	LOCK(&_propertyLock);
	if (drawBorder)	{
		glColor4f(borderColor[0], borderColor[1], borderColor[2], borderColor[3]);
		GLSTROKERECT(localBounds);
	}
	UNLOCK(&_propertyLock);
	
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
				glMatrixMode(GL_MODELVIEW);
				glPushMatrix();
				glTranslatef(viewFrameInMyLocalBounds.origin.x*localToBackingBoundsMultiplier, viewFrameInMyLocalBounds.origin.y*localToBackingBoundsMultiplier, 0.0);
				//	calculate the rect (in the view's local coordinate space) of the are of the view i'm going to ask to draw
				VVRECT					viewBoundsToDraw = intersectRectInMyLocalBounds;
				//viewBoundsToDraw.origin = VVMAKEPOINT(viewBoundsToDraw.origin.x-viewFrameInMyLocalBounds.origin.x, viewBoundsToDraw.origin.y-viewFrameInMyLocalBounds.origin.y);
				viewBoundsToDraw.origin = VVSUBPOINT(viewBoundsToDraw.origin, viewFrameInMyLocalBounds.origin);
				viewBoundsToDraw.origin = VVADDPOINT(viewBoundsToDraw.origin, viewBoundsOrigin);
				//NSRectLog(@"\t\tbefore rotation, viewBoundsToDraw was",viewBoundsToDraw);
				VVViewBoundsOrientation	viewBO = [viewPtr boundsOrientation];
				if (viewBO != VVViewBOBottom)	{
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
					//	...make sure the size is valid.  i don't understand why this step is necessary- i think it's a sign i may be doing something wrong.
					viewBoundsToDraw.size = VVMAKESIZE(fabs(viewBoundsToDraw.size.width), fabs(viewBoundsToDraw.size.height));
					//NSRectLog(@"\t\tafter post-rotation size adjust, viewBoundsToDraw was",viewBoundsToDraw);
				}
				
				//	now tell the view to do its drawing!
				[viewPtr _drawRect:viewBoundsToDraw inContext:cgl_ctx];
				glMatrixMode(GL_MODELVIEW);
				glPopMatrix();
			}
		}
		
		[subviews unlock];
	}
	
	spriteCtx = NULL;
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
- (void) updateSprites	{
	pthread_mutex_lock(&spritesUpdateLock);
	spritesNeedUpdate = NO;
	pthread_mutex_unlock(&spritesUpdateLock);
}

- (double) localToBackingBoundsMultiplier	{
	return localToBackingBoundsMultiplier;
}
- (void) setLocalToBackingBoundsMultiplier:(double)n	{
	BOOL		changed = (localToBackingBoundsMultiplier != n);
	localToBackingBoundsMultiplier = n;
	[subviews rdlock];
	for (VVView *viewPtr in [subviews array])	{
		[viewPtr setLocalToBackingBoundsMultiplier:n];
	}
	[subviews unlock];
	if (changed)	{
		self.spritesNeedUpdate = YES;
	}
}

- (VVRECT) convertRectToBacking:(VVRECT)n	{
	return VVMAKERECT(n.origin.x*localToBackingBoundsMultiplier, n.origin.y*localToBackingBoundsMultiplier, n.size.width*localToBackingBoundsMultiplier, n.size.height*localToBackingBoundsMultiplier);
}
- (VVRECT) convertRectToLocalBackingBounds:(VVRECT)n	{
	return [self convertRectToBacking:n];
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
			[_superview setNeedsDisplay:n];
		else if (_containerView != nil)	{
			ObjectHolder		*_containerViewHolder = [[ObjectHolder alloc] initWithZWRObject:_containerView];
			void		(^tmpBlock)(void) = ^(void)	{
				id			localContainerView = [_containerViewHolder object];
				if (localContainerView != nil)	{
					[localContainerView setNeedsDisplay:n];
				}
			};
			APPKIT_TMPBLOCK_MAINTHREAD
		}
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
- (void) setLastMouseEvent:(NSEvent *)n	{
	LOCK(&_propertyLock);
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = n;
	UNLOCK(&_propertyLock);
}
- (NSEvent *) lastMouseEvent	{
	LOCK(&_propertyLock);
	NSEvent		*returnMe = lastMouseEvent;
	UNLOCK(&_propertyLock);
	return returnMe;
}
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
- (void) setClearColors:(float)r :(float)g :(float)b :(float)a	{
	clearColor[0] = r;
	clearColor[1] = g;
	clearColor[2] = b;
	clearColor[3] = a;
}
- (void) getClearColors:(float *)n	{
	if (n==nil)
		return;
	for (int i=0; i<4; ++i)
		*(n+i)=clearColor[i];
}
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
- (void) setBorderColors:(float)r :(float)g :(float)b :(float)a	{
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
		[(id<VVViewContainer>)_containerView _setMouseIsDown:n];
}
@synthesize dragTypes;
- (BOOL) isVVView	{
	return YES;
}


@end




@implementation NSObject (VVView)
- (BOOL) isVVView	{
	return NO;
}
@end







NSMutableArray<NSAffineTransform*> * VVViewMinimizeTransformsInArray(NSMutableArray<NSAffineTransform*> *inArray)	{
	NSMutableArray<NSAffineTransform*>		*returnMe = [[NSMutableArray alloc] init];
	
	//	make a copy of the array we were passed- we're going to run through this from beginning to end, emptying it in the process as we create the array of transforms to return in the process
	NSMutableArray<NSAffineTransform*>		*tmpArray = [inArray mutableCopy];
	while (tmpArray.count > 0)	{
		
		int						tmpIndex = 0;
		NSAffineTransform		*cumulativeTransform = nil;
		BOOL					firstIsTranslation = NO;
		int						lastMatchIndex = 0;
		for (NSAffineTransform * tmpTrans in tmpArray)	{
			NSAffineTransformStruct		tmpTransStruct = tmpTrans.transformStruct;
			BOOL						tmpIsTranslation = (tmpTransStruct.tX != 0 || tmpTransStruct.tY != 0);
			//	if this is the first transform, make a note of what kind of transform it was and make a copy of it that we can mutate
			if (tmpIndex == 0)	{
				firstIsTranslation = tmpIsTranslation;
				cumulativeTransform = [tmpTrans copy];
			}
			//	else this isn't the first transform, process it
			else	{
				//	if this transform matches the first transform, make a note, update the cumulative transform, and let the iteration continue
				if (firstIsTranslation == tmpIsTranslation)	{
					lastMatchIndex = tmpIndex;
					[cumulativeTransform appendTransform:tmpTrans];
				}
				//	else this transform doesn't match the first transform
				else	{
					//	halt iteration, and process
					break;
				}
			}
			
			++tmpIndex;
		}
		
		//	...if we're here, we either broke out of the for loop or it finished iterating.
		
		//	add the cumulative transform to the array we'll be returning
		if (cumulativeTransform != nil)	{
			[returnMe addObject:cumulativeTransform];
		}
		//	remove the transforms at the appropriate indexes from the array of transforms we need to continue processing
		for (int i=0; i<=lastMatchIndex; ++i)	{
			[tmpArray removeObjectAtIndex:0];
		}
		
		//	...let the while loop repeat this process until there's nothing left in the array of transforms
		
	}
	
	return returnMe;
}




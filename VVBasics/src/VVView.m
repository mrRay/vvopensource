//
//  VVView.m
//  VVOpenSource
//
//  Created by bagheera on 11/1/12.
//
//

#import "VVView.h"
#import "VVBasicMacros.h"
#import "VVSpriteGLView.h"




//	macro for performing a bitmask and returning a BOOL
#define VVBITMASKCHECK(mask,flagToCheck) ((mask & flagToCheck) == flagToCheck) ? ((BOOL)YES) : ((BOOL)NO)




@implementation VVView


- (id) initWithFrame:(NSRect)n	{
	if (self = [super init])	{
		[self generalInit];
		_frame = n;
		//_bounds = NSMakeRect(0,0,_frame.size.width,_frame.size.height);
		return self;
	}
	[self release];
	return nil;
}
- (void) generalInit	{
	deleted = NO;
	spriteManager = [[VVSpriteManager alloc] init];
	spritesNeedUpdate = YES;
	spriteCtx = NULL;
	needsDisplay = YES;
	_frame = NSMakeRect(0,0,1,1);
	minFrameSize = NSMakeSize(1.0,1.0);
	localToBackingBoundsMultiplier = 1.0;
	//_bounds = _frame;
	_boundsOrigin = NSMakePoint(0.0, 0.0);
	_boundsOrientation = VVViewBOBottom;
	//_boundsRotation = 0.0;
	_superview = nil;
	_containerView = nil;
	subviews = [[MutLockArray alloc] init];
	autoresizesSubviews = YES;
	autoresizingMask = VVViewResizeMaxXMargin | VVViewResizeMinYMargin;
	propertyLock = OS_SPINLOCK_INIT;
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
	VVRELEASE(lastMouseEvent);
	OSSpinLockUnlock(&propertyLock);
	VVRELEASE(dragTypes);
	[super dealloc];
}


- (void) mouseDown:(NSEvent *)e	{
	NSLog(@"%s ... %@",__func__,self);
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
	mouseIsDown = YES;
	NSPoint		locationInWindow = [e locationInWindow];
	//NSPointLog(@"\t\tlocationInWindow is",locationInWindow);
	NSPoint		localPoint = [self convertPointFromWinCoords:locationInWindow];
	NSPointLog(@"\t\tlocalPoint A is",localPoint);
	localPoint = NSMakePoint(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	//double		localToBackingBoundsMultiplier = [_containerView localToBackingBoundsMultiplier];
	//localPoint = NSMakePoint(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	//NSPointLog(@"\t\tlocalPoint B is",localPoint);
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
	NSPoint		locationInWindow = [e locationInWindow];
	NSPoint		localPoint = [self convertPointFromWinCoords:locationInWindow];
	localPoint = NSMakePoint(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
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
	NSPoint		localPoint = [self convertPointFromWinCoords:[e locationInWindow]];
	localPoint = NSMakePoint(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
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
	NSPoint		localPoint = [self convertPointFromWinCoords:[e locationInWindow]];
	localPoint = NSMakePoint(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
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
	NSPoint		localPoint = [self convertPointFromWinCoords:[e locationInWindow]];
	localPoint = NSMakePoint(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	[spriteManager localRightMouseUp:localPoint];
}
- (void) keyDown:(NSEvent *)e	{
	NSLog(@"%s ... %@",__func__,e);
}
- (void) keyUp:(NSEvent *)e	{
	NSLog(@"%s ... %@",__func__,e);
}


//	the point it's passed is in coords local to the superview- i need to see if the coords are in my frame!
- (id) vvSubviewHitTest:(NSPoint)superviewPoint	{
	//NSLog(@"%s ... %@- (%0.2f, %0.2f)",__func__,self,superviewPoint.x,superviewPoint.y);
	if (deleted)
		return nil;
	if (!NSPointInRect(superviewPoint,_frame))
		return nil;
	
	/*		if i'm here, the passed point was within my frame- check to 
			see if it's hitting any of my subviews, otherwise return self!		*/
	
	NSPoint			localPoint = superviewPoint;
	localPoint.x -= _frame.origin.x;
	localPoint.y -= _frame.origin.y;
	
	NSAffineTransform	*trans = [NSAffineTransform transform];
	NSPoint				tmpPoint;
	switch (_boundsOrientation)	{
		case VVViewBOBottom:
			//[trans rotateByDegrees:0.0];
			//localPoint = [trans transformPoint:localPoint];
			localPoint = VVADDPOINT(localPoint, _boundsOrigin);
			break;
		case VVViewBORight:
			[trans rotateByDegrees:-90.0];
			localPoint = [trans transformPoint:localPoint];
			tmpPoint = NSMakePoint(0.0, _frame.size.width);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			localPoint = VVADDPOINT(tmpPoint, localPoint);
			break;
		case VVViewBOTop:
			[trans rotateByDegrees:-180.0];
			localPoint = [trans transformPoint:localPoint];
			tmpPoint = NSMakePoint(_frame.size.width,_frame.size.height);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			localPoint = VVADDPOINT(tmpPoint, localPoint);
			break;
		case VVViewBOLeft:
			[trans rotateByDegrees:-270.0];
			localPoint = [trans transformPoint:localPoint];
			tmpPoint = NSMakePoint(_frame.size.height, 0.0);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			localPoint = VVADDPOINT(tmpPoint, localPoint);
			break;
	}
	/*
	[trans rotateByDegrees:-1.0*_boundsRotation];
	localPoint = [trans transformPoint:localPoint];
	
	localPoint.x += _bounds.origin.x;
	localPoint.y += _bounds.origin.y;
	*/
	id			returnMe = nil;
	[subviews rdlock];
	for (VVView *viewPtr in [subviews array])	{
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
- (BOOL) checkRect:(NSRect)n	{
	return NSIntersectsRect(n,_frame);
}
- (NSPoint) convertPoint:(NSPoint)viewCoords fromView:(id)view	{
	if (deleted || _containerView==nil)
		return viewCoords;
	id			otherContainerView = (view==nil) ? nil : [view containerView];
	if (otherContainerView==nil)
		return viewCoords;
	if (_containerView == otherContainerView)	{
		NSPoint		containerCoords = [view convertPointToContainerViewCoords:viewCoords];
		return [self convertPointFromContainerViewCoords:containerCoords];
	}
	else	{
		//	convert the point to absolute (display) coords
		NSPoint		displayCoords = [view convertPointToDisplayCoords:viewCoords];
		//	now convert the display coords to my coordinate space!
		return [self convertPointFromDisplayCoords:displayCoords];
	}
}
- (NSPoint) convertPointFromContainerViewCoords:(NSPoint)pointInContainer	{
	NSPoint				returnMe = pointInContainer;
	NSMutableArray		*transArray = [self _locationTransformsToContainerView];
	NSEnumerator		*it = [transArray reverseObjectEnumerator];
	NSAffineTransform	*trans = nil;
	//	now convert from the container to me
	while (trans = [it nextObject])	{
		[trans invert];
		returnMe = [trans transformPoint:returnMe];
		//NSPointLog(@"\t\t\ttmpPoint is",returnMe);
	}
	return returnMe;
}
- (NSPoint) convertPointFromWinCoords:(NSPoint)pointInWindow	{
	NSPoint				returnMe = pointInWindow;
	//	convert the point from window coords to the coords local to the container view
	NSWindow			*containerWin = (_containerView==nil) ? nil : [_containerView window];
	NSView				*winContentView = (containerWin==nil) ? nil : [containerWin contentView];
	if (winContentView != nil)	{
		returnMe = [_containerView convertPoint:returnMe fromView:winContentView];
	}
	
	//	convert from container view local coords to coords local to me
	returnMe = [self convertPointFromContainerViewCoords:returnMe];
	
	return returnMe;
}
- (NSPoint) convertPointFromDisplayCoords:(NSPoint)displayPoint	{
	NSPoint			returnMe = displayPoint;
	//	convert the point from display coords to window coords
	NSWindow		*containerWin = (_containerView==nil) ? nil : [_containerView window];
	if (containerWin != nil)	{
		NSRect			containerWinFrame = [containerWin frame];
		returnMe = NSMakePoint(displayPoint.x-containerWinFrame.origin.x, displayPoint.y-containerWinFrame.origin.y);
	}
	//	now convert the point from the win coords to coords local to me
	returnMe = [self convertPointFromWinCoords:returnMe];
	return returnMe;
}
- (NSRect) convertRectFromContainerViewCoords:(NSRect)rectInContainer	{
	NSRect				returnMe = rectInContainer;
	NSMutableArray		*transArray = [self _locationTransformsToContainerView];
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


- (NSPoint) convertPointToContainerViewCoords:(NSPoint)localCoords	{
	NSMutableArray		*transArray = [self _locationTransformsToContainerView];
	NSPoint				returnMe = localCoords;
	for (NSAffineTransform *trans in transArray)	{
		returnMe = [trans transformPoint:returnMe];
	}
	return returnMe;
}
- (NSPoint) convertPointToWinCoords:(NSPoint)localCoords	{
	NSPoint				returnMe = [self convertPointToContainerViewCoords:localCoords];
	//	now that i've converted the local point to coords local to the container view, convert that to window coords
	NSWindow		*containerWin = (_containerView==nil) ? nil : [_containerView window];
	NSView			*winContentView = (containerWin==nil) ? nil : [containerWin contentView];
	if (winContentView != nil)	{
		returnMe = [winContentView convertPoint:returnMe fromView:_containerView];
	}
	return returnMe;
}
- (NSPoint) convertPointToDisplayCoords:(NSPoint)localCoords	{
	NSPoint			returnMe = [self convertPointToWinCoords:localCoords];
	NSWindow		*containerWin = (_containerView==nil) ? nil : [_containerView window];
	if (containerWin != nil)	{
		NSRect			containerWinFrame = [containerWin frame];
		returnMe = NSMakePoint(returnMe.x+containerWinFrame.origin.x, returnMe.y+containerWinFrame.origin.y);
	}
	return returnMe;
}
- (NSRect) convertRectToContainerViewCoords:(NSRect)localRect	{
	NSMutableArray		*transArray = [self _locationTransformsToContainerView];
	NSRect				returnMe = localRect;
	for (NSAffineTransform *trans in transArray)	{
		//returnMe = [trans transformRect:returnMe];
		returnMe.origin = [trans transformPoint:returnMe.origin];
		returnMe.size = [trans transformSize:returnMe.size];
	}
	return returnMe;
}
- (NSPoint) winCoordsOfLocalPoint:(NSPoint)n	{
	//NSLog(@"%s ... (%0.2f, %0.2f)",__func__,n.x,n.y);
	return [self convertPointToWinCoords:n];
}
- (NSPoint) displayCoordsOfLocalPoint:(NSPoint)n	{
	//NSLog(@"%s ... (%0.2f, %0.2f)",__func__,n.x,n.y);
	return [self convertPointToDisplayCoords:n];
}
- (NSMutableArray *) _locationTransformsToContainerView	{
	//NSLog(@"%s ... %@",__func__,self);
	VVView				*viewPtr = self;
	VVView				*theSuperview = [viewPtr superview];
	NSRect				viewFrame;
	VVViewBoundsOrientation		viewBO;
	NSPoint						viewOrigin;
	NSAffineTransform	*trans = nil;
	NSMutableArray		*returnMe = MUTARRAY;
	NSPoint				tmpPoint;
	
	while (1)	{
		//NSLog(@"\t\tviewPtr is %@",viewPtr);
		viewFrame = [viewPtr frame];
		viewBO = [viewPtr boundsOrientation];
		viewOrigin = [viewPtr boundsOrigin];
		//	compensate for the view's bounds (including any bounds offsets caused by orientation/rotation)
		switch (viewBO)	{
			case VVViewBOBottom:
				tmpPoint = NSMakePoint(0.0, 0.0);
				viewOrigin = NSMakePoint(-1.0*viewOrigin.x, -1.0*viewOrigin.y);
				break;
			case VVViewBORight:
				tmpPoint = NSMakePoint(0.0, -1.0*viewFrame.size.width);
				viewOrigin = VVSUBPOINT(tmpPoint, viewOrigin);
				break;
			case VVViewBOTop:
				tmpPoint = NSMakePoint(-1.0*viewFrame.size.width, -1.0*viewFrame.size.height);
				viewOrigin = VVSUBPOINT(tmpPoint, viewOrigin);
				break;
			case VVViewBOLeft:
				tmpPoint = NSMakePoint(-1.0*viewFrame.size.height, 0.0);
				viewOrigin = VVSUBPOINT(tmpPoint, viewOrigin);
				break;
		}
		
		//	the 'frame' is the rect the view occupies in the superview's coordinate space
		//	the 'bounds' is the coordinate space visible in the view
		
		//	goal: to make transforms that convert from local in this view's bounds to local to the superview's bounds
		
		//	first compensate for any offset from the view's bounds
		//	then compensate for any bound rotation (use the bounds here- not the frame- to move the origin back!)
		//	finally, compensate for the view's frame (its position within its superview) to obtain the coordinates (relative to the enclosing superview)
		
		//NSPointLog(@"\t\tviewOrigin is",viewOrigin);
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
			//NSPointLog(@"\t\tcompensating for frame origin, ",viewFrame.origin);
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

- (NSMutableArray *) _locationTransformsFromSuperview	{
	NSLog(@"ERR: %s",__func__);
	return nil;
	/*
	NSMutableArray		*returnMe = MUTARRAY;
	NSAffineTransform	*trans = nil;
	if (_boundsRotation != 0)	{
		trans = [NSAffineTransform transform];
		[trans rotateByDegrees:_boundsRotation];
		[returnMe addObject:trans];
	}
	if (_bounds.origin.x!=0 || _bounds.origin.y!=0)	{
		trans = [NSAffineTransform transform];
		[trans translateXBy:_bounds.origin.x yBy:_bounds.origin.y];
		[returnMe addObject:trans];
	}
	if (_frame.origin.x!=0 || _frame.origin.y!=0)	{
		trans = [NSAffineTransform transform];
		[trans translateXBy:-1.0*_frame.origin.x yBy:-1.0*_frame.origin.y];
		[returnMe addObject:trans];
	}
	return returnMe;
	*/
}


- (NSRect) frame	{
	return _frame;
}
- (void) setFrame:(NSRect)n	{
	//NSLog(@"%s ... (%f, %f) : %f x %f",__func__,n.origin.x,n.origin.y,n.size.width,n.size.height);
	if (deleted)
		return;
	if (NSEqualRects(n,_frame))
		return;
	[self setFrameSize:n.size];
	_frame.origin = n.origin;
}
- (void) setFrameSize:(NSSize)proposedSize	{
	//NSLog(@"%s ... %@, (%f x %f)",__func__,self,proposedSize.width,proposedSize.height);
	NSSize			oldSize = _frame.size;
	NSSize			n = NSMakeSize(fmax(minFrameSize.width,proposedSize.width),fmax(minFrameSize.height,proposedSize.height));
	
	if ([self autoresizesSubviews])	{
		double		widthDelta = n.width - oldSize.width;
		double		heightDelta = n.height - oldSize.height;
		[subviews rdlock];
		for (VVView *viewPtr in [subviews array])	{
			VVViewResizeMask	viewResizeMask = [viewPtr autoresizingMask];
			NSRect				viewNewFrame = [viewPtr frame];
			//NSRectLog(@"\t\torig viewNewFrame is",viewNewFrame);
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
			//NSRectLog(@"\t\tmod viewNewFrame is",viewNewFrame);
			[viewPtr setFrame:viewNewFrame];
		}
		[subviews unlock];
	}
	
	_frame.size = n;
	/*
	if (_boundsRotation==90 || _boundsRotation==270)
		_bounds = NSMakeRect(0,0,_frame.size.height,_frame.size.width);
	else
		_bounds = NSMakeRect(0,0,_frame.size.width,_frame.size.height);
	*/
}
- (void) setFrameOrigin:(NSPoint)n	{
	_frame.origin = n;
	[self setNeedsDisplay:YES];
}
- (NSRect) bounds	{
	switch (_boundsOrientation)	{
		case VVViewBOBottom:
		case VVViewBOTop:
			return NSMakeRect(_boundsOrigin.x, _boundsOrigin.y, _frame.size.width, _frame.size.height);
		case VVViewBORight:
		case VVViewBOLeft:
			return NSMakeRect(_boundsOrigin.x, _boundsOrigin.y, _frame.size.height, _frame.size.width);
	}
	return NSMakeRect(0,0,0,0);
	/*
	return _bounds;
	*/
}
/*
- (void) setBounds:(NSRect)n	{
	//_bounds = n;
	if (_boundsRotation==90 || _boundsRotation==270)
		_bounds = NSMakeRect(n.origin.x, n.origin.y, n.size.height, n.size.width);
	else
		_bounds = n;
}
*/
- (void) setBoundsOrigin:(NSPoint)n	{
	BOOL		changed = (!NSEqualPoints(n,_boundsOrigin)) ? YES : NO;
	_boundsOrigin = n;
	if (changed)
		[self setNeedsDisplay];
	/*
	_boundsOrigin = n;
	*/
}
- (NSPoint) boundsOrigin	{
	return _boundsOrigin;
	/*
	return _boundsOrigin;
	*/
}
/*
- (void) setBoundsRotation:(GLfloat)n	{
	if (_boundsRotation != n)	{
		if ((n==0&&_boundsRotation==90) || (n==90&&_boundsRotation==0))
			_bounds.size = NSMakeSize(_bounds.size.height, _bounds.size.width);
		_boundsRotation = n;
	}
}
- (GLfloat) boundsRotation	{
	return _boundsRotation;
}
*/
- (VVViewBoundsOrientation) boundsOrientation	{
	return _boundsOrientation;
}
- (void) setBoundsOrientation:(VVViewBoundsOrientation)n	{
	BOOL		changed = (n==_boundsOrientation) ? NO : YES;
	_boundsOrientation = n;
	if (changed)
		[self setNeedsDisplay];
}
//	returns the visible rect in this view's LOCAL COORDINATE SPACE (bounds), just like NSView
- (NSRect) visibleRect	{
	//NSLog(@"%s ... %@",__func__,self);
	NSRect		tmpRect = [self _visibleRect];
	NSRect		returnMe;
	returnMe.origin.x = VVMINX(tmpRect);
	returnMe.size.width = VVMAXX(tmpRect)-returnMe.origin.x;
	returnMe.origin.y = VVMINY(tmpRect);
	returnMe.size.height = VVMAXY(tmpRect)-returnMe.origin.y;
	return returnMe;
}
- (NSRect) _visibleRect	{
	//NSLog(@"%s ... %@",__func__,self);
	if (deleted || (_superview==nil && _containerView==nil))	{
		NSLog(@"\t\terr: bailing, %s",__func__);
		return NSZeroRect;
	}
	//	i need my superview's visible rect (in my superview's local coords)
	NSRect		superviewVisRect = NSZeroRect;
	//	if my superview's nil, i'm a top-level VVView
	if (_superview==nil)	{
		//	get the container view's visible rect (its visible bounds)
		superviewVisRect = [_containerView visibleRect];
		if (VVISZERORECT(superviewVisRect))
			return NSZeroRect;
		
		NSRect		tmpBounds = [_containerView bounds];
		superviewVisRect.origin.x += tmpBounds.origin.x;
		superviewVisRect.origin.y += tmpBounds.origin.y;
	}
	//	else get my superview's visible rect
	else	{
		superviewVisRect = [_superview visibleRect];
		if (VVISZERORECT(superviewVisRect))
			return NSZeroRect;
	}
	//NSRectLog(@"\t\tsuperviewVisRect is",superviewVisRect);
	//	get the intersect rect with my superview's visible rect and my frame- this is my visible rect
	NSRect		myVisibleFrame = NSIntersectionRect(superviewVisRect,_frame);
	if (VVISZERORECT(myVisibleFrame))
		return NSZeroRect;
	myVisibleFrame.origin = NSMakePoint(myVisibleFrame.origin.x-_frame.origin.x, myVisibleFrame.origin.y-_frame.origin.y);
	//NSRectLog(@"\t\tmyVisibleFrame is",myVisibleFrame);
	//	convert the intersect rect (my visible frame) to my local coordinate space (bounds)
	
	
	NSRect				returnMe = myVisibleFrame;
	NSAffineTransform	*trans = nil;
	//NSPoint				tmpPoint;
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
			//tmpPoint = NSMakePoint(0.0, -1.0*_frame.size.width);
			//tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			//returnMe.origin = VVADDPOINT(returnMe.origin, tmpPoint);
			break;
		case VVViewBOTop:
			trans = [NSAffineTransform transform];
			[trans rotateByDegrees:-180.0];
			returnMe.origin = [trans transformPoint:returnMe.origin];
			returnMe.size = [trans transformSize:returnMe.size];
			returnMe.origin = VVADDPOINT(returnMe.origin, _boundsOrigin);
			//tmpPoint = NSMakePoint(-1.0*_frame.size.width,-1.0*_frame.size.height);
			//tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			//returnMe.origin = VVADDPOINT(returnMe.origin, tmpPoint);
			break;
		case VVViewBOLeft:
			trans = [NSAffineTransform transform];
			[trans rotateByDegrees:-270.0];
			returnMe.origin = [trans transformPoint:returnMe.origin];
			returnMe.size = [trans transformSize:returnMe.size];
			returnMe.origin = VVADDPOINT(returnMe.origin, _boundsOrigin);
			//tmpPoint = NSMakePoint(-1.0*_frame.size.height, 0.0);
			//tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			//returnMe.origin = VVADDPOINT(returnMe.origin, tmpPoint);
			break;
	}
	returnMe.size = NSMakeSize(fabs(returnMe.size.width),fabs(returnMe.size.height));
	//NSRectLog(@"\t\treturning",returnMe);
	/*
	NSRect		returnMe = myVisibleFrame;
	if (_boundsRotation != 0.0)	{
		NSAffineTransform		*trans = [NSAffineTransform transform];
		[trans rotateByDegrees:-1.0*_boundsRotation];
		returnMe.origin = [trans transformPoint:returnMe.origin];
		returnMe.size = [trans transformSize:returnMe.size];
	}
	returnMe.origin = NSMakePoint(returnMe.origin.x+_bounds.origin.x, returnMe.origin.y+_bounds.origin.y);
	*/
	return returnMe;
}
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
		NSRect		visRect = [self visibleRect];
		if ((visRect.size.width>0) && (visRect.size.height>0))	{
			returnMe = YES;
		}
	}
	return returnMe;
}


@synthesize autoresizesSubviews;
@synthesize autoresizingMask;
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
	NSLog(@"%s - ERR",__func__);
	if (_superview != nil)	{
		[_superview removeSubview:self];
	}
	else if (_containerView != nil)	{
		[_containerView removeVVSubview:self];
	}
}
- (void) _setSuperview:(id)n	{
	_superview = n;
}
- (id) superview	{
	return _superview;
}
- (BOOL) containsSubview:(id)n	{
	if (deleted || n==nil || subviews==nil)
		return NO;
	[subviews rdlock];
	for (VVView *viewPtr in [subviews array])	{
		if (viewPtr == n)
			return YES;
		if ([viewPtr containsSubview:n])
			return YES;
	}
	[subviews unlock];
	return NO;
}
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
- (void) setContainerView:(id)n	{
	_containerView = n;
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
	return nil;
}


- (void) drawRect:(NSRect)r	{
	NSLog(@"ERR: %s",__func__);
	/*		this method should never be called or used, ever.		*/
}
- (void) _drawRect:(NSRect)r inContext:(CGLContextObj)cgl_ctx	{
	//NSLog(@"%s ... %@",__func__,self);
	//NSRectLog(@"\t\tpassed rect is",r);
	//NSRectLog(@"\t\tclipRect is",c);
	if (deleted)
		return;
	
	spriteCtx = cgl_ctx;
	
	if (spritesNeedUpdate)
		[self updateSprites];
	
	//	configure glScissor so it's clipping to my visible rect (bail if i don't have a visible rect)
	NSRect			clipRect = [self visibleRect];
	if (VVISZERORECT(clipRect))	{
		//NSLog(@"\t\terr: bailing, clipRect zero %s",__func__);
		return;
	}
	//NSRectLog(@"\t\tclipRect in local coords is",clipRect);
	clipRect = [self convertRectToContainerViewCoords:clipRect];
	//NSRectLog(@"\t\tfirst-pass container coords are",clipRect);
	//	make sure the passed clip rect has positive dimensions (adjust origin if dimensions are negative to compensate)
	NSRect			tmpClipRect;
	tmpClipRect.origin.x = roundf(VVMINX(clipRect));
	tmpClipRect.size.width = roundf(VVMAXX(clipRect)-tmpClipRect.origin.x);
	tmpClipRect.origin.y = roundf(VVMINY(clipRect));
	tmpClipRect.size.height = roundf(VVMAXY(clipRect)-tmpClipRect.origin.y);
	//NSRectLog(@"\t\tclipRect in container coords is",tmpClipRect);
	//	use scissor to clip drawing to the passed rect
	glScissor(tmpClipRect.origin.x*localToBackingBoundsMultiplier, tmpClipRect.origin.y*localToBackingBoundsMultiplier, tmpClipRect.size.width*localToBackingBoundsMultiplier, tmpClipRect.size.height*localToBackingBoundsMultiplier);
	
	
	//	do the rotation & translation for the bounds now, AFTER i filled in the background/clear color
	NSPoint			tmpPoint;
	switch (_boundsOrientation)	{
		case VVViewBOBottom:
			tmpPoint = _boundsOrigin;
			tmpPoint = NSMakePoint(-1.0*tmpPoint.x*localToBackingBoundsMultiplier, -1.0*tmpPoint.y*localToBackingBoundsMultiplier);
			glTranslatef(tmpPoint.x, tmpPoint.y, 0.0);
			break;
		case VVViewBORight:
			glRotatef(90.0, 0, 0, 1);
			tmpPoint = NSMakePoint(0.0, _frame.size.width);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			tmpPoint = NSMakePoint(-1.0*tmpPoint.x*localToBackingBoundsMultiplier, -1.0*tmpPoint.y*localToBackingBoundsMultiplier);
			//NSPointLog(@"\t\ttranslating",tmpPoint);
			glTranslatef(tmpPoint.x, tmpPoint.y, 0.0);
			break;
		case VVViewBOTop:
			glRotatef(180.0, 0, 0, 1);
			tmpPoint = NSMakePoint(_frame.size.width,_frame.size.height);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			tmpPoint = NSMakePoint(-1.0*tmpPoint.x*localToBackingBoundsMultiplier, -1.0*tmpPoint.y*localToBackingBoundsMultiplier);
			//NSPointLog(@"\t\ttranslating",tmpPoint);
			glTranslatef(tmpPoint.x, tmpPoint.y, 0.0);
			break;
		case VVViewBOLeft:
			glRotatef(270.0, 0, 0, 1);
			tmpPoint = NSMakePoint(_frame.size.height, 0.0);
			tmpPoint = VVADDPOINT(tmpPoint, _boundsOrigin);
			tmpPoint = NSMakePoint(-1.0*tmpPoint.x*localToBackingBoundsMultiplier, -1.0*tmpPoint.y*localToBackingBoundsMultiplier);
			//NSPointLog(@"\t\ttranslating",tmpPoint);
			glTranslatef(tmpPoint.x, tmpPoint.y, 0.0);
			break;
	}
	/*
	glRotatef(_boundsRotation, 0, 0, 1);
	glTranslatef(-1.0*_bounds.origin.x*localToBackingBoundsMultiplier, -1.0*_bounds.origin.y*localToBackingBoundsMultiplier, 0);
	*/
	
	
	
	//	get the local bounds- zero out the origin before clearing
	NSRect		localBounds = [self backingBounds];
	//NSRectLog(@"\t\tlocalBounds is",localBounds);
	//	if i'm opaque, fill my bounds
	OSSpinLockLock(&propertyLock);
	/*
	if (isOpaque)	{
		glColor4f(clearColor[0], clearColor[1], clearColor[2], 1.0);
		GLDRAWRECT(NSMakeRect(localBounds.origin.x, localBounds.origin.y,localBounds.size.width, localBounds.size.height));
	}
	else if (clearColor[3]!=0.0)	{
		glColor4f(clearColor[0], clearColor[1], clearColor[2], clearColor[3]);
		GLDRAWRECT(NSMakeRect(localBounds.origin.x, localBounds.origin.y,localBounds.size.width, localBounds.size.height));
	}
	*/
	if (isOpaque)	{
		glClearColor(clearColor[0], clearColor[1], clearColor[2], 1.0);
		glClear(GL_COLOR_BUFFER_BIT);
	}
	else if (clearColor[3]!=0.0)	{
		glClearColor(clearColor[0], clearColor[1], clearColor[2], clearColor[3]);
		glClear(GL_COLOR_BUFFER_BIT);
	}
	
	OSSpinLockUnlock(&propertyLock);
	
	
	
	
	//	tell the sprite manager to draw
	if (spriteManager != nil)
		[spriteManager drawInContext:cgl_ctx];
	
	//	...now call the "meat" of my drawing method (where most drawing code will be handled)
	[self drawRect:r inContext:cgl_ctx];
	
	//	if there's a border, draw it now
	OSSpinLockLock(&propertyLock);
	if (drawBorder)	{
		glColor4f(borderColor[0], borderColor[1], borderColor[2], borderColor[3]);
		GLSTROKERECT(localBounds);
	}
	OSSpinLockUnlock(&propertyLock);
	
	//	call 'finishedDrawing' so subclasses of me have a chance to perform post-draw cleanup
	[self finishedDrawing];
	//	if i have subviews, tell them to draw now- back to front...
	if (subviews!=nil && [subviews count]>0)	{
		[subviews rdlock];
		
		NSEnumerator	*it = [[subviews array] objectEnumerator];
		VVView			*viewPtr = nil;
		while (viewPtr = [it nextObject])	{
			//NSLog(@"\t\tview is %@",viewPtr);
			NSPoint			viewBoundsOrigin = [viewPtr boundsOrigin];
			NSRect			viewFrameInMyLocalBounds = [viewPtr frame];
			//NSRectLog(@"\t\tviewFrameInMyLocalBounds is",viewFrameInMyLocalBounds);
			NSRect			intersectRectInMyLocalBounds = NSIntersectionRect(r,viewFrameInMyLocalBounds);
			if (intersectRectInMyLocalBounds.size.width>0 && intersectRectInMyLocalBounds.size.height>0)	{
				//NSRectLog(@"\t\tintersectRectInMyLocalBounds is",intersectRectInMyLocalBounds);
				//	apply transformation matrices so that when the view draws, its origin in GL is the correct location in the context (the view will have to correct for its own bounds rotation & bounds offset, but that's beyond the scope of this instance)
				glMatrixMode(GL_MODELVIEW);
				glPushMatrix();
				glTranslatef(viewFrameInMyLocalBounds.origin.x*localToBackingBoundsMultiplier, viewFrameInMyLocalBounds.origin.y*localToBackingBoundsMultiplier, 0.0);
				
				//	calculate the rect (in the view's local coordinate space) of the are of the view i'm going to ask to draw
				NSRect					viewBoundsToDraw = intersectRectInMyLocalBounds;
				//viewBoundsToDraw.origin = NSMakePoint(viewBoundsToDraw.origin.x-viewFrameInMyLocalBounds.origin.x, viewBoundsToDraw.origin.y-viewFrameInMyLocalBounds.origin.y);
				viewBoundsToDraw.origin = VVSUBPOINT(viewBoundsToDraw.origin, viewFrameInMyLocalBounds.origin);
				viewBoundsToDraw.origin = VVADDPOINT(viewBoundsToDraw.origin, viewBoundsOrigin);
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
					viewBoundsToDraw.size = NSMakeSize(fabs(viewBoundsToDraw.size.width), fabs(viewBoundsToDraw.size.height));
				}
				/*
				NSAffineTransform		*rotTrans = [NSAffineTransform transform];
				[rotTrans rotateByDegrees:-1.0*[viewPtr boundsRotation]];
				viewBoundsToDraw.origin = [rotTrans transformPoint:viewBoundsToDraw.origin];
				viewBoundsToDraw.size = [rotTrans transformSize:viewBoundsToDraw.size];
				//	...make sure the size is valid.  i don't understand why this step is necessary- i think it's a sign i may be doing something wrong.
				viewBoundsToDraw.size = NSMakeSize(fabs(viewBoundsToDraw.size.width), fabs(viewBoundsToDraw.size.height));
				//viewBoundsToDraw.origin = NSMakePoint(viewBoundsToDraw.origin.x+viewBounds.origin.x, viewBoundsToDraw.origin.y+viewBounds.origin.y);
				//NSRectLog(@"\t\viewBoundsToDraw is",viewBoundsToDraw);
				*/
				
				//	now tell the view to do its drawing!
				[viewPtr
					_drawRect:viewBoundsToDraw
					inContext:cgl_ctx];
				
				glMatrixMode(GL_MODELVIEW);
				glPopMatrix();
			}
		}
		
		[subviews unlock];
	}
	
	spriteCtx = NULL;
}
- (void) drawRect:(NSRect)r inContext:(CGLContextObj)cgl_ctx	{
	NSLog(@"ERR: %s",__func__);
	/*		this method should be used by subclasses.  put the simple drawing code in here (origin is the bottom-left corner of me!)		*/
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
	spritesNeedUpdate = NO;
}
- (NSRect) backingBounds	{
	switch (_boundsOrientation)	{
		case VVViewBOBottom:
		case VVViewBOTop:
			return NSMakeRect(_boundsOrigin.x*localToBackingBoundsMultiplier, _boundsOrigin.y*localToBackingBoundsMultiplier, _frame.size.width*localToBackingBoundsMultiplier, _frame.size.height*localToBackingBoundsMultiplier);
		case VVViewBORight:
		case VVViewBOLeft:
			return NSMakeRect(_boundsOrigin.x*localToBackingBoundsMultiplier, _boundsOrigin.y*localToBackingBoundsMultiplier, _frame.size.height*localToBackingBoundsMultiplier, _frame.size.width*localToBackingBoundsMultiplier);
	}
	return NSMakeRect(0,0,0,0);
	/*
	return NSMakeRect(_bounds.origin.x*localToBackingBoundsMultiplier, _bounds.origin.y*localToBackingBoundsMultiplier, _bounds.size.width*localToBackingBoundsMultiplier, _bounds.size.height*localToBackingBoundsMultiplier);
	*/
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

@synthesize deleted;
@synthesize spriteManager;
@synthesize spritesNeedUpdate;
- (void) setSpritesNeedUpdate	{
	spritesNeedUpdate = YES;
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
@synthesize lastMouseEvent;
- (void) setClearColor:(NSColor *)n	{
	NSColor				*devColor = nil;
	NSColorSpace		*devCS = [NSColorSpace deviceRGBColorSpace];
	devColor = ([n colorSpace]==devCS) ? n : [n colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	if (devColor != nil)
		[devColor getComponents:(CGFloat *)clearColor];
}
- (void) setClearColors:(GLfloat)r :(GLfloat)g :(GLfloat)b :(GLfloat)a	{
	clearColor[0] = r;
	clearColor[1] = g;
	clearColor[2] = b;
	clearColor[3] = a;
}
- (void) setBorderColor:(NSColor *)n	{
	NSColor				*devColor = nil;
	NSColorSpace		*devCS = [NSColorSpace deviceRGBColorSpace];
	devColor = ([n colorSpace]==devCS) ? n : [n colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	if (devColor != nil)
		[devColor getComponents:(CGFloat *)borderColor];
}
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
@synthesize dragTypes;


@end


#import "VVSpriteView.h"
#import "VVBasicMacros.h"
//#import "VVControl.h"




#define LOCK VVLockLock
#define UNLOCK VVLockUnlock
#define VVBITMASKCHECK(mask,flagToCheck) ((mask & flagToCheck) == flagToCheck) ? ((BOOL)YES) : ((BOOL)NO)




int				_spriteViewCount;




@implementation VVSpriteView


+ (void) load	{
	_spriteViewCount = 0;
}

/*===================================================================================*/
#pragma mark --------------------- creation/deletion/setup
/*------------------------------------*/

- (id) initWithFrame:(VVRECT)f	{
	//NSLog(@"%s ... %@, %p",__func__,[self class],self);
	if (self = [super initWithFrame:f])	{
		[self generalInit];
		return self;
	}
	VVRELEASE(self);
	return self;
}
- (id) initWithCoder:(NSCoder *)c	{
	//NSLog(@"%s ... %@, %p",__func__,[self class],self);
	if (self = [super initWithCoder:c])	{
		[self generalInit];
		return self;
	}
	VVRELEASE(self);
	return self;
}
- (void) generalInit	{
	//NSLog(@"%s ... %@, %p",__func__,[self class],self);
	deleted = NO;
	_localToBackingBoundsMultiplier = 1.0;
	spriteManager = [[VVSpriteManager alloc] init];
	spritesNeedUpdate = YES;
	propertyLock = VV_LOCK_INIT;
	lastMouseEvent = nil;
	clearColor = nil;
	drawBorder = NO;
	borderColor = nil;
	mouseDownModifierFlags = 0;
	mouseDownEventType = VVSpriteEventNULL;
	modifierFlags = 0;
	mouseIsDown = NO;
	clickedSubview = nil;
	
	self.localBoundsRotation = self.boundsRotation;
	self.localBounds = self.bounds;
	self.localFrame = self.frame;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.bounds];
	self.localWindow = self.window;
	self.localHidden = self.hidden;
	self.localVisibleRect = self.visibleRect;
	
	vvSubviews = [[MutLockArray alloc] init];
}
- (void) prepareToBeDeleted	{
	//NSLog(@"%s",__func__);
	NSMutableArray		*subCopy = [vvSubviews lockCreateArrayCopy];
	if (subCopy != nil)	{
		for (id subview in subCopy)
			[self removeVVSubview:subview];
		[subCopy removeAllObjects];
	}
	if (spriteManager != nil)
		[spriteManager prepareToBeDeleted];
	spritesNeedUpdate = NO;
	deleted = YES;
}
- (void) dealloc	{
	//NSLog(@"%s ... %@, %p",__func__,[self class],self);
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(spriteManager);
	
	LOCK(&propertyLock);
	VVRELEASE(lastMouseEvent);
	VVRELEASE(clearColor);
	VVRELEASE(borderColor);
	UNLOCK(&propertyLock);
	VVRELEASE(vvSubviews);
}
- (void) awakeFromNib	{
	//NSLog(@"%s",__func__);
	spritesNeedUpdate = YES;
}


/*===================================================================================*/
#pragma mark --------------------- overrides
/*------------------------------------*/


- (BOOL) acceptsFirstMouse:(NSEvent *)theEvent	{
	return YES;
}
- (BOOL) isOpaque	{
	return YES;
}
- (BOOL) acceptsFirstResponder	{
	return YES;
}
- (BOOL) needsPanelToBecomeKey	{
	return YES;
}


- (void) setBoundsRotation:(CGFloat)n	{
	[super setBoundsRotation:n];
	self.localBoundsRotation = self.boundsRotation;
	self.localVisibleRect = self.visibleRect;
}
- (void) setBounds:(NSRect)n	{
	[super setBounds:n];
	self.localBounds = self.bounds;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
}
- (void) setBoundsOrigin:(NSPoint)n	{
	[super setBoundsOrigin:n];
	self.localBounds = self.bounds;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
}
- (void) setBoundsSize:(NSSize)n	{
	[super setBoundsSize:n];
	self.localBounds = self.bounds;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
}
- (void) setFrame:(NSRect)n	{
	if (deleted)
		return;
	
	[super setFrame:n];
	
	VVRECT		bounds = [self bounds];
	VVRECT		backingBounds = [(id)self convertRectToBacking:bounds];
	double		tmpDouble;
	tmpDouble = (backingBounds.size.width/bounds.size.width);
	_localToBackingBoundsMultiplier = tmpDouble;
	
	self.localBounds = self.bounds;
	self.localFrame = self.frame;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
	spritesNeedUpdate = YES;
}
- (void) viewDidChangeBackingProperties	{
	//NSLog(@"%s ... %@",__func__,self);
	[super viewDidChangeBackingProperties];
	
	VVRECT		bounds = [self bounds];
	VVRECT		backingBounds = [(id)self convertRectToBacking:bounds];
	double		tmpDouble;
	tmpDouble = (backingBounds.size.width/bounds.size.width);
	_localToBackingBoundsMultiplier = tmpDouble;
	
	self.localBounds = self.bounds;
	self.localFrame = self.frame;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
	self.spritesNeedUpdate = YES;
	[self setNeedsDisplay:YES];
}
- (void) viewWillMoveToWindow:(NSWindow *)n	{
	//NSLog(@"%s",__func__);
	self.localWindow = n;
	self.localVisibleRect = self.visibleRect;
	[super viewWillMoveToWindow:n];
}
- (void) viewDidMoveToWindow	{
	//NSLog(@"%s",__func__);
	self.localWindow = self.window;
	self.localVisibleRect = self.visibleRect;
	[super viewDidMoveToWindow];
}
- (void) setHidden:(BOOL)n	{
	[super setHidden:n];
	self.localHidden = self.hidden;
	self.localVisibleRect = self.visibleRect;
}
- (void) setNeedsDisplay:(BOOL)n	{
	if (n)	{
		self.localVisibleRect = self.visibleRect;
	}
	[super setNeedsDisplay:n];
}
- (void) setNeedsDisplayInRect:(NSRect)n	{
	self.localVisibleRect = self.visibleRect;
	[super setNeedsDisplayInRect:n];
}
- (VVRECT) convertRectToLocalBackingBounds:(VVRECT)n	{
	return n;
}


/*
- (void) keyDown:(NSEvent *)event	{
	//NSLog(@"%s",__func__);
	[VVControl keyPressed:event];
	//[super keyDown:event];
}
- (void) keyUp:(NSEvent *)event	{
	//NSLog(@"%s",__func__);
	[VVControl keyPressed:event];
	//[super keyUp:event];
}
*/


/*===================================================================================*/
#pragma mark --------------------- subview-related
/*------------------------------------*/


- (void) addVVSubview:(VVView *)n	{
	//NSLog(@"%s",__func__);
	if (deleted || n==nil)
		return;
	if (![n isKindOfClass:[VVView class]])
		return;
	
	[vvSubviews wrlock];
	if (![vvSubviews containsIdenticalPtr:n])	{
		[vvSubviews insertObject:n atIndex:0];
		[n setContainerView:self];
		[n _setSuperview:nil];
	}
	[vvSubviews unlock];
	
	//	if the subviews i'm adding have any drag types, tell the container view to reconcile its drag types
	//NSMutableArray		*tmpArray = MUTARRAY;
	//[n _collectDragTypesInArray:tmpArray];
	//if ([tmpArray count]>0)
	//	[self reconcileVVSubviewDragTypes];
	
	[self setNeedsDisplay:YES];
}
- (void) removeVVSubview:(VVView *)n	{
	//NSLog(@"%s",__func__);
	if (deleted || n==nil)
		return;
	if (![n isKindOfClass:[VVView class]])
		return;
	id			tmpSubview = n;
	[vvSubviews lockRemoveIdenticalPtr:tmpSubview];
	[tmpSubview setContainerView:nil];
	
	//	if there's a drag and drop subview (if i'm in the middle of a drag and drop action), i have to check if it's in the subview i'm removing!
	//if (dragNDropSubview!=nil && [n containsSubview:dragNDropSubview])	{
	//	[dragNDropSubview draggingExited:nil];
	//	dragNDropSubview = nil;
	//}
	//	if the subviews i'm adding have any drag types, tell the container view to reconcile its drag types
	//NSMutableArray		*tmpArray = MUTARRAY;
	//[tmpSubview _collectDragTypesInArray:tmpArray];
	//if ([tmpArray count]>0)
	//	[self reconcileVVSubviewDragTypes];
	
	[self setNeedsDisplay:YES];
}
- (BOOL) containsSubview:(VVView *)n	{
	if (deleted || n==nil || vvSubviews==nil)
		return NO;
	BOOL		returnMe = NO;
	[vvSubviews rdlock];
	for (VVView *viewPtr in [vvSubviews array])	{
		if (viewPtr==n || [viewPtr containsSubview:n])	{
			returnMe = YES;
			break;
		}
	}
	[vvSubviews unlock];
	return returnMe;
}
- (VVView *) vvSubviewHitTest:(VVPOINT)p	{
	//NSLog(@"%s ... (%f, %f)",__func__,p.x,p.y);
	if (deleted || vvSubviews==nil)
		return nil;
	
	id					returnMe = nil;
	//	run from "top" view to bottom, checking to see if the point lies within any of the views
	[vvSubviews rdlock];
	for (VVView *viewPtr in [vvSubviews array])	{
		VVRECT			tmpFrame = [viewPtr frame];
		//VVRectLog(@"\t\tview's frame is",tmpFrame);
		if (VVPOINTINRECT(p,tmpFrame))	{
			returnMe = [viewPtr vvSubviewHitTest:p];
			if (returnMe != nil)
				break;
		}
	}
	[vvSubviews unlock];
	
	return returnMe;
}
- (void) reconcileVVSubviewDragTypes	{
	//NSLog(@"%s",__func__);
	if (deleted || vvSubviews==nil)
		return;
	NSMutableArray		*tmpArray = [NSMutableArray arrayWithCapacity:0];
	[vvSubviews rdlock];
	for (VVView *viewPtr in [vvSubviews array])	{
		[viewPtr _collectDragTypesInArray:tmpArray];
	}
	[vvSubviews unlock];
	
	[self unregisterDraggedTypes];
	[self registerForDraggedTypes:tmpArray];
}


/*===================================================================================*/
#pragma mark --------------------- frame-related
/*------------------------------------*/


- (void) setFrameSize:(VVSIZE)n	{
	//NSLog(@"%s ... %@, %f x %f",__func__,self,n.width,n.height);
	VVSIZE			oldSize = [self frame].size;
	double			oldBackingBounds = _localToBackingBoundsMultiplier;
	
	[super setFrameSize:n];
	
	VVRECT		bounds = [self bounds];
	VVRECT		backingBounds = [(id)self convertRectToBacking:bounds];
	double		tmpDouble;
	tmpDouble = (backingBounds.size.width/bounds.size.width);
	_localToBackingBoundsMultiplier = tmpDouble;
	
	self.localBounds = self.bounds;
	self.localFrame = self.frame;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
	
	if ([self autoresizesSubviews])	{
		double		widthDelta = n.width - oldSize.width;
		double		heightDelta = n.height - oldSize.height;
		[vvSubviews rdlock];
		for (VVView *viewPtr in [vvSubviews array])	{
			VVViewResizeMask	viewResizeMask = [viewPtr autoresizingMask];
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
			[viewPtr setFrame:viewNewFrame];
		}
		[vvSubviews unlock];
	}
}
- (void) setFrameOrigin:(NSPoint)n	{
	[super setFrameOrigin:n];
	self.localBounds = self.bounds;
	self.localFrame = self.frame;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
	spritesNeedUpdate = YES;
}
- (void) updateSprites	{
	spritesNeedUpdate = NO;
}


/*===================================================================================*/
#pragma mark --------------------- UI
/*------------------------------------*/


- (void) mouseDown:(NSEvent *)e	{
	if (deleted)
		return;
	
	LOCK(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = e;
	UNLOCK(&propertyLock);
	
	mouseIsDown = YES;
	VVPOINT		locationInWindow = [e locationInWindow];
	VVPOINT		localPoint = [self convertPoint:locationInWindow fromView:nil];
	/*
	//	if i have subviews and i clicked on one of them, skip the sprite manager
	if ([[self subviews] count]>0)	{
		clickedSubview = [self hitTest:locationInWindow];
		if (clickedSubview == self) clickedSubview = nil;
		if (clickedSubview != nil)	{
			[clickedSubview mouseDown:e];
			return;
		}
	}
	//	else there aren't any subviews or i didn't click on any of them- do the sprite manager
	*/
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
	if (deleted)
		return;
	
	LOCK(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = e;
	UNLOCK(&propertyLock);
	
	mouseIsDown = YES;
	VVPOINT		locationInWindow = [e locationInWindow];
	VVPOINT		localPoint = [self convertPoint:locationInWindow fromView:nil];
	/*
	//	if i have subviews and i clicked on one of them, skip the sprite manager
	if ([[self subviews] count]>0)	{
		clickedSubview = [self hitTest:locationInWindow];
		if (clickedSubview == self) clickedSubview = nil;
		if (clickedSubview != nil)	{
			[clickedSubview mouseDown:e];
			return;
		}
	}
	*/
	mouseDownModifierFlags = [e modifierFlags];
	mouseDownEventType = VVSpriteEventRightDown;
	modifierFlags = mouseDownModifierFlags;
	//	else there aren't any subviews or i didn't click on any of them- do the sprite manager
	[spriteManager localRightMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
}
- (void) mouseDragged:(NSEvent *)e	{
	if (deleted)
		return;
	
	LOCK(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
		lastMouseEvent = e;
	UNLOCK(&propertyLock);
	
	modifierFlags = [e modifierFlags];
	VVPOINT		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
	if (clickedSubview != nil)
		[clickedSubview mouseDragged:e];
	else
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
	
	LOCK(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = e;
	UNLOCK(&propertyLock);
	
	modifierFlags = [e modifierFlags];
	mouseIsDown = NO;
	VVPOINT		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
	if (clickedSubview != nil)
		[clickedSubview mouseUp:e];
	else
		[spriteManager localMouseUp:localPoint];
}
- (void) rightMouseUp:(NSEvent *)e	{
	if (deleted)
		return;
	
	LOCK(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = e;
	UNLOCK(&propertyLock);
	
	modifierFlags = [e modifierFlags];
	mouseIsDown = NO;
	VVPOINT		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	/*
	//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
	if (clickedSubview != nil)
		[clickedSubview rightMouseUp:e];
	else
	*/
		[spriteManager localRightMouseUp:localPoint];
}


/*===================================================================================*/
#pragma mark --------------------- drawing
/*------------------------------------*/


- (void) drawRect:(VVRECT)f	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	if (spritesNeedUpdate)
		[self updateSprites];
	
	LOCK(&propertyLock);
	if (clearColor != nil)	{
		[clearColor set];
		NSRectFill(NSIntersectionRect(f,self.localBackingBounds));
	}
	UNLOCK(&propertyLock);
	
	NSArray<VVView*>	*localSubviews = [vvSubviews lockCreateArrayCopy];
	for (VVView * subview in localSubviews)	{
		[subview _drawRect:[subview bounds]];
	}
	
	if (spriteManager != nil)
		[spriteManager drawRect:f];
	
	LOCK(&propertyLock);
	if (drawBorder && borderColor!=nil)	{
		[borderColor set];
		NSFrameRect([self bounds]);
	}
	UNLOCK(&propertyLock);
	
	//	call 'finishedDrawing' so subclasses of me have a chance to perform post-draw cleanup
	[self finishedDrawing];
}
/*	this method exists so subclasses of me have an opportunity to do something after drawing 
	has completed.  this is particularly handy with the GL view, as drawing does not complete- and 
	therefore resources have to stay available- until after glFlush() has been called.		*/
- (void) finishedDrawing	{

}


@synthesize deleted;
@synthesize spriteManager;
- (void) setSpritesNeedUpdate:(BOOL)n	{
	spritesNeedUpdate = n;
}
- (BOOL) spritesNeedUpdate	{
	return spritesNeedUpdate;
}
- (void) setSpritesNeedUpdate	{
	spritesNeedUpdate = YES;
}
- (NSEvent *) lastMouseEvent	{
	if (deleted)
		return nil;
	NSEvent		*returnMe = nil;
	
	LOCK(&propertyLock);
	returnMe = (lastMouseEvent==nil) ? nil : [lastMouseEvent copy];
	UNLOCK(&propertyLock);
	
	return returnMe;
}


- (void) setClearColor:(NSColor *)n	{
	if (deleted)
		return;
	LOCK(&propertyLock);
	VVRELEASE(clearColor);
	clearColor = n;
	UNLOCK(&propertyLock);
}
- (NSColor *) clearColor	{
	if (deleted)
		return nil;
	NSColor		*returnMe = nil;
	
	LOCK(&propertyLock);
	returnMe = [clearColor copy];
	UNLOCK(&propertyLock);
	
	return returnMe;
}
- (void) setDrawBorder:(BOOL)n	{
	if (deleted)
		return;
	LOCK(&propertyLock);
	drawBorder = n;
	UNLOCK(&propertyLock);
}
- (BOOL) drawBorder	{
	if (deleted)
		return NO;
	BOOL		returnMe = NO;
	LOCK(&propertyLock);
	returnMe = drawBorder;
	UNLOCK(&propertyLock);
	return returnMe;
}
- (void) setBorderColor:(NSColor *)n	{
	if (deleted)
		return;
	LOCK(&propertyLock);
	VVRELEASE(borderColor);
	borderColor = n;
	UNLOCK(&propertyLock);
}
- (NSColor *) borderColor	{
	if (deleted)
		return nil;
	NSColor		*returnMe = nil;
	
	LOCK(&propertyLock);
		if (borderColor != nil)
			returnMe = [borderColor copy];
	UNLOCK(&propertyLock);
	
	return returnMe;
}
@synthesize mouseDownModifierFlags;
@synthesize mouseDownEventType;
@synthesize modifierFlags;
@synthesize mouseIsDown;
- (void) _setMouseIsDown:(BOOL)n	{
	mouseIsDown = n;
}


@end


#import "VVSpriteControl.h"
#import "VVBasicMacros.h"
#import "VVSpriteControlCell.h"




#define LOCK VVLockLock
#define UNLOCK VVLockUnlock




int					_maxSpriteControlCount;
int					_spriteControlCount;




@implementation VVSpriteControl


+ (void) initialize	{
	[self setCellClass:[VVSpriteControlCell class]];
}
+ (void) load	{
	_maxSpriteControlCount = 0;
	_spriteControlCount = 0;
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
	spriteLock = VV_LOCK_INIT;
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
	
	self.clipsToBounds = YES;
	self.localBoundsRotation = self.boundsRotation;
	self.localBounds = self.bounds;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.bounds];
	self.localFrame = self.frame;
	self.localWindow = self.window;
	self.localHidden = self.hidden;
	self.localVisibleRect = self.visibleRect;
}
- (void) prepareToBeDeleted	{
	//NSLog(@"%s",__func__);
	LOCK(&propertyLock);
	BOOL		localDeleted = deleted;
	deleted = YES;
	UNLOCK(&propertyLock);
	if (localDeleted)
		return;
	LOCK(&spriteLock);
	spritesNeedUpdate = NO;
	UNLOCK(&spriteLock);
	if (spriteManager != nil)
		[spriteManager prepareToBeDeleted];
}
- (void) dealloc	{
	//NSLog(@"%s ... %@, %p",__func__,[self class],self);
	if (!self.deleted)
		[self prepareToBeDeleted];
	LOCK(&spriteLock);
	VVRELEASE(spriteManager);
	UNLOCK(&spriteLock);
	
	LOCK(&propertyLock);
	VVRELEASE(lastMouseEvent);
	VVRELEASE(clearColor);
	VVRELEASE(borderColor);
	UNLOCK(&propertyLock);
}
- (void) awakeFromNib	{
	//NSLog(@"%s",__func__);
	LOCK(&spriteLock);
	spritesNeedUpdate = YES;
	UNLOCK(&spriteLock);
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
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
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
	LOCK(&spriteLock);
	spritesNeedUpdate = YES;
	UNLOCK(&spriteLock);
}
- (void) setFrameSize:(NSSize)n	{
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
	LOCK(&spriteLock);
	spritesNeedUpdate = YES;
	UNLOCK(&spriteLock);
}
- (void) setFrameOrigin:(NSPoint)n	{
	[super setFrameOrigin:n];
	self.localBounds = self.bounds;
	self.localFrame = self.frame;
	self.localBackingBounds = [self convertRectToLocalBackingBounds:self.localBounds];
	self.localVisibleRect = self.visibleRect;
	LOCK(&spriteLock);
	spritesNeedUpdate = YES;
	UNLOCK(&spriteLock);
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
#pragma mark --------------------- frame-related
/*------------------------------------*/


- (void) updateSprites	{
	LOCK(&spriteLock);
	spritesNeedUpdate = NO;
	UNLOCK(&spriteLock);
}


/*===================================================================================*/
#pragma mark --------------------- UI
/*------------------------------------*/


- (void) mouseDown:(NSEvent *)e	{
	LOCK(&propertyLock);
	BOOL		localDeleted = deleted;
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = e;
	UNLOCK(&propertyLock);
	if (localDeleted)
		return;
	
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
		mouseDownEventType = VVSpriteEventDown;
		[spriteManager localMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
	}
}
- (void) rightMouseDown:(NSEvent *)e	{
	LOCK(&propertyLock);
	BOOL		localDeleted = deleted;
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = e;
	UNLOCK(&propertyLock);
	if (localDeleted)
		return;
	
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
	mouseDownEventType = VVSpriteEventRightDown;
	modifierFlags = mouseDownModifierFlags;
	[spriteManager localRightMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
}
- (void) mouseDragged:(NSEvent *)e	{
	LOCK(&propertyLock);
	BOOL		localDeleted = deleted;
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = e;
	UNLOCK(&propertyLock);
	if (localDeleted)
		return;
	
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
	LOCK(&propertyLock);
	BOOL		localDeleted = deleted;
	UNLOCK(&propertyLock);
	if (localDeleted)
		return;

	if (mouseDownEventType == VVSpriteEventRightDown)	{
		[self rightMouseUp:e];
		return;
	}

	LOCK(&propertyLock);
	VVRELEASE(lastMouseEvent);
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
	LOCK(&propertyLock);
	BOOL		localDeleted = deleted;
	VVRELEASE(lastMouseEvent);
	lastMouseEvent = e;
	UNLOCK(&propertyLock);
	if (localDeleted)
		return;
	
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
	//NSLog(@"%s ... %@",__func__,self);
	LOCK(&propertyLock);
	BOOL		localDeleted = deleted;
	NSColor		*localClearColor = clearColor;
	NSColor		*localBorderColor = borderColor;
	BOOL		localDrawBorder = drawBorder;
	UNLOCK(&propertyLock);
	if (localDeleted)
		return;

	LOCK(&spriteLock);
	BOOL		localSpritesNeedUpdate = spritesNeedUpdate;
	UNLOCK(&spriteLock);
	
	if (localSpritesNeedUpdate)
		[self updateSprites];
	
	if (localClearColor != nil)	{
		[localClearColor set];
		NSRect		tmpRect = NSIntersectionRect(f, self.localBackingBounds);
		NSRectFill(tmpRect);
	}
	
	if (spriteManager != nil)
		[spriteManager drawRect:f];
	
	if (localDrawBorder && localBorderColor!=nil)	{
		[localBorderColor set];
		NSFrameRect([self bounds]);
	}
	
	//	call 'finishedDrawing' so subclasses of me have a chance to perform post-draw cleanup
	[self finishedDrawing];
}
/*	this method exists so subclasses of me have an opportunity to do something after drawing 
	has completed.  this is particularly handy with the GL view, as drawing does not complete- and 
	therefore resources have to stay available- until after glFlush() has been called.		*/
- (void) finishedDrawing	{

}


- (BOOL) deleted	{
	LOCK(&propertyLock);
	BOOL		returnMe = deleted;
	UNLOCK(&propertyLock);
	return returnMe;
}
@synthesize spriteManager;
- (void) setSpritesNeedUpdate:(BOOL)n	{
	LOCK(&spriteLock);
	spritesNeedUpdate = n;
	UNLOCK(&spriteLock);
}
- (BOOL) spritesNeedUpdate	{
	LOCK(&spriteLock);
	BOOL		returnMe = spritesNeedUpdate;
	UNLOCK(&spriteLock);
	return returnMe;
}
- (void) setSpritesNeedUpdate	{
	LOCK(&spriteLock);
	spritesNeedUpdate = YES;
	UNLOCK(&spriteLock);
}
- (NSEvent *) lastMouseEvent	{
	NSEvent		*returnMe = nil;

	LOCK(&propertyLock);
	if (!deleted)
		returnMe = (lastMouseEvent==nil) ? nil : [lastMouseEvent copy];
	UNLOCK(&propertyLock);

	return returnMe;
}


- (void) setClearColor:(NSColor *)n	{
	LOCK(&propertyLock);
	if (!deleted)	{
		VVRELEASE(clearColor);
		clearColor = n;
	}
	UNLOCK(&propertyLock);
}
- (NSColor *) clearColor	{
	NSColor		*returnMe = nil;

	LOCK(&propertyLock);
	if (!deleted)
		returnMe = [clearColor copy];
	UNLOCK(&propertyLock);

	return returnMe;
}
- (void) setDrawBorder:(BOOL)n	{
	LOCK(&propertyLock);
	if (!deleted)
		drawBorder = n;
	UNLOCK(&propertyLock);
}
- (BOOL) drawBorder	{
	BOOL		returnMe = NO;
	LOCK(&propertyLock);
	if (!deleted)
		returnMe = drawBorder;
	UNLOCK(&propertyLock);
	return returnMe;
}
- (void) setBorderColor:(NSColor *)n	{
	LOCK(&propertyLock);
	if (!deleted)	{
		VVRELEASE(borderColor);
		borderColor = n;
	}
	UNLOCK(&propertyLock);
}
- (NSColor *) borderColor	{
	NSColor		*returnMe = nil;

	LOCK(&propertyLock);
	if (!deleted)
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

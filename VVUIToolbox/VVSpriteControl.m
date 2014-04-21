
#import "VVSpriteControl.h"
#import "VVBasicMacros.h"
#import "VVSpriteControlCell.h"




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
	[self release];
	return nil;
}
- (id) initWithCoder:(NSCoder *)c	{
	//NSLog(@"%s ... %@, %p",__func__,[self class],self);
	if (self = [super initWithCoder:c])	{
		[self generalInit];
		return self;
	}
	[self release];
	return nil;
}
- (void) generalInit	{
	//NSLog(@"%s ... %@, %p",__func__,[self class],self);
	deleted = NO;
	spriteManager = [[VVSpriteManager alloc] init];
	spritesNeedUpdate = YES;
	propertyLock = OS_SPINLOCK_INIT;
	lastMouseEvent = nil;
	clearColor = nil;
	drawBorder = NO;
	borderColor = nil;
	mouseDownModifierFlags = 0;
	mouseDownEventType = VVSpriteEventNULL;
	modifierFlags = 0;
	mouseIsDown = NO;
	clickedSubview = nil;
}
- (void) prepareToBeDeleted	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
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
	
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	VVRELEASE(clearColor);
	VVRELEASE(borderColor);
	OSSpinLockUnlock(&propertyLock);
	
	[super dealloc];
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


- (void) setFrame:(VVRECT)f	{
	[super setFrame:f];
	//[self updateSprites];
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
	
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
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
	if (deleted)
		return;
	
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
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
	if (deleted)
		return;
	
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
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
	
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
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
	
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
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
	
	OSSpinLockLock(&propertyLock);
	if (clearColor != nil)	{
		[clearColor set];
		NSRectFill(f);
	}
	OSSpinLockUnlock(&propertyLock);
	
	if (spriteManager != nil)
		[spriteManager drawRect:f];
	
	OSSpinLockLock(&propertyLock);
	if (drawBorder && borderColor!=nil)	{
		[borderColor set];
		NSFrameRect([self bounds]);
	}
	OSSpinLockUnlock(&propertyLock);
	
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
	
	OSSpinLockLock(&propertyLock);
	returnMe = (lastMouseEvent==nil) ? nil : [[lastMouseEvent copy] autorelease];
	OSSpinLockUnlock(&propertyLock);
	
	return returnMe;
}


- (void) setClearColor:(NSColor *)n	{
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(clearColor);
	if (n != nil)
		clearColor = [n retain];
	OSSpinLockUnlock(&propertyLock);
}
- (NSColor *) clearColor	{
	if (deleted)
		return nil;
	NSColor		*returnMe = nil;
	
	OSSpinLockLock(&propertyLock);
		if (clearColor != nil)
			returnMe = [[clearColor copy] autorelease];
	OSSpinLockUnlock(&propertyLock);
	
	return returnMe;
}
- (void) setDrawBorder:(BOOL)n	{
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	drawBorder = n;
	OSSpinLockUnlock(&propertyLock);
}
- (BOOL) drawBorder	{
	if (deleted)
		return NO;
	BOOL		returnMe = NO;
	OSSpinLockLock(&propertyLock);
	returnMe = drawBorder;
	OSSpinLockUnlock(&propertyLock);
	return returnMe;
}
- (void) setBorderColor:(NSColor *)n	{
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(borderColor);
	if (n != nil)
		borderColor = [n retain];
	OSSpinLockUnlock(&propertyLock);
}
- (NSColor *) borderColor	{
	if (deleted)
		return nil;
	NSColor		*returnMe = nil;
	
	OSSpinLockLock(&propertyLock);
		if (borderColor != nil)
			returnMe = [[borderColor copy] autorelease];
	OSSpinLockUnlock(&propertyLock);
	
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

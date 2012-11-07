//
//  VVView.m
//  VVOpenSource
//
//  Created by bagheera on 11/1/12.
//
//

#import "VVView.h"
#import "VVBasicMacros.h"




@implementation VVView


- (id) initWithFrame:(NSRect)n	{
	if (self = [super init])	{
		[self generalInit];
		frame = n;
		bounds = NSMakeRect(0,0,frame.size.width,frame.size.height);
		return self;
	}
	[self release];
	return nil;
}
- (void) generalInit	{
	deleted = NO;
	spriteManager = [[VVSpriteManager alloc] init];
	spritesNeedUpdate = YES;
	needsDisplay = YES;
	frame = NSMakeRect(0,0,1,1);
	bounds = frame;
	superview = nil;
	subviews = [[MutLockArray alloc] init];
	autoresizesSubviews = YES;
	autoresizingMask = VVViewResizeNone;
	propertyLock = OS_SPINLOCK_INIT;
	lastMouseEvent = nil;
	for (int i=0;i<4;++i)	{
		clearColor[i] = 0.0;
		borderColor[i] = 0.0;
	}
	drawBorder = NO;
	mouseDownModifierFlags = 0;
	modifierFlags = 0;
	mouseIsDown = NO;
	clickedSubview = nil;
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
	[super dealloc];
}


- (void) mouseDown:(NSEvent *)e	{
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
	mouseIsDown = YES;
	NSPoint		locationInWindow = [e locationInWindow];
	NSPoint		localPoint = [self convertPoint:locationInWindow fromView:nil];
	mouseDownModifierFlags = [e modifierFlags];
	modifierFlags = mouseDownModifierFlags;
	if ((mouseDownModifierFlags&NSControlKeyMask)==NSControlKeyMask)
		[spriteManager localRightMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
	else
		[spriteManager localMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
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
	NSPoint		locationInWindow = [e locationInWindow];
	NSPoint		localPoint = [self convertPoint:locationInWindow fromView:nil];
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
	NSPoint		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	[spriteManager localMouseDragged:localPoint];
}
- (void) mouseUp:(NSEvent *)e	{
	if (deleted)
		return;
	OSSpinLockLock(&propertyLock);
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	OSSpinLockUnlock(&propertyLock);
	
	modifierFlags = [e modifierFlags];
	mouseIsDown = NO;
	NSPoint		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
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
	NSPoint		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	[spriteManager localRightMouseUp:localPoint];
}
- (void) keyDown:(NSEvent *)e	{
	NSLog(@"%s ... %@",__func__,e);
}
- (void) keyUp:(NSEvent *)e	{
	NSLog(@"%s ... %@",__func__,e);
}


- (NSPoint) convertPoint:(NSPoint)pointInWindow fromView:(id)view	{
	
}
- (id) hitTest:(NSPoint)p	{
	NSLog(@"%s ... %@- %f, %f",__func__,self,p.x,p.y);
	//	convert the point to coords local to me
	NSPoint			convertedPoint = [self convertPoint:p fromView:[[self window] contentView]];
	NSRect			localBounds = [self bounds];
	if (convertedPoint.x<0 || convertedPoint.y<0 || convertedPoint.x>localBounds.size.width || convertedPoint.y>localBounds.size.height)
		return nil;
	id				returnMe = nil;
	[subviews rdlock];
	for (VVView *viewPtr in [subviews array])	{
		returnMe = [viewPtr hitTest:p];
		if (returnMe != nil)
			break;
	}
	[subviews unlock];
	if (returnMe == nil)
		returnMe = self;
	return returnMe;
}


- (NSRect) frame	{
	
}
- (void) setFrame:(NSRect)n	{
	
}
- (void) setFrameSize:(NSSize)n	{
	
}
- (NSRect) bounds	{
	
}
- (void) setBounds:(NSRect)n	{
	
}
- (NSRect) visibleRect	{
	
}


@synthesize autoresizesSubviews;
@synthesize autoresizingMask;
- (void) addSubview:(id)n	{
	
}
- (void) removeSubview:(id)n	{
	
}
- (void) removeFromSuperview	{
	
}
- (MutLockArray *) subviews	{
	
}
- (id) window	{
	
}
- (id) nearestFormatSupplier	{
	
}
- (void) formatSupplierMayHaveChanged	{
	
}


- (void) drawRect:(NSRect)r	{
	if (deleted)
		return;
	if (spritesNeedUpdate)
		[self updateSprites];
	
	OSSpinLockLock(&propertyLock);
	if (clearColor != nil)	{
		[clearColor set];
		NSRectFill(r);
	}
	OSSpinLockUnlock(&propertyLock);
	
	if (spriteManager != nil)
		[spriteManager drawRect:r];
	
	OSSpinLockLock(&propertyLock);
	if (drawBorder && borderColor!=nil)	{
		[borderColor set];
		NSFrameRect([self bounds]);
	}
	OSSpinLockUnlock(&propertyLock);
	
	//	call 'finishedDrawing' so subclasses of me have a chance to perform post-draw cleanup
	[self finishedDrawing];

	//	if i have subviews, tell them to draw now- back to front...
	if (subviews!=nil && [subviews count]>0)	{
		[subviews rdlock];
		for (VVView *viewPtr in [[subviews array] reverseObjectEnumerator])	{
			//[viewPtr drawRect
		}
		[subviews unlock];
	}
}
- (BOOL) isOpaque	{
	
}
- (void) finishedDrawing	{
	
}
- (void) updateSprites	{
	
}

@synthesize deleted;
@synthesize spriteManager;
@synthesize spritesNeedUpdate;
- (void) setSpritesNeedUpdate	{
	[self setSpritesNeedUpdate:YES];
}
@synthesize needsDisplay;
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
@synthesize lastMouseEvent;
- (void) setClearColor:(NSColor *)n	{

}
- (void) setClearColors:(GLfloat)r:(GLfloat)g:(GLfloat)b:(GLfloat)a	{

}
- (void) setBorderColor:(NSColor *)n	{

}
- (void) setBorderColors:(GLfloat)r:(GLfloat)g:(GLfloat)b:(GLfloat)a	{

}
@synthesize drawBorder;
@synthesize mouseDownModifierFlags;
@synthesize modifierFlags;
@synthesize mouseIsDown;


@end

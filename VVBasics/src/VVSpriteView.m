
#import "VVSpriteView.h"
#import "VVBasicMacros.h"
//#import "VVControl.h"




@implementation VVSpriteView


/*===================================================================================*/
#pragma mark --------------------- creation/deletion/setup
/*------------------------------------*/

- (id) initWithFrame:(NSRect)f	{
	//NSLog(@"%s",__func__);
	if (self = [super initWithFrame:f])	{
		deleted = NO;
		spriteManager = [[VVSpriteManager alloc] init];
		pathsAndZonesNeedUpdate = YES;
		lastMouseEvent = nil;
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithCoder:(NSCoder *)c	{
	//NSLog(@"%s",__func__);
	if (self = [super initWithCoder:c])	{
		deleted = NO;
		spriteManager = [[VVSpriteManager alloc] init];
		pathsAndZonesNeedUpdate = YES;
		lastMouseEvent = nil;
		return self;
	}
	[self release];
	return nil;
}
- (void) prepareToBeDeleted	{
	//NSLog(@"%s",__func__);
	if (spriteManager != nil)
		[spriteManager prepareToBeDeleted];
	pathsAndZonesNeedUpdate = NO;
	deleted = YES;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(spriteManager);
	VVRELEASE(lastMouseEvent);
	[super dealloc];
}
- (void) awakeFromNib	{
	//NSLog(@"%s",__func__);
	pathsAndZonesNeedUpdate = YES;
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


- (void) setFrame:(NSRect)f	{
	[super setFrame:f];
	//[self updatePathsAndZones];
	pathsAndZonesNeedUpdate = YES;
}
- (void) updatePathsAndZones	{
	pathsAndZonesNeedUpdate = NO;
}


/*===================================================================================*/
#pragma mark --------------------- UI
/*------------------------------------*/


- (void) mouseDown:(NSEvent *)e	{
	if (deleted)
		return;
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	NSPoint		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	[spriteManager localMouseDown:localPoint];
}
- (void) mouseDragged:(NSEvent *)e	{
	if (deleted)
		return;
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	NSPoint		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	[spriteManager localMouseDragged:localPoint];
}
- (void) mouseUp:(NSEvent *)e	{
	if (deleted)
		return;
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	NSPoint		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	[spriteManager localMouseUp:localPoint];
}


/*===================================================================================*/
#pragma mark --------------------- drawing
/*------------------------------------*/


- (void) drawRect:(NSRect)f	{
	//NSLog(@"%s",__func__);
	if (pathsAndZonesNeedUpdate)
		[self updatePathsAndZones];
	if (spriteManager != nil)
		[spriteManager drawRect:f];
}

- (void) setPathsAndZonesNeedUpdate:(BOOL)n	{
	pathsAndZonesNeedUpdate = n;
}
- (BOOL) pathsAndZonesNeedUpdate	{
	return pathsAndZonesNeedUpdate;
}
- (NSEvent *) lastMouseEvent	{
	return lastMouseEvent;
}


@end

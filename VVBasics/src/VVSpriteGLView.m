
#import "VVSpriteGLView.h"
#import <OpenGL/CGLMacro.h>
#import "VVBasicMacros.h"
//#import "VVControl.h"




@implementation VVSpriteGLView


- (id) initWithFrame:(NSRect)f pixelFormat:(NSOpenGLPixelFormat *)p	{
	if (self = [super initWithFrame:f pixelFormat:p])	{
		[self generalInit];
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithCoder:(NSCoder *)c	{
	if (self = [super initWithCoder:c])	{
		[self generalInit];
		return self;
	}
	[self release];
	return nil;
}
- (void) generalInit	{
	deleted = NO;
	initialized = NO;
	needsReshape = YES;
	spriteManager = [[VVSpriteManager alloc] init];
	pathsAndZonesNeedUpdate = YES;
	lastMouseEvent = nil;
}
- (void) awakeFromNib	{
	//NSLog(@"%s",__func__);
	pathsAndZonesNeedUpdate = YES;
}
- (void) prepareToBeDeleted	{
	if (spriteManager != nil)
		[spriteManager prepareToBeDeleted];
	pathsAndZonesNeedUpdate = NO;
	deleted = YES;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(spriteManager);
	VVRELEASE(lastMouseEvent);
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- overrides
/*------------------------------------*/


- (void) setOpenGLContext:(NSOpenGLContext *)c	{
	//NSLog(@"%s",__func__);
	[super setOpenGLContext:c];
	initialized = NO;
	needsReshape = YES;
}

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
	//NSLog(@"%s",__func__);
	[super setFrame:f];
	//[self updatePathsAndZones];
	pathsAndZonesNeedUpdate = YES;
	needsReshape = YES;
	initialized = NO;
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


- (void) drawRect:(NSRect)r	{
	CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
	if (!initialized)	{
		[self initializeGL];
		initialized = YES;
		needsReshape = YES;
	}
	if (needsReshape)	{
		[self reshapeGL];
		needsReshape = NO;
	}
	glClear(GL_COLOR_BUFFER_BIT);
	
	if (pathsAndZonesNeedUpdate)
		[self updatePathsAndZones];
	if (spriteManager != nil)
		[spriteManager drawRect:r];
	
}
- (void) initializeGL	{
	//NSLog(@"%s",__func__);
	CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
	//NSRect				bounds = [self bounds];
	long				cpSwapInterval = 1;
	
	[[self openGLContext] setValues:(GLint *)&cpSwapInterval forParameter:NSOpenGLCPSwapInterval];
	glEnableClientState(GL_VERTEX_ARRAY);
	
	//glMatrixMode(GL_MODELVIEW);
	//glLoadIdentity();
	//glMatrixMode(GL_PROJECTION);
	//glLoadIdentity();
	
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
	glHint(GL_CLIP_VOLUME_CLIPPING_HINT_EXT, GL_FASTEST);
	glDisable(GL_DEPTH_TEST);
	glClearColor(0.0, 0.0, 0.0, 0.0);
}
- (void) reshapeGL	{
	//NSLog(@"%s",__func__);
	CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
	NSRect				bounds = [self bounds];
	//	set up the view to draw
	glViewport(0, 0, (GLsizei) bounds.size.width, (GLsizei) bounds.size.height);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	//NSRectLog(@"\t\tbounds",bounds);
	//glOrtho(bounds.origin.x, NSMaxX(bounds), NSMaxY(bounds), bounds.origin.y, -1.0, 1.0);
	glOrtho(bounds.origin.x, NSMaxX(bounds), bounds.origin.y, NSMaxY(bounds), -1.0, 1.0);
	
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

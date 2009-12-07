
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
	//needsReshape = YES;
	spriteManager = [[VVSpriteManager alloc] init];
	spritesNeedUpdate = YES;
	lastMouseEvent = nil;
	
	pthread_mutexattr_t		attr;
	
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr,PTHREAD_MUTEX_NORMAL);
	pthread_mutex_init(&glLock,&attr);
	pthread_mutexattr_destroy(&attr);
}
- (void) awakeFromNib	{
	//NSLog(@"%s",__func__);
	spritesNeedUpdate = YES;
}
- (void) prepareToBeDeleted	{
	if (spriteManager != nil)
		[spriteManager prepareToBeDeleted];
	spritesNeedUpdate = NO;
	deleted = YES;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(spriteManager);
	VVRELEASE(lastMouseEvent);
	pthread_mutex_destroy(&glLock);
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- overrides
/*------------------------------------*/


- (void) setOpenGLContext:(NSOpenGLContext *)c	{
	//NSLog(@"%s",__func__);
	pthread_mutex_lock(&glLock);
		[super setOpenGLContext:c];
		[c setView:self];
		initialized = NO;
	pthread_mutex_unlock(&glLock);
	//needsReshape = YES;
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
- (BOOL) becomeFirstResponder	{
	return YES;
}
- (BOOL) resignFirstResponder	{
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
	//[self updateSprites];
	spritesNeedUpdate = YES;
	//needsReshape = YES;
	initialized = NO;
	//NSLog(@"\t\t%s - FINISHED",__func__);
}
- (void) updateSprites	{
	spritesNeedUpdate = NO;
}
- (void) reshape	{
	//NSLog(@"%s",__func__);
	spritesNeedUpdate = YES;
	initialized = NO;
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
	NSLog(@"%s",__func__);
	pthread_mutex_lock(&glLock);
		CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
		if (!initialized)	{
			[self initializeGL];
			initialized = YES;
		}
		//	set up the view to draw
		NSRect				bounds = [self bounds];
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glViewport(0, 0, (GLsizei) bounds.size.width, (GLsizei) bounds.size.height);
		glOrtho(bounds.origin.x, bounds.origin.x+bounds.size.width, bounds.origin.y, bounds.origin.y+bounds.size.height, -1.0, 1.0);
		//	clear the view
		glClear(GL_COLOR_BUFFER_BIT);
		//	if the sprites need to be updated, do so now
		if (spritesNeedUpdate)
			[self updateSprites];
		//	tell the sprite manager to start drawing the sprites
		if (spriteManager != nil)
			[spriteManager drawRect:r];
	pthread_mutex_unlock(&glLock);
}
- (void) initializeGL	{
	//NSLog(@"%s",__func__);
	CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
	//NSRect				bounds = [self bounds];
	long				cpSwapInterval = 1;
	
	[[self openGLContext] setValues:(GLint *)&cpSwapInterval forParameter:NSOpenGLCPSwapInterval];
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	//glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	//glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
	glHint(GL_CLIP_VOLUME_CLIPPING_HINT_EXT, GL_FASTEST);
	glDisable(GL_DEPTH_TEST);
	glClearColor(0.0, 0.0, 0.0, 0.0);
}


- (void) setSpritesNeedUpdate:(BOOL)n	{
	spritesNeedUpdate = n;
}
- (BOOL) spritesNeedUpdate	{
	return spritesNeedUpdate;
}
- (NSEvent *) lastMouseEvent	{
	return lastMouseEvent;
}


@end

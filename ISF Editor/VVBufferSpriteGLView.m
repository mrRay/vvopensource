#import "VVBufferSpriteGLView.h"




@implementation VVBufferSpriteGLView


- (void) generalInit	{
	[super generalInit];
	
	sizingMode = VVSizingModeFit;
	bgSprite = nil;
	retainDrawLock = VV_LOCK_INIT;
	retainDrawBuffer = nil;
	
	bgSprite = [spriteManager makeNewSpriteAtBottomForRect:NSMakeRect(0,0,1,1)];
	if (bgSprite != nil)	{
		[bgSprite setDelegate:self];
		[bgSprite setActionCallback:@selector(actionBgSprite:)];
		[bgSprite setDrawCallback:@selector(drawBgSprite:)];
	}
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	
	VVLockLock(&retainDrawLock);
	VVRELEASE(retainDrawBuffer);
	VVLockUnlock(&retainDrawLock);
	
	[super dealloc];
}

- (void) updateSprites	{
	[super updateSprites];
	
	[bgSprite setRect:[self backingBounds]];
	
	spritesNeedUpdate = NO;
}

- (void) actionBgSprite:(VVSprite *)s	{
	NSLog(@"%s",__func__);
}
- (void) drawBgSprite:(VVSprite *)s	{
	//NSLog(@"%s",__func__);
	
	VVLockLock(&retainDrawLock);
	VVBuffer		*drawBuffer = (retainDrawBuffer==nil) ? nil : [retainDrawBuffer retain];
	VVLockUnlock(&retainDrawLock);
	
	GLuint			target = (drawBuffer==nil) ? GL_TEXTURE_RECTANGLE_EXT : [drawBuffer target];
	if (initialized)	{
		CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
		
		//glBlendFunc(GL_ONE, GL_ZERO);
		//glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
		//glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
		glHint(GL_CLIP_VOLUME_CLIPPING_HINT_EXT, GL_FASTEST);
		glDisable(GL_DEPTH_TEST);
		glClearColor(0.0, 0.0, 0.0, 1.0);
		
		glEnable(target);
		glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
		
		//	bilinear filtering stuff
		//glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		//glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		//glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		//glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		
		//	set up the view to draw
		NSRect				bounds = [self backingBounds];
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glViewport(0, 0, (GLsizei) bounds.size.width, (GLsizei) bounds.size.height);
		//if (flipped)
			glOrtho(bounds.origin.x, bounds.origin.x+bounds.size.width, bounds.origin.y, bounds.origin.y+bounds.size.height, 1.0, -1.0);
		//else
		//	glOrtho(bounds.origin.x, bounds.origin.x+bounds.size.width, bounds.origin.y+bounds.size.height, bounds.origin.y, 1.0, -1.0);
		//glEnable(GL_BLEND);
		//glBlendFunc(GL_SRC_ALPHA,GL_DST_ALPHA);
		//glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		//glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
		glDisable(GL_BLEND);
		glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
		//	clear the view
		glClearColor(0.0,0.0,0.0,0.0);
		glClear(GL_COLOR_BUFFER_BIT);
		
		
		if (drawBuffer != nil)	{
			//NSSize			bufferSize = [b size];
			//BOOL			bufferFlipped = [b flipped];
			NSRect			destRect = [VVSizingTool
				//rectThatFitsRect:NSMakeRect(0,0,bufferSize.width,bufferSize.height)
				rectThatFitsRect:[drawBuffer srcRect]
				inRect:bounds
				sizingMode:sizingMode];
			
			
			GLDRAWTEXQUADMACRO([drawBuffer name],[drawBuffer target],[drawBuffer flipped],[drawBuffer glReadySrcRect],destRect);
		}
		//	flush!
		glFlush();
		
		glDisable(target);
	}
	
	VVRELEASE(drawBuffer);
}


- (void) redraw	{
	[self performDrawing:[self bounds]];
}
- (void) drawBuffer:(VVBuffer *)b	{
	//NSLog(@"%s",__func__);
	VVLockLock(&retainDrawLock);
	VVRELEASE(retainDrawBuffer);
	retainDrawBuffer = (b==nil) ? nil : [b retain];
	VVLockUnlock(&retainDrawLock);
	
	[self redraw];
}
- (void) setSharedGLContext:(NSOpenGLContext *)c	{
	NSOpenGLContext		*newCtx = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:c];
	[self setOpenGLContext:newCtx];
	[newCtx setView:self];
	[newCtx release];
	newCtx = nil;
}


@synthesize sizingMode;


@end

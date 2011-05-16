
#import "VVSpriteGLView.h"
#import <OpenGL/CGLMacro.h>
#import "VVBasicMacros.h"
//#import "VVControl.h"




@implementation VVSpriteGLView


- (id) initWithFrame:(NSRect)f pixelFormat:(NSOpenGLPixelFormat *)p	{
	//NSLog(@"%s",__func__);
	if (self = [super initWithFrame:f pixelFormat:p])	{
		[self generalInit];
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithCoder:(NSCoder *)c	{
	//NSLog(@"%s",__func__);
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
	initialized = NO;
	//needsReshape = YES;
	spriteManager = [[VVSpriteManager alloc] init];
	spritesNeedUpdate = YES;
	lastMouseEvent = nil;
	for (int i=0;i<4;++i)
		clearColor[i] = 0.0;
	mouseDownModifierFlags = 0;
	mouseIsDown = NO;
	clickedSubview = nil;
	
	pthread_mutexattr_t		attr;
	
	pthread_mutexattr_init(&attr);
	//pthread_mutexattr_settype(&attr,PTHREAD_MUTEX_NORMAL);
	pthread_mutexattr_settype(&attr,PTHREAD_MUTEX_RECURSIVE);
	pthread_mutex_init(&glLock,&attr);
	pthread_mutexattr_destroy(&attr);
	
	flushMode = VVFlushModeGL;
	
	fenceMode = VVFenceModeEveryRefresh;
	fenceA = 0;
	fenceB = 0;
	waitingForFenceA = YES;
	fenceADeployed = NO;
	fenceBDeployed = NO;
	fenceLock = OS_SPINLOCK_INIT;
	//NSLog(@"\t\t%s ... %@, %p - FINISHED",__func__,[self class],self);
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
	
	pthread_mutex_lock(&glLock);
	OSSpinLockLock(&fenceLock);
		//NSLog(@"\t\tdeleting fences %ld & %ld in context %p",fenceA,fenceB,[self openGLContext]);
		CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
		glDeleteFencesAPPLE(1,&fenceA);
		fenceA = 0;
		fenceADeployed = NO;
		glDeleteFencesAPPLE(1,&fenceB);
		fenceB = 0;
		fenceBDeployed = NO;
	OSSpinLockUnlock(&fenceLock);
	pthread_mutex_unlock(&glLock);
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
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
		OSSpinLockLock(&fenceLock);
		CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
		if (fenceA > 0)
			glDeleteFencesAPPLE(1,&fenceA);
		fenceA = 0;
		fenceADeployed = NO;
		if (fenceB > 0)
			glDeleteFencesAPPLE(1,&fenceB);
		fenceB = 0;
		fenceBDeployed = NO;
		OSSpinLockUnlock(&fenceLock);
		
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
- (void) removeFromSuperview	{
	pthread_mutex_lock(&glLock);
	[(id)super removeFromSuperview];
	pthread_mutex_unlock(&glLock);
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
	pthread_mutex_lock(&glLock);
		[super setFrame:f];
		[self updateSprites];
		//spritesNeedUpdate = YES;
		//needsReshape = YES;
		initialized = NO;
	pthread_mutex_unlock(&glLock);
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
- (void) update	{
	spritesNeedUpdate = YES;
	initialized = NO;
}


- (void) _lock	{
	pthread_mutex_lock(&glLock);
}
- (void) _unlock	{
	pthread_mutex_unlock(&glLock);
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
	mouseIsDown = YES;
	NSPoint		locationInWindow = [e locationInWindow];
	NSPoint		localPoint = [self convertPoint:locationInWindow fromView:nil];
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
	mouseDownModifierFlags = [e modifierFlags];
	if ((mouseDownModifierFlags&NSControlKeyMask)==NSControlKeyMask)
		[spriteManager localRightMouseDown:localPoint];
	else
		[spriteManager localMouseDown:localPoint];
}
- (void) rightMouseDown:(NSEvent *)e	{
	if (deleted)
		return;
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	mouseIsDown = YES;
	NSPoint		locationInWindow = [e locationInWindow];
	NSPoint		localPoint = [self convertPoint:locationInWindow fromView:nil];
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
	[spriteManager localRightMouseDown:localPoint];
}
- (void) rightMouseUp:(NSEvent *)e	{
	if (deleted)
		return;
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	mouseIsDown = NO;
	NSPoint		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
	if (clickedSubview != nil)
		[clickedSubview rightMouseUp:e];
	else
		[spriteManager localRightMouseUp:localPoint];
}
- (void) mouseDragged:(NSEvent *)e	{
	if (deleted)
		return;
	VVRELEASE(lastMouseEvent);
	if (e != nil)//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
		lastMouseEvent = [e retain];
	NSPoint		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
	if (clickedSubview != nil)
		[clickedSubview mouseDragged:e];
	else
		[spriteManager localMouseDragged:localPoint];
}
- (void) mouseUp:(NSEvent *)e	{
	if (deleted)
		return;
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	mouseIsDown = NO;
	NSPoint		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
	if (clickedSubview != nil)
		[clickedSubview mouseUp:e];
	else
		[spriteManager localMouseUp:localPoint];
}


/*===================================================================================*/
#pragma mark --------------------- drawing
/*------------------------------------*/


- (void) lockFocus	{
	if (deleted)	{
		[super lockFocus];
		return;
	}
	
	pthread_mutex_lock(&glLock);
	[super lockFocus];
	pthread_mutex_unlock(&glLock);
}
- (void) drawRect:(NSRect)r	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	
	id			myWin = [self window];
	if (myWin == nil)
		return;
	//	if the sprites need to be updated, do so now
	if (spritesNeedUpdate)
		[self updateSprites];
	
	pthread_mutex_lock(&glLock);
		if (!initialized)	{
			[self initializeGL];
			initialized = YES;
		}
		NSOpenGLContext		*context = [self openGLContext];
		CGLContextObj		cgl_ctx = [context CGLContextObj];
		
		//	lock around the fence, determine whether i should proceed with the render or not
		OSSpinLockLock(&fenceLock);
		BOOL		proceedWithRender = NO;
		//	if the fences are broken, i'm going to proceed with rendering and ignore fencing
		if ((fenceA < 1) || (fenceB < 1))
			proceedWithRender = YES;
		//	else the fences are fine- fence based on the fencing mode
		else	{
			//	if the fence mode wants to draw every refresh, proceed with rendering
			if ((fenceMode==VVFenceModeEveryRefresh) || (fenceMode==VVFenceModeFinish))	{
				//NSLog(@"\t\tfence mode is every refresh!");
				proceedWithRender = YES;
			}
			//	else the fence mode *isn't* drawing every refresh- i need to test fenceA no matter what
			else	{
				//	if i'm in single-buffer mode but i'm not waiting for fenceA, something's wrong- i should be waiting for A!
				if ((fenceMode==VVFenceModeSBSkip) && (!waitingForFenceA))
					waitingForFenceA = YES;
				
				//	if i'm waiting for fence A....
				if (waitingForFenceA)	{
					//	if fence A hasn't been deployed, proceed with rendering anyway
					if (!fenceADeployed)
						proceedWithRender = YES;
					else	{
						proceedWithRender = glTestFenceAPPLE(fenceA);
						fenceADeployed = (proceedWithRender)?NO:YES;
					}
					//if (proceedWithRender)
					//	NSLog(@"\t\tfenceA executed- clear to render");
					//else
					//	NSLog(@"\t\tfenceA hasn't executed yet");
					
				}
				//	if i'm in DB skip mode and i'm not waiting for fence A...
				if ((fenceMode==VVFenceModeDBSkip) && (!waitingForFenceA))	{
					//	if fence B hasn't been deployed, proceed with rendering anyway
					if (!fenceBDeployed)
						proceedWithRender = YES;
					else	{
						proceedWithRender = glTestFenceAPPLE(fenceB);
						fenceBDeployed = (proceedWithRender)?NO:YES;
					}
					//if (proceedWithRender)
					//	NSLog(@"\t\tfenceB executed- clear to render");
					//else
					//	NSLog(@"\t\tfenceB hasn't executed yet");
				}
			}
		}
		OSSpinLockUnlock(&fenceLock);
		
		
		if (proceedWithRender)	{
			/*
			//	set up the view to draw
			NSRect				bounds = [self bounds];
			glMatrixMode(GL_MODELVIEW);
			glLoadIdentity();
			glMatrixMode(GL_PROJECTION);
			glLoadIdentity();
			glViewport(0, 0, (GLsizei) bounds.size.width, (GLsizei) bounds.size.height);
			glOrtho(bounds.origin.x, bounds.origin.x+bounds.size.width, bounds.origin.y, bounds.origin.y+bounds.size.height, -1.0, 1.0);
			*/
			
			//	clear the view
			glClear(GL_COLOR_BUFFER_BIT);
			
			//	tell the sprite manager to start drawing the sprites
			if (spriteManager != nil)
				[spriteManager drawRect:r];
			//	flush!
			switch (flushMode)	{
				case VVFlushModeGL:
					glFlush();
					break;
				case VVFlushModeCGL:
					CGLFlushDrawable(cgl_ctx);
					break;
				case VVFlushModeNS:
					[context flushBuffer];
					break;
				case VVFlushModeApple:
					glFlushRenderAPPLE();
					break;
				case VVFlushModeFinish:
					glFinish();
					break;
			}
			
			//	lock around the fence, insert a fence in the command stream, and swap fences
			OSSpinLockLock(&fenceLock);
			if ((fenceMode!=VVFenceModeEveryRefresh) && (fenceMode!=VVFenceModeFinish) && (fenceA > 0) && (fenceB > 0))	{
				if (waitingForFenceA)	{
					glSetFenceAPPLE(fenceA);
					fenceADeployed = YES;
					//NSLog(@"\t\tdone drawing, inserting fenceA into stream");
					if (fenceMode == VVFenceModeDBSkip)
						waitingForFenceA = NO;
				}
				else	{
					glSetFenceAPPLE(fenceB);
					fenceBDeployed = YES;
					//NSLog(@"\t\tdone drawing, inserting fenceB into stream");
					waitingForFenceA = YES;
				}
			}
			OSSpinLockUnlock(&fenceLock);
			
			//	call 'finishedDrawing' so subclasses of me have a chance to perform post-draw cleanup
			[self finishedDrawing];
		}
		//else
		//	NSLog(@"\t\terr: sprite GL view fence prevented output!");
		
		
	pthread_mutex_unlock(&glLock);
}
- (void) initializeGL	{
	//NSLog(@"%s ... %p",__func__,self);
	if (deleted)
		return;
	CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
	//NSRect				bounds = [self bounds];
	//long				cpSwapInterval = 1;
	//[[self openGLContext] setValues:(GLint *)&cpSwapInterval forParameter:NSOpenGLCPSwapInterval];
	
	OSSpinLockLock(&fenceLock);
	if (fenceA < 1)	{
		glGenFencesAPPLE(1,&fenceA);
		fenceADeployed = NO;
	}
	if (fenceB < 1)	{
		glGenFencesAPPLE(1,&fenceB);
		fenceBDeployed = NO;
	}
	OSSpinLockUnlock(&fenceLock);
	
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	//glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	//glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
	glHint(GL_CLIP_VOLUME_CLIPPING_HINT_EXT, GL_FASTEST);
	
	//	from http://developer.apple.com/library/mac/#documentation/GraphicsImaging/Conceptual/OpenGL-MacProgGuide/opengl_designstrategies/opengl_designstrategies.html%23//apple_ref/doc/uid/TP40001987-CH2-SW17
	glDisable(GL_DITHER);
	glDisable(GL_ALPHA_TEST);
	glDisable(GL_STENCIL_TEST);
	glDisable(GL_FOG);
	glDisable(GL_TEXTURE_2D);
	glPixelZoom(1.0,1.0);
	
	//	moved in from drawRect:
	NSRect				bounds = [self bounds];
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glViewport(0, 0, (GLsizei) bounds.size.width, (GLsizei) bounds.size.height);
	glOrtho(bounds.origin.x, bounds.origin.x+bounds.size.width, bounds.origin.y, bounds.origin.y+bounds.size.height, -1.0, 1.0);
	
	//	always here!
	glDisable(GL_DEPTH_TEST);
	glClearColor(clearColor[0],clearColor[1],clearColor[2],clearColor[3]);
}
/*	this method exists so subclasses of me have an opportunity to do something after drawing 
	has completed.  this is particularly handy with the GL view, as drawing does not complete- and 
	therefore resources have to stay available- until after glFlush() has been called.		*/
- (void) finishedDrawing	{

}


@synthesize deleted;
@synthesize initialized;
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
	return lastMouseEvent;
}
- (VVSpriteManager *) spriteManager	{
	return spriteManager;
}
- (void) setClearColor:(NSColor *)c	{
	if ((deleted)||(c==nil))
		return;
	[c getComponents:(CGFloat *)clearColor];
}
- (NSColor *) clearColor	{
	if (deleted)
		return nil;
	return [NSColor colorWithDeviceRed:clearColor[0] green:clearColor[1] blue:clearColor[2] alpha:clearColor[3]];
}
@synthesize mouseIsDown;
@synthesize flushMode;


@end

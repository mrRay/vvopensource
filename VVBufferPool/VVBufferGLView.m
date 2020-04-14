#import "VVBufferGLView.h"
#import <OpenGL/CGLMacro.h>
#import "GLScene.h"
#import "VVSizingTool.h"
//#import "Canvas.h"
#import "VVBufferPool.h"




@implementation VVBufferGLView


- (id) initWithFrame:(VVRECT)f	{
	if (self = [super initWithFrame:f])	{
		pthread_mutexattr_t		attr;
		pthread_mutexattr_init(&attr);
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
		pthread_mutex_init(&renderLock, &attr);
		pthread_mutexattr_destroy(&attr);
		initialized = NO;
		sizingMode = VVSizingModeFit;
		retainDraw = NO;
		retainDrawLock = OS_UNFAIR_LOCK_INIT;
		retainDrawBuffer = nil;
		onlyDrawNewStuff = NO;
		onlyDrawNewStuffLock = OS_UNFAIR_LOCK_INIT;
		onlyDrawNewStuffTimestamp = 0;
		return self;
	}
	VVRELEASE(self);
	return self;
}
- (id) initWithCoder:(NSCoder *)c	{
	if (self = [super initWithCoder:c])	{
		pthread_mutexattr_t		attr;
		pthread_mutexattr_init(&attr);
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
		pthread_mutex_init(&renderLock, &attr);
		pthread_mutexattr_destroy(&attr);
		initialized = NO;
		sizingMode = VVSizingModeFit;
		retainDraw = NO;
		retainDrawLock = OS_UNFAIR_LOCK_INIT;
		retainDrawBuffer = nil;
		onlyDrawNewStuff = NO;
		onlyDrawNewStuffLock = OS_UNFAIR_LOCK_INIT;
		onlyDrawNewStuffTimestamp = 0;
		return self;
	}
	VVRELEASE(self);
	return self;
}
- (void) awakeFromNib	{
	initialized = NO;
}
- (void) dealloc	{
	pthread_mutex_destroy(&renderLock);
	os_unfair_lock_lock(&retainDrawLock);
	VVRELEASE(retainDrawBuffer);
	os_unfair_lock_unlock(&retainDrawLock);
	
}
- (void) drawRect:(VVRECT)r	{
	pthread_mutex_lock(&renderLock);
		if (!initialized)	{
			//NSLog(@"\t\tinitializing during %s",__func__);
			if (_globalVVBufferPool != nil)	{
				NSOpenGLContext		*sharedCtx = [_globalVVBufferPool sharedContext];
				if (sharedCtx != nil)	{
					[self setSharedGLContext:sharedCtx];
					initialized = YES;
				}
			}
		}
	pthread_mutex_unlock(&renderLock);
	[self redraw];
}
- (void) redraw	{
	VVBuffer		*lastBuffer = nil;
	os_unfair_lock_lock(&retainDrawLock);
	lastBuffer = (!retainDraw || retainDrawBuffer==nil) ? nil : retainDrawBuffer;
	os_unfair_lock_unlock(&retainDrawLock);
	
	[self drawBuffer:lastBuffer];
	
	VVRELEASE(lastBuffer);
}
- (void) drawBuffer:(VVBuffer *)b	{
	//NSLog(@"%s",__func__);
	BOOL			bail = NO;
	
	VVBuffer		*tmpBuffer = b;
	
	os_unfair_lock_lock(&retainDrawLock);
	if (retainDraw)	{
		if (retainDrawBuffer != tmpBuffer)	{
			VVRELEASE(retainDrawBuffer);
			retainDrawBuffer = tmpBuffer;
		}
	}
	os_unfair_lock_unlock(&retainDrawLock);
	
	os_unfair_lock_lock(&onlyDrawNewStuffLock);
	if (onlyDrawNewStuff)	{
		uint64_t		bufferTimestamp;
		[tmpBuffer getContentTimestamp:&bufferTimestamp];
		if (onlyDrawNewStuffTimestamp==bufferTimestamp)
			bail = YES;
	}
	os_unfair_lock_unlock(&onlyDrawNewStuffLock);
	if (bail)	{
		VVRELEASE(tmpBuffer);
		return;
	}
	
	GLuint			target = (tmpBuffer==nil) ? GL_TEXTURE_RECTANGLE_EXT : [tmpBuffer target];
	pthread_mutex_lock(&renderLock);
		if (initialized)	{
			CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
			if (cgl_ctx != NULL)	{
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
				VVRECT				bounds = [self bounds];
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
				
				
				if (tmpBuffer != nil)	{
					//VVSIZE			bufferSize = [tmpBuffer size];
					//BOOL			bufferFlipped = [tmpBuffer flipped];
					VVRECT			destRect = [VVSizingTool
						//rectThatFitsRect:VVMAKERECT(0,0,bufferSize.width,bufferSize.height)
						rectThatFitsRect:[tmpBuffer srcRect]
						inRect:[self bounds]
						sizingMode:sizingMode];
					
					
					GLDRAWTEXQUADMACRO([tmpBuffer name],[tmpBuffer target],[tmpBuffer flipped],[tmpBuffer glReadySrcRect],destRect);
				}
				//	flush!
				glFlush();
				
				glDisable(target);
			}
		}
	pthread_mutex_unlock(&renderLock);
	
	VVRELEASE(tmpBuffer);
}
- (void) setSharedGLContext:(NSOpenGLContext *)c	{
	if (c == nil)
		return;
	pthread_mutex_lock(&renderLock);
		NSOpenGLContext		*newContext = [[NSOpenGLContext alloc] initWithFormat:[_globalVVBufferPool customPixelFormat] shareContext:c];
		[self setOpenGLContext:newContext];
		[newContext setView:self];
		long				swap = 1;
		[[self openGLContext] setValues:(GLint *)&swap forParameter:NSOpenGLCPSwapInterval];
		initialized = YES;
	pthread_mutex_unlock(&renderLock);
}


@synthesize initialized;
@synthesize sizingMode;
- (void) setOnlyDrawNewStuff:(BOOL)n	{
	os_unfair_lock_lock(&onlyDrawNewStuffLock);
	onlyDrawNewStuff = n;
	onlyDrawNewStuffTimestamp = 0;
	os_unfair_lock_unlock(&onlyDrawNewStuffLock);
}
- (void) setRetainDraw:(BOOL)n	{
	os_unfair_lock_lock(&retainDrawLock);
	retainDraw = n;
	os_unfair_lock_unlock(&retainDrawLock);
}
- (void) setRetainDrawBuffer:(VVBuffer *)n	{
	os_unfair_lock_lock(&retainDrawLock);
	VVRELEASE(retainDrawBuffer);
	retainDrawBuffer = (n==nil) ? nil : n;
	os_unfair_lock_unlock(&retainDrawLock);
}
- (BOOL) onlyDrawNewStuff	{
	BOOL		returnMe = NO;
	os_unfair_lock_lock(&onlyDrawNewStuffLock);
	returnMe = onlyDrawNewStuff;
	os_unfair_lock_unlock(&onlyDrawNewStuffLock);
	return returnMe;
}


@end

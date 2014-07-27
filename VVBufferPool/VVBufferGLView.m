#import "VVBufferGLView.h"
#import <OpenGL/CGLMacro.h>
#import "GLScene.h"
#import "VVSizingTool.h"
//#import "Canvas.h"
#import "VVBufferPool.h"




@implementation VVBufferGLView


- (id) initWithFrame:(NSRect)f	{
	if (self = [super initWithFrame:f])	{
		pthread_mutexattr_t		attr;
		pthread_mutexattr_init(&attr);
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
		pthread_mutex_init(&renderLock, &attr);
		pthread_mutexattr_destroy(&attr);
		initialized = NO;
		sizingMode = VVSizingModeFit;
		retainDraw = NO;
		retainDrawLock = OS_SPINLOCK_INIT;
		retainDrawBuffer = nil;
		onlyDrawNewStuff = NO;
		onlyDrawNewStuffLock = OS_SPINLOCK_INIT;
		onlyDrawNewStuffTimestamp.tv_sec = 0;
		onlyDrawNewStuffTimestamp.tv_usec = 0;
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
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
		retainDrawLock = OS_SPINLOCK_INIT;
		retainDrawBuffer = nil;
		onlyDrawNewStuff = NO;
		onlyDrawNewStuffLock = OS_SPINLOCK_INIT;
		onlyDrawNewStuffTimestamp.tv_sec = 0;
		onlyDrawNewStuffTimestamp.tv_usec = 0;
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (void) awakeFromNib	{
	initialized = NO;
}
- (void) dealloc	{
	pthread_mutex_destroy(&renderLock);
	OSSpinLockLock(&retainDrawLock);
	VVRELEASE(retainDrawBuffer);
	OSSpinLockUnlock(&retainDrawLock);
	[super dealloc];
}
- (void) drawRect:(NSRect)r	{
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
	OSSpinLockLock(&retainDrawLock);
	lastBuffer = (!retainDraw || retainDrawBuffer==nil) ? nil : [retainDrawBuffer retain];
	OSSpinLockUnlock(&retainDrawLock);
	
	[self drawBuffer:lastBuffer];
	
	[lastBuffer release];
	lastBuffer = nil;
}
- (void) drawBuffer:(VVBuffer *)b	{
	//NSLog(@"%s",__func__);
	BOOL			bail = NO;
	
	OSSpinLockLock(&retainDrawLock);
	if (retainDraw)	{
		if (retainDrawBuffer != b)	{
			VVRELEASE(retainDrawBuffer);
			retainDrawBuffer = [b retain];
		}
	}
	OSSpinLockUnlock(&retainDrawLock);
	
	OSSpinLockLock(&onlyDrawNewStuffLock);
	if (onlyDrawNewStuff)	{
		struct timeval		bufferTimestamp;
		[b getContentTimestamp:&bufferTimestamp];
		if (onlyDrawNewStuffTimestamp.tv_sec==bufferTimestamp.tv_sec && onlyDrawNewStuffTimestamp.tv_usec==bufferTimestamp.tv_usec)
			bail = YES;
	}
	OSSpinLockUnlock(&onlyDrawNewStuffLock);
	if (bail)
		return;
	
	GLuint			target = (b==nil) ? GL_TEXTURE_RECTANGLE_EXT : [b target];
	pthread_mutex_lock(&renderLock);
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
			NSRect				bounds = [self bounds];
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
			
			
			if (b != nil)	{
				[b retain];
				//NSSize			bufferSize = [b size];
				//BOOL			bufferFlipped = [b flipped];
				NSRect			destRect = [VVSizingTool
					//rectThatFitsRect:NSMakeRect(0,0,bufferSize.width,bufferSize.height)
					rectThatFitsRect:[b srcRect]
					inRect:[self bounds]
					sizingMode:sizingMode];
				
				
				GLDRAWTEXQUADMACRO([b name],[b target],[b flipped],[b glReadySrcRect],destRect);
			}
			//	flush!
			glFlush();
			if (b != nil)
				[b release];
			
			glDisable(target);
		}
	pthread_mutex_unlock(&renderLock);
}
- (void) setSharedGLContext:(NSOpenGLContext *)c	{
	if (c == nil)
		return;
	pthread_mutex_lock(&renderLock);
		NSOpenGLContext		*newContext = [[NSOpenGLContext alloc] initWithFormat:[_globalVVBufferPool customPixelFormat] shareContext:c];
		[self setOpenGLContext:newContext];
		[newContext setView:self];
		[newContext release];
		long				swap = 1;
		[[self openGLContext] setValues:(GLint *)&swap forParameter:NSOpenGLCPSwapInterval];
		initialized = YES;
	pthread_mutex_unlock(&renderLock);
}


@synthesize initialized;
@synthesize sizingMode;
- (void) setOnlyDrawNewStuff:(BOOL)n	{
	OSSpinLockLock(&onlyDrawNewStuffLock);
	onlyDrawNewStuff = n;
	onlyDrawNewStuffTimestamp.tv_sec = 0;
	onlyDrawNewStuffTimestamp.tv_usec = 0;
	OSSpinLockUnlock(&onlyDrawNewStuffLock);
}
- (void) setRetainDraw:(BOOL)n	{
	OSSpinLockLock(&retainDrawLock);
	retainDraw = n;
	OSSpinLockUnlock(&retainDrawLock);
}
- (void) setRetainDrawBuffer:(VVBuffer *)n	{
	OSSpinLockLock(&retainDrawLock);
	VVRELEASE(retainDrawBuffer);
	retainDrawBuffer = (n==nil) ? nil : [n retain];
	OSSpinLockUnlock(&retainDrawLock);
}
- (BOOL) onlyDrawNewStuff	{
	BOOL		returnMe = NO;
	OSSpinLockLock(&onlyDrawNewStuffLock);
	returnMe = onlyDrawNewStuff;
	OSSpinLockUnlock(&onlyDrawNewStuffLock);
	return returnMe;
}


@end

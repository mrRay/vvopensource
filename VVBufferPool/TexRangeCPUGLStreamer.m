#import "TexRangeCPUGLStreamer.h"
#import "VVBufferPool.h"
#import <OpenGL/CGLMacro.h>




@implementation TexRangeCPUGLStreamer


- (id) init	{
	if (self = [super init])	{
		pthread_mutexattr_t		attr;
		pthread_mutexattr_init(&attr);
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
		pthread_mutex_init(&contextLock, &attr);
		pthread_mutexattr_destroy(&attr);
		
		deleted = NO;
		
		//shaderScene = nil;
		//swizzleNode = nil;
		ctx = nil;
		return self;
	}
	[self release];
	return nil;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	pthread_mutex_lock(&contextLock);
	//VVRELEASE(shaderScene);
	//VVRELEASE(swizzleNode);
	VVRELEASE(ctx);
	pthread_mutex_unlock(&contextLock);
	pthread_mutex_destroy(&contextLock);
	[super dealloc];
}
- (void) prepareToBeDeleted	{
	pthread_mutex_lock(&contextLock);
	//if (shaderScene != nil)
	//	[shaderScene prepareToBeDeleted];
	//if (swizzleNode != nil)
	//	[swizzleNode prepareToBeDeleted];
	pthread_mutex_unlock(&contextLock);
	deleted = YES;
}


- (void) pushTexRangeBufferRAMtoVRAM:(VVBuffer *)b	{
	//NSLog(@"%s ... %@",__func__,b);
	if (deleted || b==nil)
		return;
	
	pthread_mutex_lock(&contextLock);
	
	if (ctx == nil)
		[self _createGLResources];
	[VVBufferPool
		pushTexRangeBufferRAMtoVRAM:b
		usingContext:[ctx CGLContextObj]];
	
	pthread_mutex_unlock(&contextLock);
}


- (void) _createGLResources	{
	//NSLog(@"%s",__func__);
	if (deleted || ctx!=nil)
		return;
	if (ctx == nil)	{
		ctx = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:[_globalVVBufferPool sharedContext]];
		//[swizzleNode setCopyToIOSurface:NO];	//	added recently- stuff was refactored, and this was **NOT** the default value before the refactor.
	}
}


@end

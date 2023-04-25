#import "VideoSource.h"




@implementation VideoSource


- (id) init	{
	if (self = [super init])	{
		deleted = NO;
		/*
		lastBufferLock = OS_SPINLOCK_INIT;
		lastBuffer = nil;
		*/
		propLock = VV_LOCK_INIT;
		propRunning = NO;
		propDelegate = nil;
		return self;
	}
	[self release];
	return nil;
}
- (void) prepareToBeDeleted	{
	[self stop];
	deleted = YES;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	/*
	OSSpinLockLock(&lastBufferLock);
	VVRELEASE(lastBuffer);
	OSSpinLockUnlock(&lastBufferLock);
	*/
	[super dealloc];
}
- (VVBuffer *) allocBuffer	{
	return nil;
}
- (NSArray *) arrayOfSourceMenuItems	{
	return nil;
}


- (void) start	{
	//NSLog(@"%s ... %@",__func__,self);
	VVLockLock(&propLock);
	if (!propRunning)	{
		[self _start];
		propRunning = YES;
	}
	else
		NSLog(@"\t\tERR: starting something that wasn't stopped, %s",__func__);
	VVLockUnlock(&propLock);
}
- (void) _start	{
	//NSLog(@"%s ... %@",__func__,self);
}
- (void) stop	{
	//NSLog(@"%s ... %@",__func__,self);
	VVLockLock(&propLock);
	if (propRunning)	{
		[self _stop];
		propRunning = NO;
	}
	else
		NSLog(@"\t\tERR: stopping something that wasn't running, %s",__func__);
	VVLockUnlock(&propLock);
}
- (void) _stop	{
	//NSLog(@"%s ... %@",__func__,self);
}


- (BOOL) propRunning	{
	BOOL		returnMe;
	VVLockLock(&propLock);
	returnMe = propRunning;
	VVLockUnlock(&propLock);
	return returnMe;
}
- (void) setPropDelegate:(id<VideoSourceDelegate>)n	{
	VVLockLock(&propLock);
	propDelegate = n;
	VVLockUnlock(&propLock);
}


@end

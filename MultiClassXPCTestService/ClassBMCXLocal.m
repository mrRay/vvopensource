#import "ClassBMCXLocal.h"




@implementation ClassBMCXLocal


- (id) init	{
	self = [super init];
	if (self!=nil)	{
		connLock = OS_SPINLOCK_INIT;
		conn = nil;
	}
	return self;
}
- (void) dealloc	{
	[super dealloc];
}
- (void) setConn:(NSXPCConnection *)n	{
	OSSpinLockLock(&connLock);
	conn = n;
	[n setInvalidationHandler:^()	{
		NSLog(@"LOCAL B invalidation handler");
	}];
	[n setInterruptionHandler:^()	{
		NSLog(@"LOCAL B interruption handler");
		exit(EXIT_FAILURE);
	}];
	OSSpinLockUnlock(&connLock);
}


#pragma mark ClassBXPCService protocol


- (void) establishConnection	{
	NSLog(@"%s",__func__);
	OSSpinLockLock(&connLock);
	id<ClassBAppService>		rop = [[[conn remoteObjectProxy] retain] autorelease];
	OSSpinLockUnlock(&connLock);
	[rop connectionEstablished];
}
- (void) startProcessingB	{
	NSLog(@"%s",__func__);
	OSSpinLockLock(&connLock);
	id<ClassBAppService>		rop = [[[conn remoteObjectProxy] retain] autorelease];
	OSSpinLockUnlock(&connLock);
	[rop finishedProcessingB];
}


@end

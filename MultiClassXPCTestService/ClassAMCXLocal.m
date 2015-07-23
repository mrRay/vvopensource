#import "ClassAMCXLocal.h"




@implementation ClassAMCXLocal


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
		NSLog(@"LOCAL A invalidation handler");
	}];
	[n setInterruptionHandler:^()	{
		NSLog(@"LOCAL A interruption handler");
		exit(EXIT_FAILURE);
	}];
	OSSpinLockUnlock(&connLock);
}


#pragma mark ClassAXPCService protocol


- (void) establishConnection	{
	NSLog(@"%s",__func__);
	OSSpinLockLock(&connLock);
	id<ClassAAppService>		rop = [[[conn remoteObjectProxy] retain] autorelease];
	OSSpinLockUnlock(&connLock);
	[rop connectionEstablished];
}
- (void) startProcessingA	{
	NSLog(@"%s",__func__);
	OSSpinLockLock(&connLock);
	id<ClassAAppService>		rop = [[[conn remoteObjectProxy] retain] autorelease];
	OSSpinLockUnlock(&connLock);
	[rop finishedProcessingA];
}


@end

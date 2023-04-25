#import "ClassBMCXLocal.h"




@implementation ClassBMCXLocal


- (id) init	{
	self = [super init];
	if (self!=nil)	{
		connLock = VV_LOCK_INIT;
		conn = nil;
	}
	return self;
}
- (void) dealloc	{
	[super dealloc];
}
- (void) setConn:(NSXPCConnection *)n	{
	VVLockLock(&connLock);
	conn = n;
	[n setInvalidationHandler:^()	{
		NSLog(@"LOCAL B invalidation handler");
	}];
	[n setInterruptionHandler:^()	{
		NSLog(@"LOCAL B interruption handler");
		exit(EXIT_FAILURE);
	}];
	VVLockUnlock(&connLock);
}


#pragma mark ClassBXPCService protocol


- (void) establishConnection	{
	NSLog(@"%s",__func__);
	VVLockLock(&connLock);
	id<ClassBAppService>		rop = [[[conn remoteObjectProxy] retain] autorelease];
	VVLockUnlock(&connLock);
	[rop connectionEstablished];
}
- (void) startProcessingB	{
	NSLog(@"%s",__func__);
	VVLockLock(&connLock);
	id<ClassBAppService>		rop = [[[conn remoteObjectProxy] retain] autorelease];
	VVLockUnlock(&connLock);
	[rop finishedProcessingB];
}


@end

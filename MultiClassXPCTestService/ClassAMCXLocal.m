#import "ClassAMCXLocal.h"




@implementation ClassAMCXLocal


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
		NSLog(@"LOCAL A invalidation handler");
	}];
	[n setInterruptionHandler:^()	{
		NSLog(@"LOCAL A interruption handler");
		exit(EXIT_FAILURE);
	}];
	VVLockUnlock(&connLock);
}


#pragma mark ClassAXPCService protocol


- (void) establishConnection	{
	NSLog(@"%s",__func__);
	VVLockLock(&connLock);
	id<ClassAAppService>		rop = [[[conn remoteObjectProxy] retain] autorelease];
	VVLockUnlock(&connLock);
	[rop connectionEstablished];
}
- (void) startProcessingA	{
	NSLog(@"%s",__func__);
	VVLockLock(&connLock);
	id<ClassAAppService>		rop = [[[conn remoteObjectProxy] retain] autorelease];
	VVLockUnlock(&connLock);
	[rop finishedProcessingA];
}


@end

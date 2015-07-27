#import "ClassBMCXRemote.h"
#import "MCXTestAppDelegate.h"




@interface ClassBMCXRemote ()
- (void) establishConnection;
- (void) killConnection;
@end




@implementation ClassBMCXRemote


- (id) init	{
	NSLog(@"%s",__func__);
	self = [super init];
	if (self!=nil)	{
		connLock = OS_SPINLOCK_INIT;
		conn = nil;
		connEstablished = NO;
		
		[self establishConnection];
	}
	return self;
}
- (void) dealloc	{
	
	[super dealloc];
}


#pragma mark public interface


- (void) processAThing	{
	NSLog(@"%s",__func__);
	OSSpinLockLock(&connLock);
	if (conn!=nil)
		[(id<ClassBXPCService>)[conn remoteObjectProxy] startProcessingB];
	OSSpinLockUnlock(&connLock);
}


#pragma mark backend methods


- (void) establishConnection	{
	//NSLog(@"%s",__func__);
	//	if the mgr's classes aren't available yet, wait and then call this method again later
	if (![_mcxTestAppServiceMgr classesAvailable])	{
		__block id		bss = self;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			[bss establishConnection];
		});
		return;
	}
	//NSLog(@"%s",__func__);
	//	first of all, kill the connection
	[self killConnection];
	//	get the listener endpoint for this class from the manager, then create the connection from that
	NSXPCListenerEndpoint		*listener = [_mcxTestAppServiceMgr listenerEndpointForClassNamed:@"ClassBMCXRemote"];
	if (listener==nil)	{
		NSLog(@"\t\terr: bailing, listener nil, %s",__func__);
		return;
	}
	__block id		bss = self;
	void			(^errHandlerBlock)(void) = ^(void)	{
		NSLog(@"%@ err handler",[bss className]);
		
		//	immediately inform the remote mgr that a listener error handler has been tripped- this clears its cache of classes and will re-launch the XPC service
		[_mcxTestAppServiceMgr listenerErrHandlerTripped];
		//	try to establish a connection later- this automatically waits for the remote mgr to relaunch the XPC service and re-establish its cache of classes
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.0001*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			[bss establishConnection];
		});
		
	};
	OSSpinLockLock(&connLock);
	connEstablished = NO;
	conn = [[NSXPCConnection alloc] initWithListenerEndpoint:listener];
	[conn setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(ClassBXPCService)]];
	[conn setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(ClassBAppService)]];
	[conn setExportedObject:self];
	[conn setInvalidationHandler:errHandlerBlock];
	[conn setInterruptionHandler:errHandlerBlock];
	[conn resume];
	OSSpinLockUnlock(&connLock);
	//	send the 'establish connetion' message to the ROP- this actually establishes the connection with the remote process
	[(id<ClassBXPCService>)[conn remoteObjectProxy] establishConnection];
}
- (void) killConnection	{
	//NSLog(@"%s",__func__);
	OSSpinLockLock(&connLock);
	connEstablished = NO;
	if (conn != nil)	{
		[conn setInvalidationHandler:nil];
		[conn setInterruptionHandler:nil];
		[conn invalidate];
		//	if i don't explicitly set the exported object to nil, the exported object (self) just fucking leaks.  i know, i can't believe it either.
		[conn setExportedObject:nil];
		[conn release];
		conn = nil;
	}
	OSSpinLockUnlock(&connLock);
}


#pragma mark ClassBAppService protocol


- (void) connectionEstablished	{
	NSLog(@"%s",__func__);
	OSSpinLockLock(&connLock);
	connEstablished = YES;
	OSSpinLockUnlock(&connLock);
}
- (void) finishedProcessingB	{
	NSLog(@"%s",__func__);
}


@end

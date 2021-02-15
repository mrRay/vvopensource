#import "MCXServiceManager.h"
#import "MCXProtocols.h"




@interface MCXServiceManager ()
- (void) establishConnection;
- (void) killConnection;
- (void) fetchListenerEndpoints;
@end




@implementation MCXServiceManager


#pragma mark -------------- instance methods


- (instancetype) initWithXPCServiceIdentifier:(NSString *)n	{
	NSLog(@"%s ... %@",__func__,n);
	if (n==nil)	{
		self = nil;
		return self;
	}
	self = [super init];
	if (self!=nil)	{
		connLock = VV_LOCK_INIT;
		connServiceIdentifier = n;
		conn = nil;
		classesAvailable = NO;
		classDictLock = VV_LOCK_INIT;
		classDict = nil;
		
		[self establishConnection];
	}
	return self;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	[self killConnection];
	VVLockLock(&classDictLock);
	classDict = nil;
	VVLockUnlock(&classDictLock);
	
}


- (void) establishConnection	{
	//NSLog(@"%s",__func__);
	//	first of all, kill the connection (makes sure everything's ready to create a connection)
	[self killConnection];
	
	//	make the actual connection, configure it, then resume it
	VVLockLock(&connLock);
	__weak MCXServiceManager		*bssOuter = self;
	void			(^errHandlerBlock)(void) = ^(void)	{
		MCXServiceManager		*bss = bssOuter;
		if (bss == nil)
			return;
		NSLog(@"%@ err handler for %@",[bss className],bss->connServiceIdentifier);
		//	just try to establish a connection again- this automatically kills any remnants of the old conn and fetches new listener endpoints
		[bss establishConnection];
	};
	conn = [[NSXPCConnection alloc] initWithServiceName:connServiceIdentifier];
	[conn setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(MCXService)]];
	[conn setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(MCXServiceManager)]];
	[conn setExportedObject:self];
	[conn setInvalidationHandler:errHandlerBlock];
	[conn setInterruptionHandler:errHandlerBlock];
	
	[conn resume];
	VVLockUnlock(&connLock);
	
	//	fetch the listener endpoints from the remote object- this will launch the XPC service
	[self fetchListenerEndpoints];
}
- (void) killConnection	{
	//NSLog(@"%s",__func__);
	VVLockLock(&connLock);
	if (conn != nil)	{
		//NSLog(@"\t\tinvalidating the conn");
		[conn setInvalidationHandler:nil];
		[conn setInterruptionHandler:nil];
		//[conn suspend];	//	DO NOT SUSPEND- for some reason, this prevents 'invalidate' from working.
		[conn invalidate];
		//	if i don't explicitly set the exported object to nil, the exported object (self) just fucking leaks.  i know, i can't believe it either.
		[conn setExportedObject:nil];
		conn = nil;
	}
	VVLockUnlock(&connLock);
	
	VVLockLock(&classDictLock);
	if (classDict!=nil)
		[classDict removeAllObjects];
	classesAvailable = NO;
	VVLockUnlock(&classDictLock);
}
- (void) listenerErrHandlerTripped	{
	VVLockLock(&classDictLock);
	if (classDict!=nil)
		[classDict removeAllObjects];
	classesAvailable = NO;
	VVLockUnlock(&classDictLock);
}
- (void) fetchListenerEndpoints	{
	//NSLog(@"%s",__func__);
	//	lock, clear the class dict
	VVLockLock(&classDictLock);
	classDict = nil;
	classesAvailable = NO;
	VVLockUnlock(&classDictLock);
	
	//	tell the ROP to fetch the classes
	VVLockLock(&connLock);
	if (conn!=nil && [conn remoteObjectProxy]!=nil)	{
		[(id<MCXService>)[conn remoteObjectProxy] fetchListenerEndpoints];
	}
	VVLockUnlock(&connLock);
}
- (BOOL) classesAvailable	{
	BOOL		returnMe = NO;
	VVLockLock(&classDictLock);
	returnMe = classesAvailable;
	VVLockUnlock(&classDictLock);
	return returnMe;
}
- (NSDictionary *) classDict	{
	NSDictionary		*returnMe = nil;
	VVLockLock(&classDictLock);
	returnMe = (classDict==nil) ? nil : [classDict copy];
	VVLockUnlock(&classDictLock);
	return returnMe;
}
- (NSXPCListenerEndpoint *) listenerEndpointForClassNamed:(NSString *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if (n==nil)
		return nil;
	NSXPCListenerEndpoint		*returnMe = nil;
	VVLockLock(&classDictLock);
	if (classDict!=nil)	{
		returnMe = [classDict objectForKey:n];
	}
	VVLockUnlock(&classDictLock);
	return returnMe;
}


#pragma mark -------------- MCXServiceManager protocol


- (void) fetchedEndpoint:(NSXPCListenerEndpoint *)e forClassName:(NSString *)n	{
	//NSLog(@"%s ... %@, %@",__func__,n,e);
	if (e==nil || n==nil)
		return;
	VVLockLock(&classDictLock);
	if (classDict==nil)
		classDict = [NSMutableDictionary dictionaryWithCapacity:0];
	[classDict setObject:e forKey:n];
	VVLockUnlock(&classDictLock);
}
- (void) finishedFetchingEndpoints	{
	//NSLog(@"%s",__func__);
	VVLockLock(&classDictLock);
	classesAvailable = YES;
	VVLockUnlock(&classDictLock);
}


@end

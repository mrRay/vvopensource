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
		connLock = OS_UNFAIR_LOCK_INIT;
		connServiceIdentifier = n;
		conn = nil;
		classesAvailable = NO;
		classDictLock = OS_UNFAIR_LOCK_INIT;
		classDict = nil;
		
		[self establishConnection];
	}
	return self;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	[self killConnection];
	os_unfair_lock_lock(&classDictLock);
	classDict = nil;
	os_unfair_lock_unlock(&classDictLock);
	
}


- (void) establishConnection	{
	//NSLog(@"%s",__func__);
	//	first of all, kill the connection (makes sure everything's ready to create a connection)
	[self killConnection];
	
	//	make the actual connection, configure it, then resume it
	os_unfair_lock_lock(&connLock);
	__block id		bss = self;
	void			(^errHandlerBlock)(void) = ^(void)	{
		NSLog(@"%@ err handler for %@",[bss className],connServiceIdentifier);
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
	os_unfair_lock_unlock(&connLock);
	
	//	fetch the listener endpoints from the remote object- this will launch the XPC service
	[self fetchListenerEndpoints];
}
- (void) killConnection	{
	//NSLog(@"%s",__func__);
	os_unfair_lock_lock(&connLock);
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
	os_unfair_lock_unlock(&connLock);
	
	os_unfair_lock_lock(&classDictLock);
	if (classDict!=nil)
		[classDict removeAllObjects];
	classesAvailable = NO;
	os_unfair_lock_unlock(&classDictLock);
}
- (void) listenerErrHandlerTripped	{
	os_unfair_lock_lock(&classDictLock);
	if (classDict!=nil)
		[classDict removeAllObjects];
	classesAvailable = NO;
	os_unfair_lock_unlock(&classDictLock);
}
- (void) fetchListenerEndpoints	{
	//NSLog(@"%s",__func__);
	//	lock, clear the class dict
	os_unfair_lock_lock(&classDictLock);
	classDict = nil;
	classesAvailable = NO;
	os_unfair_lock_unlock(&classDictLock);
	
	//	tell the ROP to fetch the classes
	os_unfair_lock_lock(&connLock);
	if (conn!=nil && [conn remoteObjectProxy]!=nil)	{
		[(id<MCXService>)[conn remoteObjectProxy] fetchListenerEndpoints];
	}
	os_unfair_lock_unlock(&connLock);
}
- (BOOL) classesAvailable	{
	BOOL		returnMe = NO;
	os_unfair_lock_lock(&classDictLock);
	returnMe = classesAvailable;
	os_unfair_lock_unlock(&classDictLock);
	return returnMe;
}
- (NSDictionary *) classDict	{
	NSDictionary		*returnMe = nil;
	os_unfair_lock_lock(&classDictLock);
	returnMe = (classDict==nil) ? nil : [classDict copy];
	os_unfair_lock_unlock(&classDictLock);
	return returnMe;
}
- (NSXPCListenerEndpoint *) listenerEndpointForClassNamed:(NSString *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if (n==nil)
		return nil;
	NSXPCListenerEndpoint		*returnMe = nil;
	os_unfair_lock_lock(&classDictLock);
	if (classDict!=nil)	{
		returnMe = [classDict objectForKey:n];
	}
	os_unfair_lock_unlock(&classDictLock);
	return returnMe;
}


#pragma mark -------------- MCXServiceManager protocol


- (void) fetchedEndpoint:(NSXPCListenerEndpoint *)e forClassName:(NSString *)n	{
	//NSLog(@"%s ... %@, %@",__func__,n,e);
	if (e==nil || n==nil)
		return;
	os_unfair_lock_lock(&classDictLock);
	if (classDict==nil)
		classDict = [NSMutableDictionary dictionaryWithCapacity:0];
	[classDict setObject:e forKey:n];
	os_unfair_lock_unlock(&classDictLock);
}
- (void) finishedFetchingEndpoints	{
	//NSLog(@"%s",__func__);
	os_unfair_lock_lock(&classDictLock);
	classesAvailable = YES;
	os_unfair_lock_unlock(&classDictLock);
}


@end

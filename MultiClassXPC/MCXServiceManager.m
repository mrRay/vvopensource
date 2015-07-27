#import "MCXServiceManager.h"
#import "MCXProtocols.h"




@interface MCXServiceManager ()
- (void) establishConnection;
- (void) killConnection;
- (void) fetchListenerEndpoints;
@end




@implementation MCXServiceManager


#pragma mark -------------- instance methods


- (id) initWithXPCServiceIdentifier:(NSString *)n	{
	NSLog(@"%s ... %@",__func__,n);
	if (n==nil)	{
		[self release];
		return nil;
	}
	self = [super init];
	if (self!=nil)	{
		connLock = OS_SPINLOCK_INIT;
		connServiceIdentifier = [n retain];
		conn = nil;
		classesAvailable = NO;
		classDictLock = OS_SPINLOCK_INIT;
		classDict = nil;
		
		[self establishConnection];
	}
	return self;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	[self killConnection];
	OSSpinLockLock(&classDictLock);
	if (classDict!=nil)	{
		[classDict release];
		classDict = nil;
	}
	OSSpinLockUnlock(&classDictLock);
	[super dealloc];
}


- (void) establishConnection	{
	//NSLog(@"%s",__func__);
	//	first of all, kill the connection (makes sure everything's ready to create a connection)
	[self killConnection];
	
	//	make the actual connection, configure it, then resume it
	OSSpinLockLock(&connLock);
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
	OSSpinLockUnlock(&connLock);
	
	//	fetch the listener endpoints from the remote object- this will launch the XPC service
	[self fetchListenerEndpoints];
}
- (void) killConnection	{
	//NSLog(@"%s",__func__);
	OSSpinLockLock(&connLock);
	if (conn != nil)	{
		//NSLog(@"\t\tinvalidating the conn");
		[conn setInvalidationHandler:nil];
		[conn setInterruptionHandler:nil];
		//[conn suspend];	//	DO NOT SUSPEND- for some reason, this prevents 'invalidate' from working.
		[conn invalidate];
		//	if i don't explicitly set the exported object to nil, the exported object (self) just fucking leaks.  i know, i can't believe it either.
		[conn setExportedObject:nil];
		[conn release];
		conn = nil;
	}
	OSSpinLockUnlock(&connLock);
	
	OSSpinLockLock(&classDictLock);
	if (classDict!=nil)
		[classDict removeAllObjects];
	classesAvailable = NO;
	OSSpinLockUnlock(&classDictLock);
}
- (void) listenerErrHandlerTripped	{
	OSSpinLockLock(&classDictLock);
	if (classDict!=nil)
		[classDict removeAllObjects];
	classesAvailable = NO;
	OSSpinLockUnlock(&classDictLock);
}
- (void) fetchListenerEndpoints	{
	//NSLog(@"%s",__func__);
	//	lock, clear the class dict
	OSSpinLockLock(&classDictLock);
	if (classDict!=nil)	{
		[classDict release];
		classDict = nil;
	}
	classesAvailable = NO;
	OSSpinLockUnlock(&classDictLock);
	
	//	tell the ROP to fetch the classes
	OSSpinLockLock(&connLock);
	if (conn!=nil && [conn remoteObjectProxy]!=nil)	{
		[(id<MCXService>)[conn remoteObjectProxy] fetchListenerEndpoints];
	}
	OSSpinLockUnlock(&connLock);
}
- (BOOL) classesAvailable	{
	BOOL		returnMe = NO;
	OSSpinLockLock(&classDictLock);
	returnMe = classesAvailable;
	OSSpinLockUnlock(&classDictLock);
	return returnMe;
}
- (NSDictionary *) classDict	{
	NSDictionary		*returnMe = nil;
	OSSpinLockLock(&classDictLock);
	returnMe = (classDict==nil) ? nil : [[classDict copy] autorelease];
	OSSpinLockUnlock(&classDictLock);
	return returnMe;
}
- (NSXPCListenerEndpoint *) listenerEndpointForClassNamed:(NSString *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if (n==nil)
		return nil;
	NSXPCListenerEndpoint		*returnMe = nil;
	OSSpinLockLock(&classDictLock);
	if (classDict!=nil)	{
		returnMe = [classDict objectForKey:n];
		returnMe = (returnMe==nil) ? nil : [[returnMe retain] autorelease];
	}
	OSSpinLockUnlock(&classDictLock);
	return returnMe;
}


#pragma mark -------------- MCXServiceManager protocol


- (void) fetchedEndpoint:(NSXPCListenerEndpoint *)e forClassName:(NSString *)n	{
	//NSLog(@"%s ... %@, %@",__func__,n,e);
	if (e==nil || n==nil)
		return;
	OSSpinLockLock(&classDictLock);
	if (classDict==nil)
		classDict = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	[classDict setObject:e forKey:n];
	OSSpinLockUnlock(&classDictLock);
}
- (void) finishedFetchingEndpoints	{
	//NSLog(@"%s",__func__);
	OSSpinLockLock(&classDictLock);
	classesAvailable = YES;
	OSSpinLockUnlock(&classDictLock);
}


@end

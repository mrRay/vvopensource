#import "MCXService.h"




@implementation MCXService


- (id) init	{
	//NSLog(@"%s",__func__);
	self = [super init];
	if (self!=nil)	{
		connLock = OS_SPINLOCK_INIT;
		conn = nil;
		classDictLock = OS_SPINLOCK_INIT;
		classDict = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	}
	return self;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	OSSpinLockLock(&classDictLock);
	if (classDict!=nil)	{
		[classDict release];
		classDict = nil;
	}
	OSSpinLockUnlock(&classDictLock);
	[super dealloc];
}
- (void) setConn:(NSXPCConnection *)n	{
	//NSLog(@"%s",__func__);
	OSSpinLockLock(&connLock);
	conn = n;
	[n setInvalidationHandler:^()	{
		NSLog(@"MCXService invalidation handler");
	}];
	[n setInterruptionHandler:^()	{
		NSLog(@"MCXService interruption handler");
		exit(EXIT_FAILURE);
	}];
	OSSpinLockUnlock(&connLock);
}


- (void) addServiceDelegate:(id<NSXPCListenerDelegate>)d forClassNamed:(NSString *)c	{
	if (d==nil || c==nil)	{
		NSLog(@"\t\terr: bailing, delegate or class nil, %s",__func__);
		return;
	}
	//	make a listener for the service delegate
	NSXPCListener			*listener = [NSXPCListener anonymousListener];
	if (listener==nil)	{
		NSLog(@"\t\terr: bailing, listener nil, %s",__func__);
		return;
	}
	//	connect the listener to the service delegate, start the listener
	[listener setDelegate:d];
	[listener resume];
	
	//	make a dict to store everything
	NSMutableDictionary		*tmpDict = [NSMutableDictionary dictionaryWithCapacity:0];
	[tmpDict setObject:d forKey:@"serviceDelegate"];
	[tmpDict setObject:listener forKey:@"listener"];
	//	add the dict storing everything to the class dict
	OSSpinLockLock(&classDictLock);
	[classDict setObject:tmpDict forKey:c];
	OSSpinLockUnlock(&classDictLock);
}


#pragma mark XPCServiceMgr protocol


- (void) fetchListenerEndpoints	{
	//NSLog(@"%s",__func__);
	//	assemble a dict- key is class name, object is listener endpoint
	__block NSMutableDictionary		*thingToReturn = nil;
	OSSpinLockLock(&classDictLock);
	thingToReturn = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	if (classDict!=nil)	{
		[classDict enumerateKeysAndObjectsUsingBlock:^(NSString *tmpClassName, NSDictionary *tmpClassDict, BOOL *stop)	{
			NSXPCListener			*listener = [tmpClassDict objectForKey:@"listener"];
			NSXPCListenerEndpoint	*endpoint = (listener==nil) ? nil : [listener endpoint];
			if (endpoint!=nil)	{
				[thingToReturn setObject:endpoint forKey:tmpClassName];
			}
		}];
	}
	OSSpinLockUnlock(&classDictLock);
	//	pass the dict of endpoints to the ROP
	OSSpinLockLock(&connLock);
	if (conn!=nil)	{
		id<MCXServiceManager>	rop = [conn remoteObjectProxy];
		[thingToReturn enumerateKeysAndObjectsUsingBlock:^(NSString *tmpClassName, NSXPCListenerEndpoint *tmpEndpoint, BOOL *stop)	{
			[rop fetchedEndpoint:tmpEndpoint forClassName:tmpClassName];
		}];
		[rop finishedFetchingEndpoints];
	}
	OSSpinLockUnlock(&connLock);
	
	if (thingToReturn!=nil)
		[thingToReturn autorelease];
}


@end

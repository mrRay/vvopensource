#import "MCXService.h"




@implementation MCXService


- (instancetype) init	{
	//NSLog(@"%s",__func__);
	self = [super init];
	if (self!=nil)	{
		connLock = OS_UNFAIR_LOCK_INIT;
		conn = nil;
		classDictLock = OS_UNFAIR_LOCK_INIT;
		classDict = [NSMutableDictionary dictionaryWithCapacity:0];
	}
	return self;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	os_unfair_lock_lock(&classDictLock);
	classDict = nil;
	os_unfair_lock_unlock(&classDictLock);
	
}
- (void) setConn:(NSXPCConnection *)n	{
	//NSLog(@"%s",__func__);
	os_unfair_lock_lock(&connLock);
	conn = n;
	[n setInvalidationHandler:^()	{
		NSLog(@"MCXService invalidation handler");
	}];
	[n setInterruptionHandler:^()	{
		NSLog(@"MCXService interruption handler");
		exit(EXIT_FAILURE);
	}];
	os_unfair_lock_unlock(&connLock);
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
	os_unfair_lock_lock(&classDictLock);
	[classDict setObject:tmpDict forKey:c];
	os_unfair_lock_unlock(&classDictLock);
}


#pragma mark XPCServiceMgr protocol


- (void) fetchListenerEndpoints	{
	//NSLog(@"%s",__func__);
	//	assemble a dict- key is class name, object is listener endpoint
	__block NSMutableDictionary		*thingToReturn = nil;
	os_unfair_lock_lock(&classDictLock);
	thingToReturn = [NSMutableDictionary dictionaryWithCapacity:0];
	if (classDict!=nil)	{
		[classDict enumerateKeysAndObjectsUsingBlock:^(NSString *tmpClassName, NSDictionary *tmpClassDict, BOOL *stop)	{
			NSXPCListener			*listener = [tmpClassDict objectForKey:@"listener"];
			NSXPCListenerEndpoint	*endpoint = (listener==nil) ? nil : [listener endpoint];
			if (endpoint!=nil)	{
				[thingToReturn setObject:endpoint forKey:tmpClassName];
			}
		}];
	}
	os_unfair_lock_unlock(&classDictLock);
	//	pass the dict of endpoints to the ROP
	os_unfair_lock_lock(&connLock);
	if (conn!=nil)	{
		id<MCXServiceManager>	rop = [conn remoteObjectProxy];
		[thingToReturn enumerateKeysAndObjectsUsingBlock:^(NSString *tmpClassName, NSXPCListenerEndpoint *tmpEndpoint, BOOL *stop)	{
			[rop fetchedEndpoint:tmpEndpoint forClassName:tmpClassName];
		}];
		[rop finishedFetchingEndpoints];
	}
	os_unfair_lock_unlock(&connLock);
}


@end

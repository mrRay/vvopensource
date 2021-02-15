#import "MCXService.h"




@implementation MCXService


- (instancetype) init	{
	//NSLog(@"%s",__func__);
	self = [super init];
	if (self!=nil)	{
		connLock = VV_LOCK_INIT;
		conn = nil;
		classDictLock = VV_LOCK_INIT;
		classDict = [NSMutableDictionary dictionaryWithCapacity:0];
	}
	return self;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	VVLockLock(&classDictLock);
	classDict = nil;
	VVLockUnlock(&classDictLock);
	
}
- (void) setConn:(NSXPCConnection *)n	{
	//NSLog(@"%s",__func__);
	VVLockLock(&connLock);
	conn = n;
	[n setInvalidationHandler:^()	{
		NSLog(@"MCXService invalidation handler");
	}];
	[n setInterruptionHandler:^()	{
		NSLog(@"MCXService interruption handler");
		exit(EXIT_FAILURE);
	}];
	VVLockUnlock(&connLock);
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
	VVLockLock(&classDictLock);
	[classDict setObject:tmpDict forKey:c];
	VVLockUnlock(&classDictLock);
}


#pragma mark XPCServiceMgr protocol


- (void) fetchListenerEndpoints	{
	//NSLog(@"%s",__func__);
	//	assemble a dict- key is class name, object is listener endpoint
	__block NSMutableDictionary		*thingToReturn = nil;
	VVLockLock(&classDictLock);
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
	VVLockUnlock(&classDictLock);
	//	pass the dict of endpoints to the ROP
	VVLockLock(&connLock);
	if (conn!=nil)	{
		id<MCXServiceManager>	rop = [conn remoteObjectProxy];
		[thingToReturn enumerateKeysAndObjectsUsingBlock:^(NSString *tmpClassName, NSXPCListenerEndpoint *tmpEndpoint, BOOL *stop)	{
			[rop fetchedEndpoint:tmpEndpoint forClassName:tmpClassName];
		}];
		[rop finishedFetchingEndpoints];
	}
	VVLockUnlock(&connLock);
}


@end

#import "MCXServiceDelegate.h"
#import "MCXProtocols.h"
#import "MCXService.h"



/*
 @interface MCXServiceDelegate
 - (NSMutableDictionary *) tmpServiceDelegates;
 @end
 */



@implementation MCXServiceDelegate


- (id) init	{
	//NSLog(@"%s",__func__);
	self = [super init];
	if (self!=nil)	{
		tmpServiceDelegates = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	}
	return self;
}
- (BOOL) listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection	{
	//NSLog(@"%s",__func__);
	
	//	make the service i'll be exporting, set it up with the passed connection
	__block MCXService		*exported = [[MCXService alloc] init];
	[newConnection setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(MCXService)]];
	[newConnection setExportedObject:exported];
	[exported release];
	
	//	pass the service delegates i've retained to the service
	@synchronized (self)	{
		[tmpServiceDelegates enumerateKeysAndObjectsUsingBlock:^(NSString *key, id val, BOOL *stop)	{
			[exported addServiceDelegate:val forClassNamed:key];
		}];
		[tmpServiceDelegates removeAllObjects];
	}
	
	[newConnection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(MCXServiceManager)]];
	[newConnection resume];
	
	[exported setConn:newConnection];
	
	return YES;
}
- (void) addServiceDelegate:(id<NSXPCListenerDelegate>)d forClassNamed:(NSString *)c	{
	if (d==nil || c==nil)	{
		NSLog(@"\t\terr: bailing, delegate or class nil, %s",__func__);
		return;
	}
	
	@synchronized (self)	{
		[tmpServiceDelegates setObject:d forKey:c];
	}
}


@end

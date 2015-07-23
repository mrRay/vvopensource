#import "ServiceDelegateA.h"




@implementation ServiceDelegateA


- (id) init	{
	//NSLog(@"%s",__func__);
	self = [super init];
	if (self!=nil)	{
		
	}
	return self;
}
- (BOOL) listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection	{
	NSLog(@"%s",__func__);
	
	ClassAMCXLocal		*exported = [[ClassAMCXLocal alloc] init];
	[newConnection setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(ClassAXPCService)]];
	[newConnection setExportedObject:exported];
	[exported release];
	
	[newConnection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(ClassAAppService)]];
	[newConnection resume];
	
	[exported setConn:newConnection];
	
	return YES;
}


@end

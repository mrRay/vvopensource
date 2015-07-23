#import "ServiceDelegateB.h"




@implementation ServiceDelegateB


- (id) init	{
	//NSLog(@"%s",__func__);
	self = [super init];
	if (self!=nil)	{
		
	}
	return self;
}
- (BOOL) listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection	{
	NSLog(@"%s",__func__);
	
	ClassBMCXLocal		*exported = [[ClassBMCXLocal alloc] init];
	[newConnection setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(ClassBXPCService)]];
	[newConnection setExportedObject:exported];
	[exported release];
	
	[newConnection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(ClassBAppService)]];
	[newConnection resume];
	
	[exported setConn:newConnection];
	
	return YES;
}


@end

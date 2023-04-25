#import <Cocoa/Cocoa.h>
#import "ClassAMCXProtocols.h"
#import <VVBasics/VVBasicMacros.h>




@interface ClassAMCXLocal : NSObject <ClassAXPCService>	{
	VVLock			connLock;
	NSXPCConnection		*conn;
}

- (void) setConn:(NSXPCConnection *)n;

@end

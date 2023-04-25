#import <Cocoa/Cocoa.h>
#import "ClassBMCXProtocols.h"
#import <VVBasics/VVBasicMacros.h>




@interface ClassBMCXLocal : NSObject <ClassBXPCService>	{
	VVLock			connLock;
	NSXPCConnection		*conn;
}

- (void) setConn:(NSXPCConnection *)n;

@end

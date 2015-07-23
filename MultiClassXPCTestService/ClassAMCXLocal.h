#import <Cocoa/Cocoa.h>
#import "ClassAMCXProtocols.h"




@interface ClassAMCXLocal : NSObject <ClassAXPCService>	{
	OSSpinLock			connLock;
	NSXPCConnection		*conn;
}

- (void) setConn:(NSXPCConnection *)n;

@end

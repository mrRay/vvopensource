#import <Cocoa/Cocoa.h>
#import "ClassBMCXProtocols.h"




@interface ClassBMCXLocal : NSObject <ClassBXPCService>	{
	OSSpinLock			connLock;
	NSXPCConnection		*conn;
}

- (void) setConn:(NSXPCConnection *)n;

@end

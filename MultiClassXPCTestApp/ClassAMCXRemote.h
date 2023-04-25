#import <Cocoa/Cocoa.h>
#import <MultiClassXPC/MultiClassXPC.h>
#import "ClassAMCXProtocols.h"
#import <VVBasics/VVBasicMacros.h>




@interface ClassAMCXRemote : NSObject <ClassAAppService>	{
	VVLock				connLock;
	NSXPCConnection		*conn;
	BOOL				connEstablished;
}

- (void) processAThing;

@end

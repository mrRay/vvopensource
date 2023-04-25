#import <Cocoa/Cocoa.h>
#import <MultiClassXPC/MultiClassXPC.h>
#import "ClassBMCXProtocols.h"
#import <VVBasics/VVBasicMacros.h>




@interface ClassBMCXRemote : NSObject <ClassBAppService>	{
	VVLock				connLock;
	NSXPCConnection		*conn;
	BOOL				connEstablished;
}

- (void) processAThing;

@end

#import <Cocoa/Cocoa.h>
#import <MultiClassXPC/MultiClassXPC.h>
#import "ClassBMCXProtocols.h"




@interface ClassBMCXRemote : NSObject <ClassBAppService>	{
	OSSpinLock			connLock;
	NSXPCConnection		*conn;
	BOOL				connEstablished;
}

- (void) processAThing;

@end

#import <Cocoa/Cocoa.h>
#import <MultiClassXPC/MultiClassXPC.h>
#import "ClassAMCXProtocols.h"




@interface ClassAMCXRemote : NSObject <ClassAAppService>	{
	OSSpinLock			connLock;
	NSXPCConnection		*conn;
	BOOL				connEstablished;
}

- (void) processAThing;

@end

#import <Foundation/Foundation.h>
#import "MCXProtocols.h"




//	you should never have to create an instance of this class manually outside of the guts of this framework




@interface MCXService : NSObject <MCXService>	{
	OSSpinLock			connLock;
	NSXPCConnection		*conn;
	
	OSSpinLock				classDictLock;
	NSMutableDictionary		*classDict;
}

- (void) setConn:(NSXPCConnection *)n;

- (void) addServiceDelegate:(id<NSXPCListenerDelegate>)d forClassNamed:(NSString *)c;

@end


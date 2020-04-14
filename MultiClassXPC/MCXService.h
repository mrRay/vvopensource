#import <Foundation/Foundation.h>
#import "MCXProtocols.h"
#include <os/lock.h>




//	you should never have to create an instance of this class manually outside of the guts of this framework




@interface MCXService : NSObject <MCXService>	{
	os_unfair_lock			connLock;
	NSXPCConnection		*conn;
	
	os_unfair_lock				classDictLock;
	NSMutableDictionary		*classDict;
}

- (void) setConn:(NSXPCConnection *)n;

- (void) addServiceDelegate:(id<NSXPCListenerDelegate>)d forClassNamed:(NSString *)c;

@end


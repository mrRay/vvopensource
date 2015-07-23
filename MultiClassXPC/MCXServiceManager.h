#import <Foundation/Foundation.h>
#import "MCXProtocols.h"




/*
 you need to make one instance of this class for each XPC service you want MultiClassXPC to manager
 */




@interface MCXServiceManager : NSObject <MCXServiceManager>	{
	OSSpinLock			connLock;
	NSString			*connServiceIdentifier;
	NSXPCConnection		*conn;
	
	BOOL				classesAvailable;
	OSSpinLock			classDictLock;
	NSMutableDictionary		*classDict;
}

//	you must provide a valid XPC service identifier when creating an instance of this class
- (id) initWithXPCServiceIdentifier:(NSString *)n;
//	don't call any other methods until this returns YES (indicates that that XPC process has been launched and that this has received a full set of listener endpoints in classDict
- (BOOL) classesAvailable;
//	returns a dict with the available classes (key is name of class created by app, object is listener endpoint for that class)
- (NSDictionary *) classDict;
//	returns the listener endpoint for the passed class name (created by the app)
- (NSXPCListenerEndpoint *) listenerEndpointForClassNamed:(NSString *)n;
//	when you're writing the proxy objects in the main app, call this method immediately in any invalidation or interruption handlers
- (void) listenerErrHandlerTripped;

@end


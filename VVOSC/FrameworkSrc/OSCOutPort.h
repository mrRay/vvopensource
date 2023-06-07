#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif


#include <arpa/inet.h>

#import <VVOSC/OSCPacket.h>
#import <VVOSC/OSCBundle.h>
#import <VVOSC/OSCMessage.h>




///	OSCOutPort handles everything needed to send OSC data to a given address
/*!
\ingroup VVOSC
You should never create or destroy an instance of this class manually.  OSCOutPort instances should be created/destroyed by the OSCManager.

the documentation here only covers the basics, the header file for this class is small and heavily commented if you want to know more because you're heavily customizing OSCOutPort.
*/
@interface OSCOutPort : NSObject {
	BOOL					deleted;
	int						sock;
	struct sockaddr_in		addr;
	unsigned short			port;	//!<The port i'm sending to
	NSString				*addressString;	//!<The IP address i'm sending to as an NSString
	NSString				*portLabel;	//!<The label used to distinguish this port from other OSCOutPorts in the same OSCManager
}

///	Creates and returns an auto-released OSCOutPort for the given address and port
+ (instancetype) createWithAddress:(NSString *)a andPort:(unsigned short)p;
///	Creates and returns an auto-released OSCOutPort for the given address, port, and label
+ (instancetype) createWithAddress:(NSString *)a andPort:(unsigned short)p labelled:(NSString *)l;
- (instancetype) initWithAddress:(NSString *)a andPort:(unsigned short)p;
- (instancetype) initWithAddress:(NSString *)a andPort:(unsigned short)p labelled:(NSString *)l;
- (void) prepareToBeDeleted;

///	returns an auto-released NSDictionary which describes this port (useful for restoring the port later)
- (NSDictionary *) createSnapshot;

- (BOOL) createSocket;

///	sends the passed bundle to this port's address/port
- (void) sendThisBundle:(OSCBundle *)b;
///	sends the passed message to this port's address/port
- (void) sendThisMessage:(OSCMessage *)m;
///	sends the passed packet to this port's address/port
- (void) sendThisPacket:(OSCPacket *)p;

///	changes the address this output will send to the passed address
- (void) setAddressString:(NSString *)n;
///	changes the port this output will send to the passed port
- (void) setPort:(unsigned short)p;
///	changes this output's address and port to the passed address and port
- (void) setAddressString:(NSString *)n andPort:(unsigned short)p;

- (BOOL) _matchesRawAddress:(unsigned int)a andPort:(unsigned short)p;
- (BOOL) _matchesRawAddress:(unsigned int)a;

///	the label used to distinguish this output from other outputs in my manager
- (NSString *) portLabel;
///	change the label used to distinguish this output from other outputs in my manager
- (void) setPortLabel:(NSString *)n;

- (unsigned short) port;
- (NSString *) addressString;
- (struct sockaddr_in *) addr;

@end

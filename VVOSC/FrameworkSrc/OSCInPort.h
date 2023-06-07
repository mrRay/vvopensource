#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import <VVBasics/VVBasics.h>
//#import <sys/types.h>
//#import <sys/socket.h>
#import <netinet/in.h>
#import <unistd.h>
#import <libkern/OSAtomic.h>
#import <VVOSC/OSCPacket.h>
#import <VVOSC/OSCBundle.h>
#import <VVOSC/OSCMessage.h>
#import <VVOSC/OSCOutPort.h>




///	OSCInPort handles everything needed to receive OSC data on a given port
/*!
\ingroup VVOSC
You should never create or destroy an instance of this class manually.  OSCInPort instances should be created/destroyed by the OSCManager.

Each OSCInPort is running in its own separate thread- so make sure anything called as a result of received OSC input is thread-safe!  When OSCInPort receives data, it gets parsed and passed to the in port's delegate as a series of OSCMessages consisting of an address path and an OSCValue.  By default, the inport's delegate is the manager which created it- and by default, managers pass this data on to *their* delegates (your objects/app).

the documentation here only covers the basics, the header file for this class is small and heavily commented if you want to know more because you're heavily customizing OSCInPort.
*/
@interface OSCInPort : NSObject {
	BOOL					deleted;	//	whether or not i'm deleted- ensures that socket gets closed
	BOOL					bound;		//	whether or not the socket is bound
	VVLock				socketLock;
	int						sock;		//	socket file descriptor.  remember, everything in unix is files!
	struct sockaddr_in		addr;		//	struct that describes *my* address (this is an in port)
	unsigned short			port;		//	the port number i'm receiving from
	unsigned char			*buf;	//	the socket gets data and dumps it here immediately
	double					interval;	//	how many times/sec you want the thread to run
	
	VVLock				scratchLock;
	NSThread				*thread;
	
	NSString				*portLabel;		//!<the "name" of the port (added to distinguish multiple osc input ports for bonjour)
	BOOL					zeroConfEnabled;	//	YES by default
	VVLock				zeroConfLock;
	VVStopwatch				*zeroConfSwatch;	//	bonjour services need ~5 seconds between destroy/creation or the changes get ignored- this is how we track this time
	NSNetService			*zeroConfDest;	//	bonjour service for publishing this input's address...only active if there's a portLabel!
	
	NSMutableArray			*scratchArray;	//	array of OSCMessage objects.  used for serial messaging.
	id						delegate;	//!<my delegate gets notified of incoming messages
}

//	Creates and returns an auto-released OSCInPort for the given port (or nil if the port's busy)
+ (instancetype) createWithPort:(unsigned short)p;
//	Creates and returns an auto-released OSCInPort for the given port and label (or nil if the port's busy)
+ (instancetype) createWithPort:(unsigned short)p labelled:(NSString *)n;
- (instancetype) initWithPort:(unsigned short)p;
- (instancetype) initWithPort:(unsigned short)p labelled:(NSString *)n;

- (void) prepareToBeDeleted;

///	returns an auto-released NSDictionary which describes this port (useful for restoring the state of the port later with OSCManager )
- (NSDictionary *) createSnapshot;

- (BOOL) createSocket;
- (void) start;
- (void) stop;
- (void) OSCThreadProc;
- (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l fromAddr:(unsigned int)txAddr port:(unsigned short)txPort;

///	called internally by this OSCInPort, passed an array of OSCMessage objects corresponding to the serially received data.  useful if you're subclassing OSCInPort.
- (void) handleScratchArray:(NSArray *)a;
///	called internally as messages are parsed.  useful if you're subclassing OSCInPort.
- (void) _addMessage:(OSCMessage *)val;



///	By default, sending an OSCMessage out an OSCOutPort will result in the actual data being sent from an unnamed socket that this lib isn't listening to.  If the target OSC service is trying to be sneaky- if it's trying to examing the packet header to assemble a "reply to" address- then you need to dispatch the OSCMessage via this method, which will ensure that it gets sent from an OSC port that is being listened to.
- (void) dispatchMessage:(OSCMessage *)m toOutPort:(OSCOutPort *)o;

//	called internally by OSCManager when it's asked to dispatch an OSCMessage that may need to be replied to.  you should never need to call this method manually.
- (void) _dispatchMessage:(OSCMessage *)m toOutPort:(OSCOutPort *)o;



- (unsigned short) port;
- (void) setPort:(unsigned short)n;
- (BOOL) zeroConfEnabled;
- (void) setZeroConfEnabled:(BOOL)n;
- (NSString *) portLabel;
- (void) setPortLabel:(NSString *)n;
- (NSString *) zeroConfName;
- (BOOL) bound;
- (NSString *) ipAddressString;

///	returns the delegate (default is the OSCManager which created me).
- (id) delegate;
///	sets the delegate- the delegate is NOT retained!  if the delegate gets released before the port, make sure you set this to nil!
- (void) setDelegate:(id)n;
///	sets the frequency of the callback which checks for OSC input
- (void) setInterval:(double)n;

@end

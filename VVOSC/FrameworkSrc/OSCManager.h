#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <VVOSC/OSCAddressSpace.h>
#import <VVOSC/OSCZeroConfManager.h>
#import <VVOSC/OSCInPort.h>
#import <VVOSC/OSCOutPort.h>
#import <VVOSC/OSCConstants.h>




///	Main VVOSC class- manages in & out port creation, zero configuration networking (bonjour/zeroconf)
/*!
\ingroup VVOSC
The OSCManager will probably be the main class that you're working with: it creates/deletes inputs (which receive data) and outputs (which send data), passes any OSC data received to its delegate (your application), optionally handles distribution of all received OSC messages, and does other manager-ish things.  You should only need one instance of OSCManager in your application.  One of your objects should be OSCManager's delegate (see the "OSCDelegateProtocol" below) so you may receive OSC data.

Incoming OSC data is initially received by an OSCInPort; fundamentally, in ports are running a loop which checks a socket for data received since the last loop.  By default, the OSCInPort's delegate is the OSCManager which created it.  Every time the loop runs, it passes the received data off to its delegate (the manager) as the raw address/value pairs in the order they're received.  When the OSCManager receives data from its in port it immediately passes the received data to its delegate, which should respond to one of the following methods (referred to as the 'OSCDelegateProtocol'):

\htmlonly
<div style="width: 100%; border: 1px #000 solid; background-color: #F0F0F0; padding: 5px; margin: 5px; color: black; font-family: Courier; font-size: 10pt; font-style: normal;">
@protocol OSCDelegateProtocol<BR>
- (void) receivedOSCMessage:(OSCMessage *)m;<BR>
@end
</div>
\endhtmlonly

...if you want to work with received OSC data, OSCManager's delegate must respond to this method!
*/




@interface OSCManager : NSObject <OSCDelegateProtocol> {
	MutLockArray			*inPortArray;	//	Array of OSCInPorts in a locking array for threadsafe access
	MutLockArray			*outPortArray;	//	Array of OSCOutPorts in a locking array for threadsafe access
	
	id						delegate;		//!<If there's a delegate, it will be notified when OSC messages are received
	
	OSCZeroConfManager		*zeroConfManager;	//!<Creates OSCOutPorts for any OSC destinations detected via bonjour/zeroconf
	
	Class					inPortClass;
	NSString				*inPortLabelBase;
	Class					outPortClass;
}

//	used to generate the IP addresses for this host
+ (NSArray *) hostIPv4Addresses;

- (instancetype) initWithServiceType:(NSString *)t;
- (instancetype) initWithInPortClass:(Class)i outPortClass:(Class)o;
- (instancetype) initWithInPortClass:(Class)i outPortClass:(Class)o serviceType:(NSString *)t;
- (void) _generalInit;

///	Deletes all input ports
- (void) deleteAllInputs;
///	Deletes all output ports
- (void) deleteAllOutputs;

///	Creates a new input from a snapshot dict (the snapshot must have been created via OSCInPort's createSnapshot method)
- (OSCInPort *) createNewInputFromSnapshot:(NSDictionary *)s;
///	Creates a new input for a given port and label
- (OSCInPort *) createNewInputForPort:(int)p withLabel:(NSString *)l;
///	Creates a new input for a given port, automatically generates a label
- (OSCInPort *) createNewInputForPort:(int)p;
///	Creates a new input at an arbitrary port (it tries to use port 1234) and label
- (OSCInPort *) createNewInput;

///	Creates a new output from a snapshot dict (the snapshot must have been created via OSCOutPort's createSnapshot method)
- (OSCOutPort *) createNewOutputFromSnapshot:(NSDictionary *)s;
///	Creates a new output to a given address and port with the given label
- (OSCOutPort *) createNewOutputToAddress:(NSString *)a atPort:(int)p withLabel:(NSString *)l;
///	Creates a new output to a given address and port, automatically generates a label
- (OSCOutPort *) createNewOutputToAddress:(NSString *)a atPort:(int)p;
///	Creates a new output to this machine at port 1234
- (OSCOutPort *) createNewOutput;

///	Called when OSCInPorts are processing received messages serially (by default, the manager is an OSCInPort's delegate)
- (void) receivedOSCMessage:(OSCMessage *)m;

//	Creates and returns a unique label for an input port (unique to this manager)
- (NSString *) getUniqueInputLabel;
- (BOOL) isUniqueInputLabel:(NSString *)n;
//	Creates and returns a unique label for an output port (unique to this manager)
- (NSString *) getUniqueOutputLabel;
//	Finds and returns an input matching the passed label (returns nil if not found)
- (OSCInPort *) findInputWithLabel:(NSString *)n;
- (NSMutableArray *) findInputsWithLabel:(NSString *)n;
//	Finds and returns an output matching the passed label (returns nil if not found)
- (OSCOutPort *) findOutputWithLabel:(NSString *)n;
- (NSMutableArray *) findOutputsWithLabel:(NSString *)n;
//	Finds and returns an output matching the passed address and port (returns nil if not found)
- (OSCOutPort *) findOutputWithAddress:(NSString *)a andPort:(int)p;
//	Finds and returns an output matching the passed address (which is the raw, network-byte-order internet address expressed as an int) and port.  Returns nil if not found.
- (OSCOutPort *) findOutputWithRawAddress:(unsigned int)a andPort:(unsigned short)p;
//	Finds and returns an output matching the passed address (which is the raw, network-byte-order internet address as an int).  returns nil if not found.
- (OSCOutPort *) findOutputWithRawAddress:(unsigned int)a;

//	Returns the output at the provided index in outPortArray
- (OSCOutPort *) findOutputForIndex:(int)i;
//	Finds and returns the input whose zero conf name matches the passed string (returns nil if not found)
- (OSCInPort *) findInputWithZeroConfName:(NSString *)n;
///	Removes the passed input from the inPortArray
- (void) removeInput:(id)p;
///	Removes the passed output from the outPortArray
- (void) removeOutput:(id)p;
///	Removes the first output with the passed label
- (void) removeOutputWithLabel:(NSString *)n;
///	Removes all the outputs from the outPortArray
- (void) removeAllOutputs;
///	Generates and returns an array of strings which correspond to the labels of this manager's out ports
- (NSArray *) outPortLabelArray;

///	By default, returns [OSCInPort class]- subclass around to use different subclasses of OSCInPort
- (id) inPortClass;
//	By default, returns @"VVOSC"- subclass around this to use a different base string when generating in port labels
@property (strong) NSString * inPortLabelBase;
///	By default, returns [OSCOutPort class]- subclass around to use different subclasses of OSCOutPort
- (id) outPortClass;

//	misc
///	Returns the delegate (by default, an OSCManager doesn't have a delegate)
- (id) delegate;
///	Sets the delegate; the delegate is NOT retained, make sure you tell the manager's nil before releasing it!
- (void) setDelegate:(id)n;
- (id) inPortArray;
- (id) outPortArray;


@end

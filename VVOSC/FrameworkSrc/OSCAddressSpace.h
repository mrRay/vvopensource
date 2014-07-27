
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "OSCNode.h"




//	OSCAddressSpace delegate protocol
@protocol OSCAddressSpaceDelegateProtocol
- (void) nodeRenamed:(OSCNode *)n;
//	this method is called by other nodes in the address space replying to queries.  the passed message is the reply or error in response to a query- this response needs to be transmitted (sent via an output).  this response can probably be transmitted via OSCManager's "transmitReplyOrError:" method, but the OSC address space and the OSC manager aren't necessarily related so we have this as a separate delegate method.
- (void) queryResponseNeedsToBeSent:(OSCMessage *)m;
@end




//	this is the main instance of OSCAddressSpace.  it is auto-created when this class is initialized
extern id				_mainVVOSCAddressSpace;




///	OSCAddressSpace is the primary means of interacting with the OSC address space described in the OSC specification.  This class is optional- it's not needed for basic OSC message sending/receiving.
/*!
\ingroup VVOSC
There should only ever be one instance of OSCAddressSpace, which is automatically created when the class is initialized- you should not create another instance of this class.  The main instance may be retrieved by the class method +[OSCAddressSpace mainAddressSpace] or by the class variable _mainVVOSCAddressSpace.

OSCAddressSpace is your application's main way of dealing with the OSC address space- if you need to dispatch a message, set, rename, or delete a node, you should do via the main instance of this class.  OSCAddressSpace is a subclass of OSCNode- the entire address space is made up of OSCNodes (nodes within nodes), and each "node" represents a discrete destination address.  The single instance of OSCAddressSpace is just the topmost node (for the address "/").

The basic workflow for address spaces is relatively straightforward: first locate (or create) an OSCNode instance using the OSCAddressSpace class.  If you'd like to receive messages dispatched to that address in the OSC address space, add an instance of something to the node as a delegate.  OSCAddressSpace has a couple high-level methods for doing basic manipulation of the address space.
*/




@interface OSCAddressSpace : OSCNode {
	id			delegate;
}

///	Returns the main instance of the OSC address space (and creates it if necessary)
+ (id) mainAddressSpace;
+ (void) refreshMenu;
#if !IPHONE
+ (NSMenu *) makeMenuForNode:(OSCNode *)n withTarget:(id)t action:(SEL)a;
+ (NSMenu *) makeMenuForNode:(OSCNode *)n ofType:(NSIndexSet *)ts withTarget:(id)t action:(SEL)a;
#endif

///	Renames 'before' to 'after'.  Sub-nodes stay with their owners!  Can also be though of as a "move".
- (void) renameAddress:(NSString *)before to:(NSString *)after;
- (void) renameAddressArray:(NSArray *)before toArray:(NSArray *)after;

///	If 'n' is nil, the node at the passed address will be deleted (as will any of its sub-nodes)
- (void) setNode:(OSCNode *)n forAddress:(NSString *)a;
- (void) setNode:(OSCNode *)n forAddress:(NSString *)a createIfMissing:(BOOL)c;
- (void) setNode:(OSCNode *)n forAddressArray:(NSArray *)a;
- (void) setNode:(OSCNode *)n forAddressArray:(NSArray *)a createIfMissing:(BOOL)c;

///	Tries to find the node at the passed address, creating it (and any missing interim nodes) in the process if appropriate.  Returns an instance of OSCNode which is already retained by the address space- if you're going to keep a weak ref to this OSCNode, become its delegate so you can be informed of its deletion.
- (OSCNode *) findNodeForAddress:(NSString *)p createIfMissing:(BOOL)c;
///	This method uses regex to find matches.  path components may be regex strings- this returns all the nodes that match every component in the passed address/address array!
- (NSMutableArray *) findNodesMatchingAddress:(NSString *)a;

//	this method is called whenever a node is added to another node
- (void) nodeRenamed:(OSCNode *)n;

///	Sends the passed message to the appropriate node in the address space- this is how you pass received OSC data from a source (like an OSCInPort) to your address space.  First it finds the OSCNode corresponding to the passed message's address, and then calls "dispatchMessage:" on it, which ultimately results in the node's delegates acquiring the passed OSC message.
- (void) dispatchMessage:(OSCMessage *)m;
//	Don't call this method externally- this gets called by an OSCNode inside me (or by me), and you probably won't need to ever call this method.  The passed message is a reply or error that needs to be sent back in response to a query.  The passed OSCMessage contains the IP address and port of the destination.  This method just passes the data on to the addres space's delegate- it does NOT actually send anything out, this is something you'll have to implement in the delegate.
- (void) _dispatchReplyOrError:(OSCMessage *)m;

- (void) addDelegate:(id)d forPath:(NSString *)p;
- (void) removeDelegate:(id)d forPath:(NSString *)p;
/*
- (void) addQueryDelegate:(id)d forPath:(NSString *)p;
- (void) removeQueryDelegate:(id)d forPath:(NSString *)p;
*/
@property (assign, readwrite) id delegate;


@end






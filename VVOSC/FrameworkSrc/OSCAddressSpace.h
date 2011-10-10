
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "OSCNode.h"




//	OSCAddressSpace delegate protocol
@protocol OSCAddressSpaceDelegateProtocol
- (void) nodeRenamed:(OSCNode *)n;
- (void) dispatchReplyOrError:(OSCMessage *)m;	//	this method is called by nodes in the address space.  the passed message is a reply or error in response to a query which should be sent out an output.
@end




//	this is the main instance of OSCAddressSpace.  it is auto-created when this class is initialized
extern id				_mainAddressSpace;




///	OSCAddressSpace is a representation of the OSC address space described in the OSC spec.  It is a subclass of OSCNode.  This class is optional- it's not needed for basic OSC message sending/receiving.
/*!
There should only ever be one instance of OSCAddressSpace, and you shouldn't explicitly create it.  Just call [OSCAddressSpace class] (or any other OSCAddressSpace method) and it will be automatically created.  This main instance may be retrieved by the class method +[OSCAddressSpace mainAddressSpace] or by the class variable _mainAddressSpace.

OSCAddressSpace is your application's main way of dealing with the OSC address space- if you need to dispatch a message, set, rename, or delete a node, you should do via the main instance of this class.
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

//	this method is called whenever a node is added to another node
- (void) nodeRenamed:(OSCNode *)n;

///	Unlike a normal OSCNode, this method finds the destination node and then dispatches the msg.  If the destination is itself, it just calls the super.
- (void) dispatchMessage:(OSCMessage *)m;
//	This method gets called by an OSCNode inside me (or by me), and you probably won't need to ever call this method.  The passed message is a reply or error that needs to be sent back in response to a query.  The passed OSCMessage contains the IP address and port of the destination.  This method just passes the data on to the addres space's delegate- it does NOT actually send anything out, this is something you'll have to implement in the delegate.
- (void) _dispatchReplyOrError:(OSCMessage *)m;

- (void) addDelegate:(id)d forPath:(NSString *)p;
- (void) removeDelegate:(id)d forPath:(NSString *)p;
/*
- (void) addQueryDelegate:(id)d forPath:(NSString *)p;
- (void) removeQueryDelegate:(id)d forPath:(NSString *)p;
*/
@property (assign, readwrite) id delegate;


@end






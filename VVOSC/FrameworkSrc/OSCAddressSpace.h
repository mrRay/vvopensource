
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "OSCNode.h"




//	OSCAddressSpace delegate protocol
@protocol OSCAddressSpaceDelegateProtocol
- (void) nodeRenamed:(OSCNode *)n;
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
- (void) setNode:(OSCNode *)n forAddressArray:(NSArray *)a;

//	this method is called whenever a node is added to another node
- (void) nodeRenamed:(OSCNode *)n;

//	unlike a normal node: first finds the destination node, then dispatches the msg
- (void) dispatchMessage:(OSCMessage *)m;

- (void) addDelegate:(id)d forPath:(NSString *)p;
- (void) removeDelegate:(id)d forPath:(NSString *)p;

@property (assign, readwrite) id delegate;


@end






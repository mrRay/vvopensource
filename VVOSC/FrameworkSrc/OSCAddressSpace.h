
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "OSCNode.h"




#define AddressSpaceUpdateMenus @"AddressSpaceUpdateMenus"




id _mainAddressSpace;




//	OSCAddressSpace delegate protocol
@protocol OSCAddressSpaceDelegateProtocol
//- (void) newNodeCreated:(OSCNode *)n;
- (void) nodeRenamed:(OSCNode *)n;
@end




@interface OSCAddressSpace : OSCNode {
	id			delegate;
}

+ (OSCAddressSpace *) mainSpace;
+ (void) refreshMenu;
#if !IPHONE
+ (NSMenu *) makeMenuForNode:(OSCNode *)n withTarget:(id)t action:(SEL)a;
+ (NSMenu *) makeMenuForNode:(OSCNode *)n ofType:(NSIndexSet *)ts withTarget:(id)t action:(SEL)a;
#endif

- (void) renameAddress:(NSString *)before to:(NSString *)after;
- (void) renameAddressArray:(NSArray *)before toArray:(NSArray *)after;

- (void) setNode:(OSCNode *)n forAddress:(NSString *)a;
- (void) setNode:(OSCNode *)n forAddressArray:(NSArray *)a;

//	this method is called whenever a new node is added to the address space- subclasses can override this for custom notifications
//- (void) newNodeCreated:(OSCNode *)n;
//	this method is called whenever a node is added to another node
- (void) nodeRenamed:(OSCNode *)n;

//	unlike a normal node: first finds the destination node, then dispatches the msg
- (void) dispatchMessage:(OSCMessage *)m;

- (void) addDelegate:(id)d forPath:(NSString *)p;
- (void) removeDelegate:(id)d forPath:(NSString *)p;

@property (assign, readwrite) id delegate;


@end


#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "OSCMessage.h"
#import <VVBasics/MutNRLockArray.h>
#import <VVBasics/VVBasicMacros.h>
#import <libkern/OSAtomic.h>




@protocol OSCNodeDelegateProtocol
- (void) node:(id)n receivedOSCMessage:(id)msg;
- (void) nodeNameChanged:(id)node;
- (void) nodeDeleted:(id)node;
@end
///	An OSCNode's queryDelegate must respond to these methods, which are called when a query-type OSCMessage is dispatched to an OSCNode
@protocol OSCNodeQueryDelegateProtocol
- (NSMutableArray *) namespaceArrayForNode:(id)n;
- (NSString *) docStringForNode:(id)n;
- (NSString *) typeSignatureForNode:(id)n;
- (OSCValue *) currentValueForNode:(id)n;
- (NSString *) returnTypeStringForNode:(id)n;
@end




///	OSCNode describes a single destination for OSC addresses.  The OSC address space is made up of many different nodes.  This class is optional- it is not used for basic OSC message sending/receiving, and only gets used if you start working with OSCAddressSpace.
/*!
The OSC specification describes a slash-delineated address space- as messages are received, they are dispatched to the described address.  An OSCNode represents a single unique destination in the OSC address space.  OSCNodes may have subnodes and have a non-retaining reference to their parent node (unless they're top-level, in which case their parent node is nil).  They retain a copy of the last message dispatched directly to this node for convenience.  OSCNode instances have zero or more delegates- delegates are NOT retained, and are assumed to respond to all the methods in OSCNOdeDelegateProtocol.

If you want to work with an instance of OSCNode, you need to acquire or work with it from the main OSCAddressSpace.  Do not just start creating OSCNode instances willy-nilly; there's no point, they're only useful if they're part of an address space.

Generally speaking, it's a good idea for each instance of OSCNode to have a discrete type, as this makes it easier to browse and filter the hierarchy of OSCNode instances that make up the OSC address space.  Most of the documented methods here are simply for querying basic properties of the OSCNode instance or doing simple message dispatch.
*/




@interface OSCNode : NSObject {
	id					addressSpace;	//	the class OSCAddressSpace is a subclass of OSCNode, and is essentially the "root" node.  all OSCNodes have a pointer to the root node!
	BOOL				deleted;
	
	OSSpinLock			nameLock;
	NSString			*nodeName;	///	"local" name: name of the node at /a/b/c is "c"
	NSString			*fullName;	///	"full" name: name of the node at /a/b/c is "/a/b/c"
	MutLockArray		*nodeContents;	///	Contains OSCNode instances- this OSCNode's sub-nodes.  type 'MutLockArray'- this should all be threadsafe...
	OSCNode				*parentNode;	//	my "parent" node (or nil).  NOT retained!
	OSCNodeType			nodeType;	///	What 'type' of node i am
	BOOL				hiddenInMenu;	//	NO by default. if YES, this node (and all its sub-nodes) will be omitted from menus!
	
	OSCMessage			*lastReceivedMessage;	///	The last message sent to this node is retained (the message is retained instead of the value because messages can have multiple values)
	OSSpinLock			lastReceivedMessageLock;
	MutNRLockArray		*delegateArray;	//	type 'MutNRLockArray'. contents are NOT retained! could be anything!
	
	BOOL				autoQueryReply;	//	NO by default. if YES and the queryDelegate is nil or doesn't respond to one of the delegate methods or returns nil from one of the delegate methods, the OSCNode will try to automatically respond to the query
	id <OSCNodeQueryDelegateProtocol>	queryDelegate;	//	nil by default, NOT retained; unlike "normal" delegates, an OSCNode has a single query delegate
}

//	only called by the address space to craft a formatted string for logging purposes
- (void) _logDescriptionToString:(NSMutableString *)s tabDepth:(int)d;

+ (id) createWithName:(NSString *)n;
- (id) initWithName:(NSString *)n;
- (id) init;
- (void) prepareToBeDeleted;

//	convenience method so nodes may be sorted by name
- (NSComparisonResult) nodeNameCompare:(OSCNode *)comp;

//	"local" add/remove/find methods for working with my node contents
- (void) addLocalNode:(OSCNode *)n;
- (void) addLocalNodes:(NSArray *)n;
- (void) removeLocalNode:(OSCNode *)n;	//	this just removes the passed node from my 'nodeContents' array- doesn't assume that the passed node will be released!
- (void) deleteLocalNode:(OSCNode *)n;	//	calls 'prepareToBeDeleted' on the passed node- call this is if you want to make sure that the passed node will stop sending delegate messages/etc!
- (void) removeFromAddressSpace;	//	tries to remove me from the OSCAddressSpace singleton by setting my fullName to nil

///	It's assumed that the passed name doesn't have any wildcards/regex.  If the receiver contains a node with the identical name as the passed string, the node will be returned.  This is not a "deep" search, it's restricted to the receiver's nodeContents array.
- (OSCNode *) findLocalNodeNamed:(NSString *)n;
///	Same as findLocalNodeNamed:, but if any of the interim nodes don't exist they will be created.
- (OSCNode *) findLocalNodeNamed:(NSString *)n createIfMissing:(BOOL)c;

///	Compares the names of all the receiver's sub-nodes to the passed POSIX regex string, returns an array with all the nodes whose nodeNames match the regex.  If there are no sub-nodes or none of the sub-nodes match the regex, returns nil.
- (NSMutableArray *) findLocalNodesMatchingPOSIXRegex:(NSString *)regex;
- (void) _addLocalNodesMatchingRegex:(NSString *)regex toMutArray:(NSMutableArray *)a;


///	Calls findNodeForAddress:createIfMissing:NO.
//	these find methods do NOT work with regex!  it is assumed that the passed string is NOT a regex algorithm!
- (OSCNode *) findNodeForAddress:(NSString *)p;
///	It's assumed that the passed address doesn't have any wildcards/regex (no checking is done).  The receiver tries to locate the node at the passed address (relative to the receiver).  If c is YES, any OSCNodes missing in the passed address are automatically created.  If they have sub-nodes, the auto-created nodes' types are set to OSCNodeDirectory; if not, the auto-created nodes' types are OSCNodeTypeUnknown
- (OSCNode *) findNodeForAddress:(NSString *)p createIfMissing:(BOOL)c;
- (OSCNode *) findNodeForAddressArray:(NSArray *)a;
- (OSCNode *) findNodeForAddressArray:(NSArray *)a createIfMissing:(BOOL)c;
//	these find methods work with regex!  path components may be regex strings- this returns all the nodes that match every component in the passed address/address array!
- (NSMutableArray *) findNodesMatchingAddress:(NSString *)a;
- (NSMutableArray *) findNodesMatchingAddressArray:(NSArray *)a;

//	a node's delegate is informed of received osc messages or name changes (OSCNodeDelegateProtocol)
//	NODE DELEGATES ARE __NOT__ RETAINED!
//	NODE DELEGATES __MUST__ REMOVE THEMSELVES FROM THE DELEGATE ARRAY!
- (void) addDelegate:(id)d;
- (void) removeDelegate:(id)d;
- (void) informDelegatesOfNameChange;
- (void) addDelegatesFromNode:(OSCNode *)n;

///	Sends the passed message to all of the node's delegates- it does NOT parse the address at all (it's assumed that the passed message's address points to this instance of OSCNode).  If the passed message is a query, this tries to assemble a reply (either from the queryDelegate or automatically if autoQueryReply is enabled) which is sent to the main address space.
- (void) dispatchMessage:(OSCMessage *)m;

@property (assign, readwrite) id addressSpace;
@property (assign, readwrite) NSString *nodeName;
- (void) _setNodeName:(NSString *)n;
@property (readonly) NSString *fullName;
@property (readonly) id nodeContents;
@property (assign, readwrite) OSCNode *parentNode;
@property (assign, readwrite) int nodeType;
@property (assign, readwrite) BOOL hiddenInMenu;
@property (readonly) OSCMessage *lastReceivedMessage;
@property (readonly) OSCValue *lastReceivedValue;
@property (readonly) id delegateArray;
//@property (readonly) id queryDelegateArray;
@property (assign,readwrite) BOOL autoQueryReply;
@property (assign,readwrite) id<OSCNodeQueryDelegateProtocol> queryDelegate;

@end

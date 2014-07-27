
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "OSCMessage.h"
#import <VVBasics/MutNRLockArray.h>
#import <VVBasics/VVBasicMacros.h>
#import <libkern/OSAtomic.h>



///	Delegates of OSCNode must respond to all three of these methods.
/**
\ingroup VVOSC
*/
@protocol OSCNodeDelegateProtocol
///	The receiver is passed the node which received the message as well as the received message.
- (void) node:(id)n receivedOSCMessage:(OSCMessage *)msg;
///	This method is called whenever the passed node's name or address path changes (if the node's parent's name changes, this method will get called).
- (void) nodeNameChanged:(id)node;
///	This method is called when the passed node is about to be deleted- if your delegate receives this method, it should immediately get rid of any references it has to the passed node
- (void) nodeDeleted:(id)node;
@end


///	An OSCNode's queryDelegate must respond to these methods, which are called when a query-type OSCMessage is dispatched to an OSCNode.
/**
\ingroup VVOSC
*/
@protocol OSCNodeQueryDelegate
///	The receiver should return an auto-released array of NSString instances corresponding to the sub-nodes in response to the query.
- (NSMutableArray *) namespaceArrayForNode:(id)n;
///	The receiver should return an auto-released NSString instance containing the documentation for the passed node.
- (NSString *) docStringForNode:(id)n;
///	The receiver should return an auto-released NSString instance containing the type signature for the passed node (the format of the messages you want the node to reply to).
- (NSString *) typeSignatureForNode:(id)n;
///	The receiver should return an auto-released OSCValue instance that best represents the current value of the passed node.
- (OSCValue *) currentValueForNode:(id)n;
///	The receiver should return an auto-released NSString instance describing the format of the values returned by the passed node.
- (NSString *) returnTypeStringForNode:(id)n;
@end




///	OSCNode describes a single destination for OSC addresses.  The OSC address space is made up of many different nodes.  This class is optional- it is not used for basic OSC message sending/receiving, and only gets used if you start working with OSCAddressSpace.
/*!
\ingroup VVOSC
The OSC specification describes a slash-delineated address space- as messages are received, they are dispatched to the described address.  An OSCNode represents a single unique destination in the OSC address space.  OSCNodes may have subnodes and have a non-retaining reference to their parent node (unless they're top-level, in which case their parent node is nil).  They retain a copy of the last message dispatched directly to this node for convenience.  OSCNodes pass the OSC messages they receive to your application via the node's delegates- an instance of OSCNode has zero or more delegates.  These delegates must support the OSCNodeDelegateProtocol, and the delegate should be removed from the node before the delegate is released.  Correspondingly, the node will inform all its delegates of its impending release so weak references to the node may be destroyed.

If you want to work with an instance of OSCNode, you need to acquire or work with it from the main OSCAddressSpace.  Do not just start creating OSCNode instances on your own; there's no point, they're only useful if they're part of an address space.  This documentation exists in case you want to explore the address space or get/set properties of an OSCNode.  The documentation only covers a fraction of the contents of the header files.

Generally speaking, it's a good idea for each instance of OSCNode to have a discrete type, as this makes it easier to browse and filter the hierarchy of OSCNode instances that make up the OSC address space.  Most of the documented methods here are simply for querying basic properties of the OSCNode instance or doing simple message dispatch.
*/
@interface OSCNode : NSObject {
	id					addressSpace;	//	the class OSCAddressSpace is a subclass of OSCNode, and is essentially the "root" node.  all OSCNodes have a pointer to the root node!
	BOOL				deleted;
	
	OSSpinLock			nameLock;
	NSString			*nodeName;	//	"local" name: name of the node at /a/b/c is "c"
	NSString			*fullName;	//	"full" name: name of the node at /a/b/c is "/a/b/c"
	MutLockArray		*nodeContents;	//	Contains OSCNode instances- this OSCNode's sub-nodes.  type 'MutLockArray'- this should all be threadsafe...
	OSCNode				*parentNode;	//	my "parent" node (or nil).  NOT retained!
	OSCNodeType			nodeType;	//	What 'type' of node i am
	BOOL				hiddenInMenu;	//	NO by default. if YES, this node (and all its sub-nodes) will be omitted from menus!
	
	OSCMessage			*lastReceivedMessage;	//	retained
	OSSpinLock			lastReceivedMessageLock;
	MutNRLockArray		*delegateArray;	//	type 'MutNRLockArray'. contents are NOT retained! could be anything!
	
	BOOL				autoQueryReply;	//	NO by default
	id <OSCNodeQueryDelegate>	queryDelegate;	//	NOT RETAINED
}

/*	only called by the address space to craft a formatted string for logging purposes	*/
- (void) _logDescriptionToString:(NSMutableString *)s tabDepth:(int)d;

//	Creates and returns an auto-released instance of OSCNode with the passed name.  Returns nil if passed a nil name.
+ (id) createWithName:(NSString *)n;
//	Inits an instance of OSCNode with the passed name.  Returns nil if passed a nil name.
- (id) initWithName:(NSString *)n;
- (id) init;

- (void) prepareToBeDeleted;

///	Convenience method so nodes may be sorted by name
- (NSComparisonResult) nodeNameCompare:(OSCNode *)comp;

//	Adds the passed node to my ndoe contents
- (void) addLocalNode:(OSCNode *)n;
//	Adds the passed nodes to my node contents
- (void) addLocalNodes:(NSArray *)n;
//	Call this to remove the passed node from my contents.  This method releases the passed node, but doesn't try to deactivate it!  If the node was only retained by the address space, this is equivalent to "deleteLocalNode:".
- (void) removeLocalNode:(OSCNode *)n;
//	Call this to remove the passed node from my contents.  This method releases the passed node and deactivates it (calls "prepareToBeDeleted" so it stops sending delegate methods/responding).
- (void) deleteLocalNode:(OSCNode *)n;
///	Call this to remove an instance of OSCNode from the address space
- (void) removeFromAddressSpace;

//	It's assumed that the passed name doesn't have any wildcards/regex.  If the receiver contains a node with the identical name as the passed string, the node will be returned.  This is not a "deep" search, it's restricted to the receiver's nodeContents array.
- (OSCNode *) findLocalNodeNamed:(NSString *)n;
//	Same as findLocalNodeNamed:, but if any of the interim nodes don't exist they will be created.
- (OSCNode *) findLocalNodeNamed:(NSString *)n createIfMissing:(BOOL)c;

//	Compares the names of all the receiver's sub-nodes to the passed POSIX regex string, returns an array with all the nodes whose nodeNames match the regex.  If there are no sub-nodes or none of the sub-nodes match the regex, returns nil.
- (NSMutableArray *) findLocalNodesMatchingPOSIXRegex:(NSString *)regex;
- (void) _addLocalNodesMatchingRegex:(NSString *)regex toMutArray:(NSMutableArray *)a;

//	these "findNode" methods DO NOT USE regex!  it is assumed that the passed string is NOT a regex algorithm (the language "findNode" implies a single result, precluding the use of regex)
- (OSCNode *) findNodeForAddress:(NSString *)p;
//	It's assumed that the passed address doesn't have any wildcards/regex (no checking is done).  The receiver tries to locate the node at the passed address (relative to the receiver).  If c is YES, any OSCNodes missing in the passed address are automatically created.  If they have sub-nodes, the auto-created nodes' types are set to OSCNodeDirectory; if not, the auto-created nodes' types are OSCNodeTypeUnknown
- (OSCNode *) findNodeForAddress:(NSString *)p createIfMissing:(BOOL)c;
- (OSCNode *) findNodeForAddressArray:(NSArray *)a;
- (OSCNode *) findNodeForAddressArray:(NSArray *)a createIfMissing:(BOOL)c;
//	THESE METHODS ALWAYS USE REGEX TO FIND MATCHES!  path components may be regex strings- this returns all the nodes that match every component in the passed address/address array!
- (NSMutableArray *) findNodesMatchingAddress:(NSString *)a;
- (NSMutableArray *) findNodesMatchingAddressArray:(NSArray *)a;

//	If you want to receive OSC messages and other info (OSCNodeDelegateProtocol) from an OSCNode, you need to be its delegate.
//	NODE DELEGATES ARE __NOT__ RETAINED!
//	NODE DELEGATES __MUST__ REMOVE THEMSELVES FROM THE DELEGATE ARRAY!
///	Adds the passed object to the receiving node's array of delegates- must conform to OSCNodeDelegateProtocol.
- (void) addDelegate:(id <OSCNodeDelegateProtocol>)d;
///	Removes the passed object from the receiving node's array of delegates.
- (void) removeDelegate:(id)d;
- (void) informDelegatesOfNameChange;
- (void) addDelegatesFromNode:(OSCNode *)n;

///	Sends the passed message to all of the node's delegates- it does NOT parse the address at all (it's assumed that the passed message's address points to this instance of OSCNode).  If the passed message is a query, this tries to assemble a reply (either from the queryDelegate or automatically if autoQueryReply is enabled) which is sent to the main address space.
- (void) dispatchMessage:(OSCMessage *)m;

///	Generates a default reply for a query of the passed type.  if "autoQueryReply" is enabled, this is how the reply is generated- this is a discrete method so query delegates can quickly generate query replies without having to implement reply methods in every query delegate class!
- (OSCMessage *) generateAutomaticResponseForQuery:(OSCMessage *)m;

@property (assign, readwrite) id addressSpace;
///	Sets or gets the node's local name.  The node "/A/B/C" would return "C".
@property (assign, readwrite) NSString *nodeName;
- (void) _setNodeName:(NSString *)n;
///	Sets or gets the node's full address.  The node "/A/B/C" would return "/A/B/C"
@property (readonly) NSString *fullName;
///	Read-only, returns nil or a threadsafe array of OSCNode instances "inside" me.
@property (readonly) MutLockArray *nodeContents;
@property (assign, readwrite) OSCNode *parentNode;
///	Nodes can have a basic "type", which is useful for sorting and organization
@property (assign, readwrite) OSCNodeType nodeType;
@property (assign, readwrite) BOOL hiddenInMenu;
///	The last message sent to this node is retained (the message is retained instead of the value because messages can have multiple values)
@property (readonly) OSCMessage *lastReceivedMessage;
///	Convenience method for returning the first value from the last received message
@property (readonly) OSCValue *lastReceivedValue;
@property (readonly) id delegateArray;
///	Only used for the OSC query protocol.  NO by default. if YES and the queryDelegate is nil or doesn't respond to one of the delegate methods or returns nil from one of the delegate methods, the OSCNode will try to automatically respond to the query
@property (assign,readwrite) BOOL autoQueryReply;
///	Only used for the OSC query protocol.  nil by default, NOT retained, must respond to the OSCNodeQueryDelegate protocol; unlike "normal" delegates, an OSCNode has a single query delegate...
@property (assign,readwrite) id<OSCNodeQueryDelegate> queryDelegate;

@end

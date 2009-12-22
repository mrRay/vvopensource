
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "OSCMessage.h"
#import <VVBasics/MutNRLockArray.h>
#import <VVBasics/VVBasicMacros.h>




typedef enum	{
	OSCNodeTypeUnknown,
	OSCNodeDirectory,
	OSCNodeTypeFloat,
	OSCNodeType2DPoint,
	OSCNodeType3DPoint,
	OSCNodeTypeRect,
	OSCNodeTypeColor,
	OSCNodeTypeString,
} OSCNodeType;




@protocol OSCNodeDelegateProtocol
- (void) receivedOSCMessage:(id)msg;
- (void) nodeNameChanged:(id)node;
- (void) nodeDeleted;
@end




@interface OSCNode : NSObject {
	id					addressSpace;	//	the class OSCAddressSpace is a subclass of OSCNode, and is essentially the "root" node.  all OSCNodes have a pointer to the root node!
	BOOL				deleted;
	
	NSString			*nodeName;	//	"local" name: name of the node at /a/b/c is "c"
	NSString			*fullName;	//	"full" name: name of the node at /a/b/c is "/a/b/c"
	MutLockArray		*nodeContents;	//	type 'MutLockArray'
	OSCNode				*parentNode;	//	NOT retained!
	int					nodeType;	//	what 'type' of node i am
	
	OSCMessage			*lastReceivedMessage;	//	store the msg instead of the val because msgs can have multiple vals
	MutNRLockArray		*delegateArray;	//	type 'MutNRLockArray'. contents are NOT retained! could be anything!
}

//	only called by the address space to craft a formatted string for logging purposes
- (void) logDescriptionToString:(NSMutableString *)s tabDepth:(int)d;

+ (id) createWithName:(NSString *)n;
- (id) initWithName:(NSString *)n;
- (id) init;

//	convenience method so nodes may be sorted by name
- (NSComparisonResult) nodeNameCompare:(OSCNode *)comp;

//	"local" add/remove/find methods for working with my node contents
- (void) addNode:(OSCNode *)n;
- (void) removeNode:(OSCNode *)n;
- (OSCNode *) localNodeAtIndex:(int)i;
- (OSCNode *) findLocalNodeNamed:(NSString *)n;
- (OSCNode *) findLocalNodeNamed:(NSString *)n createIfMissing:(BOOL)c;

- (OSCNode *) findNodeForAddress:(NSString *)p;
- (OSCNode *) findNodeForAddress:(NSString *)p createIfMissing:(BOOL)c;

- (OSCNode *) findNodeForAddressArray:(NSArray *)a;
- (OSCNode *) findNodeForAddressArray:(NSArray *)a createIfMissing:(BOOL)c;

//	a node's delegate is informed of received osc messages or name changes (OSCNodeDelegateProtocol)
//	NODE DELEGATES ARE __NOT__ RETAINED!
//	NODE DELEGATES __MUST__ REMOVE THEMSELVES FROM THE DELEGATE ARRAY!
- (void) addDelegate:(id)d;
- (void) removeDelegate:(id)d;
- (void) informDelegatesOfNameChange;
- (void) addDelegatesFromNode:(OSCNode *)n;

//	simply sends the passed message to all my delegates
- (void) dispatchMessage:(OSCMessage *)m;

@property (assign, readwrite) id addressSpace;
@property (assign, readwrite) NSString *nodeName;
@property (readonly) NSString *fullName;
@property (readonly) id nodeContents;
@property (assign, readwrite) OSCNode *parentNode;
@property (assign, readwrite) int nodeType;
@property (readonly) OSCMessage *lastReceivedMessage;
@property (readonly) id delegateArray;

@end


#import <Cocoa/Cocoa.h>
#import <CoreMIDI/CoreMIDI.h>
//#import "VVMIDI.h"
#import <pthread.h>
#import "VVMIDINode.h"




@protocol VVMIDIDelegateProtocol
- (void) setupChanged;
- (void) receivedMIDI:(NSArray *)a;
@end




@interface VVMIDIManager : NSObject <VVMIDIDelegateProtocol> {
	NSMutableArray		*sourceArray;		//	array of VVMIDINode objects (sources i can receive from)
	NSMutableArray		*destArray;			//	array of VVMIDINode objects (destinations i can send to)
	pthread_mutex_t		arrayLock;			//	used to lock BOTH arrays
	
	VVMIDINode			*virtualSource;	//	a dedicated receiver other apps can send to
	VVMIDINode			*virtualDest;		//	a dedicated source other apps can receive from
	
	id					delegate;
}

- (void) generalInit;

- (void) loadMIDIInputSources;
- (void) loadMIDIOutputDestinations;
- (void) createVirtualNodes;	//	subclass around this to create a virtual destination with a different name

- (void) setupChanged;	//	called when a midi device is plugged in or unplugged
- (void) receivedMIDI:(NSArray *)a;	//	called when one of my sources has midi data to hand off to me

- (void) sendMsg:(VVMIDIMessage *)m;
- (void) sendMsgs:(NSArray *)a;

- (VVMIDINode *) findDestNodeNamed:(NSString *)n;	//	finds a destination node with a given name
- (VVMIDINode *) findSourceNodeNamed:(NSString *)n;	//	finds a source node with a given name

//	Generates and returns an array of strings which correspond to the labels of this manager's out ports
- (NSArray *) destNodeNameArray;

//	these methods exist so subclasses of me can override them to use custom subclasses of VVMIDINode
- (id) receivingNodeClass;
- (id) sendingNodeClass;
//	these methods exist so subclasses of me can override them to change the name of the default midi destinations/receivers
- (NSString *) receivingNodeName;
- (NSString *) sendingNodeName;

- (NSArray *) sourceArray;
- (NSArray *) destArray;
- (VVMIDINode *) virtualSource;
- (VVMIDINode *) virtualDest;
- (id) delegate;
- (void) setDelegate:(id)n;

@end

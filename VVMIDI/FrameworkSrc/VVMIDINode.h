
#import <Cocoa/Cocoa.h>
#import <CoreMIDI/CoreMIDI.h>
#import "VVMIDIMessage.h"




@interface VVMIDINode : NSObject {
	MIDIEndpointRef			endpointRef;	//	the endpoint for this particular node
	NSMutableDictionary		*properties;	//	dict or source properties (just for the hell of it)
	MIDIClientRef			clientRef;		//	the client receives the data
	MIDIPortRef				portRef;		//	the port is owned by the client, and connects it to the endpoint
	NSString				*name;
	id						delegate;		//	the delegate will be passed any data i receive
	BOOL					sender;			//	if it's a midi-sending endpoint, this will be YES
	BOOL					virtualSender;	//	whether or not the sender is locally owned
	//	make sure processing sysex can happen across multiple iterations of the callback loop
	BOOL					processingSysex;
	int						processingSysexIterationCount;
	NSMutableArray			*sysexArray;
	//	the node will always *process* midi, but it will only send/receive midi if 'enabled' is YES
	BOOL					enabled;
	
	//	this mutex makes sure multiple threads sending to this node simultaneously don't collid
	pthread_mutex_t			sendingLock;
	
	//	if i'm a sender, these variables are used to store a packet list
	MIDIPacketList			*packetList;
	MIDIPacket				*currentPacket;
	Byte					scratchStruct[4];
}

- (id) initReceiverWithEndpoint:(MIDIEndpointRef)e;
- (id) initReceiverWithName:(NSString *)n;
- (id) initSenderWithEndpoint:(MIDIEndpointRef)e;
- (id) initSenderWithName:(NSString *)n;

- (id) commonInit;

- (void) loadProperties;
- (void) receivedMIDI:(NSArray *)a;
- (void) setupChanged;

- (void) sendMsg:(VVMIDIMessage *)m;
- (void) sendMsgs:(NSArray *)a;

- (BOOL) sender;
- (BOOL) receiver;

- (NSString *) name;
- (id) delegate;
- (void) setDelegate:(id)n;
- (BOOL) processingSysex;
- (void) setProcessingSysex:(BOOL)n;
- (int) processingSysexIterationCount;
- (void) setProcessingSysexIterationCount:(int)n;
- (NSMutableArray *) sysexArray;
- (BOOL) enabled;
- (void) setEnabled:(BOOL)n;

@end

void myMIDIReadProc(const MIDIPacketList *pktList, void *readProcRefCon, void *srcConnRefCon);
void myMIDINotificationProc(const MIDINotification *msg, void *refCon);
void senderReadProc(const MIDIPacketList *pktList, void *readProcRefCon, void *srcConnRefCon);
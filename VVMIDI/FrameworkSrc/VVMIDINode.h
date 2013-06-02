
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
	NSMutableArray			*sysexArray;	//	received sysex data is added to this array.  array is instance in node because a sysex dump may be split up across several MIDI packets, so we need something persistent...
	//	the node will always *process* midi, but it will only send/receive midi if 'enabled' is YES
	BOOL					enabled;
	
	int						twoPieceCCVals[16][64];	//	midi CCs 0-31 are the MSBs ("coarse") of values, and CCs 32-64 are the LSBs ("fine"). in order to reconstruct the full 32-bit value from either received piece, i need to store both "pieces" of it (for each channel).  all the LSBs are set to -1 until an actual value is received: if the LSBs aren't being used, then the math changes subtly (7-bit 127 as 1.0 vs 7-bit MSB not being 1.0)
	
	Byte					*partialMTCQuarterFrameSMPTE;	//	simple 5 Byte array. fps mode (0=24, 1=25, 2=30-drop, 3=30), hours, minutes, seconds, frames.
	Byte					*cachedMTCQuarterFrameSMPTE;	//	same as above- every 4 quarter-frames, the partialMTCQuarterFrameSMPTE gets pushed here!
	//	this mutex makes sure multiple threads sending to this node simultaneously don't collide
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

- (MIDIEndpointRef) endpointRef;
- (NSMutableDictionary *) properties;
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
//	pass it an array of 5 Bytes!
- (void) _getPartialMTCSMPTEArray:(Byte *)array;
- (void) _setPartialMTCSMPTEArray:(Byte *)array;
- (void) _pushPartialMTCSMPTEArrayToCachedVal;
- (void) _getValsForCC:(int)cc channel:(int)c toMSB:(int *)msb LSB:(int *)lsb;
- (void) _setValsForCC:(int)cc channel:(int)c fromMSB:(int)msb LSB:(int)lsb;
- (double) MTCQuarterFrameSMPTEAsDouble;

@end

double MTCSMPTEByteArrayToSeconds(Byte *byteArray);
void myMIDIReadProc(const MIDIPacketList *pktList, void *readProcRefCon, void *srcConnRefCon);
void myMIDINotificationProc(const MIDINotification *msg, void *refCon);
void senderReadProc(const MIDIPacketList *pktList, void *readProcRefCon, void *srcConnRefCon);
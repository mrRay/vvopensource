
#import "VVMIDINode.h"
#import "VVMIDI.h"




@implementation VVMIDINode


- (NSString *) description	{
	return [NSString stringWithFormat:@"<VVMIDINode: %@>",name];
}

- (id) initReceiverWithEndpoint:(MIDIEndpointRef)e	{
	if (e == NULL)	{
		[self release];
		return nil;
	}
	
	OSStatus				err;
	
	self = [self commonInit];
	//	store a reference to the passed endpoint
	endpointRef = e;
	//	load the properties for the endpoint
	[self loadProperties];
	//	create MIDIClientRef- this will receive the incoming midi data
	err = MIDIClientCreate((CFStringRef)@"clientName", NULL, NULL, &clientRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIClientCreate() A",err);
		[self release];
		return nil;
	}
	//	create a MIDIInputPort- the client owns the port
	err = MIDIInputPortCreate(clientRef,(CFStringRef)@"portName",myMIDIReadProc,self,&portRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIInputPortCreate() A",err);
		[self release];
		return nil;
	}
	//	connect the MIDIInputPort to the endpoint (the port connects the client to the source)
	err = MIDIPortConnectSource(portRef,endpointRef,NULL);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIPortConnectSource() A",err);
		[self release];
		return nil;
	}
	
	return self;
}
- (id) initReceiverWithName:(NSString *)n	{
	if (n == nil)	{
		[self release];
		return nil;
	}
	
	OSStatus			err;
	
	self = [self commonInit];
	name = [n copy];
	//	create a midi client which will receive incoming midi data
	err = MIDIClientCreate((CFStringRef)@"clientName",myMIDINotificationProc,self,&clientRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIClientCreate B",err);
		[self release];
		return nil;
	}
	//	make a new destination, attach it to the client
	err = MIDIDestinationCreate(clientRef,(CFStringRef)n,myMIDIReadProc,self,&endpointRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIDestinationCreate() A",err);
		[self release];
		return nil;
	}
	//	create a MIDIInputPort- the client owns the port
	err = MIDIInputPortCreate(clientRef,(CFStringRef)n,myMIDIReadProc,self,&portRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIInputPortCreate B",err);
		[self release];
		return nil;
	}
	
	return self;
}
- (id) initSenderWithEndpoint:(MIDIEndpointRef)e	{
	if (e == NULL)	{
		[self release];
		return NULL;
	}
	
	OSStatus			err;
	
	self = [self commonInit];
	//	store a reference to the passed endpoint
	endpointRef = e;
	//	load the properties for the endpoint
	[self loadProperties];
	//	create a MIDIClientRef- this will handle the midi data
	err = MIDIClientCreate((CFStringRef)@"clientName",NULL,NULL,&clientRef);
	if (err != noErr)	{
		NSLog(@"\t\terr %ld at MIDIClientCreate C",err);
		[self release];
		return nil;
	}
	//	create a MIDIOutputPort- the client owns the port
	err = MIDIOutputPortCreate(clientRef,(CFStringRef)@"portName",&portRef);
	if (err != noErr)	{
		NSLog(@"\t\terr %ld at MIDIOutputPortCreate A",err);
		[self release];
		return nil;
	}
	
	//	set the 'sender' flag
	sender = YES;
	
	//	set up the packet list related resources
	packetList = (MIDIPacketList *) malloc(1024*sizeof(char));
	currentPacket = MIDIPacketListInit(packetList);
	
	return self;
}
- (id) initSenderWithName:(NSString *)n	{
	if (n == nil)	{
		[self release];
		return nil;
	}
	
	OSStatus			err;
	
	self = [self commonInit];
	name = [n copy];
	//	create a midi client which will receive midi data to work with
	err = MIDIClientCreate((CFStringRef)n,NULL,NULL,&clientRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIClientCreate D",err);
		[self release];
		return nil;
	}
	//	make a new destination, so other apps know i'm here
	err = MIDISourceCreate(clientRef,(CFStringRef)n,&endpointRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDISourceCreate A",err);
		[self release];
		return nil;
	}
	//	create a MIDIOutputPort- the client owns the port
	err = MIDIOutputPortCreate(clientRef,(CFStringRef)n,&portRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIOutputPortCreate B",err);
		[self release];
		return nil;
	}
	
	//	set the 'sender' flag
	sender = YES;
	virtualSender = YES;
	
	//	set up the packet list related resources
	packetList = (MIDIPacketList *) malloc(1024*sizeof(char));
	currentPacket = MIDIPacketListInit(packetList);
	
	return self;
}

- (id) commonInit	{
	
	pthread_mutexattr_t		attr;
	
	
	
	self = [super init];
	//	load up some null values so if anything goes wrong, i can know about it
	endpointRef = NULL;
	properties = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	clientRef = NULL;
	portRef = NULL;
	name = nil;
	delegate = nil;
	sender = NO;
	virtualSender = NO;
	processingSysex = NO;
	processingSysexIterationCount = 0;
	sysexArray = [[NSMutableArray arrayWithCapacity:0] retain];
	enabled = YES;
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr,PTHREAD_MUTEX_NORMAL);
	pthread_mutex_init(&sendingLock,&attr);
	packetList = NULL;
	currentPacket = NULL;
	return self;
}

- (void) dealloc	{
	if (properties != nil)	{
		[properties release];
		properties = nil;
	}
	
	if (clientRef != NULL)	{
		MIDIClientDispose(clientRef);
		clientRef = NULL;
	}
	
	if (name != nil)	{
		[name release];
		name = nil;
	}
	
	if (sysexArray != nil)	{
		[sysexArray release];
		sysexArray = nil;
	}
	
	if (packetList != NULL)	{
		free(packetList);
		packetList = NULL;
	}
	currentPacket = NULL;
	pthread_mutex_destroy(&sendingLock);
	
	[super dealloc];
}

- (void) loadProperties	{
	OSStatus		err = noErr;
	CFStringRef		localName;
	SInt32			uniqueID;
	//CFDataRef		uids;
	
	//	make sure there's a "properties" dict, and that it's empty
	if (properties == nil)
		properties = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	else
		[properties removeAllObjects];
	//	get the midi source name
	err = MIDIObjectGetStringProperty(endpointRef, kMIDIPropertyName, &localName);
	if (err != noErr)
		NSLog(@"\t\terror %ld at MIDIObjectGetStringProperty()",err);
	else	{
		if (localName != NULL)	{
			name = [[NSString stringWithString:(NSString *)localName] retain];
			[properties setValue:name forKey:@"name"];
		}
	}
	//	get the midi unique identifier
	err = MIDIObjectGetIntegerProperty(endpointRef,kMIDIPropertyUniqueID, &uniqueID);
	if (err != noErr)
		NSLog(@"\t\terror %ld at MIDIObjectGetIntegerProperty()",err);
	else
		[properties setValue:[NSNumber numberWithLong:uniqueID] forKey:@"uniqueID"];
	//NSLog(@"\t\t%@",properties);
}

/*
	this method is where the midi callback sends me an array of parsed messages- feel free
	to subclass around this to get the desired behavior
*/
- (void) receivedMIDI:(NSArray *)a	{
	//NSLog(@"VVMIDINode:processMIDIMessageArray: ... %@",name);
	//NSLog(@"\t\t%@",a);
	if ((enabled == YES)&&(delegate != nil)&&([delegate respondsToSelector:@selector(receivedMIDI:)]))
		[delegate receivedMIDI:a];
}
/*
	this method is called whenever the midi setup is changed
*/
- (void) setupChanged	{
	if ((delegate != nil) && ([delegate respondsToSelector:@selector(setupChanged)]))
		[delegate setupChanged];
}

- (void) sendMsg:(VVMIDIMessage *)m	{
	if ((enabled!=YES) || (sender!=YES) || (m==nil))
		return;
	//NSLog(@"\t\tsending %@ to %@",m,name);
	
	MIDIPacket		*newPacket = nil;
	OSStatus		err = noErr;
	
	//	lock so threads sending midi data don't collide
	pthread_mutex_lock(&sendingLock);
	
	if ([m type] == VVMIDIBeginSysexDumpVal)	{
		NSArray			*msgSysexArray = [m sysexArray];
		NSEnumerator	*it = [msgSysexArray objectEnumerator];
		NSNumber		*numPtr = nil;
		Byte			*bufferPtr;
		Byte			*bytePtr;
		
		bufferPtr = (Byte *)calloc([msgSysexArray count]+2, sizeof(Byte));
		bytePtr = bufferPtr;
		//	write that sysex start byte
		*bytePtr = 0xF0;
		++bytePtr;
		//	run through array of NSNumbers, fill buffer with their contents
		while (numPtr = [it nextObject])	{
			*bytePtr = [numPtr unsignedCharValue];
			++bytePtr;
		}
		//	write the sysex stop byte
		*bytePtr = 0xF7;
		/*
		//	just dump the contents of the buffer i'm about to send- for debugging...
		for (int i=0;i<[msgSysexArray count]+2;++i)	{
			NSLog(@"\t%X",bufferPtr[i]);
		}
		*/
		newPacket = MIDIPacketListAdd(packetList,1024,currentPacket,0,[msgSysexArray count]+2,bufferPtr);
		free(bufferPtr);
		if (newPacket == NULL)	{
			NSLog(@"\terr adding new sysex packet");
			goto BAIL;
		}
	}
	else	{
		scratchStruct[0] = [m type] | [m channel];
		scratchStruct[1] = [m data1];
		scratchStruct[2] = [m data2];
		
		newPacket = MIDIPacketListAdd(packetList,1024,currentPacket,0,3,scratchStruct);
		if (newPacket == NULL)	{
			NSLog(@"\t\terror adding new packet");
			goto BAIL;
		}
	}
	
	currentPacket = newPacket;
	
	//	if this is a virtual sender, this node "owns" the source- i need to call 'MIDIReceived'
	if (virtualSender)	{
		err = MIDIReceived(endpointRef,packetList);
		if (err != noErr)	{
			NSLog(@"\t\terr %ld at MIDIReceived A",err);
		}
	}
	//	if this isn't a virtual sender, something else is managing the source- call 'MIDISend'
	else	{
		err = MIDISend(portRef,endpointRef,packetList);
		if (err != noErr)	{
			NSLog(@"\t\terr %ld at MIDISend A",err);
			goto BAIL;
		}
	}
	
	currentPacket = MIDIPacketListInit(packetList);
	
	BAIL:
	
	pthread_mutex_unlock(&sendingLock);
}
- (void) sendMsgs:(NSArray *)a	{
	//NSLog(@"VVMIDINode:sendMsgs:");
	if ((enabled!=YES) || (sender!=YES) || (a==nil) || ([a count]<1))
		return;
	//NSLog(@"\t\tsending to %@",name);
	
	MIDIPacket		*newPacket = nil;
	OSStatus		err = noErr;
	NSEnumerator	*it = [a objectEnumerator];
	VVMIDIMessage	*msgPtr;
	
	while (msgPtr = [it nextObject])	{
		scratchStruct[0] = [msgPtr type] | [msgPtr channel];
		scratchStruct[1] = [msgPtr data1];
		scratchStruct[2] = [msgPtr data2];
		
		newPacket = MIDIPacketListAdd(packetList,1024,currentPacket,0,3,scratchStruct);
		if (newPacket == NULL)	{
			NSLog(@"\t\terror adding new packet");
			return;
		}
		currentPacket = newPacket;
	}
	
	//	if this is a virtual sender, this node "owns" the source- i need to call 'MIDIReceived'
	if (virtualSender)	{
		err = MIDIReceived(endpointRef,packetList);
		if (err != noErr)	{
			NSLog(@"\t\terr %ld at MIDIReceived A",err);
		}
	}
	//	if this isn't a virtual sender, something else is managing the source- call 'MIDISend'
	else	{
		err = MIDISend(portRef,endpointRef,packetList);
		if (err != noErr)	{
			NSLog(@"\t\terr %ld at MIDISend A",err);
			return;
		}
	}
	
	currentPacket = MIDIPacketListInit(packetList);
}

- (BOOL) sender	{
	return sender;
}
- (BOOL) receiver	{
	return !sender;
}


- (NSString *) name	{
	return name;
}
- (id) delegate	{
	return delegate;
}
- (void) setDelegate:(id)n	{
	delegate = n;
}
- (BOOL) processingSysex	{
	return processingSysex;
}
- (void) setProcessingSysex:(BOOL)n	{
	processingSysex = n;
}
- (int) processingSysexIterationCount	{
	return processingSysexIterationCount;
}
- (void) setProcessingSysexIterationCount:(int)n	{
	processingSysexIterationCount = n;
}
- (NSMutableArray *) sysexArray	{
	return sysexArray;
}
- (BOOL) enabled	{
	return enabled;
}
- (void) setEnabled:(BOOL)n	{
	enabled = n;
}


@end


void myMIDIReadProc(const MIDIPacketList *pktList, void *readProcRefCon, void *srcConnRefCon)	{
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	MIDIPacket				*packet = nil;
	int						i;
	int						currByte;
	int						j;
	int						msgElementCount;
	VVMIDIMessage			*newMsg = nil;
	BOOL					processingSysex = [(VVMIDINode *)readProcRefCon processingSysex];
	int						processingSysexIterationCount = [(VVMIDINode *)readProcRefCon processingSysexIterationCount];
	NSMutableArray			*sysex = [(VVMIDINode *)readProcRefCon sysexArray];
	NSMutableArray			*msgs = [NSMutableArray arrayWithCapacity:0];
	
	//	first of all, if i'm processing sysex, bump the iteration count
	if (processingSysex)
		++processingSysexIterationCount;
	//	if the sysex iteration count is > 128, turn sysex off automatically (make sure a dropped packet won't result in a non-responsive midi proc)
	if (processingSysexIterationCount > 128)	{
		processingSysexIterationCount = 0;
		processingSysex = NO;
	}
	
	
	//	run through all the packets in the passed list of packets
	packet = (MIDIPacket *)&pktList->packet[0];
	for (i=0; i<pktList->numPackets; ++i)	{
		//	run through the packet...
		for (j=0; j<packet->length; ++j)	{
			currByte = packet->data[j];
			//	check to see what kind of byte it is
			//	if it's in the range 0x80 - 0xFF, it's a status byte- the first byte of a message
			if ((currByte >= 0x80) && (currByte <= 0xFF))	{
				//	what kind of status byte is it?
				switch(currByte & 0xF0)	{
					case VVMIDINoteOffVal:
					case VVMIDINoteOnVal:
					case VVMIDIAfterTouchVal:
					case VVMIDIControlChangeVal:
					case VVMIDIProgramChangeVal:
					case VVMIDIChannelPressureVal:
					case VVMIDIPitchWheelVal:
						newMsg = [VVMIDIMessage createWithType:(currByte & 0xF0) channel:(currByte & 0x0F)];
						if (newMsg == nil)	{
							break;
						}
						[msgs addObject:newMsg];
						msgElementCount = 0;
						break;
					default:		//	the default means that i've run up against either a common or realtime message
						switch (currByte)	{
							//	common messages- insert leisurely
							case VVMIDIMTCQuarterFrameVal:
							case VVMIDISongPosPointerVal:
							case VVMIDISongSelectVal:
							case VVMIDIUndefinedCommon1Val:
							case VVMIDIUndefinedCommon2Val:
							case VVMIDITuneRequestVal:
								newMsg = [VVMIDIMessage createWithType:currByte channel:0x00];
								[msgs addObject:newMsg];
								msgElementCount = 0;
								break;
							case VVMIDIEndSysexDumpVal:
								//NSLog(@"\t\tVVMIDIEndSysexDumpVal - %X",currByte);
								processingSysex = NO;
								processingSysexIterationCount = 0;
								//[sysex addObject:[NSNumber numberWithInt:currByte]];
								newMsg = [VVMIDIMessage createWithSysexArray:sysex];
								[msgs addObject:newMsg];
								break;
							case VVMIDIBeginSysexDumpVal:
								//NSLog(@"\t\tVVMIDIBeginSysexDumpVal - %X",currByte);
								processingSysex = YES;
								processingSysexIterationCount = 0;
								[sysex removeAllObjects];
								//[sysex addObject:[NSNumber numberWithInt:currByte]];
								break;
							//	realtime messages- insert these immediately
							case VVMIDIClockVal:
							case VVMIDITickVal:
							case VVMIDIStartVal:
							case VVMIDIContinueVal:
							case VVMIDIStopVal:
							case VVMIDIUndefinedRealtime1Val:
							case VVMIDIActiveSenseVal:
							case VVMIDIResetVal:
								[msgs addObject:[VVMIDIMessage createWithType:currByte channel:0x00]];
								break;
							default:	//	no idea what the default would be...
								break;
						}
						break;
				}
			}
			//	if the byte's in the range 0x00 - 0x7F, it's got some kind of data in it
			if ((currByte >= 0x00) && (currByte <= 0x7F))	{
				//	i'm only going to process this data if i'm not in the midst of a sysex dump and i'm assembling a message
				if (processingSysex)	{
					[sysex addObject:[NSNumber numberWithInt:currByte]];
				}
				else	{
					if (newMsg != nil)	{
						switch(msgElementCount)	{
							case 0:
								[newMsg setData1:currByte];
								++msgElementCount;
								break;
							case 1:
								[newMsg setData2:currByte];
								if (([newMsg type] == VVMIDINoteOnVal) && (currByte == 0x00))
									[newMsg setType:VVMIDINoteOffVal];
								++msgElementCount;
								break;
						}
					}
				}
			}
		}
		
		//	get the next packet
		packet = MIDIPacketNext(packet);
	}
	
	//	update the sysex-related flags in the actual VVMIDINode object
	[(VVMIDINode *)readProcRefCon setProcessingSysex:processingSysex];
	[(VVMIDINode *)readProcRefCon setProcessingSysexIterationCount:processingSysexIterationCount];
	
	//	hand the array of messages to the actual VVMIDINode object
	if ((msgs != nil) && ([msgs count] > 0))
		[(VVMIDINode *)readProcRefCon receivedMIDI:msgs];
	
	[pool release];
	//NSLog(@"\t\tmyMIDIReadProc - FINISHED");
}

void myMIDINotificationProc(const MIDINotification *msg, void *refCon)	{
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	
	//	multiple messages may get sent out for a single action, so it makes sense to simply ignore everything but 'kMIDIMsgSetupChanged'
	if (msg->messageID == kMIDIMsgSetupChanged)
		[(VVMIDINode *)refCon setupChanged];
	
	[pool release];
}

void senderReadProc(const MIDIPacketList *pktList, void *readProcRefCon, void *srcConnRefCon)	{
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	NSLog(@"VVMIDINode:senderReadProc:");
	[pool release];
}

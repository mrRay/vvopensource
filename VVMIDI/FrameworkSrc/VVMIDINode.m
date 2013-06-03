
#import "VVMIDINode.h"
#import "VVMIDI.h"




@implementation VVMIDINode


- (NSString *) description	{
	return [NSString stringWithFormat:@"<VVMIDINode: %@>",name];
}

- (id) initReceiverWithEndpoint:(MIDIEndpointRef)e	{
	if (!e)	{
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
		NSLog(@"\t\terror %ld at MIDIClientCreate() A",(long)err);
		[self release];
		return nil;
	}
	//	create a MIDIInputPort- the client owns the port
	err = MIDIInputPortCreate(clientRef,(CFStringRef)@"portName",myMIDIReadProc,self,&portRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIInputPortCreate() A",(long)err);
		[self release];
		return nil;
	}
	//	connect the MIDIInputPort to the endpoint (the port connects the client to the source)
	err = MIDIPortConnectSource(portRef,endpointRef,NULL);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIPortConnectSource() A",(long)err);
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
		NSLog(@"\t\terror %ld at MIDIClientCreate B",(long)err);
		[self release];
		return nil;
	}
	//	make a new destination, attach it to the client
	err = MIDIDestinationCreate(clientRef,(CFStringRef)n,myMIDIReadProc,self,&endpointRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIDestinationCreate() A",(long)err);
		[self release];
		return nil;
	}
	//	create a MIDIInputPort- the client owns the port
	err = MIDIInputPortCreate(clientRef,(CFStringRef)n,myMIDIReadProc,self,&portRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIInputPortCreate B",(long)err);
		[self release];
		return nil;
	}
	
	return self;
}
- (id) initSenderWithEndpoint:(MIDIEndpointRef)e	{
	if (!e)	{
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
		NSLog(@"\t\terr %ld at MIDIClientCreate C",(long)err);
		[self release];
		return nil;
	}
	//	create a MIDIOutputPort- the client owns the port
	err = MIDIOutputPortCreate(clientRef,(CFStringRef)@"portName",&portRef);
	if (err != noErr)	{
		NSLog(@"\t\terr %ld at MIDIOutputPortCreate A",(long)err);
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
		NSLog(@"\t\terror %ld at MIDIClientCreate D",(long)err);
		[self release];
		return nil;
	}
	//	make a new destination, so other apps know i'm here
	err = MIDISourceCreate(clientRef,(CFStringRef)n,&endpointRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDISourceCreate A",(long)err);
		[self release];
		return nil;
	}
	//	create a MIDIOutputPort- the client owns the port
	err = MIDIOutputPortCreate(clientRef,(CFStringRef)n,&portRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIOutputPortCreate B",(long)err);
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
	endpointRef = 0;
	properties = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	clientRef = 0;
	portRef = 0;
	name = nil;
	delegate = nil;
	sender = NO;
	virtualSender = NO;
	processingSysex = NO;
	processingSysexIterationCount = 0;
	sysexArray = [[NSMutableArray arrayWithCapacity:0] retain];
	enabled = YES;
	partialMTCQuarterFrameSMPTE = malloc(sizeof(Byte)*5);
	cachedMTCQuarterFrameSMPTE = malloc(sizeof(Byte)*5);
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr,PTHREAD_MUTEX_NORMAL);
	pthread_mutex_init(&sendingLock,&attr);
	pthread_mutexattr_destroy(&attr);
	for (int i=0; i<5; ++i)	{
		partialMTCQuarterFrameSMPTE[i] = 0;
		cachedMTCQuarterFrameSMPTE[i] = 0;
	}
	packetList = NULL;
	currentPacket = NULL;
	
	for (int c=0;c<16;++c)	{
		for (int cc=0;cc<32;++cc)
			twoPieceCCVals[c][cc] = 0;
		for (int cc=32;cc<64;++cc)
			twoPieceCCVals[c][cc] = -1;
	}
	
	return self;
}

- (void) dealloc	{
	if (properties != nil)	{
		[properties release];
		properties = nil;
	}
	
	if (clientRef)	{
		MIDIClientDispose(clientRef);
		clientRef = 0;
	}
	
	if (name != nil)	{
		[name release];
		name = nil;
	}
	
	if (sysexArray != nil)	{
		[sysexArray release];
		sysexArray = nil;
	}
	
	if (partialMTCQuarterFrameSMPTE != nil)	{
		free(partialMTCQuarterFrameSMPTE);
		partialMTCQuarterFrameSMPTE = nil;
	}
	
	if (cachedMTCQuarterFrameSMPTE != nil)	{
		free(cachedMTCQuarterFrameSMPTE);
		cachedMTCQuarterFrameSMPTE = nil;
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
	CFStringRef		tmpString;
	SInt32			tmpInt;
	//CFDataRef		uids;
	
	//	make sure there's a "properties" dict, and that it's empty
	if (properties == nil)
		properties = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	else
		[properties removeAllObjects];
	//	get the midi source name
	err = MIDIObjectGetStringProperty(endpointRef, kMIDIPropertyName, &tmpString);
	if (err != noErr)
		NSLog(@"\t\terror %ld at MIDIObjectGetStringProperty() a",(long)err);
	else	{
		if (tmpString != NULL)	{
			name = [[NSString stringWithString:(NSString *)tmpString] retain];
			[properties setValue:name forKey:@"name"];
			CFRelease(tmpString);
		}
	}
	//	get the midi unique identifier
	err = MIDIObjectGetIntegerProperty(endpointRef,kMIDIPropertyUniqueID, &tmpInt);
	if (err != noErr)
		NSLog(@"\t\terror %ld at MIDIObjectGetIntegerProperty() b",(long)err);
	else
		[properties setValue:[NSNumber numberWithLong:tmpInt] forKey:@"uniqueID"];
	/*
	//	device id
	err = MIDIObjectGetIntegerProperty(endpointRef,kMIDIPropertyDeviceID, &tmpInt);
	if (err != noErr)
		NSLog(@"\t\terror %ld at MIDIObjectGetIntegerProperty() c",(long)err);
	else
		[properties setValue:[NSNumber numberWithLong:tmpInt] forKey:@"deviceID"];
	*/
	
	//	model
	err = MIDIObjectGetStringProperty(endpointRef, kMIDIPropertyModel, &tmpString);
	if (err != noErr)	{
		//NSLog(@"\t\terror %ld at MIDIObjectGetStringProperty() d",(long)err);
	}
	else	{
		if (tmpString != NULL)	{
			[properties setValue:(NSString *)tmpString forKey:@"model"];
			CFRelease(tmpString);
		}
	}
	
	//NSLog(@"\t\t%@",properties);
}

/*
	this method is where the midi callback sends me an array of parsed messages- feel free
	to subclass around this to get the desired behavior
*/
- (void) receivedMIDI:(NSArray *)a	{
	//NSLog(@"VVMIDINode:processMIDIMessageArray: ... %@",name);
	//NSLog(@"\t\t%@",a);
	if ((enabled) && (delegate != nil))	{
		if ([delegate respondsToSelector:@selector(receivedMIDI:fromNode:)])
			[delegate receivedMIDI:a fromNode:self];
		else if ([delegate respondsToSelector:@selector(receivedMIDI:)])
			[delegate receivedMIDI:a];
	}
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
	
	//	if the message is a 'begin sysex dump', add the sysex vals to the packet list
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
			//NSLog(@"\t%X",bufferPtr[i]);
		}
		*/
		newPacket = MIDIPacketListAdd(packetList,1024,currentPacket,0,[msgSysexArray count]+2,bufferPtr);
		free(bufferPtr);
		if (newPacket == NULL)	{
			NSLog(@"\terr adding new sysex packet");
			goto BAIL;
		}
	}
	//	else it's not a sysex val
	else	{
		scratchStruct[0] = [m type] | [m channel];
		//	not all midi messages have two data bytes- some have none, or one
		switch ([m type])	{
			case VVMIDINoteOffVal:			//	+2 data bytes
			case VVMIDINoteOnVal:			//	+2 data bytes
			case VVMIDIAfterTouchVal:		//	+2 data bytes
			case VVMIDIControlChangeVal:	//	+2 data bytes
			case VVMIDIPitchWheelVal:		//	+2 data bytes
			case VVMIDISongPosPointerVal:	//	+2 data bytes
				scratchStruct[1] = [m data1];
				scratchStruct[2] = [m data2];
				newPacket = MIDIPacketListAdd(packetList,1024,currentPacket,0,3,scratchStruct);
				break;
			case VVMIDIMTCQuarterFrameVal:	//	+1 data byte
			case VVMIDISongSelectVal:		//	+1 data byte
			case VVMIDIProgramChangeVal:	//	+1 data byte
			case VVMIDIChannelPressureVal:	//	+1 data type
				scratchStruct[1] = [m data1];
				newPacket = MIDIPacketListAdd(packetList,1024,currentPacket,0,2,scratchStruct);
				break;
			case VVMIDITuneRequestVal:		//	no data bytes
			case VVMIDIClockVal:			//	no data bytes
			case VVMIDITickVal:				//	no data bytes
			case VVMIDIStartVal:			//	no data bytes
			case VVMIDIContinueVal:			//	no data bytes
			case VVMIDIStopVal:				//	no data bytes
			case VVMIDIActiveSenseVal:		//	no data bytes
			case VVMIDIResetVal:			//	no data bytes
				newPacket = MIDIPacketListAdd(packetList,1024,currentPacket,0,1,scratchStruct);
				break;
		}
		if (newPacket == NULL)	{
			NSLog(@"\t\terror adding new packet %s",__func__);
			goto BAIL;
		}
	}
	
	currentPacket = newPacket;
	
	//	if this is a virtual sender, this node "owns" the source- i need to call 'MIDIReceived'
	if (virtualSender)	{
		err = MIDIReceived(endpointRef,packetList);
		if (err != noErr)	{
			NSLog(@"\t\terr %ld at MIDIReceived A",(long)err);
		}
	}
	//	if this isn't a virtual sender, something else is managing the source- call 'MIDISend'
	else	{
		err = MIDISend(portRef,endpointRef,packetList);
		if (err != noErr)	{
			NSLog(@"\t\terr %ld at MIDISend A",(long)err);
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
			NSLog(@"\t\terr %ld at MIDIReceived A",(long)err);
		}
	}
	//	if this isn't a virtual sender, something else is managing the source- call 'MIDISend'
	else	{
		err = MIDISend(portRef,endpointRef,packetList);
		if (err != noErr)	{
			NSLog(@"\t\terr %ld at MIDISend A",(long)err);
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


- (MIDIEndpointRef) endpointRef	{
	return endpointRef;
}
- (NSMutableDictionary *) properties	{
	return properties;
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
- (void) _getPartialMTCSMPTEArray:(Byte *)array	{
	if (array==nil)
		return;
	for (int i=0; i<5; ++i)
		*((Byte *)(array + i)) = partialMTCQuarterFrameSMPTE[i];
}
- (void) _setPartialMTCSMPTEArray:(Byte *)array	{
	if (array==nil)
		return;
	for (int i=0; i<5; ++i)
		partialMTCQuarterFrameSMPTE[i] = *((Byte *)(array + i));
}
- (void) _pushPartialMTCSMPTEArrayToCachedVal	{
	//NSLog(@"%s",__func__);
	for (int i=0; i<5; ++i)
		cachedMTCQuarterFrameSMPTE[i] = partialMTCQuarterFrameSMPTE[i];
}

- (void) _getValsForCC:(int)cc channel:(int)c toMSB:(int *)msb LSB:(int *)lsb	{
	*msb = twoPieceCCVals[c][cc];
	*lsb = twoPieceCCVals[c][cc+32];
}
- (void) _setValsForCC:(int)cc channel:(int)c fromMSB:(int)msb LSB:(int)lsb	{
	twoPieceCCVals[c][cc] = msb;
	twoPieceCCVals[c][cc+32] = lsb;
}

- (double) MTCQuarterFrameSMPTEAsDouble	{
	//NSLog(@"%s: %d - %d - %d - %d - %d",__func__,cachedMTCQuarterFrameSMPTE[0],cachedMTCQuarterFrameSMPTE[1],cachedMTCQuarterFrameSMPTE[2],cachedMTCQuarterFrameSMPTE[3],cachedMTCQuarterFrameSMPTE[4]);
	double			returnMe = MTCSMPTEByteArrayToSeconds(cachedMTCQuarterFrameSMPTE);
	return returnMe;
}


@end




double MTCSMPTEByteArrayToSeconds(Byte *byteArray)	{
	double		returnMe = 0.0;
	double		baseFPS = 0.0;
	int			byteArrayVal = 0;
	for (int i=0; i<5; ++i)	{
		byteArrayVal = *((Byte *)(byteArray+i));
		switch (i)	{
			case 0:	//	the first byte is the FPS mode
				switch (byteArrayVal)	{
					case 0:	//	24
						baseFPS = 24.0;
						break;
					case 1:	//	25
						baseFPS = 24.0;
						break;
					case 2:	//	drop-30
					case 3:	//	30
						baseFPS = 30.0;
						break;
				}
				break;
			case 1:	//	hours
				returnMe += (byteArrayVal) * 60.0 * 60.0;
				break;
			case 2:	//	minutes
				returnMe += (byteArrayVal) * 60.0;
				break;
			case 3:	//	seconds
				returnMe += (byteArrayVal);
				break;
			case 4:	//	frames
				returnMe += ((double)byteArrayVal/baseFPS);
				break;
		}
	}
	
	return returnMe;
}
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
	
	Byte					MTCSMPTE[5];
	BOOL					quarterFrameVal = NO;
	
	//	run through all the packets in the passed list of packets
	packet = (MIDIPacket *)&pktList->packet[0];
	for (i=0; i<pktList->numPackets; ++i)	{
		//	run through the packet...
		for (j=0; j<packet->length; ++j)	{
			currByte = packet->data[j];
			//	check to see what kind of byte it is
			//	if it's in the range 0x80 - 0xFF, it's a status byte- the first byte of a message
			if ((currByte >= 0x80) && (currByte <= 0xFF))	{
				
				quarterFrameVal = NO;
				switch((currByte & 0xF0))	{
					case VVMIDIControlChangeVal:
						newMsg = [VVMIDIMessage createWithType:(currByte & 0xF0) channel:(currByte & 0x0F)];
						if (newMsg == nil)	{
							break;
						}
						/*		NOT A BUG: do NOT add the msg to the array now, the CC may be 14-bit (may require two messages to assemble a single value!
						[msgs addObject:newMsg];
						*/
						msgElementCount = 0;
						break;
					case VVMIDINoteOffVal:
					case VVMIDINoteOnVal:
					case VVMIDIAfterTouchVal:
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
								quarterFrameVal = YES;
							case VVMIDISongPosPointerVal:
							case VVMIDISongSelectVal:
							case VVMIDIUndefinedCommon1Val:
							case VVMIDIUndefinedCommon2Val:
							case VVMIDITuneRequestVal:
								newMsg = [VVMIDIMessage createWithType:currByte channel:0x00];
								if (newMsg != nil)	{
									[msgs addObject:newMsg];
									msgElementCount = 0;
								}
								break;
							case VVMIDIEndSysexDumpVal:
								newMsg = [VVMIDIMessage createWithSysexArray:sysex];
								if (newMsg != nil)	{
									//[sysex addObject:[NSNumber numberWithInt:currByte]];
									[msgs addObject:newMsg];
								}
								//NSLog(@"\t\tVVMIDIEndSysexDumpVal - %X",currByte);
								processingSysex = NO;
								processingSysexIterationCount = 0;
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
								newMsg = [VVMIDIMessage createWithType:currByte channel:0x00];
								if (newMsg != nil)	{
									[msgs addObject:newMsg];
								}
								break;
							default:	//	no idea what the default would be...
								break;
						}
						break;
				}
			}
			//	else if the byte's in the range 0x00 - 0x7F, it's not a status byte- instead, it's got some kind of data in it
			else if ((currByte >= 0x00) && (currByte <= 0x7F))	{
				//	i'm only going to process this data if i'm not in the midst of a sysex dump and i'm assembling a message
				if (processingSysex)	{
					NSNumber		*tmpNum = [NSNumber numberWithInt:currByte];
					if (tmpNum != nil)
						[sysex addObject:tmpNum];
				}
				//	...else i'm not processing sysex data!
				else	{
					if (newMsg != nil)	{
						switch(msgElementCount)	{
							case 0:
								[newMsg setData1:currByte];
								++msgElementCount;
								break;
							case 1:
								{
									int			msgType = [newMsg type];
									if ((msgType == VVMIDINoteOnVal) && (currByte == 0x00))	{
										[newMsg setType:VVMIDINoteOffVal];
										[newMsg setData2:currByte];
									}
									//	if it's a control change value, the message may only be the LSB of a CC value!
									else if (msgType==VVMIDIControlChangeVal)	{
										/*
										[newMsg setData2:currByte];
										[msgs addObject:newMsg];
										*/
										
										
										int			cc = [newMsg data1];
										int			channel = [newMsg channel];
										//	CCs 0-31 are the MSBs of CCs 0-31
										if (cc>=0 && cc<32)	{
											//	get current MSB & LSB from node
											int			msb;
											int			lsb;
											[(VVMIDINode *)readProcRefCon _getValsForCC:cc channel:channel toMSB:&msb LSB:&lsb];
											msb = currByte;
											//NSLog(@"\t\tMSB.  vals are now %d / %d",msb,lsb);
											//	push updated MSB & LSB to node & newMsg
											[(VVMIDINode *)readProcRefCon _setValsForCC:cc channel:channel fromMSB:msb LSB:lsb];
											[newMsg setData2:msb];
											if (lsb>=0 && lsb<=127)
												[newMsg setData3:lsb];
											//	run through the local array- make sure there aren't any other messages from this channel + ctrl (remove them if there are)
											int			tmpIndex = 0;
											for (VVMIDIMessage *msgPtr in msgs)	{
												if ([msgPtr data1]==cc && [msgPtr channel]==channel)	{
													[msgs removeObjectAtIndex:tmpIndex];
													break;
												}
												++tmpIndex;
											}
											//	...now that i know there aren't any other messages to this ctrl, add this new message to the array!
											[msgs addObject:newMsg];
										}
										//	CCs 32-63 are the LSBs of CCs 0-31
										else if (cc>=32 && cc<64)	{
											//	fix channel of newMsg
											cc -= 32;
											[newMsg setData1:cc];
											//	get current MSB & LSB from node
											int			msb;
											int			lsb;
											[(VVMIDINode *)readProcRefCon _getValsForCC:cc channel:channel toMSB:&msb LSB:&lsb];
											lsb = currByte;
											//NSLog(@"\t\tLSB.  vals are now %d / %d",msb,lsb);
											//	push updated MSB & LSB to node & newMsg
											[(VVMIDINode *)readProcRefCon _setValsForCC:cc channel:channel fromMSB:msb LSB:lsb];
											[newMsg setData2:msb];
											[newMsg setData3:lsb];
											//	run through the local array- make sure there aren't any other messages from this channel + ctrl (remove them if there are)
											int			tmpIndex = 0;
											for (VVMIDIMessage *msgPtr in msgs)	{
												if ([msgPtr data1]==cc && [msgPtr channel]==channel)	{
													[msgs removeObjectAtIndex:tmpIndex];
													break;
												}
												++tmpIndex;
											}
											//	...now that i know there aren't any other messages to this ctrl, add this new message to the array!
											[msgs addObject:newMsg];
										}
										//	else it's a normal MIDI CC!
										else	{
											[msgs addObject:newMsg];
										}
									}
									else	{
										[newMsg setData2:currByte];
									}
									++msgElementCount;
								}
								break;
						}
						
						/*	if the last midi message was a MTC quarter-frame message, i need to pass it to the 
						node now (the node maintains a full SMPTE value as it must be assembed from multiple 
						packets, and if i don't pass it now the node may not get another chance to parse this 
						data). the node maintains a partial SMPTE value, which is pushed to a cached value...	*/
						if (quarterFrameVal)	{
							if (newMsg != nil)	{
								//	get the individual SMPTE values as an array of Bytes
								[(VVMIDINode *)readProcRefCon _getPartialMTCSMPTEArray:MTCSMPTE];
								//NSLog(@"\t\tbefore: %d - %d - %d - %d - %d",MTCSMPTE[0],MTCSMPTE[1],MTCSMPTE[2],MTCSMPTE[3],MTCSMPTE[4]);
								//	update the SMPTE values from the message
								Byte		mtcVal = [newMsg data1];
								int			highNibble = ((mtcVal >> 4) & 0x0F);
								int			lowNibble = (mtcVal & 0x0F);
								//NSLog(@"\t\tval is %hhd, high is %d low is %d",mtcVal,highNibble,lowNibble);
								int			tmpVal = 0;
								switch (highNibble)	{
									case 0:	//	current frames low nibble
										tmpVal = MTCSMPTE[4];
										tmpVal = (tmpVal & 0xF0) | lowNibble;
										MTCSMPTE[4] = tmpVal;
										break;
									case 1:	//	current frames high nibble
										tmpVal = MTCSMPTE[4];
										tmpVal = (tmpVal & 0x0F) | (lowNibble << 4);
										MTCSMPTE[4] = tmpVal;
										break;
									case 2:	//	current seconds low nibble
										tmpVal = MTCSMPTE[3];
										tmpVal = (tmpVal & 0xF0) | lowNibble;
										MTCSMPTE[3] = tmpVal;
										break;
									case 3:	//	current seconds high nibble
										tmpVal = MTCSMPTE[3];
										tmpVal = (tmpVal & 0x0F) | (lowNibble << 4);
										MTCSMPTE[3] = tmpVal;
										break;
									case 4:	//	current minutes low nibble
										tmpVal = MTCSMPTE[2];
										tmpVal = (tmpVal & 0xF0) | lowNibble;
										MTCSMPTE[2] = tmpVal;
										break;
									case 5:	//	current minutes high nibble
										tmpVal = MTCSMPTE[2];
										tmpVal = (tmpVal & 0x0F) | (lowNibble << 4);
										MTCSMPTE[2] = tmpVal;
										break;
									case 6:	//	current hours low nibble
										tmpVal = MTCSMPTE[1];
										tmpVal = (tmpVal & 0xF0) | lowNibble;
										MTCSMPTE[1] = tmpVal;
										break;
									case 7:	//	current hours high nibble & SMPTE type. here, the low nibble describes two values:
										//	the highest bit is unused, and set to 0
										//	the next two bits describes the SMPTE type: 0=24, 1=25, 2=30-drop, 3=30
										//	the last bit is bit 4 (the fifth bit- the only bit in the high nibble) of "hours".
										tmpVal = MTCSMPTE[1];
										tmpVal = (tmpVal & 0x0F) | ((lowNibble & 0x01) << 4);
										MTCSMPTE[1] = tmpVal;
										MTCSMPTE[0] = ((lowNibble >> 1) & 0x03);
										break;
								}
								//	push the (modified) SMPTE values back to the node
								//NSLog(@"\t\tafter: %d - %d - %d - %d - %d",MTCSMPTE[0],MTCSMPTE[1],MTCSMPTE[2],MTCSMPTE[3],MTCSMPTE[4]);
								[(VVMIDINode *)readProcRefCon _setPartialMTCSMPTEArray:MTCSMPTE];
								
								//	if this was the first or last piece in an SMTPE message (if the high nibble is 0 or 7), i need to push the node's partial SMPTE val to the cached val.
								if (/*highNibble==0 || */highNibble==7)	{
									[(VVMIDINode *)readProcRefCon _pushPartialMTCSMPTEArrayToCachedVal];
								}
								//	if this was 0xF1 0x0n or 0xF1 0x4n, update the cached SMPTE value on the node (push the array to the value)
								//if (highNibble==0 || highNibble==4)
								//	[(VVMIDINode *)readProcRefCon _pushPartialMTCSMPTEArrayToCachedVal];
							}
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
	//NSLog(@"%s",__func__);
	/*
		NOTE: this method will be called on whatever thread this node's clientRef was created on!
		the VVMIDIManager class attempts to ensure that this always happens on the main thread, 
		so there's no need to have an autorelease pool here...
	*/
	//	multiple messages may get sent out for a single action, so it makes sense to simply ignore everything but 'kMIDIMsgSetupChanged'
	if (msg->messageID == kMIDIMsgSetupChanged)
		[(VVMIDINode *)refCon setupChanged];
}

void senderReadProc(const MIDIPacketList *pktList, void *readProcRefCon, void *srcConnRefCon)	{
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	NSLog(@"VVMIDINode:senderReadProc:");
	[pool release];
}

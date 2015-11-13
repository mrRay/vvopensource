
#import "VVMIDINode.h"
#import "VVMIDI.h"
#import <mach/mach_time.h>



BOOL			_VVMIDIFourteenBitCCs = NO;
double			_machTimeToNsFactor;



@implementation VVMIDINode


+ (void) initialize	{
	kern_return_t				kernError;
	mach_timebase_info_data_t	timebaseInfo;
	
	kernError = mach_timebase_info(&timebaseInfo);
	if (kernError != KERN_SUCCESS)	{
		NSLog(@"Error getting mach_timebase in %s",__func__);
	}
	else	{
		// Set the time factors so we can work in ns
		_machTimeToNsFactor = (double)timebaseInfo.numer / timebaseInfo.denom;
	}
	//	make sure the manager class is initialized (the manager creates the midi client)
	[VVMIDIManager class];
}
- (NSString *) description	{
	return [NSString stringWithFormat:@"<VVMIDINode: %@, %@>",name,[properties objectForKey:(NSString *)kMIDIPropertyUniqueID]];
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
	//	when the manager class was initialized, it created the single, global, MIDIClientRef (_VVMIDIProcessClientRef)...
	//	create a MIDIInputPort- the client owns the port
	err = MIDIInputPortCreate(_VVMIDIProcessClientRef,(CFStringRef)@"portName",myMIDIReadProc,self,&portRef);
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
	//	when the manager class was initialized, it created the single, global, MIDIClientRef (_VVMIDIProcessClientRef)...
	//	make a new destination, attach it to the client
	err = MIDIDestinationCreate(_VVMIDIProcessClientRef,(CFStringRef)n,myMIDIReadProc,self,&endpointRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIDestinationCreate() A",(long)err);
		[self release];
		return nil;
	}
	//	create a MIDIInputPort- the client owns the port
	err = MIDIInputPortCreate(_VVMIDIProcessClientRef,(CFStringRef)n,myMIDIReadProc,self,&portRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIInputPortCreate B",(long)err);
		[self release];
		return nil;
	}
	
	//	load the properties for the endpoint
	[self loadProperties];
	
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
	//	set the 'sender' flag
	sender = YES;
	//	load the properties for the endpoint
	[self loadProperties];
	//	when the manager class was initialized, it created the single, global, MIDIClientRef (_VVMIDIProcessClientRef)...
	//	create a MIDIOutputPort- the client owns the port
	err = MIDIOutputPortCreate(_VVMIDIProcessClientRef,(CFStringRef)@"portName",&portRef);
	if (err != noErr)	{
		NSLog(@"\t\terr %ld at MIDIOutputPortCreate A",(long)err);
		[self release];
		return nil;
	}
	
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
	//	when the manager class was initialized, it created the single, global, MIDIClientRef (_VVMIDIProcessClientRef)...
	//	make a new destination, so other apps know i'm here
	err = MIDISourceCreate(_VVMIDIProcessClientRef,(CFStringRef)n,&endpointRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDISourceCreate A",(long)err);
		[self release];
		return nil;
	}
	//	create a MIDIOutputPort- the client owns the port
	err = MIDIOutputPortCreate(_VVMIDIProcessClientRef,(CFStringRef)n,&portRef);
	if (err != noErr)	{
		NSLog(@"\t\terror %ld at MIDIOutputPortCreate B",(long)err);
		[self release];
		return nil;
	}
	
	//	set the 'sender' flag
	sender = YES;
	virtualSender = YES;
	
	//	load the properties for the endpoint
	[self loadProperties];
	
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
	portRef = 0;
	mtcClockRef = NULL;
	bpmClockRef = NULL;
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
	pthread_mutexattr_destroy(&attr);
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
	
	if (mtcClockRef != NULL)	{
		CAClockDispose(mtcClockRef);
		mtcClockRef = NULL;
	}
	if (bpmClockRef != NULL)	{
		CAClockDispose(bpmClockRef);
		bpmClockRef = NULL;
	}
	
	if (portRef!=0)	{
		MIDIPortDisconnectSource(portRef,endpointRef);
		MIDIPortDispose(portRef);
		portRef = 0;
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
	//NSLog(@"%s",__func__);
	long		err = noErr;
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
		//NSLog(@"\t\tmodel is %@",tmpString);
		if (tmpString != NULL)	{
			[properties setValue:(NSString *)tmpString forKey:@"model"];
			CFRelease(tmpString);
		}
	}
	//	get the entity.  an entity has multiple endpoints...
	MIDIEntityRef		tmpEntity = NULL;
	err = MIDIEndpointGetEntity(endpointRef, &tmpEntity);
	if (err != noErr)	{
		//NSLog(@"\t\terr: %ld at MIDIEndpointGetEntity() in %s for %@",err,__func__,name);
	}
	else	{
		//	get the device.  a device has entities...
		MIDIDeviceRef	tmpDevice = NULL;
		err = MIDIEntityGetDevice(tmpEntity, &tmpDevice);
		if (err != noErr)	{
			//NSLog(@"\t\terr: %ld at MIDIEntityGetDevice() in %s",err,__func__);
		}
		else	{
			//	get the device name?
			err = MIDIObjectGetStringProperty(tmpDevice, kMIDIPropertyName, &tmpString);
			if (err != noErr)	{
				//NSLog(@"\t\terr: %ld at MIDIObjectGetStringProperty() e in %s",err,__func__);
			}
			else	{
				//NSLog(@"\t\tdevice name is %@",tmpString);
				VVRELEASE(deviceName);
				deviceName = (tmpString==nil) ? nil : [(NSString *)tmpString copy];
			}
		}
	}
	
	//NSLog(@"\t\tname is %@",name);
	//NSLog(@"\t\t%@",properties);
	
	BOOL		successful = NO;
	//	create the clock, which will receive MTC
	if (!sender)	{
		//	create the clock
		err = CAClockNew(0, &mtcClockRef);
		if (err != noErr)	{
			NSLog(@"\t\terror %ld at CAClockNew()",err);
		}
		else	{
			CAClockTimebase		timebase = kCAClockTimebase_HostTime;
			UInt32				size = 0;
			size = sizeof(timebase);
			err = CAClockSetProperty(mtcClockRef, kCAClockProperty_InternalTimebase, size, &timebase);
			if (err != noErr)
				NSLog(@"\t\terr %ld setting internal timebase in %s",err,__func__);
			else	{
				UInt32		tSyncMode = kCAClockSyncMode_MTCTransport;
				size = sizeof(tSyncMode);
				err = CAClockSetProperty(mtcClockRef, kCAClockProperty_SyncMode, size, &tSyncMode);
				if (err != noErr)
					NSLog(@"\t\terr %ld setting sync mode in %s",err,__func__);
				else	{
					/*
					//	this should make the clock receive MIDI from the endpoint, but it doesn't work- instead i manually pass MIDI data to the clock (which parses and applies it)
					size = sizeof(endpointRef);
					err = CAClockSetProperty(mtcClockRef, kCAClockProperty_SyncSource, size, endpointRef);
					if (err != noErr)
						NSLog(@"\t\terr %d setting sync source in %s for %@",err,__func__,properties);
					else	{
					*/
						/*
						UInt32 tSMPTEType = kSMPTETimeType30;
						size = sizeof(tSMPTEType);
						err = CAClockSetProperty(mtcClockRef, kCAClockProperty_SMPTEFormat, size, &tSMPTEType);
						if (err != noErr)
							NSLog(@"\t\terr %ld setting SMPTE format in %s",err,__func__);
						else	{
						*/
							CAClockSeconds freeWheelTime = 0.2;
							size = sizeof(freeWheelTime);
							err = CAClockSetProperty(mtcClockRef, kCAClockProperty_MTCFreewheelTime, size, &freeWheelTime);
							if (err != noErr)
								NSLog(@"\t\terr %ld setting freewheel time in %s",err,__func__);
							else	{
								err = CAClockAddListener(mtcClockRef, clockListenerProc, self);
								if (err != noErr)
									NSLog(@"\t\terr %ld adding listener in %s",err,__func__);
								else	{
									err = CAClockArm(mtcClockRef);
									if (err != noErr)
										NSLog(@"\t\ter %ld arming clock in %s",err,__func__);
									else
										successful = YES;
								}
							}
						/*
						}
						*/
					/*
					}
					*/
				}
			}
			
			//	if i wasn't successful, get rid of the clock
			if (!successful && mtcClockRef!=NULL)	{
				NSLog(@"\t\terr %@ disposing clock, %s",name,__func__);
				CAClockDispose(mtcClockRef);
				mtcClockRef = NULL;
			}
		}
	}
	
	successful = NO;
	//	create the clock, which will receive MTC
	if (!sender)	{
		//	create the clock
		err = CAClockNew(0, &bpmClockRef);
		if (err != noErr)	{
			NSLog(@"\t\terror %ld at CAClockNew()",err);
		}
		else	{
			CAClockTimebase		timebase = kCAClockTimebase_HostTime;
			UInt32				size = 0;
			size = sizeof(timebase);
			err = CAClockSetProperty(bpmClockRef, kCAClockProperty_InternalTimebase, size, &timebase);
			if (err != noErr)
				NSLog(@"\t\terr %ld setting internal timebase in %s",err,__func__);
			else	{
				UInt32		tSyncMode = kCAClockSyncMode_MIDIClockTransport;
				size = sizeof(tSyncMode);
				err = CAClockSetProperty(bpmClockRef, kCAClockProperty_SyncMode, size, &tSyncMode);
				if (err != noErr)
					NSLog(@"\t\terr %ld setting sync mode in %s",err,__func__);
				else	{
					//CAClockSeconds freeWheelTime = 0.2;
					//size = sizeof(freeWheelTime);
					err = CAClockAddListener(bpmClockRef, clockListenerProc, self);
					if (err != noErr)
						NSLog(@"\t\terr %ld adding listener in %s",err,__func__);
					else	{
						err = CAClockArm(bpmClockRef);
						if (err != noErr)
							NSLog(@"\t\ter %ld arming clock in %s",err,__func__);
						else
							successful = YES;
					}
				}
			}
			
			//	if i wasn't successful, get rid of the clock
			if (!successful && bpmClockRef!=NULL)	{
				NSLog(@"\t\terr %@ disposing clock, %s",name,__func__);
				CAClockDispose(bpmClockRef);
				bpmClockRef = NULL;
			}
		}
	}
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
- (void) sendMsg:(VVMIDIMessage *)m	{
	if ((enabled!=YES) || (sender!=YES) || (m==nil))
		return;
	//NSLog(@"\t\tsending %@ to %@",m,name);
	
	MIDIPacket		*newPacket = nil;
	OSStatus		err = noErr;
	
	uint64_t		timestamp = [m timestamp];
	
	if (timestamp == 0)
		timestamp = mach_absolute_time() * _machTimeToNsFactor;
	
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
		newPacket = MIDIPacketListAdd(packetList,1024,currentPacket,timestamp,[msgSysexArray count]+2,bufferPtr);
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
				newPacket = MIDIPacketListAdd(packetList,1024,currentPacket,timestamp,3,scratchStruct);
				break;
			case VVMIDIMTCQuarterFrameVal:	//	+1 data byte
			case VVMIDISongSelectVal:		//	+1 data byte
			case VVMIDIProgramChangeVal:	//	+1 data byte
			case VVMIDIChannelPressureVal:	//	+1 data type
				scratchStruct[1] = [m data1];
				newPacket = MIDIPacketListAdd(packetList,1024,currentPacket,timestamp,2,scratchStruct);
				break;
			case VVMIDITuneRequestVal:		//	no data bytes
			case VVMIDIClockVal:			//	no data bytes
			case VVMIDITickVal:				//	no data bytes
			case VVMIDIStartVal:			//	no data bytes
			case VVMIDIContinueVal:			//	no data bytes
			case VVMIDIStopVal:				//	no data bytes
			case VVMIDIActiveSenseVal:		//	no data bytes
			case VVMIDIResetVal:			//	no data bytes
				newPacket = MIDIPacketListAdd(packetList,1024,currentPacket,timestamp,1,scratchStruct);
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
		
		uint64_t	timestamp = [msgPtr timestamp];
		
		if (timestamp == 0)
			timestamp = mach_absolute_time() * _machTimeToNsFactor;
		
		newPacket = MIDIPacketListAdd(packetList,1024,currentPacket,timestamp,3,scratchStruct);
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
- (CAClockRef) mtcClockRef	{
	return mtcClockRef;
}
- (CAClockRef) bpmClockRef	{
	return bpmClockRef;
}
- (NSString *) name	{
	return name;
}
- (NSString *) deviceName	{
	return deviceName;
}
- (NSString *) fullName	{
	if (deviceName!=nil && name!=nil)
		return VVFMTSTRING(@"%@-%@",deviceName,name);
	else if (deviceName==nil && name!=nil)
		return name;
	else
		return nil;
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
- (void) _getValsForCC:(int)cc channel:(int)c toMSB:(int *)msb LSB:(int *)lsb	{
	*msb = twoPieceCCVals[c][cc];
	*lsb = twoPieceCCVals[c][cc+32];
}
- (void) _setValsForCC:(int)cc channel:(int)c fromMSB:(int)msb LSB:(int)lsb	{
	twoPieceCCVals[c][cc] = msb;
	twoPieceCCVals[c][cc+32] = lsb;
}
- (double) MTCQuarterFrameSMPTEAsDouble	{
	if (mtcClockRef==NULL)
		return (double)0.0;
	long		err = noErr;
	CAClockTime		clockTime;
	err = CAClockGetCurrentTime(mtcClockRef, kCAClockTimeFormat_SMPTESeconds, &clockTime);
	if (err != noErr)	{
		NSLog(@"\t\terr %ld at CAClockGetCurrentTime() in %s",err,__func__);
		return (double)0.0;
	}
	Float64		tmpClockTime = clockTime.time.seconds;
	double		returnMe = (double)tmpClockTime;
	return returnMe;
}
- (double) midiClockBeats	{
	if (bpmClockRef==NULL)
		return (double)0.0;
	long			err = noErr;
	CAClockTime		clockTime;
	err = CAClockGetCurrentTime(bpmClockRef, kCAClockTimeFormat_Beats, &clockTime);
	if (err != noErr)	{
		NSLog(@"\t\terr %ld at CAClockGetCurrentTime() in %s",err,__func__);
		return (double)0.0;
	}
	Float64		tmpClockTime = clockTime.time.beats;
	double		returnMe = (double)tmpClockTime;
	return returnMe;
}
- (double) midiClockBPM	{
	if (bpmClockRef==NULL)
		return (double)0.0;
	long			err = noErr;
	CAClockTempo	tempo;
	err = CAClockGetCurrentTempo(bpmClockRef, &tempo, NULL);
	if (err != noErr)	{
		NSLog(@"\t\terr %ld at CAClockGetCurrentTempo() in %s",err,__func__);
		return (double)0.0;
	}
	Float64			playRate;
	err = CAClockGetPlayRate(bpmClockRef, &playRate);
	if (err != noErr)	{
		NSLog(@"\t\terr %ld at CAClockGetPlayRate() in %s",err,__func__);
		return (double)0.0;
	}
	double			returnMe = (double)(tempo * playRate);
	return returnMe;
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
	BOOL					hadMTCMsg = NO;
	BOOL					hadClockMsg = NO;
	
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
				
				switch((currByte & 0xF0))	{
					case VVMIDIControlChangeVal:
						newMsg = [VVMIDIMessage createWithType:(currByte & 0xF0) channel:(currByte & 0x0F) timestamp:packet->timeStamp];
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
						newMsg = [VVMIDIMessage createWithType:(currByte & 0xF0) channel:(currByte & 0x0F) timestamp:packet->timeStamp];
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
								hadMTCMsg = YES;
							case VVMIDISongPosPointerVal:
							case VVMIDISongSelectVal:
							case VVMIDIUndefinedCommon1Val:
							case VVMIDIUndefinedCommon2Val:
							case VVMIDITuneRequestVal:
								newMsg = [VVMIDIMessage createWithType:currByte channel:0x00 timestamp:packet->timeStamp];
								if (newMsg != nil)	{
									[msgs addObject:newMsg];
									msgElementCount = 0;
								}
								break;
							case VVMIDIEndSysexDumpVal:
								newMsg = [VVMIDIMessage createWithSysexArray:sysex timestamp:packet->timeStamp];
								if (newMsg != nil)	{
									if ([newMsg isFullFrameSMPTE])	{
										long					err = noErr;
										CAClockRef				tmpClock = [(VVMIDINode *)readProcRefCon mtcClockRef];
										CAClockSMPTEFormat		clockSMPTEFormat = kSMPTETimeType30;
										UInt32					tmpSize = sizeof(clockSMPTEFormat);
										//	get the SMPTE format from the clock
										err = CAClockGetProperty(tmpClock, kCAClockProperty_SMPTEFormat, &tmpSize, &clockSMPTEFormat);
										if (err != noErr)
											NSLog(@"\t\terr %ld getting SMPTE format in %s",err,__func__);
										CAClockTime				tmpTime;
										tmpTime.format = kCAClockTimeFormat_SMPTESeconds;
										tmpTime.time.smpte.mSubframes = 0;	//	untested, not sure if correct
										tmpTime.time.smpte.mSubframeDivisor = 80;	//	untested, not sure if correct
										tmpTime.time.smpte.mCounter = 0;	//	untested, not sure if correct
										tmpTime.time.smpte.mType = clockSMPTEFormat;	//	untested, not sure if correct
										tmpTime.time.smpte.mFlags = 0;	//	untested, not sure if correct
										tmpTime.time.smpte.mHours = [[sysex objectAtIndex:4] intValue];
										tmpTime.time.smpte.mMinutes = [[sysex objectAtIndex:5] intValue];
										tmpTime.time.smpte.mSeconds = [[sysex objectAtIndex:6] intValue];
										tmpTime.time.smpte.mFrames = [[sysex objectAtIndex:7] intValue];
										
										err = CAClockStop(tmpClock);
										if (err!=noErr)
											NSLog(@"\t\terr %ld at CAClockStop() in %s",err,__func__);
										else	{
											err = CAClockSetCurrentTime(tmpClock, &tmpTime);
											if (err != noErr)
												NSLog(@"\t\terr %ld at CAClockSetCurrentTime() in %s",err,__func__);
											else	{
												err = CAClockStart(tmpClock);
												if (err!=noErr)
													NSLog(@"\t\terr %ld at CAClockStart() in %s",err,__func__);
											}
										}
									}
									[msgs addObject:newMsg];
								}
								[sysex removeAllObjects];
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
								hadClockMsg = YES;
								newMsg = [VVMIDIMessage createWithType:currByte channel:0x00 timestamp:packet->timeStamp];
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
					//NSLog(@"\t\tsysex val - %X",currByte);
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
										int			cc = [newMsg data1];
										int			channel = [newMsg channel];
										//	CCs 0-31 are the MSBs of CCs 0-31
										if (_VVMIDIFourteenBitCCs && cc>=0 && cc<32)	{
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
										else if (_VVMIDIFourteenBitCCs && cc>=32 && cc<64)	{
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
											[newMsg setData2:currByte];
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
						
						/*	if the last MIDI msg was a MTC quarter-frame message, it will be passed on to the CAClockRef.  however, 
						if the CAClockRef's SMPTE mode doesn't match the SMPTE mode of the incoming message, it will be ignored.  this 
						isn't desirable, so we pull the SMPTE mode out of the message and apply it to the clock anyway.		*/
						if (hadMTCMsg)	{
							Byte		mtcVal = [newMsg data1];
							int			highNibble = ((mtcVal >> 4) & 0x0F);
							//	the high nibble is a number describing which "piece"- piece 7 contains SMPTE format data (and hours, but we don't care about that here)
							if (highNibble == 7)	{
								int			lowNibble = (mtcVal & 0x0F);
								long	err = noErr;
								CAClockRef	tmpClock = [(VVMIDINode *)readProcRefCon mtcClockRef];
								//UInt32		smpteType = ((lowNibble >> 1) & 0x03);	//	0-based, max val is 3. from 0, vals represent: 24fps, 25fps, 30-drop fps, 30fps.
								UInt32		smpteType = 0;
								UInt32		tmpSize = sizeof(UInt32);
								err = CAClockGetProperty(tmpClock, kCAClockProperty_SMPTEFormat, &tmpSize, &smpteType);
								if (err != noErr)
									NSLog(@"\t\terr %ld querying clock's SMPTE format in %s",err,__func__);
								else	{
									//	if the clock's current SMPTE format doesn't match the SMPTE format described by the received MTC...
									if (smpteType != ((lowNibble >> 1) & 0x03))	{
										smpteType = ((lowNibble >> 1) & 0x03);
										err = CAClockSetProperty(tmpClock, kCAClockProperty_SMPTEFormat, tmpSize, &smpteType);
										if (err != noErr)
											NSLog(@"\t\terr %ld correcting received SMPTE format in %s",err,__func__);
									}
								}
							}
							
							
							
							
							
							
						}
					}
				}
			}
		}
		
		//	get the next packet
		packet = MIDIPacketNext(packet);
	}
	
	if (hadMTCMsg)	{
		CAClockRef		tmpClock = [(VVMIDINode *)readProcRefCon mtcClockRef];
		long			err = CAClockParseMIDI(tmpClock, pktList);
		if (err != noErr)
			NSLog(@"\t\terr %ld at CAClockParseMIDI() for MTC in %s",err,__func__);
	}
	if (hadClockMsg)	{
		CAClockRef		tmpClock = [(VVMIDINode *)readProcRefCon bpmClockRef];
		long			err = CAClockParseMIDI(tmpClock, pktList);
		if (err != noErr)
			NSLog(@"\t\terr %ld at CAClockParseMIDI() for BPM in %s",err,__func__);
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
void senderReadProc(const MIDIPacketList *pktList, void *readProcRefCon, void *srcConnRefCon)	{
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	NSLog(@"VVMIDINode:senderReadProc:");
	[pool release];
}
void clockListenerProc(void *userData, CAClockMessage msg, const void *param)	{
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	//NSLog(@"%s",__func__);
	switch (msg)	{
		case kCAClockMessage_StartTimeSet:
			//NSLog(@"\t\tclock start time set");
			break;
		case kCAClockMessage_Started:
			//NSLog(@"\t\tclock started");
			break;
		case kCAClockMessage_Stopped:
			//NSLog(@"\t\tclock stopped");
			break;
		case kCAClockMessage_Armed:
			//NSLog(@"\t\tclock armed");
			break;
		case kCAClockMessage_Disarmed:
			//NSLog(@"\t\tclock disarmed");
			break;
		case kCAClockMessage_PropertyChanged:
			NSLog(@"\t\tclock property changed");
			break;
		case kCAClockMessage_WrongSMPTEFormat:
			NSLog(@"\t\tclock wrong SMPTE format");
			break;
	}
	[pool release];
}

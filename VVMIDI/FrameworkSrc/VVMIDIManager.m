
#import "VVMIDIManager.h"




MIDIClientRef		_VVMIDIProcessClientRef = NULL;




@implementation VVMIDIManager


+ (void) initialize	{
	static OSSpinLock		initLock = OS_SPINLOCK_INIT;
	if (OSSpinLockTry(&initLock))	{
		OSStatus			err;
		//	create a midi client which will receive incoming midi data
		err = MIDIClientCreate((CFStringRef)@"clientName",myMIDINotificationProc,self,&_VVMIDIProcessClientRef);
		if (err != noErr)	{
			NSLog(@"\t\terror %ld at MIDIClientCreate",(long)err);
			OSSpinLockUnlock(&initLock);
		}
	}
}
- (id) init	{
	if (self = [super init])	{
		[self generalInit];
		return self;
	}
	[self release];
	return nil;
}
- (void) generalInit	{
	sourceArray = [[MutLockArray alloc] init];
	destArray = [[MutLockArray alloc] init];
	
	delegate = nil;
	virtualSource = nil;
	virtualDest = nil;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupChangedNotification:) name:@"VVMIDISetupChangedNotification" object:nil];
	
	//	create a virtual destination other apps can send to
	[self createVirtualNodes];
	//	trigger the setup changed method
	[self setupChanged];
}

- (NSMutableDictionary *) createSnapshot	{
	//NSLog(@"%s",__func__);
	NSMutableDictionary		*returnMe = [NSMutableDictionary dictionaryWithCapacity:0];
	NSMutableDictionary		*tmpDict = nil;
	
	tmpDict = [NSMutableDictionary dictionaryWithCapacity:0];
	[sourceArray rdlock];
	for (VVMIDINode *nodePtr in [sourceArray array])
		[tmpDict setObject:[NSNumber numberWithBool:[nodePtr enabled]] forKey:[nodePtr fullName]];
	[sourceArray unlock];
	//	older versions of VVMIDI stored this under the "src" key!
	[returnMe setObject:tmpDict forKey:@"fullSrc"];
	
	tmpDict = [NSMutableDictionary dictionaryWithCapacity:0];
	[destArray rdlock];
	for (VVMIDINode *nodePtr in [destArray array])
		[tmpDict setObject:[NSNumber numberWithBool:[nodePtr enabled]] forKey:[nodePtr fullName]];
	[destArray unlock];
	//	older versions of VVMIDI stored this under the "dst" key!
	[returnMe setObject:tmpDict forKey:@"fullDst"];
	
	return returnMe;
}
- (void) loadSnapshot:(NSDictionary *)d	{
	//NSLog(@"%s",__func__);
	if (d == nil)
		return;
	
	NSDictionary		*tmpDict = nil;
	NSNumber			*tmpNum = nil;
	
	tmpDict = [d objectForKey:@"fullSrc"];
	if (tmpDict != nil)	{
		[sourceArray rdlock];
		for (VVMIDINode *nodePtr in [sourceArray array])	{
			tmpNum = [tmpDict objectForKey:[nodePtr fullName]];
			if (tmpNum != nil)
				[nodePtr setEnabled:[tmpNum boolValue]];
		}
		[sourceArray unlock];
	}
	//	older versions of VVMIDI stored snapshots under the node name (instead of the full name)
	else	{
		tmpDict = [d objectForKey:@"src"];
		if (tmpDict != nil)	{
			[sourceArray rdlock];
			for (VVMIDINode *nodePtr in [sourceArray array])	{
				tmpNum = [tmpDict objectForKey:[nodePtr name]];
				if (tmpNum != nil)
					[nodePtr setEnabled:[tmpNum boolValue]];
			}
			[sourceArray unlock];
		}
	}
	
	tmpDict = [d objectForKey:@"fullDst"];
	if (tmpDict != nil)	{
		[destArray rdlock];
		for (VVMIDINode *nodePtr in [destArray array])	{
			tmpNum = [tmpDict objectForKey:[nodePtr fullName]];
			if (tmpNum != nil)
				[nodePtr setEnabled:[tmpNum boolValue]];
		}
		[destArray unlock];
	}
	//	older versions of VVMIDI stored snapshots under the node name (instead of the full name)
	else	{
		tmpDict = [d objectForKey:@"dst"];
		if (tmpDict != nil)	{
			[destArray rdlock];
			for (VVMIDINode *nodePtr in [destArray array])	{
				tmpNum = [tmpDict objectForKey:[nodePtr name]];
				if (tmpNum != nil)
					[nodePtr setEnabled:[tmpNum boolValue]];
			}
			[destArray unlock];
		}
	}
}

- (void) dealloc	{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"VVMIDISetupChangedNotification" object:nil];
	
	delegate = nil;
	
	VVRELEASE(sourceArray);
	VVRELEASE(destArray);
	
	if (virtualSource != nil)
		[virtualSource release];
	virtualSource = nil;
	
	if (virtualDest != nil)
		[virtualDest release];
	virtualDest = nil;
	
	[super dealloc];
}

- (void) loadMIDIInputSources	{
	/*
	this method MUST get called on the main thread- midi notification callbacks for midi
	setup changes always occur on the thread on which the client was created, so i need
	to make sure that they always get created on the main thread because the callback method
	doesn't have an autorelease pool.  (it used to have a pool, but the pool was potentially
	causing a bug as it was replacing the "main" autorelease pool because the callback was
	occurring on the main thread)
	*/
	if (![NSThread isMainThread])	{
		[self performSelectorOnMainThread:@selector(loadMIDIInputSources) withObject:nil waitUntilDone:YES];
		return;
	}
	
	int					sourceCount;
	int					i;
	MIDIEndpointRef		endpointRef;
	VVMIDINode			*newSource;
	
	if (sourceArray != nil)
		[sourceArray lockRemoveAllObjects];
	else
		sourceArray = [[MutLockArray alloc] init];
	
	sourceCount = MIDIGetNumberOfSources();
	for (i=0; i<sourceCount; ++i)	{
		endpointRef = MIDIGetSource(i);
		newSource = [[[self receivingNodeClass] alloc] initReceiverWithEndpoint:endpointRef];
		if (newSource != nil)	{
			//NSLog(@"\t\tcreated new tmp source %@",newSource);
			BOOL			foundMatchingOutput = NO;
			//	get the new source's unique id
			NSDictionary	*newSourceProps = [newSource properties];
			NSNumber		*newSourceID = (newSourceProps==nil) ? nil : [newSourceProps objectForKey:(NSString *)kMIDIPropertyUniqueID];
			if (newSourceID != nil)	{
				
				//	make sure that i'm not trying to create a source for one of my built-in virtual destinations.
				NSDictionary		*tmpPropDict = [virtualDest properties];
				NSNumber			*tmpNum = (tmpPropDict==nil) ? nil : [tmpPropDict objectForKey:(NSString *)kMIDIPropertyUniqueID];
				if (tmpNum!=nil && [tmpNum isEqualTo:newSourceID])	{
					//NSLog(@"\t\t\ttmp source matches virtualDest");
					foundMatchingOutput = YES;
				}
				
				//	run through all my destinations, checking for a destination that has the same ID.  if i found one, this is a virtual source- this process created it, and i shouldn't make an input for it!
				if (!foundMatchingOutput)	{
					[destArray rdlock];
					for (VVMIDINode *tmpNode in [destArray array])	{
						tmpPropDict = [tmpNode properties];
						tmpNum = (tmpPropDict==nil) ? nil : [tmpPropDict objectForKey:(NSString *)kMIDIPropertyUniqueID];
						if (tmpNum!=nil && [tmpNum isEqualTo:newSourceID])	{
							//NSLog(@"\t\t\ttmp source matches dest %@",tmpNode);
							foundMatchingOutput = YES;
							break;
						}
					}
					[destArray unlock];
				}
			}
			
			if (!foundMatchingOutput)	{
				[newSource setDelegate:self];
				[sourceArray lockAddObject:newSource];
			}
			[newSource release];
		}
	}
}
- (void) loadMIDIOutputDestinations	{
	/*
	this method MUST get called on the main thread- midi notification callbacks for midi
	setup changes always occur on the thread on which the client was created, so i need
	to make sure that they always get created on the main thread because the callback method
	doesn't have an autorelease pool.  (it used to have a pool, but the pool was potentially
	causing a bug as it was replacing the "main" autorelease pool because the callback was
	occurring on the main thread)
	*/
	if (![NSThread isMainThread])	{
		[self performSelectorOnMainThread:@selector(loadMIDIOutputDestinations) withObject:nil waitUntilDone:YES];
		return;
	}
	
	int					destCount;
	int					i;
	MIDIEndpointRef		endpointRef;
	VVMIDINode			*newDest;
	
	if (destArray != nil)
		[destArray lockRemoveAllObjects];
	else
		destArray = [[MutLockArray alloc] init];
	
	destCount = MIDIGetNumberOfDestinations();
	for (i=0; i<destCount; ++i)	{
		endpointRef = MIDIGetDestination(i);
		newDest = [[[self sendingNodeClass] alloc] initSenderWithEndpoint:endpointRef];
		if (newDest != nil)	{
			if ([[newDest name] rangeOfString:[self receivingNodeName]].length<1)	{
				[newDest setDelegate:self];
				[destArray lockAddObject:newDest];
			}
			[newDest release];
		}
	}
}
/*
	subclasses can override this method to create a destination with a custom name
*/
- (void) createVirtualNodes	{
	/*
		make the receiver- this node "owns" the receiver's destination: it is
		responsible for handling data sent to the destination
	*/
	if (virtualSource != nil)	{
		[virtualSource release];
		virtualSource = nil;
	}
	virtualSource = [[[self receivingNodeClass] alloc] initReceiverWithName:[self receivingNodeName]];
	if (virtualSource != nil)
		[virtualSource setDelegate:self];
	
	/*
		make the sender- this node "owns" the destination: it is responsible for telling
		any endpoints connected to this destination that it has received midi data
	*/
	if (virtualDest != nil)	{
		[virtualDest release];
		virtualDest = nil;
	}
	virtualDest = [[[self sendingNodeClass] alloc] initSenderWithName:[self sendingNodeName]];
	if (virtualDest != nil)
		[virtualDest setDelegate:self];
}


- (void) setupChangedNotification:(NSNotification *)note	{
	[self setupChanged];
}
//	called when a midi device is plugged in or unplugged
- (void) setupChanged	{
	if ((virtualSource==nil) || (virtualDest==nil))
		return;
	[self loadMIDIInputSources];
	[self loadMIDIOutputDestinations];
	//NSLog(@"\t\t%@",delegate);
	if ((delegate != nil) && ([delegate respondsToSelector:@selector(setupChanged)]))
		[delegate setupChanged];
}
//	called when one of my sources has midi data to hand off to me
- (void) receivedMIDI:(NSArray *)a	{
	if ((delegate != nil) && ([delegate respondsToSelector:@selector(receivedMIDI:)]))
		[delegate receivedMIDI:a];
}
- (void) receivedMIDI:(NSArray *)a fromNode:(VVMIDINode *)n	{
	if (delegate != nil)	{
		if ([delegate respondsToSelector:@selector(receivedMIDI:fromNode:)])
			[delegate receivedMIDI:a fromNode:n];
		else if ([delegate respondsToSelector:@selector(receivedMIDI:)])
			[delegate receivedMIDI:a];
	}
}

- (void) sendMsg:(VVMIDIMessage *)m	{
	if (m == nil)
		return;
	
	//	first send the message to all the items in the dest array (each node has its own enable flag)
	[destArray lockMakeObjectsPerformSelector:@selector(sendMsg:) withObject:m];
	
	//	now send the msg to the virtual output destination
	if (virtualDest != nil)
		[virtualDest sendMsg:m];
}
- (void) sendMsgs:(NSArray *)a	{
	if ((a==nil) || ([a count] < 1))
		return;
	
	NSEnumerator		*msgIt = nil;
	VVMIDIMessage		*msgPtr = nil;
	
	//	first send the message to all the items in the dest array (each node has its own enable flag)
	msgIt = [a objectEnumerator];
	while (msgPtr = [msgIt nextObject])
		[destArray lockMakeObjectsPerformSelector:@selector(sendMsgs:) withObject:a];
	
	//	now send the msg to the virtual output destination
	if (virtualDest != nil)
		[virtualDest sendMsgs:a];
}

//	finds a destination node with a given name
- (VVMIDINode *) findDestNodeNamed:(NSString *)n	{
	if ((n==nil)||([n length]<1))
		return nil;
	VVMIDINode			*returnMe = nil;
	NSEnumerator		*nodeIt = nil;
	VVMIDINode			*nodePtr = nil;
	
	[destArray rdlock];
		nodeIt = [[destArray array] objectEnumerator];
		while ((nodePtr = [nodeIt nextObject]) && (returnMe == nil))	{
			if ([[nodePtr name] isEqualToString:n])
				returnMe = nodePtr;
		}
	[destArray unlock];
	return returnMe;
}
- (VVMIDINode *) findDestNodeWithFullName:(NSString *)n	{
	if ((n==nil)||([n length]<1))
		return nil;
	VVMIDINode			*returnMe = nil;
	NSEnumerator		*nodeIt = nil;
	VVMIDINode			*nodePtr = nil;
	
	[destArray rdlock];
		nodeIt = [[destArray array] objectEnumerator];
		while ((nodePtr = [nodeIt nextObject]) && (returnMe == nil))	{
			if ([[nodePtr fullName] isEqualToString:n])
				returnMe = nodePtr;
		}
	[destArray unlock];
	return returnMe;
}
- (VVMIDINode *) findDestNodeWithModelName:(NSString *)n	{
	if (n==nil || [n length]<1)
		return nil;
	VVMIDINode		*returnMe = nil;
	NSDictionary	*props = nil;
	NSString		*tmpString = nil;
	
	[destArray rdlock];
	for (VVMIDINode *nodePtr in [destArray array])	{
		props = [nodePtr properties];
		tmpString = (props==nil) ? nil : [props objectForKey:@"model"];
		if (tmpString!=nil && [tmpString isEqualToString:n])	{
			returnMe = nodePtr;
			break;
		}
	}
	[destArray unlock];
	return returnMe;
}
- (VVMIDINode *) findDestNodeWithDeviceName:(NSString *)n	{
	if ((n==nil)||([n length]<1))
		return nil;
	VVMIDINode			*returnMe = nil;
	NSEnumerator		*nodeIt = nil;
	VVMIDINode			*nodePtr = nil;
	
	[destArray rdlock];
		nodeIt = [[destArray array] objectEnumerator];
		while ((nodePtr = [nodeIt nextObject]) && (returnMe == nil))	{
			if ([[nodePtr deviceName] isEqualToString:n])
				returnMe = nodePtr;
		}
	[destArray unlock];
	return returnMe;
}
//	finds a source node with a given name
- (VVMIDINode *) findSourceNodeNamed:(NSString *)n	{
	if ((n==nil)||([n length]<1))
		return nil;
	
	VVMIDINode			*returnMe = nil;
	NSEnumerator		*nodeIt = nil;
	VVMIDINode			*nodePtr = nil;
	
	[sourceArray rdlock];
		nodeIt = [[sourceArray array] objectEnumerator];
		while ((nodePtr = [nodeIt nextObject]) && (returnMe == nil))	{
			if ([[nodePtr name] isEqualToString:n])
				returnMe = nodePtr;
		}
	[sourceArray unlock];
	return returnMe;
}
- (VVMIDINode *) findSourceNodeWithFullName:(NSString *)n	{
	if ((n==nil)||([n length]<1))
		return nil;
	
	VVMIDINode			*returnMe = nil;
	NSEnumerator		*nodeIt = nil;
	VVMIDINode			*nodePtr = nil;
	
	[sourceArray rdlock];
		nodeIt = [[sourceArray array] objectEnumerator];
		while ((nodePtr = [nodeIt nextObject]) && (returnMe == nil))	{
			if ([[nodePtr fullName] isEqualToString:n])
				returnMe = nodePtr;
		}
	[sourceArray unlock];
	return returnMe;
}
- (VVMIDINode *) findSourceNodeWithModelName:(NSString *)n	{
	if (n==nil || [n length]<1)
		return nil;
	VVMIDINode		*returnMe = nil;
	NSDictionary	*props = nil;
	NSString		*tmpString = nil;
	
	[sourceArray rdlock];
	for (VVMIDINode *nodePtr in [sourceArray array])	{
		props = [nodePtr properties];
		tmpString = (props==nil) ? nil : [props objectForKey:@"model"];
		if (tmpString!=nil && [tmpString isEqualToString:n])	{
			returnMe = nodePtr;
			break;
		}
	}
	[sourceArray unlock];
	return returnMe;
}
- (VVMIDINode *) findSourceNodeWithDeviceName:(NSString *)n	{
	if ((n==nil)||([n length]<1))
		return nil;
	
	VVMIDINode			*returnMe = nil;
	NSEnumerator		*nodeIt = nil;
	VVMIDINode			*nodePtr = nil;
	
	[sourceArray rdlock];
		nodeIt = [[sourceArray array] objectEnumerator];
		while ((nodePtr = [nodeIt nextObject]) && (returnMe == nil))	{
			if ([[nodePtr deviceName] isEqualToString:n])
				returnMe = nodePtr;
		}
	[sourceArray unlock];
	return returnMe;
}


- (NSArray *) destNodeNameArray	{
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	NSString			*nodeName = nil;
	
	[destArray rdlock];
	for (VVMIDINode *nodePtr in [destArray array])	{
		nodeName = [nodePtr name];
		if (nodeName != nil)
			[returnMe addObject:nodeName];
	}
	[destArray unlock];
	return returnMe;
}
- (NSArray *) destNodeFullNameArray	{
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	NSString			*nodeName = nil;
	
	[destArray rdlock];
	for (VVMIDINode *nodePtr in [destArray array])	{
		nodeName = [nodePtr fullName];
		if (nodeName != nil)
			[returnMe addObject:nodeName];
	}
	[destArray unlock];
	return returnMe;
}
- (NSArray *) sourceNodeNameArray	{
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	NSString			*nodeName = nil;
	
	[sourceArray rdlock];
	for (VVMIDINode *nodePtr in [sourceArray array])	{
		nodeName = [nodePtr name];
		if (nodeName != nil)
			[returnMe addObject:nodeName];
	}
	[sourceArray unlock];
	return returnMe;
}
- (NSArray *) sourceNodeFullNameArray	{
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	NSString			*nodeName = nil;
	
	[sourceArray rdlock];
	for (VVMIDINode *nodePtr in [sourceArray array])	{
		nodeName = [nodePtr fullName];
		if (nodeName != nil)
			[returnMe addObject:nodeName];
	}
	[sourceArray unlock];
	return returnMe;
}
- (NSArray *) deviceNameArray	{
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	NSString			*tmpName = nil;
	[sourceArray rdlock];
	for (VVMIDINode *nodePtr in [sourceArray array])	{
		tmpName = [nodePtr deviceName];
		if (tmpName!=nil && ![returnMe containsObject:tmpName])
			[returnMe addObject:tmpName];
	}
	[sourceArray unlock];
	return returnMe;
}

//	these methods exist so subclasses of me can override them to use custom subclasses of VVMIDINode
- (id) receivingNodeClass	{
	return [VVMIDINode class];
}
- (id) sendingNodeClass	{
	return [VVMIDINode class];
}
//	these methods exist so subclasses of me can override them to change the name of the default midi destinations/receivers
- (NSString *) receivingNodeName	{
	return @"To VVMIDI";
}
- (NSString *) sendingNodeName	{
	return @"From VVMIDI";
}

- (MutLockArray *) sourceArray	{
	return sourceArray;
}
- (MutLockArray *) destArray	{
	return destArray;
}
- (VVMIDINode *) virtualSource	{
	return virtualSource;
}
- (VVMIDINode *) virtualDest	{
	return virtualDest;
}
- (id) delegate	{
	return delegate;
}
- (void) setDelegate:(id)n	{
	delegate = n;
}


@end




void myMIDINotificationProc(const MIDINotification *msg, void *refCon)	{
	//NSLog(@"%s",__func__);
	/*
		NOTE: this method will be called on whatever thread this node's clientRef was created on!
		the VVMIDIManager class attempts to ensure that this always happens on the main thread, 
		so there's no need to have an autorelease pool here...
	*/
	//	multiple messages may get sent out for a single action, so it makes sense to simply ignore everything but 'kMIDIMsgSetupChanged'
	if (msg->messageID == kMIDIMsgSetupChanged)	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"VVMIDISetupChangedNotification" object:nil userInfo:nil];
		//[(VVMIDINode *)refCon setupChanged];
	}
}


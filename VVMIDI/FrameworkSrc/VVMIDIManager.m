
#import "VVMIDIManager.h"




@implementation VVMIDIManager


- (id) init	{
	if (self = [super init])	{
		[self generalInit];
		return self;
	}
	[self release];
	return nil;
}
- (void) generalInit	{
	pthread_mutexattr_t		attr1;
	
	sourceArray = [[NSMutableArray arrayWithCapacity:0] retain];
	destArray = [[NSMutableArray arrayWithCapacity:0] retain];
	
	pthread_mutexattr_init(&attr1);
	pthread_mutexattr_settype(&attr1,PTHREAD_MUTEX_NORMAL);
	pthread_mutex_init(&arrayLock,&attr1);
	//pthread_mutexattr_destroy(&attr);
	
	delegate = nil;
	virtualSource = nil;
	virtualDest = nil;
	
	//	create a virtual destination other apps can send to
	[self createVirtualNodes];
	//	trigger the setup changed method
	[self setupChanged];
}

- (void) dealloc	{
	delegate = nil;
	
	pthread_mutex_lock(&arrayLock);
		if (sourceArray != nil)	{
			[sourceArray removeAllObjects];
			[sourceArray release];
			sourceArray = nil;
		}
		if (destArray != nil)	{
			[destArray removeAllObjects];
			[destArray release];
			destArray = nil;
		}
	pthread_mutex_unlock(&arrayLock);
	
	if (virtualSource != nil)
		[virtualSource release];
	virtualSource = nil;
	
	if (virtualDest != nil)
		[virtualDest release];
	virtualDest = nil;
	
	pthread_mutex_destroy(&arrayLock);
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
	
	pthread_mutex_lock(&arrayLock);
	
		if (sourceArray != nil)
			[sourceArray removeAllObjects];
		else
			sourceArray = [[NSMutableArray arrayWithCapacity:0] retain];
		
		sourceCount = MIDIGetNumberOfSources();
		for (i=0; i<sourceCount; ++i)	{
			endpointRef = MIDIGetSource(i);
			newSource = [[[self receivingNodeClass] alloc] initReceiverWithEndpoint:endpointRef];
			if (newSource != nil)	{
				if (![[newSource name] isEqualToString:[self sendingNodeName]])	{
					[newSource setDelegate:self];
					[sourceArray addObject:newSource];
				}
				[newSource release];
			}
		}
	
	pthread_mutex_unlock(&arrayLock);
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
		[self performSelectorOnMainThread:@selector(loadMIDIInputSources) withObject:nil waitUntilDone:YES];
		return;
	}
	
	int					destCount;
	int					i;
	MIDIEndpointRef		endpointRef;
	VVMIDINode			*newDest;
	
	pthread_mutex_lock(&arrayLock);
	
		if (destArray != nil)
			[destArray removeAllObjects];
		else
			destArray = [[NSMutableArray arrayWithCapacity:0] retain];
		
		destCount = MIDIGetNumberOfDestinations();
		for (i=0; i<destCount; ++i)	{
			endpointRef = MIDIGetDestination(i);
			newDest = [[[self sendingNodeClass] alloc] initSenderWithEndpoint:endpointRef];
			if (newDest != nil)	{
				if (![[newDest name] isEqualToString:[self receivingNodeName]])	{
					[newDest setDelegate:self];
					[destArray addObject:newDest];
				}
				[newDest release];
			}
		}
	
	pthread_mutex_unlock(&arrayLock);
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

- (void) sendMsg:(VVMIDIMessage *)m	{
	if (m == nil)
		return;
	
	//	first send the message to all the items in the dest array (each node has its own enable flag)
	pthread_mutex_lock(&arrayLock);
		[destArray makeObjectsPerformSelector:@selector(sendMsg:) withObject:m];
	pthread_mutex_unlock(&arrayLock);
	
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
	pthread_mutex_lock(&arrayLock);
		msgIt = [a objectEnumerator];
		while (msgPtr = [msgIt nextObject])
			[destArray makeObjectsPerformSelector:@selector(sendMsgs:) withObject:a];
	pthread_mutex_unlock(&arrayLock);
	
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
	
	pthread_mutex_lock(&arrayLock);
		nodeIt = [destArray objectEnumerator];
		while ((nodePtr = [nodeIt nextObject]) && (returnMe == nil))	{
			if ([[nodePtr name] isEqualToString:n])
				returnMe = nodePtr;
		}
	pthread_mutex_unlock(&arrayLock);
	
	return returnMe;
}
//	finds a source node with a given name
- (VVMIDINode *) findSourceNodeNamed:(NSString *)n	{
	if ((n==nil)||([n length]<1))
		return nil;
	
	VVMIDINode			*returnMe = nil;
	NSEnumerator		*nodeIt = nil;
	VVMIDINode			*nodePtr = nil;
	
	pthread_mutex_lock(&arrayLock);
		nodeIt = [sourceArray objectEnumerator];
		while ((nodePtr = [nodeIt nextObject]) && (returnMe == nil))	{
			if ([[nodePtr name] isEqualToString:n])
				returnMe = nodePtr;
		}
	pthread_mutex_unlock(&arrayLock);
	
	return returnMe;
}

- (NSArray *) destNodeNameArray	{
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	NSString			*nodeName = nil;
	
	for (VVMIDINode *nodePtr in destArray)	{
		nodeName = [nodePtr name];
		if (nodeName != nil)
			[returnMe addObject:nodeName];
	}
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
	return [NSString stringWithString:@"To VVMIDI"];
}
- (NSString *) sendingNodeName	{
	return [NSString stringWithString:@"From VVMIDI"];
}

- (NSArray *) sourceArray	{
	return sourceArray;
}
- (NSArray *) destArray	{
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

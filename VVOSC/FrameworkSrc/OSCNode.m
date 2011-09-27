
#import "OSCNode.h"
#import "VVOSC.h"
#import "OSCStringAdditions.h"
#import "OSCAddressSpace.h"




@implementation OSCNode


- (NSString *) description	{
	OSSpinLockLock(&nameLock);
		NSString		*returnMe = [NSString stringWithFormat:@"<OSCNode %@>",nodeName];
	OSSpinLockUnlock(&nameLock);
	return returnMe;
}
- (void) _logDescriptionToString:(NSMutableString *)s tabDepth:(int)d	{
	int				i;
	
	//	add the tabs
	for (i=0;i<d;++i)
		[s appendString:@"\t"];
	
	//	write the description
	OSSpinLockLock(&nameLock);
		[s appendFormat:@"<%@>",nodeName];
	OSSpinLockUnlock(&nameLock);
	
	//	if there are contents
	if ((nodeContents!=nil)&&([nodeContents count]>0))	{
		[s appendString:@"\t{"];
		//	call this method on my contents
		[nodeContents rdlock];
		OSCNode				*nodePtr = nil;
		for (nodePtr in [nodeContents array])	{
			[s appendString:@"\n"];
			[nodePtr _logDescriptionToString:s tabDepth:d+1];
		}
		[nodeContents unlock];
		
		/*
		NSEnumerator		*it = [nodeContents objectEnumerator];
		OSCNode				*nodePtr;
		while (nodePtr = [it nextObject])	{
			[s appendString:@"\n"];
			[nodePtr _logDescriptionToString:s tabDepth:d+1];
		}
		[nodeContents unlock];
		*/
		
		//	add the tabs, close the description
		[s appendString:@"\n"];
		for (i=0;i<d;++i)
			[s appendString:@"\t"];
		[s appendString:@"}"];
	}
}
+ (id) createWithName:(NSString *)n	{
	OSCNode		*returnMe = [[OSCNode alloc] initWithName:n];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithName:(NSString *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if (n == nil)
		goto BAIL;
	if (self = [super init])	{
		addressSpace = _mainAddressSpace;
		deleted = NO;
		
		nameLock = OS_SPINLOCK_INIT;
		nodeName = [[n trimFirstAndLastSlashes] retain];
		fullName = nil;
		nodeContents = nil;
		parentNode = nil;
		nodeType = OSCNodeTypeUnknown;
		
		lastReceivedMessage = nil;
		lastReceivedMessageLock = OS_SPINLOCK_INIT;
		delegateArray = nil;
		//queryDelegateArray = nil;
		return self;
	}
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	[self autorelease];
	return nil;
}
- (id) init	{
	//NSLog(@"WARNING: %s",__func__);
	if (self = [super init])	{
		addressSpace = _mainAddressSpace;
		deleted = NO;
		
		nameLock = OS_SPINLOCK_INIT;
		nodeName = nil;
		fullName = nil;
		nodeContents = nil;
		parentNode = nil;
		nodeType = OSCNodeTypeUnknown;
		hiddenInMenu = NO;
		
		lastReceivedMessage = nil;
		lastReceivedMessageLock = OS_SPINLOCK_INIT;
		delegateArray = nil;
		//queryDelegateArray = nil;
		return self;
	}
	[self autorelease];
	return nil;
}
- (void) prepareToBeDeleted	{
	if (delegateArray != nil)	{
		[delegateArray wrlock];
			[delegateArray bruteForceMakeObjectsPerformSelector:@selector(nodeDeleted:) withObject:self];
			[delegateArray removeAllObjects];
		[delegateArray unlock];
		[delegateArray release];
		delegateArray = nil;
	}
	/*
	if (queryDelegateArray != nil)	{
		[queryDelegateArray wrlock];
			[queryDelegateArray bruteForceMakeObjectsPerformSelector:@selector(nodeDeleted:) withObject:self];
			[queryDelegateArray removeAllObjects];
		[queryDelegateArray unlock];
		[queryDelegateArray release];
		queryDelegateArray = nil;
	}
	*/
	deleted = YES;
}
- (void) dealloc	{
	//NSLog(@"%s ... %@",__func__,self);
	if (!deleted)
		[self prepareToBeDeleted];
	
	OSSpinLockLock(&nameLock);
		if (nodeName != nil)
			[nodeName release];
		nodeName = nil;
		if (fullName != nil)
			[fullName release];
		fullName = nil;
	OSSpinLockUnlock(&nameLock);
	
	if (nodeContents != nil)
		[nodeContents release];
	nodeContents = nil;
	parentNode = nil;
	
	OSSpinLockLock(&lastReceivedMessageLock);
	if (lastReceivedMessage != nil)
		[lastReceivedMessage release];
	lastReceivedMessage = nil;
	OSSpinLockUnlock(&lastReceivedMessageLock);
	
	[super dealloc];
}


- (NSComparisonResult) nodeNameCompare:(OSCNode *)comp	{
	if (nodeName == nil)
		return NSOrderedAscending;
	if (comp == nil)
		return NSOrderedDescending;
	NSComparisonResult		returnMe = NSOrderedSame;
	NSString				*compNodeName = [comp nodeName];
	
	OSSpinLockLock(&nameLock);
		returnMe = [nodeName caseInsensitiveCompare:compNodeName];
	OSSpinLockUnlock(&nameLock);
	
	return returnMe;
}


- (BOOL) isEqualTo:(id)o	{
	//	if the comparator is nil or i've been deleted, it's not equal
	if ((o == nil)||(deleted))
		return NO;
	//	if the ptr is an exact match (same instance), return YES
	if (self == o)
		return YES;
	
	OSSpinLockLock(&nameLock);
		NSString		*tmpNodeName = nodeName;
		[tmpNodeName retain];
	OSSpinLockUnlock(&nameLock);
	
	[tmpNodeName autorelease];
	//	if it's the same class and the nodeName matches, return YES
	if (([o isKindOfClass:[OSCNode class]]) && ([tmpNodeName isEqualToString:[o nodeName]]))
		return YES;
	
	return NO;
}


- (void) addLocalNode:(OSCNode *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if ((n == nil)||(deleted))
		return;
	if (nodeContents == nil)
		nodeContents = [[MutLockArray alloc] initWithCapacity:0];
	[nodeContents wrlock];
		[nodeContents addObject:n];
		[nodeContents sortUsingSelector:@selector(nodeNameCompare:)];
	[nodeContents unlock];
	
	[n setParentNode:self];
	
	[addressSpace nodeRenamed:n];
}
- (void) removeLocalNode:(OSCNode *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if ((n == nil)||(deleted))
		return;
	long		indexOfIdenticalPtr = NSNotFound;
	[n retain];
	[nodeContents wrlock];
		indexOfIdenticalPtr = [nodeContents indexOfIdenticalPtr:n];
		if (indexOfIdenticalPtr != NSNotFound)
			[nodeContents removeObjectAtIndex:indexOfIdenticalPtr];
	[nodeContents unlock];
	
	if (indexOfIdenticalPtr != NSNotFound)
		[n setParentNode:nil];
	
	[n release];
}
- (void) deleteLocalNode:(OSCNode *)n	{
	if ((n == nil)||(deleted))
		return;
	long		indexOfIdenticalPtr = NSNotFound;
	[n retain];
	[nodeContents wrlock];
		indexOfIdenticalPtr = [nodeContents indexOfIdenticalPtr:n];
		if (indexOfIdenticalPtr != NSNotFound)
			[nodeContents removeObjectAtIndex:indexOfIdenticalPtr];
	[nodeContents unlock];
	
	if (indexOfIdenticalPtr != NSNotFound)
		[n setParentNode:nil];
	
	[n prepareToBeDeleted];
	[n release];
}
- (OSCNode *) localNodeAtIndex:(int)i	{
	if ((i<0)||(nodeContents==nil))
		return nil;
	if (i>= [nodeContents count])
		return nil;
	OSCNode			*returnMe = nil;
	returnMe = [nodeContents lockObjectAtIndex:i];
	return returnMe;
}


- (OSCNode *) findLocalNodeNamed:(NSString *)n	{
	return [self findLocalNodeNamed:n createIfMissing:NO];
}
- (OSCNode *) findLocalNodeNamed:(NSString *)n createIfMissing:(BOOL)c	{
	//NSLog(@"%s ... %@, %ld",__func__,n,c);
	if (n == nil)
		return nil;
	OSCNode		*returnMe = nil;
	[nodeContents rdlock];
		for (OSCNode *nodePtr in [nodeContents array])	{
			if ([[nodePtr nodeName] isEqualToString:n])	{
				returnMe = nodePtr;
				break;
			}
		}
	[nodeContents unlock];
	//	if i couldn't find the node and i'm supposed to create it, do so
	if ((returnMe==nil) && (c))	{
		returnMe = [OSCNode createWithName:n];
		[self addLocalNode:returnMe];
	}
	return returnMe;
}
//	these methods manage pattern-matching and wildcard OSC address space stuff
- (NSMutableArray *) findLocalNodesMatchingPOSIXRegex:(NSString *)regex	{
	//NSLog(@"%s ... %@",__func__,regex);
	NSMutableArray		*returnMe = nil;
	[nodeContents rdlock];
	for (OSCNode *nodePtr in [nodeContents array])	{
		if ([[nodePtr nodeName] posixMatchAgainstFastRegex:regex])	{
			if (returnMe == nil)
				returnMe = [NSMutableArray arrayWithCapacity:0];
			[returnMe addObject:nodePtr];
		}
	}
	[nodeContents unlock];
	return returnMe;
}
- (void) _addLocalNodesMatchingRegex:(NSString *)regex toMutArray:(NSMutableArray *)a	{
	if (regex==nil || a==nil)
		return;
	
	[nodeContents rdlock];
	for (OSCNode *nodePtr in [nodeContents array])	{
		if ([[nodePtr nodeName] posixMatchAgainstFastRegex:regex])
			[a addObject:nodePtr];
	}
	[nodeContents unlock];
}


- (OSCNode *) findNodeForAddress:(NSString *)p	{
	//NSLog(@"%s ... %@",__func__,p);
	return [self findNodeForAddress:p createIfMissing:NO];
}
- (OSCNode *) findNodeForAddress:(NSString *)p createIfMissing:(BOOL)c	{
	//NSLog(@"%s ... %@, %ld",__func__,p,c);
	if (p == nil)	{
		NSLog(@"\terr: p was nil %s",__func__);
		return nil;
	}
	
	return [self findNodeForAddressArray:[[p trimFirstAndLastSlashes] pathComponents] createIfMissing:c];
}
- (OSCNode *) findNodeForAddressArray:(NSArray *)a	{
	return [self findNodeForAddressArray:a createIfMissing:NO];
}
- (OSCNode *) findNodeForAddressArray:(NSArray *)a createIfMissing:(BOOL)c	{
	//NSLog(@"%s ... %@",__func__,a);
	if ((a==nil)||([a count]<1))	{
		NSLog(@"\terr: a was %@ in %s",a,__func__);
		return nil;
	}
	
	OSCNode			*foundNode = nil;
	OSCNode			*nodeToSearch = self;
	int				tmpIndex = 0;
	int				lastDirectoryIndex = [a count]-2;	//	the index of the second-to-last node (or, the last node in this path which is known to have one or more sub-nodes)
	for (NSString *targetName in a)	{
		foundNode = [nodeToSearch findLocalNodeNamed:targetName];
		//	if i couldn't find a node matching the name, create one
		if ((foundNode==nil) && (c))	{
			foundNode = [OSCNode createWithName:targetName];
			//	if the node i'm creating now is known to have sub-nodes, set its type to directory automatically
			if (tmpIndex <= lastDirectoryIndex)
				[foundNode setNodeType:OSCNodeDirectory];
			//	add the node i created to the appropriate parent node
			[nodeToSearch addLocalNode:foundNode];
		}
		nodeToSearch = foundNode;
		if (nodeToSearch == nil)
			break;
		++tmpIndex;
	}
	return foundNode;
}
- (NSMutableArray *) findNodesMatchingAddress:(NSString *)a	{
	if (a==nil)	{
		NSLog(@"\terr: a was nil %s",__func__);
		return nil;
	}
	return [self findNodesMatchingAddressArray:[[a trimFirstAndLastSlashes] pathComponents]];
}
- (NSMutableArray *) findNodesMatchingAddressArray:(NSArray *)a	{
	if (a==nil || [a count]<1)	{
		NSLog(@"\terr: a was %@ in %s",a,__func__);
		return nil;
	}
	
	NSMutableArray		*currentMatches = [NSMutableArray arrayWithCapacity:0];
	NSMutableArray		*newMatches = [NSMutableArray arrayWithCapacity:0];
	[currentMatches addObject:self];
	//	run through each of the address segments
	for (NSString *addressSegment in a)	{
		//	determine if this address segment contains any OSC wildcards
		BOOL		regex = [addressSegment containsOSCWildCard];
		//	for each address segment, run through all the currently-matched nodes, looking for subnodes of theirs which match this address segment
		for (OSCNode *nodePtr in currentMatches)	{
			if (regex)
				[nodePtr _addLocalNodesMatchingRegex:addressSegment toMutArray:newMatches];
			else	{
				OSCNode		*tmpNode = [nodePtr findLocalNodeNamed:addressSegment];
				if (tmpNode != nil)
					[newMatches addObject:tmpNode];
			}
		}
		//	if i didn't find any new matches for this address segment, bail & return nil
		if ([newMatches count]<1)
			return nil;
		//	i've run through 'currentMatches'- clear it out for the next run
		[currentMatches removeAllObjects];
		//	swap 'newMatches' and 'currentMatches' for the next address segment check
		NSMutableArray		*tmpArray = currentMatches;
		currentMatches = newMatches;
		newMatches = tmpArray;
	}
	
	return newMatches;
}


- (void) addDelegate:(id)d	{
	if (d == nil)
		return;
	//	if there's no delegate array, make one
	if (delegateArray == nil)
		delegateArray = [[MutNRLockArray alloc] initWithCapacity:0];
	//	first check to make sure that this delegate hasn't already been added
	long		foundIndex = [delegateArray lockIndexOfIdenticalPtr:d];
	if (foundIndex == NSNotFound)	{
		//	if the delegate hasn't already been added, add it (this retains it)
		[delegateArray lockAddObject:d];
	}
}
- (void) removeDelegate:(id)d	{
	//NSLog(@"%s",__func__);
	if ((d == nil)||(delegateArray==nil)||([delegateArray count]<1))
		return;
	
	//	find the delegate in my delegate array
	long		foundIndex = [delegateArray lockIndexOfIdenticalPtr:d];
	//	if i could find it...
	if (foundIndex != NSNotFound)
		[delegateArray lockRemoveObjectAtIndex:foundIndex];
	else
		NSLog(@"\terr: couldn't find delegate to remove- %s",__func__);
}
- (void) informDelegatesOfNameChange	{
	//NSLog(@"%s ... %@",__func__,self);
	//	first of all, recalculate my full name (this could have been called by a parent changing its name)
	NSString		*parentFullName = (parentNode==nil)?nil:[parentNode fullName];
	OSSpinLockLock(&nameLock);
		VVRELEASE(fullName);
		if (parentNode == addressSpace)
			fullName = [[NSString stringWithFormat:@"/%@",nodeName] retain];
		else if (parentNode != nil)
			fullName = [[NSString stringWithFormat:@"%@/%@",parentFullName,nodeName] retain];
	OSSpinLockUnlock(&nameLock);
	
	//	tell my delegates that there's been a name change
	if ((delegateArray!=nil)&&([delegateArray count]>0))
		[delegateArray lockBruteForceMakeObjectsPerformSelector:@selector(nodeNameChanged:) withObject:self];
	//	tell all my sub-nodes that their name has also changed
	if ((nodeContents!=nil)&&([nodeContents count]>0))
		[nodeContents lockMakeObjectsPerformSelector:@selector(informDelegatesOfNameChange)];
}
- (void) addDelegatesFromNode:(OSCNode *)n	{
	//	put together an array of the delegates i'll be adding
	NSArray		*delegatesToAdd = [[n delegateArray] lockCreateArrayCopy];
	//	copy the delegates to my delegate array
	[delegateArray lockAddObjectsFromArray:delegatesToAdd];
	//	notify the delegates i copied that their names changed
	for (id delegatePtr in delegatesToAdd)	{
		if ([delegatePtr respondsToSelector:@selector(nodeNameChanged:)])
			[delegatePtr nodeNameChanged:self];
	}
}


/*
- (void) addQueryDelegate:(id)d	{
	if (d == nil)
		return;
	//	if there's no delegate array, make one
	if (queryDelegateArray == nil)
		queryDelegateArray = [[MutNRLockArray alloc] initWithCapacity:0];
	//	first check to make sure that this delegate hasn't already been added
	long		foundIndex = [queryDelegateArray lockIndexOfIdenticalPtr:d];
	if (foundIndex == NSNotFound)	{
		//	if the delegate hasn't already been added, add it (this retains it)
		[queryDelegateArray lockAddObject:d];
	}
}
- (void) removeQueryDelegate:(id)d	{
	//NSLog(@"%s",__func__);
	if ((d == nil)||(queryDelegateArray==nil)||([queryDelegateArray count]<1))
		return;
	
	//	find the delegate in my delegate array
	long		foundIndex = [queryDelegateArray lockIndexOfIdenticalPtr:d];
	//	if i could find it...
	if (foundIndex != NSNotFound)
		[queryDelegateArray lockRemoveObjectAtIndex:foundIndex];
	else
		NSLog(@"\terr: couldn't find query delegate to remove- %s",__func__);
}
- (void) informQueryDelegatesOfNameChange	{
	//NSLog(@"%s ... %@",__func__,self);
	//	first of all, recalculate my full name (this could have been called by a parent changing its name)
	NSString		*parentFullName = (parentNode==nil)?nil:[parentNode fullName];
	OSSpinLockLock(&nameLock);
		VVRELEASE(fullName);
		if (parentNode == addressSpace)
			fullName = [[NSString stringWithFormat:@"/%@",nodeName] retain];
		else if (parentNode != nil)
			fullName = [[NSString stringWithFormat:@"%@/%@",parentFullName,nodeName] retain];
	OSSpinLockUnlock(&nameLock);
	
	//	tell my delegates that there's been a name change
	if ((queryDelegateArray!=nil)&&([queryDelegateArray count]>0))
		[queryDelegateArray lockBruteForceMakeObjectsPerformSelector:@selector(nodeNameChanged:) withObject:self];
	//	tell all my sub-nodes that their name has also changed
	if ((nodeContents!=nil)&&([nodeContents count]>0))
		[nodeContents lockMakeObjectsPerformSelector:@selector(informQueryDelegatesOfNameChange)];
}
- (void) addQueryDelegatesFromNode:(OSCNode *)n	{
	//	put together an array of the delegates i'll be adding
	NSArray		*delegatesToAdd = [[n queryDelegateArray] lockCreateArrayCopy];
	//	copy the delegates to my delegate array
	[queryDelegateArray lockAddObjectsFromArray:delegatesToAdd];
	//	notify the delegates i copied that their names changed
	for (id delegatePtr in delegatesToAdd)	{
		if ([delegatePtr respondsToSelector:@selector(nodeNameChanged:)])
			[delegatePtr nodeNameChanged:self];
	}
}
*/


- (void) dispatchMessage:(OSCMessage *)m	{
	//NSLog(@"%s ... %@",__func__,m);
	if ((m==nil)||(deleted))
		return;
	//	retain the message so it doesn't disappear during this callback
	[m retain];
	NSMutableArray		*tmpCopy = [delegateArray lockCreateArrayCopy];
	for (ObjectHolder *holder in tmpCopy)	{
		id		delegate = [holder object];
		if (delegate != nil)
			[delegate node:self receivedOSCMessage:m];
	}
	OSSpinLockLock(&lastReceivedMessageLock);
		if (lastReceivedMessage != nil)
			[lastReceivedMessage release];
		lastReceivedMessage = m;
		if (lastReceivedMessage != nil)
			[lastReceivedMessage retain];
	OSSpinLockUnlock(&lastReceivedMessageLock);
	//	release the message!
	[m release];
}


- (void) setAddressSpace:(id)n	{
	addressSpace = n;
}
- (id) addressSpace	{
	return addressSpace;
}
- (void) setNodeName:(NSString *)n	{
	//NSLog(@"%s ... %@ -> %@",__func__,nodeName,n);
	[self _setNodeName:n];
	[addressSpace nodeRenamed:self];
}
- (NSString *) nodeName	{
	OSSpinLockLock(&nameLock);
		NSString		*returnMe = (nodeName==nil)?nil:[[nodeName retain] autorelease];
	OSSpinLockUnlock(&nameLock);
	return returnMe;
}
- (void) _setNodeName:(NSString *)n	{
	//	get a name-lock, as i'll be checking and potentially changing the name
	OSSpinLockLock(&nameLock);
		//	if the new name is the same as the old name, unlock and return immediately
		if ((n!=nil) && (nodeName!=nil) && ([n isEqualToString:nodeName]))	{
			OSSpinLockUnlock(&nameLock);
			return;
		}
		//	if i'm here, the name's changing- release, set, retain...then unlock
		VVRELEASE(nodeName);
		if (n != nil)
			nodeName = [n retain];
	OSSpinLockUnlock(&nameLock);
	
	//	if there's a parent node (if it's actually in the address space), tell my delegates about the name change
	if (parentNode != nil)	{
		//	informing delegates of name change also fixes my full name!
		[self informDelegatesOfNameChange];
	}
}
- (NSString *) fullName	{
	OSSpinLockLock(&nameLock);
		NSString		*returnMe = (fullName==nil)?nil:[[fullName retain] autorelease];
	OSSpinLockUnlock(&nameLock);
	return returnMe;
}
- (id) nodeContents	{
	return nodeContents;
}
- (void) setParentNode:(OSCNode *)n	{
	//NSLog(@"%s",__func__);
	parentNode = n;
	
	//	if there's a parent node (if it's actually in the address space), tell my delegates about the name change
	if (parentNode != nil)
		[self informDelegatesOfNameChange];
}
- (OSCNode *) parentNode	{
	return parentNode;
}
- (void) setNodeType:(int)n	{
	nodeType = n;
}
- (int) nodeType	{
	return nodeType;
}
- (void) setHiddenInMenu:(BOOL)n	{
	hiddenInMenu = n;
}
- (BOOL) hiddenInMenu	{
	return hiddenInMenu;
}
- (OSCMessage *) lastReceivedMessage	{
	if (deleted)
		return nil;
	OSCMessage		*returnMe = nil;
	
		OSSpinLockLock(&lastReceivedMessageLock);
			if (lastReceivedMessage != nil)	{
				returnMe = [lastReceivedMessage copy];
			}
		OSSpinLockUnlock(&lastReceivedMessageLock);
		if (returnMe != nil)
			[returnMe autorelease];
	
	return returnMe;
}
- (OSCValue *) lastReceivedValue	{
	OSCValue		*returnMe = nil;
	OSSpinLockLock(&lastReceivedMessageLock);
		returnMe = (lastReceivedMessage==nil) ? nil : [lastReceivedMessage value];
		returnMe = [returnMe retain];
	OSSpinLockUnlock(&lastReceivedMessageLock);
	return [returnMe autorelease];
}
- (id) delegateArray	{
	return delegateArray;
}
/*
- (id) queryDelegateArray	{
	return queryDelegateArray;
}
*/


@end

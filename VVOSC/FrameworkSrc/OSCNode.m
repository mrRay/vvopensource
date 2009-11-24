
#import "OSCNode.h"
#import "VVOSC.h"
#import "OSCStringAdditions.h"
#import "OSCAddressSpace.h"




@implementation OSCNode


- (NSString *) description	{
	return [NSString stringWithFormat:@"<OSCNode %@>",nodeName];
}
- (void) logDescriptionToString:(NSMutableString *)s tabDepth:(int)d	{
	int				i;
	
	//	add the tabs
	for (i=0;i<d;++i)
		[s appendString:@"\t"];
	//	write the description
	[s appendFormat:@"<%@>",nodeName];
	//	if there are contents
	if ((nodeContents!=nil)&&([nodeContents count]>0))	{
		[s appendString:@"\t{"];
		//	call this method on my contents
		[nodeContents rdlock];
		NSEnumerator		*it = [nodeContents objectEnumerator];
		OSCNode				*nodePtr;
		while (nodePtr = [it nextObject])	{
			[s appendString:@"\n"];
			[nodePtr logDescriptionToString:s tabDepth:d+1];
		}
		[nodeContents unlock];
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
		addressSpace = [OSCAddressSpace mainSpace];
		deleted = NO;
		
		nodeName = [[n trimFirstAndLastSlashes] retain];
		fullName = nil;
		nodeContents = nil;
		parentNode = nil;
		nodeType = OSCNodeTypeUnknown;
		
		lastReceivedMessage = nil;
		delegateArray = nil;
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
		addressSpace = [OSCAddressSpace mainSpace];
		deleted = NO;
		
		nodeName = nil;
		fullName = nil;
		nodeContents = nil;
		parentNode = nil;
		nodeType = OSCNodeTypeUnknown;
		
		lastReceivedMessage = nil;
		delegateArray = nil;
		return self;
	}
	[self autorelease];
	return nil;
}
- (void) prepareToBeDeleted	{
	if (delegateArray != nil)	{
		[delegateArray wrlock];
			[delegateArray makeObjectsPerformSelector:@selector(nodeDeleted)];
			[delegateArray removeAllObjects];
		[delegateArray unlock];
		[delegateArray release];
		delegateArray = nil;
	}
	deleted = YES;
}
- (void) dealloc	{
	//NSLog(@"%s ... %@",__func__,self);
	if (!deleted)
		[self prepareToBeDeleted];
	
	if (nodeName != nil)
		[nodeName autorelease];
	nodeName = nil;
	if (fullName != nil)
		[fullName autorelease];
	fullName = nil;
	if (nodeContents != nil)
		[nodeContents autorelease];
	nodeContents = nil;
	parentNode = nil;
	
	if (lastReceivedMessage != nil)
		[lastReceivedMessage autorelease];
	lastReceivedMessage = nil;
	
	[super dealloc];
}


- (NSComparisonResult) nodeNameCompare:(OSCNode *)comp	{
	if (nodeName == nil)
		return NSOrderedAscending;
	if (comp == nil)
		return NSOrderedDescending;
	return [nodeName caseInsensitiveCompare:[comp nodeName]];
}


- (BOOL) isEqualTo:(id)o	{
	//	if the comparator is nil or i've been deleted, it's not equal
	if ((o == nil)||(deleted))
		return NO;
	//	if the ptr is an exact match (same instance), return YES
	if (self == o)
		return YES;
	//	if it's the same class and the nodeName matches, return YES
	if (([o isKindOfClass:[OSCNode class]]) && ([nodeName isEqualToString:[o nodeName]]))
		return YES;
	
	return NO;
}


- (void) addNode:(OSCNode *)n	{
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
}
- (void) removeNode:(OSCNode *)n	{
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
	
	//	if i don't have any contents, remove myself from my parent
	if ((nodeContents==nil)||([nodeContents count]<1))	{
		if (parentNode != nil)
			[parentNode removeNode:self];
	}
	[n autorelease];
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
	
	NSEnumerator		*nodeIt;
	OSCNode				*nodePtr;
	
	[nodeContents rdlock];
		nodeIt = [nodeContents objectEnumerator];
		do	{
			nodePtr = [nodeIt nextObject];
		} while ((nodePtr!=nil) && (![[nodePtr nodeName] isEqualToString:n]));
	[nodeContents unlock];
	
	//	if i couldn't find the node and i'm supposed to create it, do so
	if ((nodePtr == nil)&&(c))	{
		nodePtr = [OSCNode createWithName:n];
		[self addNode:nodePtr];
		[addressSpace newNodeCreated:nodePtr];
	}
	
	return nodePtr;
}
- (OSCNode *) findNodeForAddress:(NSString *)p	{
	//NSLog(@"%s ... %@",__func__,p);
	return [self findNodeForAddress:p createIfMissing:NO];
}
- (OSCNode *) findNodeForAddress:(NSString *)p createIfMissing:(BOOL)c	{
	//NSLog(@"%s ... %@",__func__,p);
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
	
	NSEnumerator		*it = [a objectEnumerator];
	NSString			*pathComponent;
	OSCNode				*nodeToSearch;
	OSCNode				*foundNode = nil;
	
	nodeToSearch = self;
	while ((pathComponent=[it nextObject])&&(nodeToSearch!=nil))	{
		foundNode = [nodeToSearch findLocalNodeNamed:pathComponent];
		if ((foundNode==nil) && (c))	{
			foundNode = [OSCNode createWithName:pathComponent];
			[nodeToSearch addNode:foundNode];
			[addressSpace newNodeCreated:foundNode];
			
		}
		nodeToSearch = foundNode;
	}
	
	return foundNode;
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
	VVRELEASE(fullName);
	if (parentNode == addressSpace)
		fullName = [[NSString stringWithFormat:@"/%@",nodeName] retain];
	else if (parentNode != nil)
		fullName = [[NSString stringWithFormat:@"%@/%@",[parentNode fullName],nodeName] retain];
	
	//	tell my delegates that there's been a name change
	if ((delegateArray!=nil)&&([delegateArray count]>0))
		[delegateArray lockMakeObjectsPerformSelector:@selector(nodeNameChanged:) withObject:self];
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


- (void) dispatchMessage:(OSCMessage *)m	{
	//NSLog(@"%s ... %@",__func__,m);
	if ((m==nil)||(deleted))
		return;
	
	if (delegateArray != nil)
		[delegateArray lockMakeObjectsPerformSelector:@selector(receivedOSCMessage:) withObject:m];
	
	if (lastReceivedMessage != nil)
		[lastReceivedMessage autorelease];
	lastReceivedMessage = [m retain];
}


- (void) setAddressSpace:(id)n	{
	addressSpace = n;
}
- (id) addressSpace	{
	return addressSpace;
}
- (void) setNodeName:(NSString *)n	{
	//NSLog(@"%s ... %@ -> %@",__func__,nodeName,n);
	//	first of all, make sure that i'm not trying to rename it to the same name...
	if ((n!=nil)&&(nodeName!=nil)&&([n isEqualToString:nodeName]))
		return;
	
	VVAUTORELEASE(nodeName);
	if (n != nil)
		nodeName = [n retain];
	
	//	if there's a parent node (if it's actually in the address space), tell my delegates about the name change
	if (parentNode != nil)	{
		//	informing delegates of name change also fixes my full name!
		[self informDelegatesOfNameChange];
	}
}
- (NSString *) nodeName	{
	return nodeName;
}
- (NSString *) fullName	{
	return fullName;
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
- (OSCMessage *) lastReceivedMessage	{
	return lastReceivedMessage;
}
- (id) delegateArray	{
	return delegateArray;
}


@end

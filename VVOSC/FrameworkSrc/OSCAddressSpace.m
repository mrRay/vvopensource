
#import "OSCAddressSpace.h"
#import "VVOSC.h"
#import "OSCStringAdditions.h"




id				_mainVVOSCAddressSpace;




@implementation OSCAddressSpace


+ (id) mainAddressSpace	{
	return _mainVVOSCAddressSpace;
}
+ (void) refreshMenu	{
	//NSLog(@"%s",__func__);
	[[NSNotificationCenter defaultCenter] postNotificationName:OSCAddressSpaceUpdateMenus object:nil];
}
#if !IPHONE
+ (NSMenu *) makeMenuForNode:(OSCNode *)n withTarget:(id)t action:(SEL)a	{
	NSMenu				*returnMe = nil;
	NSMutableIndexSet	*tmpSet = [NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(OSCNodeTypeUnknown,OSCNodeTypeString+1)];
	returnMe = [OSCAddressSpace
		makeMenuForNode:n
		ofType:tmpSet
		withTarget:t
		action:a];
	return returnMe;
}
+ (NSMenu *) makeMenuForNode:(OSCNode *)n ofType:(NSIndexSet *)ts withTarget:(id)t action:(SEL)a	{
	if (n == nil)
		return nil;
	NSMenu					*returnMe = nil;
	NSString				*passedNodeName = [n nodeName];
	
	//	get the contents of the passed node
	MutLockArray		*nodeArray = [n nodeContents];
	//	run through the contents of the passed node, making items for its sub-nodes
	if (nodeArray != nil)	{
		[nodeArray rdlock];
		for (OSCNode *nodePtr in [nodeArray array])	{
			NSMenuItem			*newItem = nil;
			NSMenu				*subNodesMenu = nil;
			BOOL				matchesPassedTypes = [ts containsIndex:[nodePtr nodeType]];
			MutLockArray		*nodePtrContents = [nodePtr nodeContents];
			BOOL				hasSubNodes = ((nodePtrContents!=nil)&&([nodePtrContents count]>0)) ? YES : NO;
			BOOL				itemShouldBeCreated = NO;
			
			//	if this node isn't hidden and it either matches the passed types or has sub-nodes, i may have to make an item for it
			if ((![nodePtr hiddenInMenu]) && (matchesPassedTypes || hasSubNodes))	{
				//	if this node has sub-nodes, i'm going to need to look into generating a menu for them
				if (hasSubNodes)	{
					subNodesMenu = [self makeMenuForNode:nodePtr ofType:ts withTarget:t action:a];
					//	if the menu of sub-nodes is nil and the node doesn't match the passed node types, do nothing!
					if ((subNodesMenu==nil) && !matchesPassedTypes)	{
						//	don't create a menu item for this node!
					}
					//	else i need to make a menu item for this node, and add the menu of its sub-nodes to it
					else
						itemShouldBeCreated = YES;
				}
				//	else it doesn't have subnodes- the node must match the passed type
				else
					itemShouldBeCreated = YES;
				
				
				//	if the item should be created...
				if (itemShouldBeCreated)	{
					newItem = [[NSMenuItem alloc]
						initWithTitle:[nodePtr nodeName]
						action:nil
						keyEquivalent:@""];
					//	if i actually made the item- set it up, apply the submenu, add it to the menu i'm returning!
					if (newItem != nil)	{
						[newItem setToolTip:[nodePtr fullName]];
						[newItem setTarget:t];
						[newItem setAction:a];
						if (subNodesMenu != nil)
							[newItem setSubmenu:subNodesMenu];
						
						//	i need to add this item to the menu i'll be returning- if the menu doesn't exist yet, create it now
						if (returnMe == nil)	{
							returnMe = (passedNodeName==nil) ? [[NSMenu alloc] initWithTitle:@"root"] : [[NSMenu alloc] initWithTitle:passedNodeName];
							if (returnMe == nil)
								return nil;
							[returnMe setAutoenablesItems:NO];
						}
						//	now add the item to returnMe!
						[returnMe addItem:newItem];
						[newItem autorelease];
					}
				}
			}
		}
		[nodeArray unlock];
	}
	//	autorelease the menu and return it
	return (returnMe == nil) ? nil : [returnMe autorelease];
}
#endif
+ (void) load	{
	//NSLog(@"%s",__func__);
	_mainVVOSCAddressSpace = nil;
	//NSLog(@"\t\t_mainVVOSCAddressSpace is %@",_mainVVOSCAddressSpace);
}
+ (void) initialize	{
	//NSLog(@"%s",__func__);
	if (_mainVVOSCAddressSpace != nil)
		return;
	//NSLog(@"\t\tallocating main address space!");
	_mainVVOSCAddressSpace = [[OSCAddressSpace alloc] init];
	[_mainVVOSCAddressSpace setNodeType:OSCNodeDirectory];
	[_mainVVOSCAddressSpace setAutoQueryReply:YES];
	//NSLog(@"\t\t_mainVVOSCAddressSpace is %@",_mainVVOSCAddressSpace);
}




- (NSString *) description	{
	NSMutableString		*mutString = [NSMutableString stringWithCapacity:0];
	[mutString appendString:@"\n"];
	[mutString appendString:@"********\tOSC Address Space\t********\n"];
	if ((nodeContents != nil) && ([nodeContents count] > 0))	{
		NSArray				*localContents = [nodeContents lockCreateArrayCopy];
		for (OSCNode *nodePtr in localContents)	{
			[nodePtr _logDescriptionToString:mutString tabDepth:0];
			[mutString appendString:@"\n"];
		}
	}
	
	return mutString;
}
- (id) init	{
	//NSLog(@"%s",__func__);
	if (self = [super init])	{
		delegate = nil;
#if IPHONE

#else
		//	register to receive notifications that the app's about to terminate so i can stop running
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			selector:@selector(applicationWillTerminateNotification:)
			name:NSApplicationWillTerminateNotification
			object:nil];
#endif
		return self;
	}
	[self release];
	return nil;
}
- (void) applicationWillTerminateNotification:(NSNotification *)note	{
	[self prepareToBeDeleted];
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	//if (_mainVVOSCAddressSpace == self)
	//	_mainVVOSCAddressSpace = nil;
	[super dealloc];
}


- (void) renameAddress:(NSString *)before to:(NSString *)after	{
	//NSLog(@"%s ... %@ -> %@",__func__,before,after);
	if (deleted)
		return;
	if (before==nil)	{
		NSLog(@"\terr: before was nil %s",__func__);
		return;
	}
	if (after==nil)	{
		NSLog(@"\terr: after was nil %s",__func__);
		return;
	}
	[self renameAddressArray:[[before trimFirstAndLastSlashes] pathComponents] toArray:[[after trimFirstAndLastSlashes] pathComponents]];
	
}

- (void) renameAddressArray:(NSArray *)before toArray:(NSArray *)after	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	if (before==nil)	{
		NSLog(@"\terr: before was nil %s",__func__);
		return;
	}
	if (after==nil)	{
		NSLog(@"\terr: after was nil %s",__func__);
		return;
	}
	
	OSCNode			*beforeNode = [self findNodeForAddressArray:before];
	OSCNode			*afterNode = [self findNodeForAddressArray:after];
	
	//	if the 'beforeNode' is nil
	if (beforeNode == nil)	{
		//	if there's already an 'afterNode', i'm done!
		if (afterNode != nil)
			return;
		//	if there isn't an 'afterNode', make one
		else
			[self findNodeForAddressArray:after createIfMissing:YES];
	}
	//	else if there's a 'beforeNode', i'm going to have to move stuff
	else	{
		[self setNode:beforeNode forAddressArray:after];
	}
	
}

	
- (void) setNode:(OSCNode *)n forAddress:(NSString *)a	{
	[self setNode:n forAddress:a createIfMissing:YES];
}
- (void) setNode:(OSCNode *)n forAddress:(NSString *)a createIfMissing:(BOOL)c	{
	if (deleted)
		return;
	if (a == nil)
		[self setNode:n forAddressArray:nil createIfMissing:c];
	else
		[self setNode:n forAddressArray:[[a trimFirstAndLastSlashes] pathComponents] createIfMissing:c];
}
- (void) setNode:(OSCNode *)n forAddressArray:(NSArray *)a	{
	[self setNode:n forAddressArray:a createIfMissing:YES];
}
- (void) setNode:(OSCNode *)n forAddressArray:(NSArray *)a createIfMissing:(BOOL)c	{
	//NSLog(@"%s ... %@ - %@",__func__,n,a);
	if (deleted)
		return;
	if ((a==nil)||([a count]<1))	{
		NSLog(@"\terr: a was %@ in %s",a,__func__);
		return;
	}
	
	OSCNode			*beforeParent = nil;
	OSCNode			*afterParent = nil;
	
	//	retain the node i'm about to insert so it doesn't get released while this is happening
	if (n != nil)
		[n retain];
	//	make sure the node i'm moving has been removed from its parent.  that's removed, NOT RELEASED!
	if (n != nil)
		beforeParent = [n parentNode];
	if (beforeParent != nil)	{
		MutNRLockArray		*delegates = [n delegateArray];
		//	removing the local node will clear out its delegates (setting a node's parent to nil clears its delegates), so we store its delegates before doing so
		NSMutableArray	*delegatesBeforeRemoval = [delegates lockCreateArrayCopyFromObjects];
		[beforeParent removeLocalNode:n];
		//	re-apply any delegates that existed before removal
		[delegates lockAddObjectsFromArray:delegatesBeforeRemoval];
	}
	//	make sure the node's got the proper name (it could be different from the passed array's last object)
	if (n != nil)
		[n _setNodeName:[a lastObject]];
	//	find the new parent node for the destination
	NSMutableArray		*parentAddressArray = [[a mutableCopy] autorelease];
	[parentAddressArray removeLastObject];
	//	if the parent's address array is empty, the root level node is the parent
	if ([parentAddressArray count] == 0)
		afterParent = self;
	else
		afterParent = [self findNodeForAddressArray:parentAddressArray];
	
	//	if there isn't a parent node (if i have to make one)
	if (afterParent == nil)	{
		//	if i passed a non-nil node (if i'm actually moving a node), i'll have to make the parent
		if (n != nil)	{
			//	make the node, and simply add the passed node to it (don't have to merge delegates)
			afterParent = [self findNodeForAddressArray:parentAddressArray createIfMissing:c];
			[afterParent addLocalNode:n];
		}
		//	else if i passed a nil node (if i'm deleting a node), i'm done- the parent doesn't even exist
	}
	//	else if there's already a parent node
	else	{
		//	check to see if there's a pre-existing node
		OSCNode		*preExistingNode = [afterParent findLocalNodeNamed:[a lastObject]];
		//	if there is a pre-existing node
		if (preExistingNode != nil)	{
			//	if i'm passing a node (if i'm actually moving a node), add the delegates
			if (n != nil)
				[preExistingNode addDelegatesFromNode:n];
			//	else if i'm passing a nil node (deleting a node), delete the pre-existing node
			else	{
				[afterParent deleteLocalNode:preExistingNode];
			}
		}
		//	else if there isn't a pre-existing node
		else	{
			//	if i'm passing a node, add the node to the parent
			if (n != nil)
				[afterParent addLocalNode:n];
			//	if i was passing a nil node (deleting a node), i'd be deleting the pre-existing (so i'm done)
		}
	}
	/*
	//	if i was passed a node (if i'm actually moving something), 
	//	make sure my newNodeCreated method gets called
	if (n != nil)
		[self newNodeCreated:n];
	*/
	//	i retained the ndoe i'm about to insert earlier- release it now
	if (n != nil)
		[n release];
}
- (OSCNode *) findNodeForAddress:(NSString *)p createIfMissing:(BOOL)c	{
	return [super findNodeForAddress:p createIfMissing:c];
}
- (NSMutableArray *) findNodesMatchingAddress:(NSString *)a	{
	return [super findNodesMatchingAddress:a];
}
/*
//	this method is called whenever a new node is added to the address space- subclasses can override this for custom notifications
- (void) newNodeCreated:(OSCNode *)n	{
	//NSLog(@"%s ... %@",__func__,[n fullName]);
	if (deleted)
		return;
	if (delegate != nil)	{
		//	notify the delegate that a new node has been created
		[delegate newNodeCreated:n];
		//	 the passed node may have sub-nodes, which may need to notify things that their address has changed
		MutLockArray	*subNodes = [n nodeContents];
		if ((subNodes!=nil) && ([subNodes count]>0))	{
			[subNodes rdlock];
			for (OSCNode *subNode in [subNodes array])	{
				[delegate nodeRenamed:subNode];
			}
			[subNodes unlock];
		}
	}
}
*/
- (void) nodeRenamed:(OSCNode *)n	{
	//NSLog(@"%s ... %@",__func__,[n fullName]);
	if (deleted)
		return;
	if (delegate != nil)	{
		[delegate nodeRenamed:n];
		/*
		//	the passed node may have sub-nodes, which may need to notify things that their address has changed
		MutLockArray	*subNodes = [n nodeContents];
		if ((subNodes!=nil) && ([subNodes count]>0))	{
			NSMutableArray		*subNodesCopy = [subNodes lockCreateArrayCopy];
			for (OSCNode *subNode in subNodesCopy)	{
				[self nodeRenamed:subNode];
			}
		}
		*/
	}
}
- (void) dispatchMessage:(OSCMessage *)m	{
	//NSLog(@"%s ... %@",__func__,m);
	if ((deleted) || (m == nil))
		return;
	OSCNode			*foundNode = [self findNodeForAddress:[m address] createIfMissing:YES];
	if (foundNode != nil)	{
		if (foundNode == self)	{
			[super dispatchMessage:m];
		}
		else	{
			[foundNode dispatchMessage:m];
		}
	}
}
- (void) _dispatchReplyOrError:(OSCMessage *)m	{
	//NSLog(@"%s ... %@",__func__,m);
	if (delegate!=nil)
		[delegate queryResponseNeedsToBeSent:m];
}
- (void) addDelegate:(id)d forPath:(NSString *)p	{
	//NSLog(@"%s",__func__);
	if ((d==nil)||(p==nil)||(deleted))
		return;
	if (![d respondsToSelector:@selector(node:receivedOSCMessage:)])	{
		NSLog(@"\terr: tried to add a non-conforming delegate: %s",__func__);
		return;
	}
	
	OSCNode			*foundNode = [self findNodeForAddress:p createIfMissing:YES];
	if (foundNode != nil)
		[foundNode addDelegate:d];
}
- (void) removeDelegate:(id)d forPath:(NSString *)p	{
	//NSLog(@"%s",__func__);
	if ((d==nil)||(p==nil)||(deleted))
		return;
	
	OSCNode			*foundNode = [self findNodeForAddress:p createIfMissing:NO];
	if (foundNode != nil)
		[foundNode removeDelegate:d];
}
/*
- (void) addQueryDelegate:(id)d forPath:(NSString *)p	{
	//NSLog(@"%s",__func__);
	if ((d==nil)||(p==nil)||(deleted))
		return;
	if (![d respondsToSelector:@selector(node:receivedOSCMessage:)])	{
		NSLog(@"\terr: tried to add a non-conforming delegate: %s",__func__);
		return;
	}
	
	OSCNode			*foundNode = [self findNodeForAddress:p createIfMissing:YES];
	if (foundNode != nil)
		[foundNode addQueryDelegate:d];
}
- (void) removeQueryDelegate:(id)d forPath:(NSString *)p	{
	//NSLog(@"%s",__func__);
	if ((d==nil)||(p==nil)||(deleted))
		return;
	
	OSCNode			*foundNode = [self findNodeForAddress:p createIfMissing:NO];
	if (foundNode != nil)
		[foundNode removeQueryDelegate:d];
}
*/
- (void) setDelegate:(id)n	{
	delegate = n;
}
- (id) delegate	{
	return delegate;
}


@end

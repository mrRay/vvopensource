
#import "OSCAddressSpace.h"
#import "OSCStringAdditions.h"




@implementation OSCAddressSpace


+ (OSCAddressSpace *) mainSpace	{
	return _mainAddressSpace;
}
+ (void) refreshMenu	{
	//NSLog(@"%s",__func__);
	[[NSNotificationCenter defaultCenter] postNotificationName:AddressSpaceUpdateMenus object:nil];
}
#if !IPHONE
+ (NSMenu *) makeMenuForNode:(OSCNode *)n withTarget:(id)t action:(SEL)a	{
	if (n == nil)
		return nil;
	NSMenu					*returnMe = nil;
	NSString				*passedNodeName = [n nodeName];
	//	make the menu i'll be returning, perform basic setup on it
	if (passedNodeName == nil)
		returnMe = [[NSMenu alloc] initWithTitle:@"root"];
	else
		returnMe = [[NSMenu alloc] initWithTitle:[n nodeName]];
	if (returnMe == nil)
		return nil;
	[returnMe setAutoenablesItems:NO];
	//	get the contents of the passed node
	MutLockArray		*nodeArray = [n nodeContents];
	//	run through the contents of the passed node, making items for its sub-nodes
	if (nodeArray != nil)	{
		NSMenuItem			*newItem = nil;
		[nodeArray rdlock];
			for (OSCNode *nodePtr in [nodeArray array])	{
				newItem = [[NSMenuItem alloc]
					initWithTitle:[nodePtr nodeName]
					action:nil
					keyEquivalent:@""];
				if (newItem != nil)	{
					//	store the item's full path as its tooltip
					[newItem setToolTip:[nodePtr fullName]];
					//	set up the new item so it triggers the appropriate target/action
					if ((t!=nil)&&(a!=nil))	{
						[newItem setTarget:t];
						[newItem setAction:a];
					}
					//	add the item to the menu i'll be returning, free it
					[returnMe addItem:newItem];
					[newItem autorelease];
					//	if the node has sub-nodes, generate a menu for them and apply it to the new item
					if (([nodePtr nodeContents]!=nil)&&([[nodePtr nodeContents] count]>0))	{
						NSMenu		*subMenu = nil;
						subMenu = [self makeMenuForNode:nodePtr withTarget:t action:a];
						if (subMenu != nil)
							[newItem setSubmenu:subMenu];
					}
				}
			}
		[nodeArray unlock];
	}
	//	autorelease the menu and return it
	return [returnMe autorelease];
}
#endif
+ (void) initialize	{
	//NSLog(@"%s",__func__);
	_mainAddressSpace = [[OSCAddressSpace alloc] init];
	[_mainAddressSpace setAddressSpace:_mainAddressSpace];
}

- (NSString *) description	{
	NSMutableString		*mutString = [NSMutableString stringWithCapacity:0];
	[mutString appendString:@"\n"];
	[mutString appendString:@"********\tOSC Address Space\t********\n"];
	if ((nodeContents != nil) && ([nodeContents count] > 0))	{
		[nodeContents rdlock];
		NSEnumerator	*it = [nodeContents objectEnumerator];
		OSCNode			*nodePtr;
		while (nodePtr = [it nextObject])	{
			[nodePtr logDescriptionToString:mutString tabDepth:0];
			[mutString appendString:@"\n"];
		}
		[nodeContents unlock];
	}
	
	//[self logDescriptionToString:mutString tabDepth:0];
	return mutString;
}
- (id) init	{
	//NSLog(@"%s",__func__);
	if (self = [super init])	{
		delegate = nil;
		return self;
	}
	[self release];
	return nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (_mainAddressSpace == self)
		_mainAddressSpace = nil;
	[super dealloc];
}

- (void) renameAddress:(NSString *)before to:(NSString *)after	{
	//NSLog(@"%s ... %@ -> %@",__func__,before,after);
	
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
			afterNode = [self findNodeForAddressArray:after createIfMissing:YES];
	}
	//	else if there's a 'beforeNode', i'm going to have to move stuff
	else	{
		[self setNode:beforeNode forAddressArray:after];
	}
	
}

	

- (void) setNode:(OSCNode *)n forAddress:(NSString *)a	{
	if (a == nil)
		[self setNode:n forAddressArray:nil];
	else
		[self setNode:n forAddressArray:[[a trimFirstAndLastSlashes] pathComponents]];
}
- (void) setNode:(OSCNode *)n forAddressArray:(NSArray *)a	{
	//NSLog(@"%s ... %@ - %@",__func__,n,a);
	if ((a==nil)||([a count]<1))	{
		NSLog(@"\terr: a was %@ in %s",a,__func__);
		return;
	}
	
	OSCNode			*beforeParent = nil;
	OSCNode			*afterParent = nil;
	
	//	make sure the node i'm moving has been removed from its parent
	if (n != nil)
		beforeParent = [n parentNode];
	if (beforeParent != nil)
		[beforeParent removeNode:n];
	//	make sure the node's got the proper name (it could be different from the passed array's last object)
	if (n != nil)
		[n setNodeName:[a lastObject]];
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
			afterParent = [self findNodeForAddressArray:parentAddressArray createIfMissing:YES];
			[afterParent addNode:n];
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
			else
				[afterParent removeNode:preExistingNode];
		}
		//	else if there isn't a pre-existing node
		else	{
			//	if i'm passing a node, add the node to the parent
			if (n != nil)
				[afterParent addNode:n];
			//	if i was passing a nil node (deleting a node), i'd be deleting the pre-existing (so i'm done)
		}
	}
	
	//	if i was passed a node (if i'm actually moving something), 
	//	make sure my newNodeCreated method gets called
	if (n != nil)
		[self newNodeCreated:n];
}
//	this method is called whenever a new node is added to the address space- subclasses can override this for custom notifications
- (void) newNodeCreated:(OSCNode *)n	{
	//NSLog(@"%s ... %@",__func__,[n fullName]);
	if (delegate != nil)
		[delegate newNodeCreated:n];
}
- (void) dispatchMessage:(OSCMessage *)m	{
	//NSLog(@"%s ... %@",__func__,m);
	if (m == nil)
		return;
	OSCNode			*foundNode = [self findNodeForAddress:[m address] createIfMissing:YES];
	if ((foundNode != nil) && (foundNode != self))
		[foundNode dispatchMessage:m];
}
- (void) addDelegate:(id)d forPath:(NSString *)p	{
	//NSLog(@"%s",__func__);
	if ((d==nil)||(p==nil))
		return;
	if (![d respondsToSelector:@selector(receivedOSCMessage:)])	{
		NSLog(@"\terr: tried to add a non-conforming delegate: %s",__func__);
		return;
	}
	
	OSCNode			*foundNode = [self findNodeForAddress:p createIfMissing:YES];
	if (foundNode != nil)
		[foundNode addDelegate:d];
}
- (void) removeDelegate:(id)d forPath:(NSString *)p	{
	//NSLog(@"%s",__func__);
	if ((d==nil)||(p==nil))
		return;
	
	OSCNode			*foundNode = [self findNodeForAddress:p createIfMissing:NO];
	if (foundNode != nil)
		[foundNode addDelegate:d];
}

- (void) setDelegate:(id)n	{
	delegate = n;
}
- (id) delegate	{
	return delegate;
}


@end

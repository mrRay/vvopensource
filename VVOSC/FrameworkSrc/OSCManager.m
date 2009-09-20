
#import "OSCManager.h"
#import "VVOSC.h"




@implementation OSCManager


- (id) init	{
	[OSCAddressSpace mainSpace];
	
	if (self = [super init])	{
		inPortArray = [[MutLockArray arrayWithCapacity:0] retain];
		outPortArray = [[MutLockArray arrayWithCapacity:0] retain];
		delegate = nil;
		
		zeroConfManager = [[OSCZeroConfManager alloc] initWithOSCManager:self];
		return self;
	}
	[self release];
	return nil;
}

- (void) dealloc	{
	if (zeroConfManager != nil)	{
		[zeroConfManager release];
		zeroConfManager = nil;
	}
	if (inPortArray != nil)
		[inPortArray release];
	inPortArray = nil;
	if (outPortArray != nil)
		[outPortArray release];
	outPortArray = nil;
	delegate = nil;
	[super dealloc];
}

- (void) deleteAllInputs	{
	[inPortArray wrlock];
		[inPortArray makeObjectsPerformSelector:@selector(prepareToBeDeleted)];
		[inPortArray removeAllObjects];
	[inPortArray unlock];
	//	if there's a delegate and it responds to the setupChanged method, let it know that stuff changed
	if ((delegate!=nil)&&([delegate respondsToSelector:@selector(setupChanged)]))
		[delegate setupChanged];
}
- (void) deleteAllOutputs	{
	[outPortArray wrlock];
		[outPortArray makeObjectsPerformSelector:@selector(prepareToBeDeleted)];
		[outPortArray removeAllObjects];
	[outPortArray unlock];
	//	if there's a delegate and it responds to the setupChanged method, let it know that stuff changed
	if ((delegate!=nil)&&([delegate respondsToSelector:@selector(setupChanged)]))
		[delegate setupChanged];
}
/*===================================================================================*/
#pragma mark --------------------- creating input ports
/*------------------------------------*/
- (OSCInPort *) createNewInputFromSnapshot:(NSDictionary *)s	{
	if (s == nil)
		return nil;
	OSCInPort		*returnMe = nil;
	int				port = 1234;
	NSNumber		*numPtr = [s objectForKey:@"port"];
	NSString		*portLabel = [s objectForKey:@"portLabel"];
	if (portLabel == nil)
		portLabel = [self getUniqueInputLabel];
	if (numPtr != nil)
		port = [numPtr intValue];
	returnMe = [self createNewInputForPort:port withLabel:portLabel];
	return returnMe;
}
- (OSCInPort *) createNewInputForPort:(int)p withLabel:(NSString *)l	{
	//NSLog(@"%s ... %ld, %@",__func__,p,l);
	OSCInPort			*returnMe = nil;
	NSEnumerator		*it;
	OSCInPort			*portPtr;
	BOOL				foundPortConflict = NO;
	BOOL				foundNameConflict = NO;
	
	[inPortArray wrlock];
		//	check for port or name conflicts
		it = [inPortArray objectEnumerator];
		while ((portPtr = [it nextObject]) && (!foundPortConflict) && (!foundNameConflict))	{
			if ([portPtr port] == p)
				foundPortConflict = YES;
			if (([portPtr portLabel]!=nil) && ([[portPtr portLabel] isEqualToString:l]))
				foundNameConflict = YES;
		}
		//	if there weren't any conflicts, make an instance set it up and add it to the array
		if ((!foundPortConflict) && (!foundNameConflict))	{
			Class			inPortClass = [self inPortClass];
			
			returnMe = [[inPortClass alloc] initWithPort:p labelled:l];
			
			if (returnMe != nil)	{
				[returnMe setDelegate:self];
				[returnMe start];
				[inPortArray addObject:returnMe];
				[returnMe autorelease];
			}
		}
	[inPortArray unlock];
	//	if i made an in port, i should let the delegate know that stuff changed
	if (returnMe != nil)	{
		//	if there's a delegate and it responds to the setupChanged method, let it know that stuff changed
		if ((delegate!=nil)&&([delegate respondsToSelector:@selector(setupChanged)]))
			[delegate setupChanged];
	}
	return returnMe;
}
- (OSCInPort *) createNewInputForPort:(int)p	{
	OSCInPort			*returnMe = nil;
	NSString			*uniqueLabel = [self getUniqueInputLabel];
	returnMe = [self createNewInputForPort:p withLabel:uniqueLabel];
	return returnMe;
}
- (OSCInPort *) createNewInput	{
	OSCInPort		*portPtr = nil;
	int				portIndex = 1234;
	
	while (portPtr == nil)	{
		portPtr = [self createNewInputForPort:portIndex];
		++portIndex;
	}
	
	return portPtr;
}
/*===================================================================================*/
#pragma mark --------------------- creating output ports
/*------------------------------------*/
- (OSCOutPort *) createNewOutputFromSnapshot:(NSDictionary *)s	{
	if (s == nil)
		return nil;
	OSCOutPort		*returnMe = nil;
	NSNumber		*numPtr = nil;
	int				port;
	NSString		*addressPtr = nil;
	NSString		*portLabel = nil;
	
	//	find the address- if it's nil, return nil and bail on creation
	addressPtr = [s objectForKey:@"address"];
	if (addressPtr == nil)
		return nil;
	//	find the port- if it's nil, return nil and bail on creation
	numPtr = [s objectForKey:@"port"];
	if (numPtr == nil)
		return nil;
	port = [numPtr intValue];
	//	find the port label- if it's nil, get a new unique port label
	portLabel = [s objectForKey:@"portLabel"];
	if (portLabel == nil)
		portLabel = [self getUniqueOutputLabel];
	
	//	make the output based on the data
	returnMe = [self createNewOutputToAddress:addressPtr atPort:port withLabel:portLabel];
	
	return returnMe;
}
- (OSCOutPort *) createNewOutputToAddress:(NSString *)a atPort:(int)p withLabel:(NSString *)l	{
	//NSLog(@"%s ... %@:%ld, %@",__func__,a,p,l);
	if ((a == nil) || (p < 1024) || (l == nil))
		return nil;
	
	OSCOutPort			*returnMe = nil;
	NSEnumerator		*it;
	OSCOutPort			*portPtr;
	BOOL				foundNameConflict = NO;
	
	[outPortArray wrlock];
		//	check for name conflicts
		it = [outPortArray objectEnumerator];
		while ((portPtr = [it nextObject]) && (!foundNameConflict))	{
			if (([portPtr portLabel]!=nil) && ([[portPtr portLabel] isEqualToString:l]))
				foundNameConflict = YES;
		}
		//	if there weren't any name conflicts, make an instance and add it to the array
		if (!foundNameConflict)	{
			Class			outPortClass = [self outPortClass];
			
			returnMe = [[outPortClass alloc] initWithAddress:a andPort:p labelled:l];
			
			if (returnMe != nil)	{
				[outPortArray addObject:returnMe];
				[returnMe autorelease];
			}
		}
	[outPortArray unlock];
	//	if i made an output, i need to tell the delegate that stuff changed
	if (returnMe != nil)	{
		//	if there's a delegate and it responds to the setupChanged method, let it know that stuff changed
		if ((delegate!=nil)&&([delegate respondsToSelector:@selector(setupChanged)]))
			[delegate setupChanged];
	}
	
	return returnMe;
}
- (OSCOutPort *) createNewOutputToAddress:(NSString *)a atPort:(int)p	{
	OSCOutPort			*returnMe = nil;
	NSString			*uniqueLabel = [self getUniqueOutputLabel];
	returnMe = [self createNewOutputToAddress:a atPort:p withLabel:uniqueLabel];
	return returnMe;
}
- (OSCOutPort *) createNewOutput	{
	OSCOutPort		*portPtr = nil;
	int				portIndex = 1234;
	
	while (portPtr == nil)	{
		portPtr = [self createNewOutputToAddress:@"127.0.0.1" atPort:portIndex];
		++portIndex;
	}
	
	return portPtr;
}

/*===================================================================================*/
#pragma mark --------------------- main osc callback
/*------------------------------------*/
/*!
	the passed OSCMessage has both the address and the value (or values- a message can have more than one value).  this method is called immediately, as the incoming OSC data is received- no attempt is made to coalesce the updates and sort them by address.
	
	important: this method will be called from any of a number of threads- each port is running in its own thread!
	
	input ports tell their delegates when they receive data.  by default, the osc manager is the input port's delegate- so this method will be called by default if your input port doesn't have another delegate.  as such, this method tells the manager's delegate about any received osc messages.
*/
- (void) receivedOSCMessage:(OSCMessage *)m	{
	//NSLog(@"%s ... %@",__func__,v);
	if ((delegate != nil) && ([delegate respondsToSelector:@selector(receivedOSCMessage:)]))
		[delegate receivedOSCMessage:m];
}
/*===================================================================================*/
#pragma mark --------------------- working with ports
/*------------------------------------*/
- (NSString *) getUniqueInputLabel	{
	NSString		*tmpString = nil;
	NSEnumerator	*it;
	BOOL			found = NO;
	BOOL			alreadyInUse = NO;
	OSCInPort		*portPtr = nil;
	int				index = 1;
	
	[inPortArray rdlock];
		while (!found)	{
			tmpString = [NSString stringWithFormat:@"%@ %ld",[self inPortLabelBase],index];
			
			alreadyInUse = NO;
			it = [inPortArray objectEnumerator];
			while ((!alreadyInUse) && (portPtr = [it nextObject]))	{
				if ([[portPtr portLabel] isEqualToString:tmpString])	{
					alreadyInUse = YES;
				}
			}
			
			if ((tmpString != nil) && (!alreadyInUse))	{
				found = YES;
			}
			
			++index;
		}
	[inPortArray unlock];
	
	return tmpString;
}
- (NSString *) getUniqueOutputLabel	{
	NSString		*tmpString = nil;
	NSEnumerator	*it;
	BOOL			found = NO;
	BOOL			alreadyInUse = NO;
	OSCOutPort		*portPtr = nil;
	int				index = 1;
	
	[outPortArray rdlock];
		while (!found)	{
			tmpString = [NSString stringWithFormat:@"OSC Out Port %ld",index];
			
			alreadyInUse = NO;
			it = [outPortArray objectEnumerator];
			while ((!alreadyInUse) && (portPtr = [it nextObject]))	{
				if ([[portPtr portLabel] isEqualToString:tmpString])	{
					alreadyInUse = YES;
				}
			}
			
			if ((tmpString!=nil) && (!alreadyInUse))	{
				found = YES;
			}
			
			++index;
		}
	[outPortArray unlock];
	
	return tmpString;
}
- (OSCInPort *) findInputWithLabel:(NSString *)n	{
	if (n == nil)
		return nil;
	
	OSCInPort		*foundPort = nil;
	NSEnumerator	*it;
	OSCInPort		*portPtr = nil;
	
	[inPortArray rdlock];
		it = [inPortArray objectEnumerator];
		while ((portPtr = [it nextObject]) && (foundPort == nil))	{
			if ([[portPtr portLabel] isEqualToString:n])	{
				foundPort = portPtr;
			}
		}
	[inPortArray unlock];
	
	return foundPort;
}
- (OSCOutPort *) findOutputWithLabel:(NSString *)n	{
	if (n == nil)	{
		return nil;
	}
	
	OSCOutPort		*foundPort = nil;
	NSEnumerator		*it;
	OSCOutPort		*portPtr = nil;
	
	[outPortArray rdlock];
		it = [outPortArray objectEnumerator];
		while ((portPtr = [it nextObject]) && (foundPort == nil))	{
			if ([[portPtr portLabel] isEqualToString:n])	{
				foundPort = portPtr;
			}
		}
	[outPortArray unlock];
	
	return foundPort;
}


- (OSCOutPort *) findOutputWithAddress:(NSString *)a andPort:(int)p	{
	if (a == nil)
		return nil;
	
	OSCOutPort		*foundPort = nil;
	NSEnumerator	*it;
	OSCOutPort		*portPtr = nil;
	
	[outPortArray rdlock];
		it = [outPortArray objectEnumerator];
		while ((portPtr = [it nextObject]) && (foundPort == nil))	{
			if (([[portPtr addressString] isEqualToString:a]) && ([portPtr port] == p))	{
				foundPort = portPtr;
			}
		}
	[outPortArray unlock];
	
	return foundPort;
}
- (OSCOutPort *) findOutputForIndex:(int)i	{
	if ((i<0) || (i>=[outPortArray count]))
		return nil;
	OSCOutPort		*returnMe = nil;
	[outPortArray rdlock];
		returnMe = [outPortArray objectAtIndex:i];
	[outPortArray unlock];
	return returnMe;
}
- (OSCInPort *) findInputWithZeroConfName:(NSString *)n	{
	if (n == nil)
		return nil;
	
	id				foundPort = nil;
	NSEnumerator	*it;
	id				anObj;
	id				zeroConfDest = nil;
	
	[inPortArray rdlock];
		it = [inPortArray objectEnumerator];
		while ((anObj = [it nextObject]) && (foundPort == nil))	{
			zeroConfDest = [anObj zeroConfDest];
			if (zeroConfDest != nil)	{
				if ([n isEqualToString:[zeroConfDest name]])
					foundPort = anObj;
			}
		}
	[inPortArray unlock];
	return foundPort;
}
- (void) removeInput:(id)p	{
	if (p == nil)
		return;
	[(OSCInPort *)p stop];
	[inPortArray wrlock];
		[inPortArray removeObject:p];
	[inPortArray unlock];
	//	if there's a delegate and it responds to the setupChanged method, let it know that stuff changed
	if ((delegate!=nil)&&([delegate respondsToSelector:@selector(setupChanged)]))
		[delegate setupChanged];
}
- (void) removeOutput:(id)p	{
	if (p == nil)
		return;
	[outPortArray wrlock];
		[outPortArray removeObject:p];
	[outPortArray unlock];
	//	if there's a delegate and it responds to the setupChanged method, let it know that stuff changed
	if ((delegate!=nil)&&([delegate respondsToSelector:@selector(setupChanged)]))
		[delegate setupChanged];
}
- (NSArray *) outPortLabelArray	{
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	NSEnumerator		*it;
	OSCOutPort			*portPtr;
	
	[outPortArray rdlock];
		it = [outPortArray objectEnumerator];
		while (portPtr = [it nextObject])	{
			if ([portPtr portLabel] != nil)	{
				[returnMe addObject:[portPtr portLabel]];
			}
		}
	[outPortArray unlock];
	
	return returnMe;
}
/*===================================================================================*/
#pragma mark --------------------- subclassable methods for customization
/*------------------------------------*/
/*!
	by default, this method returns [OSCInPort class].  it’s called when creating an input port. this method exists so if you subclass OSCInPort you can override this method to have your manager create your custom subclass with the default port creation methods
*/
- (id) inPortClass	{
	return [OSCInPort class];
}
- (NSString *) inPortLabelBase	{
	if ((delegate!=nil)&&([delegate respondsToSelector:@selector(inPortLabelBase)]))
		return [delegate inPortLabelBase];
	return [NSString stringWithString:@"VVOSC"];
}
/*!
	by default, this method returns [OSCOutPort class].  it’s called when creating an input port. this method exists so if you subclass OSCOutPort you can override this method to have your manager create your custom subclass with the default port creation methods
*/
- (id) outPortClass	{
	return [OSCOutPort class];
}
/*===================================================================================*/
#pragma mark --------------------- misc.
/*------------------------------------*/
- (id) delegate	{
	return delegate;
}
- (void) setDelegate:(id)n	{
	delegate = n;
}
- (id) inPortArray	{
	return inPortArray;
}
- (id) outPortArray	{
	return outPortArray;
}


@end

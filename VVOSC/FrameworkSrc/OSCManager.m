
#import "OSCManager.h"
#import "VVOSC.h"
#include <ifaddrs.h>
#include <arpa/inet.h>




@implementation OSCManager


+ (NSArray *) hostIPv4Addresses	{
	struct ifaddrs		*interfaces = nil;
	int					err = 0;
	//	get the current interfaces
	err = getifaddrs(&interfaces);
	if (err)	{
		NSLog(@"\t\terr %d getting ifaddrs in %s",err,__func__);
		return nil;
	}
	//	define a character range with alpha-numeric chars so i can exclude IPv6 addresses!
	NSCharacterSet		*charSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefABCDEF:%"];
	NSMutableArray		*returnMe = nil;
	
	//	run through the interfaces
	struct ifaddrs		*tmpAddr = interfaces;
	while (tmpAddr != nil)	{
		if (tmpAddr->ifa_addr->sa_family == AF_INET)	{
			//	get the string for the interface
			NSString		*tmpString = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)tmpAddr->ifa_addr)->sin_addr)];
			if (tmpString != nil)	{
				//	make sure the interface string doesn't have any alpha-numeric/IPv6 chars in it!
				NSRange				charSetRange = [tmpString rangeOfCharacterFromSet:charSet];
				if ((charSetRange.length==0) && (charSetRange.location==NSNotFound))	{
					if (![tmpString isEqualToString:@"127.0.0.1"])	{
						if (returnMe == nil)
							returnMe = [NSMutableArray arrayWithCapacity:0];
						[returnMe addObject:tmpString];
					}
				}
			}
		}
		tmpAddr = tmpAddr->ifa_next;
	}
	
	if (interfaces != nil)	{
		freeifaddrs(interfaces);
		interfaces = nil;
	}
	return returnMe;
}
- (id) init	{
	return [self initWithServiceType:@"_osc._udp"];
}
- (id) initWithServiceType:(NSString *)t	{
	if (self = [super init])	{
		[self _generalInit];
		zeroConfManager = [[OSCZeroConfManager alloc] initWithOSCManager:self serviceType:t];
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (id) initWithInPortClass:(Class)i outPortClass:(Class)o	{
	return [self initWithInPortClass:i outPortClass:o serviceType:@"_osc._udp"];
}
- (id) initWithInPortClass:(Class)i outPortClass:(Class)o serviceType:(NSString *)t	{
	if (self = [super init])	{
		[self _generalInit];
		if (i != nil)
			inPortClass = i;
		if (o != nil)
			outPortClass = o;
		zeroConfManager = [[OSCZeroConfManager alloc] initWithOSCManager:self serviceType:t];
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (void) _generalInit	{
	//NSLog(@"%s",__func__);
	inPortArray = [[MutLockArray arrayWithCapacity:0] retain];
	outPortArray = [[MutLockArray arrayWithCapacity:0] retain];
	delegate = nil;
	inPortClass = [OSCInPort class];
	inPortLabelBase = [@"VVOSC" retain];
	outPortClass = [OSCOutPort class];
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
	VVRELEASE(inPortLabelBase);
	[super dealloc];
}

- (void) deleteAllInputs	{
	BOOL			postNotification = NO;
	[inPortArray wrlock];
		if ([inPortArray count]>0)
			postNotification = YES;
		[inPortArray makeObjectsPerformSelector:@selector(prepareToBeDeleted)];
		[inPortArray removeAllObjects];
	[inPortArray unlock];
	
	if (postNotification)
		[[NSNotificationCenter defaultCenter] postNotificationName:OSCInPortsChangedNotification object:self];
	/*
	//	if there's a delegate and it responds to the setupChanged method, let it know that stuff changed
	if ((delegate!=nil)&&([delegate respondsToSelector:@selector(setupChanged)]))
		[delegate setupChanged];
	*/
}
- (void) deleteAllOutputs	{
	//BOOL			postNotification = NO;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:OSCOutPortsAboutToChangeNotification object:self];
	
	[outPortArray wrlock];
		//if ([outPortArray count]>0)
		//	postNotification = YES;
		[outPortArray makeObjectsPerformSelector:@selector(prepareToBeDeleted)];
		[outPortArray removeAllObjects];
	[outPortArray unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:OSCOutPortsChangedNotification object:self];
	/*
	//	if there's a delegate and it responds to the setupChanged method, let it know that stuff changed
	if ((delegate!=nil)&&([delegate respondsToSelector:@selector(setupChanged)]))
		[delegate setupChanged];
	*/
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
		it = [[inPortArray array] objectEnumerator];
		while ((portPtr = [it nextObject]) && (!foundPortConflict) && (!foundNameConflict))	{
			if ([portPtr port] == p)
				foundPortConflict = YES;
			if (([portPtr portLabel]!=nil) && ([[portPtr portLabel] isEqualToString:l]))
				foundNameConflict = YES;
		}
		//	if there weren't any conflicts, make an instance set it up and add it to the array
		if ((!foundPortConflict) && (!foundNameConflict))	{
			returnMe = [[[self inPortClass] alloc] initWithPort:p labelled:l];
			
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
		[[NSNotificationCenter defaultCenter] postNotificationName:OSCInPortsChangedNotification object:self];
		/*
		//	if there's a delegate and it responds to the setupChanged method, let it know that stuff changed
		if ((delegate!=nil)&&([delegate respondsToSelector:@selector(setupChanged)]))
			[delegate setupChanged];
		*/
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
	
	[[NSNotificationCenter defaultCenter] postNotificationName:OSCOutPortsAboutToChangeNotification object:self];
	
	[outPortArray wrlock];
		//	check for name conflicts
		it = [[outPortArray array] objectEnumerator];
		while ((portPtr = [it nextObject]) && (!foundNameConflict))	{
			if (([portPtr portLabel]!=nil) && ([[portPtr portLabel] isEqualToString:l]))
				foundNameConflict = YES;
		}
		//	if there weren't any name conflicts, make an instance and add it to the array
		if (!foundNameConflict)	{
			returnMe = [[[self outPortClass] alloc] initWithAddress:a andPort:p labelled:l];
			
			if (returnMe != nil)	{
				[outPortArray addObject:returnMe];
				[returnMe autorelease];
			}
		}
	[outPortArray unlock];
	//	if i made an output, i need to tell the delegate that stuff changed
	//if (returnMe != nil)	{
		[[NSNotificationCenter defaultCenter] postNotificationName:OSCOutPortsChangedNotification object:self];
		/*
		//	if there's a delegate and it responds to the setupChanged method, let it know that stuff changed
		if ((delegate!=nil)&&([delegate respondsToSelector:@selector(setupChanged)]))
			[delegate setupChanged];
		*/
	//}
	
	return returnMe;
}
- (OSCOutPort *) createNewOutputToAddress:(NSString *)a atPort:(int)p	{
	//NSLog(@"%s ... %@, %ld",__func__,a,p);
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
#pragma mark --------------------- OSC query reply/error message dispatch
/*------------------------------------*/


//- (void) dispatchQuery:(OSCMessage *)m toOutPort:(OSCOutPort *)o	{
- (void) dispatchQuery:(OSCMessage *)m toOutPort:(OSCOutPort *)o timeout:(float)t replyHandler:(void (^)(OSCMessage *replyMsg))block	{
	if (m==nil || o==nil)
		return;
	OSCInPort			*inPort = [inPortArray lockObjectAtIndex:0];
	if (inPort == nil)
		return;
	[inPort dispatchQuery:m toOutPort:o timeout:t replyHandler:block];
}
- (void) dispatchQuery:(OSCMessage *)m toOutPort:(OSCOutPort *)o timeout:(float)t replyDelegate:(id <OSCQueryReplyDelegate>)d	{
	if (m==nil || o==nil)
		return;
	OSCInPort			*inPort = [inPortArray lockObjectAtIndex:0];
	if (inPort == nil)
		return;
	[inPort dispatchQuery:m toOutPort:o timeout:t replyDelegate:d];
}
- (void) transmitReplyOrError:(OSCMessage *)m	{
	//NSLog(@"%s ... %@",__func__,m);
	//	make sure that the passed message is either a reply or error
	OSCMessageType		mType = [m messageType];
	if (mType==OSCMessageTypeReply || mType==OSCMessageTypeError)	{
		//	make sure that the passed message has a valid reply-to address & port
		unsigned int		txAddr = [m queryTXAddress];
		unsigned short		txPort = [m queryTXPort];
		if (txAddr!=0 && txPort!=0)	{
			//	find the out port which corresponds to the reply-to address & port (create it if it can't be found)
			OSCOutPort		*outPort = [self findOutputWithRawAddress:txAddr andPort:txPort];
			if (outPort == nil)	{
				struct in_addr		tmpAddr;
				tmpAddr.s_addr = txAddr;
				outPort = [self
					createNewOutputToAddress:[NSString stringWithCString:inet_ntoa(tmpAddr) encoding:NSASCIIStringEncoding]
					atPort:ntohs(txPort)];
				//NSLog(@"\t\tcouldn't find output, created %@",outPort);
			}
			//	send the message out the port
			if (outPort != nil)	{
				//NSLog(@"\t\tfound matching output (%@), sending the reply...",outPort);
				[outPort sendThisMessage:m];
			}
		}
	}
	
}


/*===================================================================================*/
#pragma mark --------------------- working with ports
/*------------------------------------*/


- (NSString *) getUniqueInputLabel	{
	NSString		*tmpString = nil;
	BOOL			found = NO;
	//BOOL			alreadyInUse = NO;
	int				index = 1;
	
	while (!found)	{
#if IPHONE
		tmpString = [NSString stringWithFormat:@"%@ %@ %d",[[UIDevice currentDevice] name],[self inPortLabelBase],index];
#else
		CFStringRef computerName = SCDynamicStoreCopyComputerName(NULL, NULL);
		tmpString = [NSString stringWithFormat:@"%@ %@ %d",computerName,[self inPortLabelBase],index];
		if (computerName != NULL)
			CFRelease(computerName);
#endif
		//tmpString = [NSString stringWithFormat:@"%@ %d",[self inPortLabelBase],index];
		
		if ([self isUniqueInputLabel:tmpString])
			found = YES;
		
		++index;
	}
	
	return tmpString;
}
- (BOOL) isUniqueInputLabel:(NSString *)n	{
	BOOL		returnMe = YES;
	[inPortArray rdlock];
	for (OSCInPort *portPtr in [inPortArray array])	{
		if ([[portPtr portLabel] isEqualToString:n])	{
			returnMe = NO;
			break;
		}
	}
	[inPortArray unlock];
	
	if (returnMe)	{
		[outPortArray rdlock];
		for (OSCOutPort *portPtr in [outPortArray array])	{
			if ([[portPtr portLabel] isEqualToString:n])	{
				returnMe = NO;
				break;
			}
		}
		[outPortArray unlock];
	}
	return returnMe;
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
			tmpString = [NSString stringWithFormat:@"OSC Out Port %d",index];
			
			alreadyInUse = NO;
			it = [[outPortArray array] objectEnumerator];
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
	NSMutableArray		*matchingPorts = [self findInputsWithLabel:n];
	return (matchingPorts==nil) ? nil : [matchingPorts objectAtIndex:0];
}
- (NSMutableArray *) findInputsWithLabel:(NSString *)n	{
	if (n == nil)
		return nil;
	
	NSMutableArray	*returnMe = nil;
	[inPortArray rdlock];
	for (OSCInPort *portPtr in [inPortArray array])	{
		if ([[portPtr portLabel] isEqualToString:n])	{
			if (returnMe == nil)
				returnMe = [NSMutableArray arrayWithCapacity:0];
			[returnMe addObject:portPtr];
		}
	}
	[inPortArray unlock];
	return returnMe;
}
- (OSCOutPort *) findOutputWithLabel:(NSString *)n	{
	NSMutableArray		*matchingPorts = [self findOutputsWithLabel:n];
	return (matchingPorts==nil) ? nil : [matchingPorts objectAtIndex:0];
}
- (NSMutableArray *) findOutputsWithLabel:(NSString *)n	{
	if (n == nil)
		return nil;
	
	NSMutableArray	*returnMe = nil;
	[outPortArray rdlock];
	for (OSCOutPort *portPtr in [outPortArray array])	{
		if ([[portPtr portLabel] isEqualToString:n])	{
			if (returnMe == nil)
				returnMe = [NSMutableArray arrayWithCapacity:0];
			[returnMe addObject:portPtr];
		}
	}
	[outPortArray unlock];
	return returnMe;
}


- (OSCOutPort *) findOutputWithAddress:(NSString *)a andPort:(int)p	{
	if (a == nil)
		return nil;
	
	OSCOutPort		*foundPort = nil;
	NSEnumerator	*it;
	OSCOutPort		*portPtr = nil;
	
	[outPortArray rdlock];
		it = [[outPortArray array] objectEnumerator];
		while ((portPtr = [it nextObject]) && (foundPort == nil))	{
			if (([[portPtr addressString] isEqualToString:a]) && ([portPtr port] == p))	{
				foundPort = portPtr;
			}
		}
	[outPortArray unlock];
	
	return foundPort;
}
- (OSCOutPort *) findOutputWithRawAddress:(unsigned int)a andPort:(unsigned short)p	{
	OSCOutPort		*foundPort = nil;
	[outPortArray rdlock];
	for (OSCOutPort *outPortPtr in [outPortArray array])	{
		if ([outPortPtr _matchesRawAddress:a andPort:p])	{
			foundPort = outPortPtr;
			break;
		}
	}
	[outPortArray unlock];
	return foundPort;
}
- (OSCOutPort *) findOutputWithRawAddress:(unsigned int)a	{
	OSCOutPort		*foundPort = nil;
	[outPortArray rdlock];
	for (OSCOutPort *outPortPtr in [outPortArray array])	{
		if ([outPortPtr _matchesRawAddress:a])	{
			foundPort = outPortPtr;
			break;
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
	//NSLog(@"%s ... %@",__func__,n);
	if (n == nil)
		return nil;
	
	id				foundPort = nil;
	NSEnumerator	*it;
	id				anObj;
	
	[inPortArray rdlock];
		it = [[inPortArray array] objectEnumerator];
		while ((anObj = [it nextObject]) && (foundPort == nil))	{
			NSString		*objName = [anObj zeroConfName];
			if (objName!=nil && [objName isEqualToString:n])
				foundPort = anObj;
		}
	[inPortArray unlock];
	return foundPort;
}
- (void) removeInput:(id)p	{
	if (p == nil)
		return;
	BOOL				postNotification = NO;
	NSUInteger			origCount;
	[(OSCInPort *)p stop];
	[inPortArray wrlock];
		origCount = [inPortArray count];
		[inPortArray removeObject:p];
		if (origCount != [inPortArray count])
			postNotification = YES;
	[inPortArray unlock];
	if (postNotification)
		[[NSNotificationCenter defaultCenter] postNotificationName:OSCInPortsChangedNotification object:self];
	/*
	//	if there's a delegate and it responds to the setupChanged method, let it know that stuff changed
	if ((delegate!=nil)&&([delegate respondsToSelector:@selector(setupChanged)]))
		[delegate setupChanged];
	*/
}
- (void) removeOutput:(id)p	{
	if (p == nil)
		return;
	//BOOL				postNotification = NO;
	NSUInteger			origCount;
	//NSLog(@"\t\tfiring about-to-change notification");
	[[NSNotificationCenter defaultCenter] postNotificationName:OSCOutPortsAboutToChangeNotification object:self];
	
	[outPortArray wrlock];
		origCount = [outPortArray count];
		[outPortArray removeObject:p];
		//if (origCount != [outPortArray count])
		//	postNotification = YES;
	[outPortArray unlock];
	//NSLog(@"\t\tfiring done-changing notification");
	[[NSNotificationCenter defaultCenter] postNotificationName:OSCOutPortsChangedNotification object:self];
	/*
	//	if there's a delegate and it responds to the setupChanged method, let it know that stuff changed
	if ((delegate!=nil)&&([delegate respondsToSelector:@selector(setupChanged)]))
		[delegate setupChanged];
	*/
}
- (void) removeOutputWithLabel:(NSString *)n	{
	if (n==nil)
		return;
	[[NSNotificationCenter defaultCenter] postNotificationName:OSCOutPortsAboutToChangeNotification object:self];
	
	[outPortArray wrlock];
	int			indexToRemove = -1;
	int			tmpIndex = 0;
	//BOOL		postNote = NO;
	for (OSCOutPort *outPort in [outPortArray array])	{
		NSString		*tmpLabel = [outPort portLabel];
		if (tmpLabel!=nil && [tmpLabel isEqualToString:n])	{
			indexToRemove = tmpIndex;
			break;
		}
	}
	if (indexToRemove >= 0)	{
		//postNote = YES;
		[outPortArray removeObjectAtIndex:indexToRemove];
	}
	[outPortArray unlock];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:OSCOutPortsChangedNotification object:self];
}
- (void) removeAllOutputs	{
	//BOOL			postNote = ([outPortArray count]>0)?YES:NO;
	[[NSNotificationCenter defaultCenter] postNotificationName:OSCOutPortsAboutToChangeNotification object:self];
	[outPortArray lockRemoveAllObjects];
	//if (postNote)
		[[NSNotificationCenter defaultCenter] postNotificationName:OSCOutPortsChangedNotification object:self];
}
- (NSArray *) outPortLabelArray	{
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	NSEnumerator		*it;
	OSCOutPort			*portPtr;
	
	[outPortArray rdlock];
		it = [[outPortArray array] objectEnumerator];
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
	return inPortClass;
}
- (NSString *) inPortLabelBase	{
	return inPortLabelBase;
	/*
	if ((delegate!=nil)&&([delegate respondsToSelector:@selector(inPortLabelBase)]))
		return [delegate inPortLabelBase];
	return [NSString stringWithString:@"VVOSC"];
	*/
}
- (void) setInPortLabelBase:(NSString *)n	{
	if (n == nil)
		return;
	VVRELEASE(inPortLabelBase);
	inPortLabelBase = [n retain];
}
/*!
	by default, this method returns [OSCOutPort class].  it’s called when creating an input port. this method exists so if you subclass OSCOutPort you can override this method to have your manager create your custom subclass with the default port creation methods
*/
- (id) outPortClass	{
	return outPortClass;
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

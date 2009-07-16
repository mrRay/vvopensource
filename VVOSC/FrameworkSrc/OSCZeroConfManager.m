//
//  OSCZeroConfManager.m
//  VVOSC
//
//  Created by bagheera on 12/9/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCZeroConfManager.h"
#import "OSCManager.h"
#import "OSCInPort.h"




@implementation OSCZeroConfManager


- (id) initWithOSCManager:(id)m	{
	if (m == nil)
		goto BAIL;
	
	pthread_rwlockattr_t		attr;
	
	if (self = [super init])	{
		pthread_rwlockattr_init(&attr);
		pthread_rwlockattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
		pthread_rwlock_init(&domainLock, &attr);
		
		domainBrowser = [[NSNetServiceBrowser alloc] init];
		[domainBrowser setDelegate:self];
		[domainBrowser searchForRegistrationDomains];
		
		domainDict = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
		
		oscManager = m;
		
		return self;
	}
	
	BAIL:
	[self release];
	return nil;
}
- (void) dealloc	{
	oscManager = nil;
	pthread_rwlock_destroy(&domainLock);
	if (domainBrowser != nil)	{
		[domainBrowser stop];
		[domainBrowser release];
		domainBrowser = nil;
	}
	if (domainDict != nil)	{
		[domainDict release];
		domainDict = nil;
	}
	[super dealloc];
}




//	called when an osc service disappears
//	it finds an output matching the service being removed it will release the out port
- (void) serviceRemoved:(NSNetService *)s	{
	//NSLog(@"%s ... %@",__func__,[s name]);
	OSCOutPort		*foundPort = nil;
	//	try to find an out port in the manager with the same name
	foundPort = [oscManager findOutputWithLabel:[s name]];
	if (foundPort != nil)	{
		//	if i found the out port, delete it...make sure the list of sources gets updated
		[oscManager removeOutput:foundPort];
	}
}
//	called when an osc service (an osc destination) appears
//	it either updates an existing output port or it makes a new output port for the service
- (void) serviceResolved:(NSNetService *)s	{
	//NSLog(@"%s",__func__);
	OSCInPort			*matchingInPort = nil;
	OSCOutPort			*matchingOutPort = nil;
	NSArray				*addressArray = [s addresses];
	NSEnumerator		*it = [addressArray objectEnumerator];
	NSData				*data = nil;
	struct sockaddr_in	*sock = (struct sockaddr_in *)[data bytes];
	char				*charPtr = nil;
	NSString			*ipString = nil;
	unsigned short		port;
	NSString			*resolvedServiceName = [s name];
	
	//	find the ip address & port of the resolved service
	while ((charPtr == nil) && (data = [it nextObject]))	{
		sock = (struct sockaddr_in *)[data bytes];
		//	only continue if this is an IPv4 address (IPv6s resolve to 0.0.0.0)
		if (sock->sin_family == AF_INET)	{
			charPtr = inet_ntoa(sock->sin_addr);
		}
	}
	//	make an nsstring from the c string of the ip address string of the resolved service
	ipString = [NSString stringWithCString:charPtr encoding:NSASCIIStringEncoding];
	//	get the port of the resolved service
	port = ntohs(sock->sin_port);
	//NSLog(@"\t\tresolved service %@ at %@ : %ld",[s name],ipString,port);
	
	//	assemble an array with strings of the ip addresses this machine responds to
	NSCharacterSet		*charSet;
	NSMutableArray		*IPAddressArray = [NSMutableArray arrayWithCapacity:0];
	charSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefABCDEF:%"];
#if IPHONE
	
#else
	NSRange				charSetRange;
	NSEnumerator		*addressIt;
	NSString			*addressPtr;
	
	//	run through the array of addresses
	addressIt = [[[NSHost currentHost] addresses] objectEnumerator];
	while (addressPtr = [addressIt nextObject])	{
		//	if the address has any alpha-numeric characters, don't add it to the list
		charSetRange = [addressPtr rangeOfCharacterFromSet:charSet];
		if ((charSetRange.length==0) && (charSetRange.location==NSNotFound))	{
			//	make sure i'm not adding 127.0.0.1!
			if (![addressPtr isEqualToString:@"127.0.0.1"])
				[IPAddressArray addObject:addressPtr];
		}
	}
#endif
	
	//	if my osc manager publishes an input with the same name as the matching service,
	//	check to see if the port of the resolved service matches the input's port, bail if it does
	matchingInPort = [oscManager findInputWithZeroConfName:resolvedServiceName];
	if (matchingInPort != nil)	{
		if (([matchingInPort port]==port) && ([IPAddressArray containsObject:ipString]))
			return;
	}
	
	//	if i'm here, the service resolved to another osc manager
	//	try to find an out port in the osc manager with a matching name
	matchingOutPort = [oscManager findOutputWithLabel:[s name]];
	//	if i found a matching out port, update its ip address & port data, then return
	if (matchingOutPort != nil)	{
		[matchingOutPort setAddressString:ipString andPort:port];
		return;
	}
	
	//	this used to rename an output with the same IP address and port to match the
	//	name of the newly-appeared service.  i commented this out because if the service
	//	disappears it could inadvertently release an output port
	
	/*
	//	if i'm here, i couldn't find an out port with the same name...try to find an out port with the same ip/port data
	matchingOutPort = [oscManager findOutputWithAddress:ipString andPort:port];
	//	if i found a matching out port, update its name & return
	if (matchingOutPort != nil)	{
		[matchingOutPort setPortLabel:[s name]];
		return;
	}
	*/
	
	//	if i'm here, i couldn't find an out port with the same address/port
	//	make a new out port with the relevant data
	[oscManager createNewOutputToAddress:ipString atPort:port withLabel:[s name]];
	
}




//	NSNetServiceBrowser delegate methods
- (void)netServiceBrowser:(NSNetServiceBrowser *)n didFindDomain:(NSString *)d moreComing:(BOOL)m	{
	//NSLog(@"%s ... %@, %ld",__func__,d,m);
	OSCZeroConfDomain	*newDomain = nil;
	
	newDomain = [OSCZeroConfDomain createWithDomain:d andDomainManager:self];
	if (newDomain != nil)	{
		pthread_rwlock_wrlock(&domainLock);
			[domainDict setObject:newDomain forKey:d];
		pthread_rwlock_unlock(&domainLock);
	}
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)n didNotSearch:(NSDictionary *)err	{
	//NSLog(@"%s ... %@",__func__,err);
	NSLog(@"\t\terr, oscbm didn't search: %@",err);
}


@end


#import "OSCOutPort.h"




@implementation OSCOutPort


- (NSString *) description	{
	return [NSString stringWithFormat:@"<OSCOutPort %@:%ld>",addressString,port];
}
+ (id) createWithAddress:(NSString *)a andPort:(unsigned short)p	{
	OSCOutPort		*returnMe = [[OSCOutPort alloc] initWithAddress:a andPort:p];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithAddress:(NSString *)a andPort:(unsigned short)p labelled:(NSString *)l	{
	OSCOutPort		*returnMe = [[OSCOutPort alloc] initWithAddress:a andPort:p labelled:l];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}


- (id) initWithAddress:(NSString *)a andPort:(unsigned short)p	{
	return [self initWithAddress:a andPort:p labelled:nil];
}
- (id) initWithAddress:(NSString *)a andPort:(unsigned short)p labelled:(NSString *)l	{
	if ((a==nil) || (p<1024))
		goto BAIL;
	
	if (self = [super init])	{
		deleted = NO;
		sock = -1;
		port = p;
		addressString = [a retain];
		portLabel = nil;
		
		if (l != nil)
			portLabel = [l copy];
		
		//	if i can't make a socket, return nil
		if (![self createSocket])
			goto BAIL;
		
		return self;
	}
	
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	[self release];
	return nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (!deleted)
		[self prepareToBeDeleted];
	if (addressString != nil)
		[addressString release];
	addressString = nil;
	if (portLabel != nil)
		[portLabel release];
	portLabel = nil;
	[super dealloc];
}
- (void) prepareToBeDeleted	{
	deleted = YES;
}

- (NSDictionary *) createSnapshot	{
	NSMutableDictionary		*returnMe = [NSMutableDictionary dictionaryWithCapacity:0];
	
	if (addressString != nil)	{
		[returnMe setObject:addressString forKey:@"address"];
	}
	
	[returnMe setObject:[NSNumber numberWithInt:port] forKey:@"port"];
	
	if (portLabel != nil)	{
		[returnMe setObject:portLabel forKey:@"portLabel"];
	}
	
	return returnMe;
}

- (BOOL) createSocket	{
	sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (sock < 0)	{
		NSLog(@"\t\terr: OSCOutPort couldn't create the socket");
		return NO;
	}
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = inet_addr([addressString cStringUsingEncoding:NSASCIIStringEncoding]);
	memset(addr.sin_zero, '\0', sizeof(addr.sin_zero));
	addr.sin_port = htons(port);
	
	return YES;
}

- (void) sendThisBundle:(OSCBundle *)b	{
	if ((deleted) || (sock == -1) || (b == nil))
		return;
	
	OSCPacket		*newPacket = [OSCPacket createWithContent:b];
	
	if (newPacket != nil)
		[self sendThisPacket:newPacket];
}
- (void) sendThisMessage:(OSCMessage *)m	{
	if ((deleted) || (sock == -1) || (m == nil))
		return;
	
	OSCPacket		*newPacket = [OSCPacket createWithContent:m];
	
	if (newPacket != nil)
		[self sendThisPacket:newPacket];
}
- (void) sendThisPacket:(OSCPacket *)p	{
	//NSLog(@"%s",__func__);
	if ((deleted) || (sock == -1) || (p == nil))
		return;
	//	make sure the packet doesn't get released if its pool gets drained while i'm sending it
	[p retain];
	
	int				numBytesSent = -1;
	int				bufferSize = [p bufferLength];
	unsigned char	*buff = [p payload];
	
	if (buff == NULL)	{
		NSLog(@"\t\terr: packet's buffer was null");
		return;
	}
	//	send the packet's data to the destination
	numBytesSent = sendto(sock, buff, bufferSize, 0, (const struct sockaddr *)&addr, sizeof(addr));
	//	make sure the packet can be freed...
	[p release];
}

- (void) setAddressString:(NSString *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if ((n==nil) || ([addressString isEqualToString:n]))
		return;
	NSRange		bogusCharRange = [n rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]];
	if (bogusCharRange.location != NSNotFound)
		return;
	
	sock = -1;
	if (addressString != nil)
		[addressString release];
	addressString = [n retain];
	[self createSocket];
}
- (void) setPort:(unsigned short)p	{
	if ((p < 1024) || (p == port))
		return;
	sock = -1;
	port = p;
	[self createSocket];
}
- (void) setAddressString:(NSString *)n andPort:(unsigned short)p	{
	//	if the passed address is nil or the port is < 1024, return immediately
	if ((n == nil) || (p < 1024))
		return;
	//	if the new address AND port are the same as the current address/port, return immediately
	if (([n isEqualToString:addressString]) && (p == port))
		return;
	
	sock = -1;
	if (addressString != nil)
		[addressString release];
	addressString = [n retain];
	port = p;
	[self createSocket];
}

- (NSString *) portLabel	{
	return portLabel;
}
- (void) setPortLabel:(NSString *)n	{
	if (portLabel != nil)	{
		[portLabel release];
	}
	portLabel = nil;
	if (n != nil)	{
		portLabel = [n retain];
	}
}

- (unsigned short) port	{
	return port;
}
- (NSString *) addressString	{
	return addressString;
}


@end

//
//  OSCInPort.m
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCInPort.h"




@implementation OSCInPort


- (NSString *) description	{
	return [NSString stringWithFormat:@"<OSCInPort: %ld>",port];
}
+ (id) createWithPort:(unsigned short)p	{
	OSCInPort		*returnMe = [[OSCInPort alloc] initWithPort:p labelled:nil];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithPort:(unsigned short)p labelled:(NSString *)l	{
	OSCInPort		*returnMe = [[OSCInPort alloc] initWithPort:p labelled:l];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithPort:(unsigned short)p	{
	return [self initWithPort:p labelled:nil];
}
- (id) initWithPort:(unsigned short)p labelled:(NSString *)l	{
	pthread_mutexattr_t		attr;
	
	if (self = [super init])	{
		deleted = NO;
		port = p;
		
		pthread_mutexattr_init(&attr);
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
		pthread_mutex_init(&lock, &attr);
		
		threadLooper = [[VVThreadLoop alloc]
			initWithTimeInterval:0.03
			target:self
			selector:@selector(OSCThreadProc)];
		
		portLabel = nil;
		if (l != nil)
			portLabel = [l copy];
		
		scratchArray = [[NSMutableArray arrayWithCapacity:0] retain];
		
		delegate = nil;
		
		zeroConfDest = nil;
		
		bound = [self createSocket];
		if (!bound)
			goto BAIL;
		
		return self;
	}
	BAIL:
	[self release];
	return nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (!deleted)
		[self prepareToBeDeleted];
	
	if (threadLooper != nil)
		[threadLooper release];
	threadLooper = nil;
	
	if (scratchArray != nil)
		[scratchArray release];
	scratchArray = nil;
	
	if (portLabel != nil)
		[portLabel release];
	portLabel = nil;
	
	pthread_mutex_destroy(&lock);
	[super dealloc];
}
- (void) prepareToBeDeleted	{
	//NSLog(@"%s",__func__);
	delegate = nil;
	
	if ([threadLooper running])
		[self stop];
	close(sock);
	sock = -1;
	
	
	
	deleted = YES;
}

- (NSDictionary *) createSnapshot	{
	NSMutableDictionary		*returnMe = [NSMutableDictionary dictionaryWithCapacity:0];
	[returnMe setObject:[NSNumber numberWithInt:port] forKey:@"port"];
	if (portLabel != nil)
		[returnMe setObject:portLabel forKey:@"portLabel"];
	return returnMe;
}

- (BOOL) createSocket	{
	//	create a UDP socket
	sock = socket(PF_INET, SOCK_DGRAM, 0);
	if (sock < 0)
		return NO;
	//	set the socket to non-blocking
	//fcntl(sock, F_SETFL, 0_NONBLOCK);
	//	prep the sockaddr_in struct
	addr.sin_family = AF_INET;
	addr.sin_port = htons(port);
	addr.sin_addr.s_addr = htonl(INADDR_ANY);
	memset(addr.sin_zero, '\0', sizeof(addr.sin_zero));
	//	bind the socket
	if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0)	{
		NSLog(@"\t\terr: couldn't bind socket for OSC");
		return NO;
	}
	
	return YES;
}
- (void) start	{
	//NSLog(@"%s",__func__);
	
	//	return immediately if the thread looper's already running
	if ([threadLooper running])
		return;
	
	[threadLooper start];
	
	//	if there's a port name, create a NSNetService so devices using bonjour know they can send data to me
	if (portLabel != nil)	{
		//NSLog(@"\t\tpublishing zeroConf: %ld, %@ %@",port,CSCopyMachineName(),portLabel);
		if (zeroConfDest != nil)	{
			[zeroConfDest stop];
			[zeroConfDest release];
		}
		zeroConfDest = [[NSNetService alloc]
			initWithDomain:@"local."
			type:@"_osc._udp."
#if IPHONE
			name:nil
#else
			name:[NSString stringWithFormat:@"%@ %@",CSCopyMachineName(),portLabel]
#endif
			port:port];
		[zeroConfDest publish];
	}
	else
		NSLog(@"\t\terr: couldn't make zero conf dest, portLabel was nil");
	
}
- (void) stop	{
	//NSLog(@"%s",__func__);
	
	//	stop & release the bonjour service
	if (zeroConfDest != nil)	{
		[zeroConfDest stop];
		[zeroConfDest release];
		zeroConfDest = nil;
	}
	
	[threadLooper stopAndWaitUntilDone];
}

- (void) OSCThreadProc	{
	//NSLog(@"%s",__func__);
	
	//	if i'm not bound, return
	if (!bound)
		return;
	
	fd_set				readFileDescriptor;
	int					readyFileCount;
	struct timeval		timeout;
	
	//	set up the file descriptors and timeout struct
	FD_ZERO(&readFileDescriptor);
	FD_SET(sock, &readFileDescriptor);
	timeout.tv_sec = 0;
	timeout.tv_usec = 10000;		//	0.01 secs = 100hz
	
	//	figure out if there are any open file descriptors
	readyFileCount = select(sock+1, &readFileDescriptor, (fd_set *)NULL, (fd_set *)NULL, &timeout);
	if (readyFileCount < 0)	{	//	if there was an error, bail immediately
		NSLog(@"\t\terr: socket got closed unexpectedly");
		[self stop];
	}
	//NSLog(@"\t\tcounted %ld ready files",readyFileCount);
	//	if the socket is one of the file descriptors, i need to get data from it
	while (FD_ISSET(sock, &readFileDescriptor))	{
		//NSLog(@"\t\twhile/packet ping");
		//	if i'm no longer supposed to be running, kill the thread
		if (![threadLooper running])
			return;
		
		struct sockaddr_in		addrFrom;
		socklen_t				addrFromLen;
		int						numBytes;
		BOOL					skipThisPacket = NO;
		
		addrFromLen = sizeof(addrFrom);
		numBytes = recvfrom(sock, buf, 8192, 0, (struct sockaddr *)&addrFrom, &addrFromLen);
		if (numBytes < 1)	{
			NSLog(@"\t\terr on recvfrom: %i",errno);
			skipThisPacket = YES;
		}
		if (numBytes % 4)	{
			NSLog(@"\t\terr: bytes isn't multiple of 4");
			skipThisPacket = YES;
		}
		
		if (!skipThisPacket)	{
			buf[numBytes] = '\0';
			
			//	if i've reached this point, i have a buffer of the appropriate
			//	length which needs to be parsed.  the buffer doesn't contain
			//	multiple messages, or multiple root-level bundles
			[self parseRawBuffer:buf ofMaxLength:numBytes];
		}
		
		readyFileCount = select(sock+1, &readFileDescriptor, (fd_set *)NULL, (fd_set *)NULL, &timeout);
	}
	//	if there's stuff in the scratch dict, i have to pass the info on to my delegate
	if ([scratchArray count] > 0)	{
		NSArray				*tmpArray = nil;
		
		pthread_mutex_lock(&lock);
			tmpArray = [NSArray arrayWithArray:scratchArray];
			[scratchArray removeAllObjects];
		pthread_mutex_unlock(&lock);
		
		[self handleScratchArray:tmpArray];
	}
}
/*
	this method exists so subclasses of OSCInPort can subclass around this for custom behavior
*/
- (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l	{
	//NSLog(@"%s ... %s, %ld",__func__,b,l);
	[OSCPacket
		parseRawBuffer:b
		ofMaxLength:l
		toInPort:self];
}
/*!
	if you don't want to bother with delegates (or you're not using OSCManager), you can override this method in your subclass of OSCInPort to receive an array of AddressValPair objects.  by default, this method just calls "receivedOSCMessage:" with the in port's delegate for each of the items in the passed array.
*/
- (void) handleScratchArray:(NSArray *)a	{
	//NSLog(@"%s",__func__);
	if ((delegate != nil) && ([delegate respondsToSelector:@selector(receivedOSCMessage:)]))	{
		NSEnumerator		*it = [a objectEnumerator];
		OSCMessage			*anObj;
		while (anObj = [it nextObject])	{
			[delegate receivedOSCMessage:anObj];
		}
	}
}
/*
	this method exists so received OSCMessage objects can be added to my scratch dict and scratch array for output.  you should never need to call this method!
*/
- (void) addValue:(OSCMessage *)val toAddressPath:(NSString *)p	{
	//NSLog(@"%s ... %@",__func__,val);
	if ((val == nil) || (p == nil))
		return;
	
	pthread_mutex_lock(&lock);
		//	add the osc path msg to the scratch array
		[scratchArray addObject:val];
	pthread_mutex_unlock(&lock);
}

- (unsigned short) port	{
	return port;
}
- (void) setPort:(unsigned short)n	{
	if (n == port)
		return;
	
	unsigned short		oldPort = port;
	
	//	stop & close my socket
	[self stop];
	close(sock);
	sock = -1;
	//	clear out the scratch dict/array
	pthread_mutex_lock(&lock);
		if (scratchArray != nil)
			[scratchArray removeAllObjects];
	pthread_mutex_unlock(&lock);
	//	set up with the new port
	bound = NO;
	port = n;
	bound = [self createSocket];
	//	if i'm bound, start- if i'm not bound, something went wrong- use my old port
	if (bound)
		[self start];
	else	{
		//	close the socket
		close(sock);
		sock = -1;
		//	clear out the scratch dict
		pthread_mutex_lock(&lock);
			if (scratchArray != nil)
				[scratchArray removeAllObjects];
		pthread_mutex_unlock(&lock);
		//	set up with the old port
		bound = NO;
		port = oldPort;
		bound = [self createSocket];
		if (bound)
			[self start];
	}
}
- (NSString *) portLabel	{
	return portLabel;
}
- (void) setPortLabel:(NSString *)n	{
	if ((n != nil) && (portLabel != nil) && ([n isEqualToString:portLabel]))
		return;
	
	[self stop];
	
	if (portLabel != nil)
		[portLabel release];
	portLabel = nil;
	
	if (n != nil)
		portLabel = [n copy];
	
	[self start];
}
- (NSNetService *) zeroConfDest	{
	return zeroConfDest;
}
- (BOOL) bound	{
	return bound;
}
- (id) delegate	{
	return delegate;
}
- (void) setDelegate:(id)n	{
	delegate = n;
}


@end

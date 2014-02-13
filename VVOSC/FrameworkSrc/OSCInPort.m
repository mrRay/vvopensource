
#import "OSCInPort.h"
#import "VVOSC.h"
#import <SystemConfiguration/SystemConfiguration.h>




@implementation OSCInPort


- (NSString *) description	{
	return [NSString stringWithFormat:@"<OSCInPort: %hd>",port];
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
	if (self = [super init])	{
		deleted = NO;
		bound = NO;
		socketLock = OS_SPINLOCK_INIT;
		sock = -1;
		port = p;
		buf = malloc(65506);
		interval = 1.0/100.0;
		
		scratchLock = OS_SPINLOCK_INIT;
		/*
		threadLooper = [[VVThreadLoop alloc]
			initWithTimeInterval:1.0/30.0
			target:self
			selector:@selector(OSCThreadProc)];
		*/
		thread = nil;
		timeoutSWatch = [[VVStopwatch alloc] init];
		queryDict = [[MutLockDict alloc] init];
		
		portLabel = nil;
		if (l != nil)
			portLabel = [l copy];
		zeroConfSwatch = [[VVStopwatch alloc] init];
		zeroConfLock = OS_SPINLOCK_INIT;
		
		scratchArray = [[NSMutableArray arrayWithCapacity:0] retain];
		
		delegate = nil;
		
		zeroConfDest = nil;
		
		bound = [self createSocket];
		if (!bound)
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
	/*
	if (threadLooper != nil)
		[threadLooper release];
	threadLooper = nil;
	*/
	VVRELEASE(scratchArray);
	VVRELEASE(timeoutSWatch);
	if (queryDict != nil)
		[queryDict release];
	queryDict = nil;
	
	if (portLabel != nil)
		[portLabel release];
	portLabel = nil;
	OSSpinLockLock(&zeroConfLock);
	VVRELEASE(zeroConfSwatch);
	OSSpinLockUnlock(&zeroConfLock);
	
	if (buf != nil)	{
		free(buf);
		buf = nil;
	}
	
	[super dealloc];
}
- (void) prepareToBeDeleted	{
	//NSLog(@"%s",__func__);
	delegate = nil;
	/*
	if ([threadLooper running])
		[self stop];
	*/
	if (thread!=nil && ![thread isCancelled])
		[self stop];
	
	OSSpinLockLock(&socketLock);
	close(sock);
	sock = -1;
	OSSpinLockUnlock(&socketLock);
	
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
	//NSLog(@"%s",__func__);
	OSSpinLockLock(&socketLock);
	//	create a UDP socket
	sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (sock < 0)	{
		OSSpinLockUnlock(&socketLock);
		return NO;
	}
	//	set the socket to non-blocking
	//fcntl(sock, F_SETFL, 0_NONBLOCK);
	/*
	//	specify that the socket can be reused or you may not be able to bind to it
	int			yes = 1;
	if (setsockopt(sock,SOL_SOCKET,SO_REUSEADDR,&yes,sizeof(int)) != 0)	{
		NSLog(@"\t\terr %ld at setsockopt A in %s",errno,__func__);
	}
	if (setsockopt(sock,SOL_SOCKET,SO_REUSEPORT,&yes,sizeof(int)) != 0)	{
		NSLog(@"\t\terr %ld at setsockopt B in %s",errno,__func__);
	}
	*/
	//	prep the sockaddr_in struct
	addr.sin_family = AF_INET;
	addr.sin_port = htons(port);
	addr.sin_addr.s_addr = htonl(INADDR_ANY);
	memset(addr.sin_zero, '\0', sizeof(addr.sin_zero));
	//	bind the socket
	if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0)	{
		NSLog(@"\t\terr: couldn't bind socket for OSC");
		OSSpinLockUnlock(&socketLock);
		return NO;
	}
	
	long			bufSize = 65506;
	if (setsockopt(sock,SOL_SOCKET,SO_RCVBUF,&bufSize,sizeof(long)) != 0)	{
		NSLog(@"\t\terr %d at setsockopt() in %s",errno,__func__);
	}
	
	OSSpinLockUnlock(&socketLock);
	return YES;
}
- (void) start	{
	//NSLog(@"%s",__func__);
	
	//	return immediately if the thread looper's already running
	/*
	if ([threadLooper running])
		return;
	*/
	if (thread!=nil && ![thread isFinished] && ![thread isCancelled])
		return;
	
	/*
	[threadLooper start];
	*/
	[NSThread
		detachNewThreadSelector:@selector(OSCThreadProc)
		toTarget:self
		withObject:nil];
	
	//	if there's an NSNetService, release it and start a stopwatch (new services are created on a time-delay otherwise changes to ports are ignored)
	OSSpinLockLock(&zeroConfLock);
	VVRELEASE(zeroConfDest);
	[zeroConfSwatch start];
	OSSpinLockUnlock(&zeroConfLock);
	
}
- (void) stop	{
	//NSLog(@"%s",__func__);
	
	if (![NSThread isMainThread])	{
		[self performSelectorOnMainThread:@selector(stop) withObject:nil waitUntilDone:NO];
		return;
	}
	
	//	stop the bonjour service but dont release it yet
	OSSpinLockLock(&zeroConfLock);
	if (zeroConfDest != nil)	{
		[zeroConfDest stop];
	}
	OSSpinLockUnlock(&zeroConfLock);
	/*
	[threadLooper stopAndWaitUntilDone];
	*/
	if (thread != nil)	{
		[thread cancel];
		while (thread != nil)
			usleep(100);
	}
}
- (void) OSCThreadProc	{
	NSAutoreleasePool			*pool = [[NSAutoreleasePool alloc] init];
	
	thread = [NSThread currentThread];
	if ([NSThread threadPriority]!=1.0)
		[NSThread setThreadPriority:1.0];
	
	STARTLOOP:
	@try	{
		while (thread!=nil && ![thread isCancelled] && bound)	{
			fd_set				readFileDescriptor;
			int					readyFileCount;
			struct timeval		timeout;
			
			//	set up the file descriptors and timeout struct
			FD_ZERO(&readFileDescriptor);
			FD_SET(sock, &readFileDescriptor);
			timeout.tv_sec = 0;
			timeout.tv_usec = 1000;		//	0.01 secs = 100hz
			
			OSSpinLockLock(&socketLock);
			//	figure out if there are any open file descriptors
			readyFileCount = select(sock+1, &readFileDescriptor, (fd_set *)NULL, (fd_set *)NULL, &timeout);
			if (readyFileCount < 1)	{	//	if there was an error, bail immediately
				OSSpinLockUnlock(&socketLock);
				if (readyFileCount < 0)	{
					NSLog(@"\t\terr: socket got closed unexpectedly");
					[self stop];
				}
			}
			
			//	if the socket is one of the file descriptors, i need to get data from it
			while (FD_ISSET(sock, &readFileDescriptor))	{
				//NSLog(@"\t\twhile/packet ping");
				struct sockaddr_in		addrFrom;
				memset(&addrFrom,0,sizeof(addrFrom));
				addrFrom.sin_family = AF_INET;
				socklen_t				addrFromLen = sizeof(struct sockaddr_in);
				int						numBytes;
				BOOL					skipThisPacket = NO;
				
				addrFromLen = sizeof(addrFrom);
				numBytes = (int)recvfrom(sock, buf, 65506, 0, (struct sockaddr *)&addrFrom, &addrFromLen);
				if (numBytes < 1)	{
					NSLog(@"\t\terr on recvfrom: %i",errno);
					skipThisPacket = YES;
				}
				if (numBytes % 4)	{
					NSLog(@"\t\terr: bytes isn't multiple of 4 in %s",__func__);
					skipThisPacket = YES;
				}
				
				if (!skipThisPacket)	{
					buf[numBytes] = '\0';
					
					//	if i've reached this point, i have a buffer of the appropriate
					//	length which needs to be parsed.  the buffer doesn't contain
					//	multiple messages, or multiple root-level bundles
					[self
						parseRawBuffer:buf
						ofMaxLength:numBytes
						fromAddr:(unsigned int)addrFrom.sin_addr.s_addr
						port:(unsigned short)addrFrom.sin_port];
				}
				
				readyFileCount = select(sock+1, &readFileDescriptor, (fd_set *)NULL, (fd_set *)NULL, &timeout);
			}
			OSSpinLockUnlock(&socketLock);
			//	if there's stuff in the scratch dict, i have to pass the info on to my delegate
			if ([scratchArray count] > 0)	{
				NSArray				*tmpArray = nil;
				
				OSSpinLockLock(&scratchLock);
					tmpArray = [NSArray arrayWithArray:scratchArray];
					[scratchArray removeAllObjects];
				OSSpinLockUnlock(&scratchLock);
				
				[self handleScratchArray:tmpArray];
			}
			//	check the query dict occasionally for queries which have timed out and need a reply
			if ([timeoutSWatch timeSinceStart]>0.5)	{
				[queryDict wrlock];
				__block NSMutableArray		*stringsToRemove = nil;
				__block NSMutableArray		*expiredQueries = nil;
				NSDate						*nowDate = [NSDate date];
				[[queryDict dict] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)	{
					//	if the query's timeout has expired
					if ([obj _timeoutCheckAgainstDate:nowDate])	{
						//	store the string (i need to remove the query from the dict)
						if (stringsToRemove==nil)
							stringsToRemove = [[NSMutableArray alloc] initWithCapacity:0];
						[stringsToRemove addObject:key];
						//	store the query (i have to dispatch an error for the timeout after removing them)
						if (expiredQueries==nil)
							expiredQueries = [[NSMutableArray alloc] initWithCapacity:0];
						[expiredQueries addObject:obj];
					}
				}];
				if (stringsToRemove != nil)
					[[queryDict dict] removeObjectsForKeys:stringsToRemove];
				[queryDict unlock];
				
				[timeoutSWatch start];
				
				//	now that the query dict has been re-locked, send error messages for all the expired queries
				for (OSCQueryReply *queryReply in expiredQueries)	{
					[queryReply dispatchReply:[OSCMessage createErrorForMessage:[queryReply initialQuery]]];
				}
				
				VVRELEASE(stringsToRemove);
				VVRELEASE(expiredQueries);
			}
			//	is it time to start advertising a bonjour/zeroconf service yet?
			if (zeroConfDest==nil)	{
				OSSpinLockLock(&zeroConfLock);
				if (zeroConfDest==nil && portLabel!=nil && [zeroConfSwatch timeSinceStart]>1.0)	{
					zeroConfDest = [[NSNetService alloc]
						initWithDomain:@"local."
						type:@"_osc._udp."
//#if IPHONE
//						name:[NSString stringWithFormat:@"%@ %@",[[UIDevice currentDevice] name],portLabel]
//#else
//						name:[NSString stringWithFormat:@"%@ %@",SCDynamicStoreCopyComputerName(NULL, NULL),portLabel]
//#endif
						name:portLabel
						port:port];
					[zeroConfDest publish];
				}
				OSSpinLockUnlock(&zeroConfLock);
			}
			
			
			{
				NSAutoreleasePool		*oldPool = pool;
				pool = nil;
				[oldPool release];
				pool = [[NSAutoreleasePool alloc] init];
			}
			
			if (interval > 0.0)
				[NSThread sleepForTimeInterval:interval];
		}
	}
	@catch (NSException *err)	{
		NSAutoreleasePool		*oldPool = pool;
		pool = nil;
		NSLog(@"\t\t%s caught exception %@ on %@",__func__,err,self);
		@try {
			[oldPool release];
		}
		@catch (NSException *subErr)	{
			NSLog(@"\t\t%s caught sub-exception %@ on %@",__func__,subErr,self);
		}
		pool = [[NSAutoreleasePool alloc] init];
		goto STARTLOOP;
	}
	
	thread = nil;
	
	[pool release];
}

/*
- (void) OSCThreadProc	{
	//NSLog(@"%s",__func__);
	
	if ([NSThread threadPriority]!=1.0)
		[NSThread setThreadPriority:1.0];
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
	
	OSSpinLockLock(&socketLock);
	//	figure out if there are any open file descriptors
	readyFileCount = select(sock+1, &readFileDescriptor, (fd_set *)NULL, (fd_set *)NULL, &timeout);
	if (readyFileCount < 1)	{	//	if there was an error, bail immediately
		OSSpinLockUnlock(&socketLock);
		if (readyFileCount < 0)	{
			NSLog(@"\t\terr: socket got closed unexpectedly");
			[self stop];
		}
	}
	//NSLog(@"\t\tcounted %ld ready files",readyFileCount);
	//	if the socket is one of the file descriptors, i need to get data from it
	while (FD_ISSET(sock, &readFileDescriptor))	{
		//NSLog(@"\t\twhile/packet ping");
		//	if i'm no longer supposed to be running, kill the thread
		if (![threadLooper running])	{
			OSSpinLockUnlock(&socketLock);
			return;
		}
		
		struct sockaddr_in		addrFrom;
		memset(&addrFrom,0,sizeof(addrFrom));
		addrFrom.sin_family = AF_INET;
		socklen_t				addrFromLen = sizeof(struct sockaddr_in);
		int						numBytes;
		BOOL					skipThisPacket = NO;
		
		addrFromLen = sizeof(addrFrom);
		numBytes = (int)recvfrom(sock, buf, 65506, 0, (struct sockaddr *)&addrFrom, &addrFromLen);
		if (numBytes < 1)	{
			NSLog(@"\t\terr on recvfrom: %i",errno);
			skipThisPacket = YES;
		}
		if (numBytes % 4)	{
			NSLog(@"\t\terr: bytes isn't multiple of 4 in %s",__func__);
			skipThisPacket = YES;
		}
		
		if (!skipThisPacket)	{
			buf[numBytes] = '\0';
			
			//	if i've reached this point, i have a buffer of the appropriate
			//	length which needs to be parsed.  the buffer doesn't contain
			//	multiple messages, or multiple root-level bundles
			[self
				parseRawBuffer:buf
				ofMaxLength:numBytes
				fromAddr:(unsigned int)addrFrom.sin_addr.s_addr
				port:(unsigned short)addrFrom.sin_port];
		}
		
		readyFileCount = select(sock+1, &readFileDescriptor, (fd_set *)NULL, (fd_set *)NULL, &timeout);
	}
	OSSpinLockUnlock(&socketLock);
	//	if there's stuff in the scratch dict, i have to pass the info on to my delegate
	if ([scratchArray count] > 0)	{
		NSArray				*tmpArray = nil;
		
		OSSpinLockLock(&scratchLock);
			tmpArray = [NSArray arrayWithArray:scratchArray];
			[scratchArray removeAllObjects];
		OSSpinLockUnlock(&scratchLock);
		
		[self handleScratchArray:tmpArray];
	}
}
*/


/*
	this method exists so subclasses of OSCInPort can subclass around this for custom behavior
*/
- (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l fromAddr:(unsigned int)txAddr port:(unsigned short)txPort	{
	//NSLog(@"%s ... %s, %ld",__func__,b,l);
	[OSCPacket
		parseRawBuffer:b
		ofMaxLength:l
		toInPort:self
		fromAddr:txAddr
		port:txPort];
}

/*!
	if you don't want to bother with delegates (or you're not using OSCManager), you can override this method in your subclass of OSCInPort to receive an array of OSCMessage objects.  by default, this method just calls "receivedOSCMessage:" with the in port's delegate for each of the items in the passed array.
*/
- (void) handleScratchArray:(NSArray *)a	{
	//NSLog(@"%s",__func__);
	if ((delegate != nil) && ([delegate respondsToSelector:@selector(receivedOSCMessage:)]))	{
		for (OSCMessage *msg in a)	{
			OSCMessageType		msgType = [msg messageType];
			switch (msgType)	{
				//	control messages and received queries get handled "normally" (the delegate is told that it has received an OSC message)
				case OSCMessageTypeControl:
				case OSCMessageTypeQuery:
					[delegate receivedOSCMessage:msg];
					break;
				//	replies & errors are received as a result of queries sent from this in port: look for an object in the queryDict!
				case OSCMessageTypeReply:
				case OSCMessageTypeError:
					{
						OSCValue			*parsedQueryStringVal = [msg value];
						NSString			*stringVal = [parsedQueryStringVal stringValue];
						
						[queryDict wrlock];
						OSCQueryReply		*queryReplyObj = [queryDict objectForKey:stringVal];
						if (queryReplyObj != nil)	{
							[queryReplyObj retain];
							[queryDict removeObjectForKey:stringVal];
							[queryDict unlock];
							
							[queryReplyObj dispatchReply:msg];
							[queryReplyObj release];
						}
						else
							[queryDict unlock];
					}
					break;
				case OSCMessageTypeUnknown:
					break;
			}
		}
	}
}
/*
	this method exists so received OSCMessage objects can be added to my scratch dict and scratch array for output.  you should never need to call this method!
*/
- (void) _addMessage:(OSCMessage *)val	{
	//NSLog(@"%s ... %@",__func__,val);
	if (val == nil)
		return;
	
	OSSpinLockLock(&scratchLock);
		//	add the osc path msg to the scratch array
		[scratchArray addObject:val];
	OSSpinLockUnlock(&scratchLock);
}

- (void) _dispatchQuery:(OSCMessage *)m toOutPort:(OSCOutPort *)o	{
	//NSLog(@"%s ... %@, %@",__func__,m,o);
	if (deleted || m==nil || o==nil || (sock==-1))
		return;
	OSCPacket		*pack = [OSCPacket createWithContent:m];
	if (pack == nil)
		return;
	//	make sure the packet doesn't get released if its pool gets drained while i'm sending it
	[pack retain];
	//[self stop];
	int				numBytesSent = -1;
	long			bufferSize = [pack bufferLength];
	unsigned char	*buff = [pack payload];
	if (buff == nil)	{
		NSLog(@"\t\terr, buff nil in %s",__func__);
		[pack release];
		return;
	}
	struct sockaddr_in	*outAddr = [o addr];
	
	OSSpinLockLock(&socketLock);
	numBytesSent = (int)sendto(sock,buff,bufferSize,0,(const struct sockaddr *)outAddr,sizeof(*outAddr));
	OSSpinLockUnlock(&socketLock);
	//[self start];
	[pack release];
}





///	Only used to support the (non-specification) OSC query protocol.  All queries should be sent via one of these methods (the query has to actually be sent from an input port, or the client won't know what to reply to- the manager takes care of this, and also checks timeouts).
- (void) dispatchQuery:(OSCMessage *)m toOutPort:(OSCOutPort *)o timeout:(float)t replyHandler:(void (^)(OSCMessage *replyMsg))block	{
	//NSLog(@"%s",__func__);
	//NSLog(@"\t\tquery is %@",m);
	if (m==nil || o==nil || (sock==-1))
		return;
	OSCMessageType		mType = [m messageType];
	if (mType != OSCMessageTypeQuery)
		return;
	//	get the reply address for the message (which basically represents the query with a unique string, and will be echoed back with the reply)
	NSString			*replyAddress = [m replyAddress];
	//NSLog(@"\t\treplyAddress is %@, length is %d",replyAddress,[replyAddress length]);
	OSCQueryReply		*replyObj = [[OSCQueryReply alloc] initWithQuery:m timeout:t replyBlock:block];
	[queryDict lockSetObject:replyObj forKey:replyAddress];
	[replyObj release];
	replyObj = nil;
	
	[self _dispatchQuery:m toOutPort:o];
}
- (void) dispatchQuery:(OSCMessage *)m toOutPort:(OSCOutPort *)o timeout:(float)t replyDelegate:(id <OSCQueryReplyDelegate>)d	{
	//NSLog(@"%s",__func__);
	//NSLog(@"\t\tquery is %@",m);
	if (m==nil || o==nil || (sock==-1))
		return;
	OSCMessageType		mType = [m messageType];
	if (mType != OSCMessageTypeQuery)
		return;
	//	get the reply address for the message (which basically represents the query with a unique string, and will be echoed back with the reply)
	NSString			*replyAddress = [m replyAddress];
	//NSLog(@"\t\treplyAddress is %@, length is %d",replyAddress,[replyAddress length]);
	OSCQueryReply		*replyObj = [[OSCQueryReply alloc] initWithQuery:m timeout:t replyDelegate:d];
	[queryDict lockSetObject:replyObj forKey:replyAddress];
	[replyObj release];
	replyObj = nil;
	
	[self _dispatchQuery:m toOutPort:o];
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
	
	OSSpinLockLock(&socketLock);
	close(sock);
	sock = -1;
	OSSpinLockUnlock(&socketLock);
	
	//	clear out the scratch dict/array
	OSSpinLockLock(&scratchLock);
		if (scratchArray != nil)
			[scratchArray removeAllObjects];
	OSSpinLockUnlock(&scratchLock);
	//	set up with the new port
	bound = NO;
	port = n;
	bound = [self createSocket];
	//	if i'm bound, start- if i'm not bound, something went wrong- use my old port
	if (bound)
		[self start];
	else	{
		//	close the socket
		OSSpinLockLock(&socketLock);
		close(sock);
		sock = -1;
		OSSpinLockUnlock(&socketLock);
		//	clear out the scratch dict
		OSSpinLockLock(&scratchLock);
			if (scratchArray != nil)
				[scratchArray removeAllObjects];
		OSSpinLockUnlock(&scratchLock);
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
	
	[[NSNotificationCenter defaultCenter] postNotificationName:OSCInPortsChangedNotification object:nil];
}
- (NSString *) zeroConfName	{
	NSString		*returnMe = nil;
	OSSpinLockLock(&zeroConfLock);
	returnMe = (zeroConfDest==nil) ? nil : [zeroConfDest name];
	OSSpinLockUnlock(&zeroConfLock);
	return returnMe;
}
- (BOOL) bound	{
	return bound;
}
- (NSString *) ipAddressString	{
	if (deleted || !bound)
		return nil;
	return [NSString stringFromRawIPAddress:addr.sin_addr.s_addr];
}
- (id) delegate	{
	return delegate;
}
- (void) setDelegate:(id)n	{
	delegate = n;
}
- (void) setInterval:(double)n	{
	interval = fmax(0.0, n);
}


@end

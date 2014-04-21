
#import "OSCMessage.h"
#import "OSCInPort.h"
#import "OSCStringAdditions.h"




@implementation OSCMessage


- (NSString *) description	{
	NSString			*baseDescription = nil;
	
	switch (messageType)	{
		case OSCMessageTypeControl:
			baseDescription = [self _description];
			return [NSString stringWithFormat:@"<OSCMessage %@>",baseDescription];
		case OSCMessageTypeQuery:
			baseDescription = [self _description];
			//return [NSString stringWithFormat:@"<OSCMsg Query %ld %@>",queryType,baseDescription];
			switch (queryType)	{
				case OSCQueryTypeUnknown:
					return [NSString stringWithFormat:@"<OSCMsg unknown query %@>",baseDescription];
				case OSCQueryTypeNamespaceExploration:
					return [NSString stringWithFormat:@"<OSCMsg namespace query %@>",baseDescription];
				case OSCQueryTypeDocumentation:
					return [NSString stringWithFormat:@"<OSCMsg doc query %@>",baseDescription];
				case OSCQueryTypeTypeSignature:
					return [NSString stringWithFormat:@"<OSCMsg type sig query %@>",address];
				case OSCQueryTypeCurrentValue:
					return [NSString stringWithFormat:@"<OSCMsg current val query %@>",address];
				case OSCQueryTypeReturnTypeSignature:
					return [NSString stringWithFormat:@"<OSCMsg return type query %@>",address];
			}
		case OSCMessageTypeReply:
			if (valueCount < 2)
				return [NSString stringWithFormat:@"<OSCMsg Reply %@>",value];
			else
				return [NSString stringWithFormat:@"<OSCMsg Reply %@>",valueArray];
		case OSCMessageTypeError:
			if (valueCount < 2)
				return [NSString stringWithFormat:@"<OSCMsg Err %@>",value];
			else
				return [NSString stringWithFormat:@"<OSCMsg Err %@>",valueArray];
		case OSCMessageTypeUnknown:
			if (valueCount < 2)
				return [NSString stringWithFormat:@"<OSCMsg ? %@>",value];
			else
				return [NSString stringWithFormat:@"<OSCMsg ? %@>",valueArray];
	}
	return [NSString stringWithFormat:@"<OSCMessage %@>",baseDescription];
}
- (NSString *) _description	{
	if (valueCount < 1)
		return [NSString stringWithFormat:@"'%@'",address];
	else if (valueCount < 2)
		return [NSString stringWithFormat:@"'%@', '%@'",address,value];
	else
		return [NSString stringWithFormat:@"'%@'-'%@'",address,valueArray];
}
+ (OSCMessage *) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l fromAddr:(unsigned int)txAddr port:(unsigned short)txPort	{
	//NSLog(@"%s",__func__);
	if ((b == nil) || (l == 0))
		return nil;
	/*
	printf("******************************\n");
	int				bundleIndexCount;
	unsigned char	*bufferCharPtr=b;
	for (bundleIndexCount=0; bundleIndexCount<(l/4); ++bundleIndexCount)	{
		printf("(%0.2d)\t\t%c\t%c\t%c\t%c\t\t%d\t\t%d\t\t%d\t\t%d\n",bundleIndexCount * 4,
			*(bufferCharPtr+bundleIndexCount*4), *(bufferCharPtr+bundleIndexCount*4+1), *(bufferCharPtr+bundleIndexCount*4+2), *(bufferCharPtr+bundleIndexCount*4+3),
			*(bufferCharPtr+bundleIndexCount*4), *(bufferCharPtr+bundleIndexCount*4+1), *(bufferCharPtr+bundleIndexCount*4+2), *(bufferCharPtr+bundleIndexCount*4+3));
	}
	printf("******************************\n");
	*/
	OSCMessage			*returnMe = nil;
	NSString			*address = nil;
	long				i, j;
	long				tmpIndex = 0;
	long				tmpInt;
	long				tmpLong;
	long				msgTypeStartIndex = -1;
	long				msgTypeEndIndex = -1;
	NSData				*tmpData = nil;
	BOOL				hasWildcard = NO;
	OSCMessageType		msgType = OSCMessageTypeControl;
	OSCQueryType		queryType = OSCQueryTypeUnknown;
	
	/*
				parse the address string
	*/
	tmpIndex = -1;
	//	there's guaranteed to be a '\0' at the end of the address string- find the '\0' and look for some basic properties along the way
	for (i=0; ((i<l) && (tmpIndex == (-1))); ++i)	{
		switch (b[i])	{
			case '\0':
				//	first of all, this character delineates the end of the address string (or the end of the query descriptor)
				tmpIndex = i;
				//	if this is an uknown message type- because of a malformed query type- then this is the end of the query
				if (msgType == OSCMessageTypeUnknown)	{
					NSLog(@"\t\tfinished parsing malformed query %@ in %s",[NSString stringWithBytes:b length:i encoding:NSUTF8StringEncoding],__func__);
				}
				//	else it's a known message type
				else	{
					//	if the previous character was a '/', then i'm implicitly requesting a directory listing
					if (i>0 && b[i-1]=='/')	{
						//	if the new length is 0, then i'm requesting a base-level directory listing
						if ((i-1)==0)
							address = [NSString stringWithBytes:b length:i encoding:NSUTF8StringEncoding];
						//	else i want the address to stop one short of the last slash (trim off the last slash)
						else	{
							address = [NSString stringWithBytes:b length:i-1 encoding:NSUTF8StringEncoding];
							if (b[0] != '/')
								address = [NSString stringWithFormat:@"/%@",address];
						}
						msgType = OSCMessageTypeQuery;
						queryType = OSCQueryTypeNamespaceExploration;
					}
					//	else the previous char *wasn't* a '/', it's *not* a directory listing- just a normal message
					else	{
						address = [NSString stringWithBytes:b length:i encoding:NSUTF8StringEncoding];	//	assemble the address (stop short of the / before the #)
						if (b[0] != '/')
							address = [NSString stringWithFormat:@"/%@",address];
					}
				}
				break;
			case '#':	//	the # character is reserved for declaring a query type, reply, or error
				//	if this is the 1st character in the message and the address is #reply or #error...
				if (i==0)	{
					if (strncmp((char *)b,"#reply",6)==0)	{
						msgType = OSCMessageTypeReply;
						tmpIndex = i+5;
					}
					else if (strncmp((char *)b,"#error",6)==0)	{
						msgType = OSCMessageTypeError;
						tmpIndex = i+5;
					}
					//	 if it's not reply or error, then it's an unrecognized query- continue parsing it anyway
					else	{
						msgType = OSCMessageTypeUnknown;
					}
				}
				//	else it's not the 1st character in the message address- it's either a query, or a message with a # in it that someone made (technically, this violates the spec- but there's no benefit to preventing it now)
				else	{
					//	if the previous character is a '/', then this is a query of some sort...
					if (b[i-1]=='/')	{
						//	set these now, if they aren't recognized they'll be the fallback values
						msgType = OSCMessageTypeQuery;
						queryType = OSCQueryTypeUnknown;
						//	as a shortcut, look to the next character before doing a string comparison to save time
						switch (b[i+1])	{
							case 'd':
								if (strncmp((char *)(b+i),"#documentation",14)==0)	{	//	if the query's recognized...
									address = [NSString stringWithBytes:b length:fmaxl(i-1,1) encoding:NSUTF8StringEncoding];	//	assemble the address (stop short of the / before the #)
									if (b[0] != '/')
										address = [NSString stringWithFormat:@"/%@",address];
									queryType = OSCQueryTypeDocumentation;	//	set the query type...
									tmpIndex = i+14;	//	...and i can exit now and save a couple loops- i know the end
								}
								break;
							case 't':
								if (strncmp((char *)(b+i),"#type-signature",15)==0)	{
									address = [NSString stringWithBytes:b length:fmaxl(i-1,1) encoding:NSUTF8StringEncoding];	//	assemble the address (stop short of the / before the #)
									if (b[0] != '/')
										address = [NSString stringWithFormat:@"/%@",address];
									queryType = OSCQueryTypeTypeSignature;
									tmpIndex = i+15;
								}
								break;
							case 'c':
								if (strncmp((char *)(b+i),"#current-value",14)==0)	{
									address = [NSString stringWithBytes:b length:fmaxl(i-1,1) encoding:NSUTF8StringEncoding];	//	assemble the address (stop short of the / before the #)
									if (b[0] != '/')
										address = [NSString stringWithFormat:@"/%@",address];
									queryType = OSCQueryTypeCurrentValue;
									tmpIndex = i+14;
								}
								break;
							case 'r':
								if (strncmp((char *)(b+i),"#return-type-string",19)==0)	{
									address = [NSString stringWithBytes:b length:fmaxl(i-1,1) encoding:NSUTF8StringEncoding];	//	assemble the address (stop short of the / before the #)
									if (b[0] != '/')
										address = [NSString stringWithFormat:@"/%@",address];
									queryType = OSCQueryTypeReturnTypeSignature;
									tmpIndex = i+19;
								}
								break;
						}
					}
					//	else the prev. char wasn't a '/'- this is just a fucked-up message of some sort, let it slide!
					else	{
						/*		do nothing here- let the for loop proceed, parsing the message normally.  pretend that the # isn't a violation of the spec.		*/
					}
				}
				break;
			case '[':
			case '\\':
			case '^':
			case '$':
			case '.':
			case '|':
			case '?':
			case '*':
			case '+':
			case '(':
				hasWildcard = YES;
				break;
		}
	}
	
	/*
	//	get the actual address string
	if (tmpIndex != -1)
		address = [NSString stringWithCString:(char *)b encoding:NSUTF8StringEncoding];
	*/
	
	/*
	//	if i couldn't make the address string for any reason, return
	if (address == nil)	{
		NSLog(@"\t\terr: couldn't parse message address %s",__func__);
		return nil;
	}
	*/
	
	
	//	"tmpIndex" is the offset i'm reading from- account for four-byte padding (or a four-byte space if it's already aligned)
	msgTypeStartIndex = ROUNDUP4(tmpIndex);
	if (msgTypeStartIndex == tmpIndex)
		msgTypeStartIndex += 4;
	
	
	/*
				find the bounds of the type tag string
	*/
	//	if the item at the type tag string start isn't a comma, return immediately
	if (b[msgTypeStartIndex] != ',')	{
		NSLog(@"\t\terr: msg type tag string not present");
		return nil;
	}
	tmpIndex = -1;
	//	there's guaranteed to be a '\0' at the end of the type tag string- find it
	for (i=msgTypeStartIndex; ((i<l) && (tmpIndex == (-1))); ++i)	{
		if (b[i] == '\0')
			tmpIndex = i;
	}
	//	if i couldn't find the '\0', return
	if (tmpIndex == -1)	{
		NSLog(@"\t\terr: couldn't find the msg type end index");
		return nil;
	}
	msgTypeEndIndex = tmpIndex;
	//	"tmpIndex" is the offset i'm currently reading from- so before i go further i
	//	have to account for any padding
	if (tmpIndex % 4 == 0)
		tmpIndex = tmpIndex + 4;
	else
		tmpIndex = (4 - (tmpIndex %4)) + tmpIndex;
	
	
	
	/*
				now actually parse the contents of the message
	*/
	
	//returnMe = [OSCMessage createWithAddress:address];
	returnMe = [[OSCMessage alloc] initFast:address:hasWildcard:msgType:queryType:txAddr:txPort];
	if (returnMe == nil)	{
		NSLog(@"\t\terr: msg was nil %s",__func__);
		return nil;
	}
	OSCValue		*tmpVal = nil;
	NSMutableArray	*arrayVals = nil;	//	an OSC message can have multiple levels of arrays- they're assembled and stored in here during parsing...
	
	//	run through the type arguments (,ffis etc.)- for each type arg, pull data from the buffer
	for (i=msgTypeStartIndex; i<msgTypeEndIndex; ++i)	{
		//	"tmpIndex" is the offset in "b" i'm currently reading data for this type from!
		switch(b[i])	{
			case 'i':			//	int32
				tmpVal = [OSCValue createWithInt:NSSwapBigIntToHost(*((unsigned int *)(b+tmpIndex)))];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				tmpIndex += 4;;
				break;
			case 'f':			//	float32
				tmpVal = [OSCValue createWithFloat:NSSwapBigFloatToHost(*((NSSwappedFloat *)(b+tmpIndex)))];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				tmpIndex += 4;
				break;
			case 's':			//	OSC-string
			case 'S':			//	alternate type represented as an OSC-string
				//	determine where the string ends by looking for the next 'null' character
				tmpInt = tmpIndex;
				for (j=tmpIndex; (j<l) && (tmpInt == tmpIndex); ++j)	{
					if (*((char *)b+j) == '\0')	{
						tmpInt = j;
					}
				}
				
				//	according to the spec, if the contents of the OSC-string occupy the
				//	full "width" of the 4-byte-aligned struct that *is* OSC, then there's an entire
				//	4-byte-struct of '\0' to ensure that you know where that shit ends.
				//	of course, this means that i don't need to check for the modulus before applying it.
				
				tmpVal = [OSCValue createWithString:[NSString stringWithCString:(char *)(b+tmpIndex) encoding:NSUTF8StringEncoding]];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				
				//	beginning of this string (tmpIndex), plus the length of this string (tmpInt - tmpIndex), plus 1 (the null), then round that up to the nearest 4 bytes
				//	this condenses down to....
				tmpIndex = ROUNDUP4((tmpInt + 1));
				
				break;
			case 'b':			//	OSC-blob
				//	first, determine the size of the blob.  the size is prepended to the blob as a 32-bit int.
				tmpLong = 0;
				for (j=0; j<4; ++j)	{
					tmpInt = b[tmpIndex+j];
					tmpLong = tmpLong | (tmpInt << (j*8));
				}
				tmpInt = ntohl((int)tmpLong);
				//	don't forget to update tmpIndex- i've moved forward in the buffer!
				tmpIndex += 4;
				//	now that i know how big the blob is, create an NSData from the buffer
				tmpData = [NSData dataWithBytes:(void *)(b+tmpIndex) length:tmpInt];
				tmpVal = [OSCValue createWithNSDataBlob:tmpData];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				
				//	update tmpIndex, make sure it's an even multiple of 4
				tmpIndex = tmpIndex + tmpInt;
				tmpIndex = ROUNDUP4(tmpIndex);
				break;
			case 'h':			//	64 bit big-endian two's complement integer
				tmpVal = [OSCValue createWithLongLong:NSSwapBigLongLongToHost(*((long long *)(b+tmpIndex)))];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				tmpIndex += 8;
				break;
			case 't':			//	OSC-timetag (64-bit/8 byte)
				tmpVal = [OSCValue
					createWithTimeSeconds:NSSwapBigLongToHost(*((long *)(b+tmpIndex)))
					microSeconds:NSSwapBigLongToHost(*((long *)(b+tmpIndex+4)))];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				tmpIndex = tmpIndex + 8;
				break;
			case 'd':			//	64 bit ("double") IEEE 754 floating point number
				tmpVal = [OSCValue createWithDouble:NSSwapBigDoubleToHost(*((NSSwappedDouble *)(b+tmpIndex)))];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				tmpIndex = tmpIndex + 8;
				break;
			case 'c':			//	an ascii character, sent as 32 bits- NOT SUPPORTED
				tmpIndex = tmpIndex + 4;
				break;
			case 'r':			//	32 bit RGBA color
				//NSLog(@"%d, %d, %d, %d",*((unsigned char *)b+tmpIndex),*((unsigned char *)b+tmpIndex+1),*((unsigned char *)b+tmpIndex+2),*((unsigned char *)b+tmpIndex+3));

#if IPHONE
				tmpVal = [OSCValue
					createWithColor:[UIColor
						colorWithRed:b[tmpIndex]/255.0
						green:b[tmpIndex+1]/255.0
						blue:b[tmpIndex+2]/255.0
						alpha:b[tmpIndex+3]/255.0]];
#else
				tmpVal = [OSCValue
					createWithColor:[NSColor
						colorWithDeviceRed:b[tmpIndex]/255.0
						green:b[tmpIndex+1]/255.0
						blue:b[tmpIndex+2]/255.0
						alpha:b[tmpIndex+3]/255.0]];
#endif
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				tmpIndex = tmpIndex + 4;
				break;
			case 'm':			//	4 byte MIDI message.  bytes from MSB to LSB are: port id, status byte, data1, data2
				tmpVal = [OSCValue
					createWithMIDIChannel:b[tmpIndex]
					status:b[tmpIndex+1]
					data1:b[tmpIndex+2]
					data2:b[tmpIndex+3]];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				
				tmpIndex = tmpIndex + 4;
				break;
			case 'T':			//	True.  no bytes are allocated in the argument data!
				tmpVal = [OSCValue createWithBool:YES];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				break;
			case 'F':			//	False.  no bytes are allocated in the argument data!
				tmpVal = [OSCValue createWithBool:NO];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				break;
			case 'N':			//	Nil.  no bytes are allocated in the argument data!
				tmpVal = [OSCValue createWithNil];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				break;
			case 'I':			//	Infinitum.  no bytes are allocated in the argument data!
				tmpVal = [OSCValue createWithInfinity];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				break;
			case '[':			//	indicates the start of an array
				if (arrayVals==nil)
					arrayVals = MUTARRAY;
				tmpVal = [OSCValue createArray];
				[arrayVals addObject:tmpVal];
				break;
			case ']':			//	indicates the end of an array
				if (arrayVals!=nil && [arrayVals count]>0)	{
					OSCValue	*finishedVal = [arrayVals lastObject];
					[finishedVal retain];
					[arrayVals removeLastObject];
					
					if ([arrayVals count]>0)
						[[arrayVals lastObject] addValue:finishedVal];
					else
						[returnMe addValue:finishedVal];
					
					[finishedVal release];
				}
				break;
			case 'E':			//	SMPTE timecode. AD-HOC DATA TYPE! ONLY SUPPORTED BY THIS FRAMEWORK!
				tmpVal = [OSCValue createWithSMPTEChunk:NSSwapBigIntToHost(*((unsigned int *)(b+tmpIndex)))];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				tmpIndex += 4;
				break;
		}
	}
	//	return the msg- the bundle that parsed it will add an execution date (if appropriate) and send it to the port
	return (returnMe==nil)?nil:[returnMe autorelease];
}
+ (id) createWithAddress:(NSString *)a	{
	OSCMessage		*returnMe = [[OSCMessage alloc] initWithAddress:a];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createQueryType:(OSCQueryType)t forAddress:(NSString *)a	{
	OSCMessage		*returnMe = [[OSCMessage alloc] initQueryType:t forAddress:a];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createReplyForAddress:(NSString *)a	{
	OSCMessage		*returnMe = [[OSCMessage alloc] initReplyForAddress:a];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createReplyForMessage:(OSCMessage*)m	{
	OSCMessage		*returnMe = [[OSCMessage alloc] initReplyForMessage:m];
	return (returnMe==nil)?nil:[returnMe autorelease];
}
+ (id) createErrorForAddress:(NSString *)a	{
	OSCMessage		*returnMe = [[OSCMessage alloc] initErrorForAddress:a];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createErrorForMessage:(OSCMessage *)m	{
	OSCMessage		*returnMe = [[OSCMessage alloc] initErrorForMessage:m];
	return (returnMe==nil)?nil:[returnMe autorelease];
}


- (id) initWithAddress:(NSString *)a	{
	if (a == nil)	{
		if (self != nil)
			[self release];
		return nil;
	}
	id			returnMe = nil;
	NSString	*addrString = [a stringByDeletingLastAndAddingFirstSlash];
	returnMe = [self initFast:
		addrString:
		((a==nil)?NO:[a containsOSCWildCard]):
		OSCMessageTypeControl:
		OSCQueryTypeUnknown:
		0:
		0];
	return returnMe;
}
- (id) initQueryType:(OSCQueryType)t forAddress:(NSString *)a	{
	if (a==nil)	{
		if (self != nil)
			[self release];
		return nil;
	}
	id			returnMe = nil;
	NSString	*addrString = [a stringByDeletingLastAndAddingFirstSlash];
	returnMe = [self initFast:
		addrString:
		((a==nil)?NO:[a containsOSCWildCard]):
		OSCMessageTypeQuery:
		t:
		0:
		0];
	return returnMe;
}
- (id) initReplyForAddress:(NSString *)a	{
	if (a == nil)	{
		if (self != nil)
			[self release];
		return nil;
	}
	id			returnMe = nil;
	NSString	*addrString = [a stringByDeletingLastAndAddingFirstSlash];
	returnMe = [self initFast:
		nil:
		NO:
		OSCMessageTypeReply:
		OSCQueryTypeUnknown:
		0:
		0];
	if (returnMe != nil)
		[returnMe addString:addrString];
	return returnMe;
}
- (id) initReplyForMessage:(OSCMessage *)m	{
	//NSLog(@"%s ... %@",__func__,m);
	if (m==nil)
		goto BAIL;
	self = [self initFast:
		nil:
		NO:
		OSCMessageTypeReply:
		OSCQueryTypeUnknown:
		[m queryTXAddress]:
		[m queryTXPort]];
	if (self == nil)
		return nil;
	if ([m valueCount] > 0)	{
		NSData		*tmpData = [m writeToNSData];
		if (tmpData == nil)
			goto BAIL;
		[self addNSDataBlob:tmpData];
	}
	else	{
		//NSLog(@"\t\treplyAddress is %@",[m replyAddress]);
		[self addString:[m replyAddress]];
	}
	return self;
	
	BAIL:
	if (self != nil)
		[self release];
	return nil;
}
- (id) initErrorForAddress:(NSString *)a	{
	if (a == nil)	{
		if (self != nil)
			[self release];
		return nil;
	}
	id			returnMe = nil;
	returnMe = [self initFast:
		a:
		((a==nil)?NO:[a containsOSCWildCard]):
		OSCMessageTypeError:
		OSCQueryTypeUnknown:
		0:
		0];
	return returnMe;
}
- (id) initErrorForMessage:(OSCMessage *)m	{
	if (m==nil)
		goto BAIL;
	self = [self initFast:
		nil:
		NO:
		OSCMessageTypeError:
		OSCQueryTypeUnknown:
		[m queryTXAddress]:
		[m queryTXPort]];
	if (self == nil)
		return nil;
	if ([m valueCount] > 0)	{
		NSData		*tmpData = [m writeToNSData];
		if (tmpData == nil)
			goto BAIL;
		[self addNSDataBlob:tmpData];
	}
	else
		[self addString:[m replyAddress]];
	return self;
	
	BAIL:
	if (self != nil)
		[self release];
	return nil;
}
//	DOES NO CHECKING WHATSOEVER.  MEANT TO BE FAST, NOT SAFE.  USE OTHER CREATE/INIT METHODS.
- (id) initFast:(NSString *)addr :(BOOL)addrHasWildcards :(OSCMessageType)mType :(OSCQueryType)qType :(unsigned int)qTxAddr :(unsigned short)qTxPort	{
	if (self = [super init])	{
		address = (addr==nil)?nil:[addr retain];
		valueCount = 0;
		value = nil;
		valueArray = nil;
		timeTag = nil;
		wildcardsInAddress = addrHasWildcards;
		messageType = mType;
		queryType = qType;
		queryTXAddress = qTxAddr;
		queryTXPort = qTxPort;
		msgInfo = nil;
		return self;
	}
	BAIL:
	[self release];
	return nil;
}
- (id) copyWithZone:(NSZone *)z	{
	//OSCMessage		*returnMe = [[OSCMessage allocWithZone:z] initWithAddress:address];
	OSCMessage		*returnMe = [[OSCMessage allocWithZone:z] initFast:address:wildcardsInAddress:messageType:queryType:queryTXAddress:queryTXPort];
	
	if (valueCount == 1)
		[returnMe addValue:value];
	else if (valueCount > 1)	{
		for (OSCValue *valPtr in valueArray)
			[returnMe addValue:valPtr];
	}
	if (timeTag != nil)
		[returnMe setTimeTag:timeTag];
	if (msgInfo != nil)
		[returnMe setMsgInfo:msgInfo];
	return returnMe;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (address != nil)
		[address release];
	address = nil;
	if (value != nil)
		[value release];
	value = nil;
	if (valueArray != nil)
		[valueArray release];
	valueArray = nil;
	valueCount = 0;
	if (timeTag != nil)	{
		[timeTag release];
		timeTag = nil;
	}
	if (msgInfo != nil)	{
		[msgInfo release];
		msgInfo = nil;
	}
	[super dealloc];
}

- (void) addInt:(int)n	{
	//NSLog(@"%s ... %d",__func__,n);
	[self addValue:[OSCValue createWithInt:n]];
}
- (void) addFloat:(float)n	{
	//NSLog(@"%s",__func__);
	[self addValue:[OSCValue createWithFloat:n]];
}
- (void) addDouble:(double)n	{
	[self addValue:[OSCValue createWithDouble:n]];
}
- (void) addString:(NSString *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	[self addValue:[OSCValue createWithString:n]];
}
#if IPHONE
- (void) addColor:(UIColor *)c	{
	[self addValue:[OSCValue createWithColor:c]];
}
#else
- (void) addColor:(NSColor *)c	{
	[self addValue:[OSCValue createWithColor:c]];
}
#endif
- (void) addBOOL:(BOOL)n	{
	//NSLog(@"%s",__func__);
	[self addValue:[OSCValue createWithBool:n]];
}
- (void) addNSDataBlob:(NSData *)b	{
	if (b==nil)
		return;
	[self addValue:[OSCValue createWithNSDataBlob:b]];
}
- (void) addValue:(OSCValue *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if (n == nil)
		return;
	//	if i haven't already stored a val, just store it at the single variable
	if (valueCount == 0)
		value = [n retain];
	//	else if there's more than 1 val, i'll be adding it to the array
	else	{
		//	if the array doesn't exist yet, create it (and clean up the existing val)
		if (valueArray == nil)	{
			valueArray = [[NSMutableArray arrayWithCapacity:0] retain];
			[valueArray addObject:value];
			[value release];
			value = nil;
		}
		//	add the new val to the array
		[valueArray addObject:n];
	}
	
	//	increment the value count
	++valueCount;
}
/*!
	NOT A KEY-VALUE METHOD!
	
	The 'value' method is purely for convenience- most OSC messages only have a single value, and most of the time when they have multiple values you really only want the first one.  If this message only has a single value, it returns the value- if the message has multiple values, this method only returns the first of my values!
*/
- (OSCValue *) value	{
	if (valueCount < 2)
		return value;
	if (valueArray != nil)
		return [valueArray objectAtIndex:0];
	return nil;
}
- (OSCValue *) valueAtIndex:(int)i	{
	if (valueCount<2)	{
		return (i==0) ? value : nil;
	}
	if ((i<valueCount)&&(valueArray!=nil))
		return [valueArray objectAtIndex:i];
	
	return nil;
}


- (float) calculateFloatValue	{
	return [self calculateFloatValueAtIndex:0];
}
- (float) calculateFloatValueAtIndex:(int)i	{
	if (valueCount < 2)	{
		if (value != nil)
			return (i==0) ? [(OSCValue *)value calculateFloatValue] : (float)0.0;
		return (float)0.0;
	}
	//	get the OSCValue at the index
	if ((i<valueCount)&&(valueArray!=nil))	{
		OSCValue	*tmpVal = [valueArray objectAtIndex:i];
		return (tmpVal != nil ) ? [tmpVal calculateFloatValue] : (float)0.0;
	}
	//	return -1.0 if i couldn't find the value!
	return (float)-1.0;
}
- (double) calculateDoubleValue	{
	return [self calculateDoubleValueAtIndex:0];
}
- (double) calculateDoubleValueAtIndex:(int)i	{
	if (valueCount < 2)	{
		if (value != nil)
			return (i==0) ? [(OSCValue *)value calculateDoubleValue] : (double)0.0;
		return (double)0.0;
	}
	//	get the OSCValue at the index
	if ((i<valueCount)&&(valueArray!=nil))	{
		OSCValue	*tmpVal = [valueArray objectAtIndex:i];
		return (tmpVal != nil ) ? [tmpVal calculateDoubleValue] : (double)0.0;
	}
	//	return -1.0 if i couldn't find the value!
	return (double)-1.0;
}


- (NSString *) address	{
	return address;
}
- (NSString *) replyAddress	{
	switch (messageType)	{
		case OSCMessageTypeUnknown:
		case OSCMessageTypeControl:
			return address;
			break;
		case OSCMessageTypeQuery:
			switch (queryType)	{
				case OSCQueryTypeUnknown:
					return address;
					break;
				case OSCQueryTypeNamespaceExploration:
					if ([address isEqualToString:@"/"])
						return address;
					return [NSString stringWithFormat:@"%@/",address];
					break;
				case OSCQueryTypeDocumentation:
					if ([address isEqualToString:@"/"])
						return @"/#documentation";
					return [NSString stringWithFormat:@"%@/#documentation",address];
					break;
				case OSCQueryTypeTypeSignature:
					if ([address isEqualToString:@"/"])
						return @"/#type-signature";
					return [NSString stringWithFormat:@"%@/#type-signature",address];
					break;
				case OSCQueryTypeCurrentValue:
					if ([address isEqualToString:@"/"])
						return @"/#current-value";
					return [NSString stringWithFormat:@"%@/#current-value",address];
					break;
				case OSCQueryTypeReturnTypeSignature:
					if ([address isEqualToString:@"/"])
						return @"/#return-type-string";
					return [NSString stringWithFormat:@"%@/#return-type-string",address];
					break;
			}
			break;
		case OSCMessageTypeReply:
			return @"#reply";
			break;
		case OSCMessageTypeError:
			return @"#error";
			break;
	}
	return address;
}
- (int) valueCount	{
	return valueCount;
}
- (NSMutableArray *) valueArray	{
	return valueArray;
}
- (NSDate *) timeTag	{
	return timeTag;
}
- (void) setTimeTag:(NSDate *)n	{
	if (timeTag != nil)	{
		[timeTag release];
		timeTag = nil;
	}
	if (n != nil)	{
		timeTag = [n retain];
	}
}



- (long) bufferLength	{
	//NSLog(@"%s",__func__);
	long		addressLength = 0;
	long		typeLength = 0;
	long		payloadLength = 0;
	
	//	determine the length of the address (round up to the nearest 4 bytes)
	switch (messageType)	{
		case OSCMessageTypeUnknown:
		case OSCMessageTypeControl:
			addressLength = (address==nil)?0:strlen([address UTF8String]);
			break;
		case OSCMessageTypeQuery:
			addressLength = (address==nil)?0:strlen([address UTF8String]);
			switch (queryType)	{
				case OSCQueryTypeUnknown:
					break;
				case OSCQueryTypeNamespaceExploration:
					addressLength += 1;	//	add the '/' at the end of the address
					break;
				case OSCQueryTypeDocumentation:
					addressLength += 15;
					break;
				case OSCQueryTypeTypeSignature:
					addressLength += 16;
					break;
				case OSCQueryTypeCurrentValue:
					addressLength += 15;
					break;
				case OSCQueryTypeReturnTypeSignature:
					addressLength += 20;
					break;
			}
			break;
		case OSCMessageTypeReply:
			addressLength = 6;
			break;
		case OSCMessageTypeError:
			addressLength = 6;
			break;
	}
	addressLength = ROUNDUP4((addressLength+1));
	
	//	determine the length of the type args. 1 [comma] + actual type args + 1 [for the null]
	typeLength = 1;
	if (valueCount>0)	{
		if (valueCount==1 && value!=nil)	{
			typeLength += [value typeSignatureLength];
			payloadLength += [value bufferLength];
		}
		else if (valueCount>1 && valueArray!=nil)	{
			for (OSCValue *valPtr in valueArray)	{
				typeLength += [valPtr typeSignatureLength];
				payloadLength += [valPtr bufferLength];
			}
		}
	}
	//	the type string is an OSC-string, which means it's terminated by a null character and then padded with enough 0s to make it a multiple of 4
	++typeLength;
	typeLength = ROUNDUP4(typeLength);
	
	return addressLength + typeLength + payloadLength;
}
- (void) writeToBuffer:(unsigned char *)b	{
	//NSLog(@"%s ... %@",__func__,self);
	if (b == NULL)
		return;
	
	int					dataWriteOffset = 0;
	int					typeWriteOffset = 0;
	
	
	//	write the address, rounded up to the nearest 4 bytes (the +1 is for the null after the address)
	NSString			*tmpString = [self replyAddress];
	const char			*tmpChars = (tmpString==nil) ? nil : [tmpString UTF8String];
	int					tmpCharsLength = (tmpChars==nil) ? 0 : (int)strlen(tmpChars);
	
	if (tmpCharsLength != 0)
	{
		strncpy((char *)b, tmpChars, tmpCharsLength);
	}
	typeWriteOffset += (tmpCharsLength + 1);
	//	the actual type data location is rounded up to the nearest 4-byte segment
	typeWriteOffset = ROUNDUP4(typeWriteOffset);
	//	figure out where i'll be starting to write the data. +1 for the comma + actual type args + 1 for the null
	dataWriteOffset = typeWriteOffset + 1;
	if (valueCount > 0)	{
		if (valueCount==1 && value!=nil)	{
			dataWriteOffset += [value typeSignatureLength];
		}
		else if (valueCount>1 && valueArray!=nil)	{
			for (OSCValue *valPtr in valueArray)	{
				dataWriteOffset += [valPtr typeSignatureLength];
			}
		}
	}
	dataWriteOffset += 1;
	//	the type args has to be rounded up to the nearest 4 bytes!
	dataWriteOffset = ROUNDUP4(dataWriteOffset);
	
	//	write the comma at the beginning of the list of types
	*(b + typeWriteOffset) = ',';
	++typeWriteOffset;
	
	//	now write all the data from the vals to the buffer
	if ((valueCount < 2) && (value != nil))
		[value writeToBuffer:b typeOffset:&typeWriteOffset dataOffset:&dataWriteOffset];
	else	{
		OSCValue			*valuePtr = nil;
		for (valuePtr in valueArray)	{
			[valuePtr writeToBuffer:b typeOffset:&typeWriteOffset dataOffset:&dataWriteOffset];
		}
	}
}
- (NSData *) writeToNSData	{
	NSData			*returnMe = nil;
	NSUInteger		bufferLen = [self bufferLength];
	if (bufferLen>0)	{
		unsigned char	*buffer = malloc(bufferLen * sizeof(unsigned char));
		if (buffer != nil)	{
			memset(buffer,'\0',bufferLen);
			[self writeToBuffer:buffer];
			//	create a data from the buffer- the NSData instance takes ownership of the buffer, and will free it when it's released
			returnMe = [NSData dataWithBytesNoCopy:buffer length:bufferLen];
			if (returnMe == nil)
				free(buffer);
		}
	}
	return returnMe;
}


- (BOOL) wildcardsInAddress	{
	return wildcardsInAddress;
}
- (OSCMessageType) messageType	{
	return messageType;
}
- (OSCQueryType) queryType	{
	return queryType;
}
- (unsigned int) queryTXAddress	{
	return queryTXAddress;
}
- (unsigned short) queryTXPort	{
	return queryTXPort;
}
- (void) _setWildcardsInAddress:(BOOL)n	{
	wildcardsInAddress = n;
}
- (void) _setMessageType:(OSCMessageType)n	{
	messageType = n;
}
- (void) _setQueryType:(OSCQueryType)n	{
	queryType = n;
}


- (void) setMsgInfo:(id)n	{
	if (msgInfo != nil)
		[msgInfo release];
	msgInfo = (n==nil) ? nil : [n retain];
}
- (id) msgInfo	{
	return msgInfo;
}


@end


#import "OSCMessage.h"
#import "OSCInPort.h"
#import "OSCStringAdditions.h"




@implementation OSCMessage


- (NSString *) description	{
	NSString			*baseDescription = nil;
	baseDescription = [self _description];
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
	
	/*
				parse the address string
	*/
	tmpIndex = -1;
	//	there's guaranteed to be a '\0' at the end of the address string- find the '\0' and look for some basic properties along the way
	for (i=0; ((i<l) && (tmpIndex == (-1))); ++i)	{
		switch (b[i])	{
			case '\0':
				//	this character delineates the end of the address string
				tmpIndex = i;
				address = [NSString stringWithBytes:b length:i encoding:NSUTF8StringEncoding];	//	assemble the address (stop short of the / before the #)
				if (b[0] != '/')
					address = [NSString stringWithFormat:@"/%@",address];
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
	returnMe = [[OSCMessage alloc] initFast:address:hasWildcard:txAddr:txPort];
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
				tmpVal = [OSCValue createWithOSCTimetag:NSSwapBigLongLongToHost(*((uint64_t *)(b+tmpIndex)))];
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
				//tmpIndex = tmpIndex + 4;
				
				tmpVal = [OSCValue createWithChar:NSSwapBigIntToHost(*((unsigned int *)(b+tmpIndex)))];
				if (arrayVals!=nil && [arrayVals count]>0)
					[[arrayVals lastObject] addValue:tmpVal];
				else
					[returnMe addValue:tmpVal];
				tmpIndex += 4;
				
				break;
			case 'r':			//	32 bit RGBA color
				//NSLog(@"%d, %d, %d, %d",*((unsigned char *)b+tmpIndex),*((unsigned char *)b+tmpIndex+1),*((unsigned char *)b+tmpIndex+2),*((unsigned char *)b+tmpIndex+3));

#if TARGET_OS_IPHONE
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
					[arrayVals removeLastObject];
					
					if ([arrayVals count]>0)
						[[arrayVals lastObject] addValue:finishedVal];
					else
						[returnMe addValue:finishedVal];
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
	return (returnMe==nil)?nil:returnMe;
}
+ (instancetype) createWithAddress:(NSString *)a	{
	OSCMessage		*returnMe = [[OSCMessage alloc] initWithAddress:a];
	return returnMe;
}


- (instancetype) initWithAddress:(NSString *)a	{
	if (a == nil)	{
		VVRELEASE(self);
		return self;
	}
	OSCMessage			*returnMe = nil;
	NSString	*addrString = [a stringByDeletingLastAndAddingFirstSlash];
	returnMe = [self initFast:
		addrString:
		((a==nil)?NO:[a containsOSCWildCard]):
		0:
		0];
	return returnMe;
}
//	DOES NO CHECKING WHATSOEVER.  MEANT TO BE FAST, NOT SAFE.  USE OTHER CREATE/INIT METHODS.
- (instancetype) initFast:(NSString *)addr :(BOOL)addrHasWildcards :(unsigned int)qTxAddr :(unsigned short)qTxPort	{
	self = [super init];
	if (self != nil)	{
		address = (addr==nil)?nil:addr;
		valueCount = 0;
		value = nil;
		valueArray = nil;
		timeTag = nil;
		wildcardsInAddress = addrHasWildcards;
		txAddress = qTxAddr;
		txPort = qTxPort;
		msgInfo = nil;
	}
	return self;
}
- (instancetype) copyWithZone:(NSZone *)z	{
	//OSCMessage		*returnMe = [[OSCMessage allocWithZone:z] initWithAddress:address];
	OSCMessage		*returnMe = [[OSCMessage allocWithZone:z] initFast:address:wildcardsInAddress:txAddress:txPort];
	
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
	VVRELEASE(address);
	VVRELEASE(value)
	VVRELEASE(valueArray);
	valueCount = 0;
	VVRELEASE(timeTag);
	VVRELEASE(msgInfo);
	
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
#if TARGET_OS_IPHONE
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
		value = n;
	//	else if there's more than 1 val, i'll be adding it to the array
	else	{
		//	if the array doesn't exist yet, create it (and clean up the existing val)
		if (valueArray == nil)	{
			valueArray = [NSMutableArray arrayWithCapacity:0];
			[valueArray addObject:value];
			VVRELEASE(value);
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
- (OSCValue *) valueAtFlatIndex:(int)targetIndex	{
	if (targetIndex >= valueCount)
		return nil;
	if (targetIndex==0 && valueCount==1)
		return value;
	__block int			flatIndex = 0;
	__block OSCValue	*foundValue = nil;
	__block void		(^flatIndexValFinder)(OSCValue *);
	
	flatIndexValFinder = ^(OSCValue *inVal)	{
		switch ([inVal type])	{
		case OSCValUnknown:
			break;
		case OSCValNil:
		case OSCValInfinity:
		case OSCValBool:
			//	these technically don't have a data type but the OSC framework creates OSCValue instances if it receives a message with these data types
			if (flatIndex == targetIndex)
				foundValue = inVal;
			else
				++flatIndex;
			break;
		case OSCValInt:
		case OSCValFloat:
		case OSCValString:
		case OSCValTimeTag:
		case OSCVal64Int:
		case OSCValDouble:
		case OSCValChar:
		case OSCValColor:
		case OSCValMIDI:
		case OSCValBlob:
		case OSCValSMPTE:
			if (flatIndex == targetIndex)
				foundValue = inVal;
			else
				++flatIndex;
			break;
		case OSCValArray:
			for (OSCValue *tmpVal in [inVal valueArray])	{
				if (foundValue!=nil || flatIndex>targetIndex)
					return;
				flatIndexValFinder(tmpVal);
			}
			break;
		}
	};
	
	for (OSCValue *tmpVal in [self valueArray])	{
		if (foundValue!=nil || flatIndex>targetIndex)
			break;;
		flatIndexValFinder(tmpVal);
	}
	
	return foundValue;
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


- (int) calculateIntValue	{
	return [self calculateIntValueAtIndex:0];
}
- (int) calculateIntValueAtIndex:(int)i	{
	if (valueCount < 2)	{
		if (value != nil)
			return (i==0) ? [(OSCValue *)value calculateIntValue] : (int)0;
		return (int)0;
	}
	//	get the OSCValue at the index
	if ((i<valueCount)&&(valueArray!=nil))	{
		OSCValue	*tmpVal = [valueArray objectAtIndex:i];
		return (tmpVal != nil ) ? [tmpVal calculateIntValue] : (int)0;
	}
	//	return -1.0 if i couldn't find the value!
	return (int)-1;
}


- (NSString *) address	{
	return address;
}
- (NSString *) replyAddress	{
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
	VVRELEASE(timeTag);
	timeTag = n;
}



- (long) bufferLength	{
	//NSLog(@"%s",__func__);
	long		addressLength = 0;
	long		typeLength = 0;
	long		payloadLength = 0;
	
	//	determine the length of the address (round up to the nearest 4 bytes)
	addressLength = (address==nil)?0:strlen([address UTF8String]);
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
- (unsigned int) txAddress	{
	return txAddress;
}
- (unsigned short) txPort	{
	return txPort;
}
- (void) _setWildcardsInAddress:(BOOL)n	{
	wildcardsInAddress = n;
}


- (void) setMsgInfo:(id)n	{
	VVRELEASE(msgInfo);
	msgInfo = n;
}
- (id) msgInfo	{
	return msgInfo;
}


@end

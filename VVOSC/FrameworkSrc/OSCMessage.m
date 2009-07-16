//
//  OSCMessage.m
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCMessage.h"
#import "OSCInPort.h"




@implementation OSCMessage


- (NSString *) description	{
	if (valueCount < 2)
		return [NSString stringWithFormat:@"<OSCMessage: %@\n%@\n>",address,value];
	else
		return [NSString stringWithFormat:@"<OSCMessage: %@-%@>",address,valueArray];
}
+ (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l toInPort:(id)p	{
	//NSLog(@"%s ... %s, %ld -> %@",__func__,b,l,p);
	if ((b == nil) || (l == 0) || (p == NULL))
		return;
	
	NSString		*address = nil;
	int				i, j;
	int				tmpIndex = 0;
	int				tmpInt;
	float			*tmpFloatPtr;
	long			tmpLong;
	int				msgTypeStartIndex = -1;
	int				msgTypeEndIndex = -1;
	
	
	
	/*
				parse the address string
	*/
	tmpIndex = -1;
	//	there's guaranteed to be a '\0' at the end of the address string- find the '\0'
	for (i=0; ((i<l) && (tmpIndex == (-1))); ++i)	{
		if (b[i] == '\0')
			tmpIndex = i;
	}
	//	get the actual address string
	if (tmpIndex != -1)
		address = [NSString stringWithCString:(char *)b encoding:NSASCIIStringEncoding];
	//	if i couldn't make the address string for any reason, return
	if (address == nil)	{
		NSLog(@"\t\terr: couldn't parse message address");
		return;
	}
	//	"tmpIndex" is the offset i'm currently reading from- so before i go further i
	//	have to account for any padding
	if (tmpIndex %4 == 0)
		msgTypeStartIndex = tmpIndex + 4;
	else
		msgTypeStartIndex = (4 - (tmpIndex % 4)) + tmpIndex;
	
	
	
	/*
				find the bounds of the type tag string
	*/
	//	if the item at the type tag string start isn't a comma, return immediately
	if (b[msgTypeStartIndex] != ',')	{
		NSLog(@"\t\terr: msg type tag string not present");
		return;
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
		return;
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
	
	OSCMessage		*msg = [OSCMessage createWithAddress:address];
	OSCValue		*oscValue = nil;
	
	if (msg == nil)	{
		NSLog(@"\t\terr: msg was nil %s",__func__);
		return;
	}
	//	run through the type arguments (,ffis etc.)- for each type arg, pull data from the buffer
	for (i=msgTypeStartIndex; i<msgTypeEndIndex; ++i)	{
		switch(b[i])	{
			case 'i':			//	int32
				tmpLong = 0;
				for(j=0; j<4; ++j)	{
					tmpInt = b[tmpIndex+j];
					tmpLong = tmpLong | (tmpInt << (j*8));
				}
				tmpInt = ntohl(tmpLong);
				oscValue = [OSCValue createWithInt:tmpInt];
				[msg addValue:oscValue];
				tmpIndex = tmpIndex + 4;
				break;
			case 'f':			//	float32
				tmpInt = ntohl(*((long *)(b+tmpIndex)));
				tmpFloatPtr = (float *)&tmpInt;
				oscValue = [OSCValue createWithFloat:*tmpFloatPtr];
				[msg addValue:oscValue];
				tmpIndex = tmpIndex + 4;
				break;
			case 's':			//	OSC-string
			case 'S':			//	alternate type represented as an OSC-string
				tmpInt = -1;
				for (j=tmpIndex; (j<l) && (tmpInt == -1); ++j)	{
					if (*((char *)b+j) == '\0')	{
						tmpInt = j-1;
					}
				}
				//	according to the spec, if the contents of the OSC-string occupy the
				//	full "width" of the 4-byte-aligned struct that *is* OSC, then there's an entire
				//	4-byte-struct of '\0' to ensure that you know where that shit ends.
				//	of course, this means that i don't need to check for the modulus before applying it.
				
				oscValue = [OSCValue createWithString:[NSString stringWithCString:(char *)(b+tmpIndex) encoding:NSASCIIStringEncoding]];
				[msg addValue:oscValue];
				tmpIndex = tmpInt+1;
				tmpIndex = 4 - (tmpIndex % 4) + tmpIndex;
				break;
			case 'b':			//	OSC-blob
				break;
			case 'h':			//	64 bit big-endian two's complement integer
				tmpIndex = tmpIndex + 8;
				break;
			case 't':			//	OSC-timetag (64-bit/8 byte)
				tmpIndex = tmpIndex + 8;
				break;
			case 'd':			//	64 bit ("double") IEEE 754 floating point number
				tmpIndex = tmpIndex + 8;
				break;
			case 'c':			//	an ascii character, sent as 32 bits
				tmpIndex = tmpIndex + 4;
				break;
			case 'r':			//	32 bit RGBA color
				//NSLog(@"%d, %d, %d, %d",*((unsigned char *)b+tmpIndex),*((unsigned char *)b+tmpIndex+1),*((unsigned char *)b+tmpIndex+2),*((unsigned char *)b+tmpIndex+3));

#if IPHONE
				oscValue = [OSCValue
					createWithColor:[UIColor
						colorWithRed:b[tmpIndex]/255.0
						green:b[tmpIndex+1]/255.0
						blue:b[tmpIndex+2]/255.0
						alpha:b[tmpIndex+3]/255.0]];
				[msg addValue:oscValue];
#else
				oscValue = [OSCValue
					createWithColor:[NSColor
						colorWithCalibratedRed:b[tmpIndex]/255.0
						green:b[tmpIndex+1]/255.0
						blue:b[tmpIndex+2]/255.0
						alpha:b[tmpIndex+3]/255.0]];
				[msg addValue:oscValue];
#endif
				tmpIndex = tmpIndex + 4;
				break;
			case 'm':			//	4 byte MIDI message.  bytes from MSB to LSB are: port id, status byte, data1, data2
				oscValue = [OSCValue
					createWithMIDIChannel:b[tmpIndex]
					status:b[tmpIndex+1]
					data1:b[tmpIndex+2]
					data2:b[tmpIndex+3]];
				[msg addValue:oscValue];
				
				tmpIndex = tmpIndex + 4;
				break;
			case 'T':			//	True.  no bytes are allocated in the argument data!
				oscValue = [OSCValue createWithBool:YES];
				[msg addValue:oscValue];
				break;
			case 'F':			//	False.  no bytes are allocated in the argument data!
				oscValue = [OSCValue createWithBool:NO];
				[msg addValue:oscValue];
				break;
			case 'N':			//	Nil.  no bytes are allocated in the argument data!
				break;
			case 'I':			//	Infinitum.  no bytes are allocated in the argument data!
				break;
		}
	}
	
	//	now that i've assembed the message, send it to the in port
	[p addValue:msg toAddressPath:address];
	
}
+ (id) createWithAddress:(NSString *)a	{
	OSCMessage		*returnMe = [[OSCMessage alloc] initWithAddress:a];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithAddress:(NSString *)a	{
	if (a == nil)
		goto BAIL;
	
	if (self = [super init])	{
		//	if the address doesn't start with a "/", i need to add one
		const char		*stringPtr = [a cStringUsingEncoding:NSASCIIStringEncoding];
		if (stringPtr == nil)
			goto BAIL;
		if (*stringPtr != '/')
			address = [[NSString stringWithFormat:@"/%@",a] retain];
		else
			address = [a retain];
		valueCount = 0;
		value = nil;
		valueArray = nil;
		return self;
	}
	
	BAIL:
	[self release];
	return nil;
}
- (id) copyWithZone:(NSZone *)z	{
	OSCMessage		*returnMe = [[OSCMessage allocWithZone:z] initWithAddress:address];
	
	if (valueCount == 1)
		[returnMe addValue:value];
	else if (valueCount > 1)	{
		for (OSCValue *valPtr in valueArray)
			[returnMe addValue:valPtr];
	}
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
- (void) addString:(NSString *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	[self addValue:[OSCValue createWithString:n]];
}
#if IPHONE
- (void) addColor:(UIColor *)c	{
#else
- (void) addColor:(NSColor *)c	{
#endif
	//NSLog(@"%s",__func__);
	[self addValue:[OSCValue createWithColor:c]];
}
- (void) addBOOL:(BOOL)n	{
	//NSLog(@"%s",__func__);
	[self addValue:[OSCValue createWithBool:n]];
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
		if (i==0)
			return value;
		else
			return nil;
	}
	if ((i<valueCount)&&(valueArray!=nil))
		return [valueArray objectAtIndex:i];
	
	return nil;
}


- (NSString *) address	{
	return address;
}
- (int) valueCount	{
	return valueCount;
}
- (NSMutableArray *) valueArray	{
	return valueArray;
}



- (int) bufferLength	{
	//NSLog(@"%s",__func__);
	
	int		addressLength = 0;
	int		typeLength = 0;
	int		payloadLength = 0;
	
	//	determine the length of the address (round up to the nearest 4 bytes)
	addressLength = [address length];
	addressLength = ROUNDUP4(addressLength);
	//	determine the length of the type args (# of type + 1 [for the comma], round up to nearest 4 bytes)
	typeLength = valueCount + 1;
	typeLength = ROUNDUP4(typeLength);
	//	determine the length of the various arguments- each rounded up to the nearest 4 bytes
	//	now write all the data from the vals to the buffer
	if ((valueCount < 2) && (value != nil))
		payloadLength += [value bufferLength];
	else	{
		NSEnumerator		*it = [valueArray objectEnumerator];
		OSCValue			*valuePtr;
		while (valuePtr = [it nextObject])
			payloadLength += [valuePtr bufferLength];
	}
	
	return addressLength + typeLength + payloadLength;
}
- (void) writeToBuffer:(unsigned char *)b	{
	//NSLog(@"%s",__func__);
	
	if (b == NULL)
		return;
	
	int					dataWriteOffset = 0;
	int					typeWriteOffset = 0;
	
	
	//	write the address, rounded up to the nearest 4 bytes
	strncpy((char *)b, [address cStringUsingEncoding:NSASCIIStringEncoding], [address length]);
	typeWriteOffset += [address length];
	//	the actual type data location is rounded up to the nearest 4
	typeWriteOffset = ROUNDUP4(typeWriteOffset);
	//	figure out where i'll be starting to write the data (the +1 is the comma)
	dataWriteOffset = typeWriteOffset + 1 + valueCount;
	dataWriteOffset = ROUNDUP4(dataWriteOffset);
	
	//	write the comma at the beginning of the list of types
	*(b + typeWriteOffset) = ',';
	++typeWriteOffset;
	
	//	now write all the data from the vals to the buffer
	if ((valueCount < 2) && (value != nil))
		[value writeToBuffer:b typeOffset:&typeWriteOffset dataOffset:&dataWriteOffset];
	else	{
		NSEnumerator		*it = [valueArray objectEnumerator];
		OSCValue			*valuePtr;
		while (valuePtr = [it nextObject])
			[valuePtr writeToBuffer:b typeOffset:&typeWriteOffset dataOffset:&dataWriteOffset];
	}
}


@end

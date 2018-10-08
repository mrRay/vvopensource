
#import "OSCValue.h"




@implementation OSCValue


- (NSString *) description	{
	switch (type)	{
		case OSCValUnknown:
			return @"<OSCVal ?>";
		case OSCValInt:
			return [NSString stringWithFormat:@"<OSCVal i %d>",*(int *)value];
		case OSCValFloat:
			return [NSString stringWithFormat:@"<OSCVal f %f>",*(float *)value];
		case OSCValString:
			return [NSString stringWithFormat:@"<OSCVal s %@>",(id)value];
		case OSCValTimeTag:
			//return [NSString stringWithFormat:@"<OSCVal t: %ld-%ld>",*(long *)(value),*(long *)(value+1)];
			//return [NSString stringWithFormat:@"<OSCVal t: %ld-%ld>",(unsigned long)(*((uint64_t *)value)>>32),(unsigned long)((*(uint64_t *)value) & 0x00000000FFFFFFFF)];
			//return [NSString stringWithFormat:@"<OSCVal t: %@>",[self dateValue]];
			{
				NSDateFormatter		*fmt = [[[NSDateFormatter alloc] init] autorelease];
				[fmt setDateFormat:@"dd/MM, HH:mm:ss.SSSSS"];
				return [fmt stringFromDate:[self dateValue]];
			}
		case OSCVal64Int:
			return [NSString stringWithFormat:@"<OSCVal h: %qi>",*(long long *)value];
		case OSCValDouble:
			return [NSString stringWithFormat:@"<OSCVal d: %f>",*(double *)value];
		case OSCValChar:
			return [NSString stringWithFormat:@"<OSCVal c: %s>",(char *)value];
		case OSCValColor:
			return [NSString stringWithFormat:@"<OSCVal r %@>",(id)value];
		case OSCValMIDI:
			return [NSString stringWithFormat:@"<OSCVal m %d-%d-%d-%d>",((Byte *)value)[0],((Byte *)value)[1],((Byte *)value)[2],((Byte *)value)[3]];
		case OSCValBool:
			if (*(BOOL *)value)
				return @"<OSCVal T>";
			else
				return @"<OSCVal F>";
		case OSCValNil:
			return [NSString stringWithFormat:@"<OSCVal N>"];
		case OSCValInfinity:
			return [NSString stringWithFormat:@"<OSCVal I>"];
		case OSCValArray:
			return [NSString stringWithFormat:@"<OSCVal [%@]>",value];
		case OSCValBlob:
			return [NSString stringWithFormat:@"<OSCVal b: %@>",value];
		case OSCValSMPTE:
			return [NSString stringWithFormat:@"<OSCVal E: %d>",*(int *)value];
	}
	return [NSString stringWithFormat:@"<OSCValue ?>"];
}
- (NSString *) lengthyDescription	{
#if !TARGET_OS_IPHONE
	CGFloat		colorComps[4];
#endif
	switch (type)	{
		case OSCValUnknown:
			return @"unknown";
		case OSCValInt:
			return [NSString stringWithFormat:@"integer %d",*(int *)value];
		case OSCValFloat:
			return [NSString stringWithFormat:@"float %f",*(float *)value];
		case OSCValString:
			return [NSString stringWithFormat:@"string \"%@\"",(id)value];
		case OSCValTimeTag:
			//return [NSString stringWithFormat:@"Time Tag %ld-%ld",(unsigned long)(*((uint64_t *)value)>>32),(unsigned long)((*(uint64_t *)value) & 0x00000000FFFFFFFF)];
			return [NSString stringWithFormat:@"<OSCVal t: %@>",[self dateValue]];
		case OSCVal64Int:
			return [NSString stringWithFormat:@"64-bit Integer %qi",*(long long *)value];
		case OSCValDouble:
			return [NSString stringWithFormat:@"64-bit Float %f",*(double *)value];
		case OSCValChar:
			return [NSString stringWithFormat:@"Character \"%s\"",(char *)value];
		case OSCValColor:
#if TARGET_OS_IPHONE
			return [NSString stringWithFormat:@"color %@",(id)value];
#else
			[(NSColor *)value getComponents:(CGFloat *)colorComps];
			return [NSString stringWithFormat:@"color %0.2f-%0.2f-%0.2f-%0.2f",colorComps[0],colorComps[1],colorComps[2],colorComps[3]];
#endif
			
		case OSCValMIDI:
			return [NSString stringWithFormat:@"MIDI %d-%d-%d-%d>",((Byte *)value)[0],((Byte *)value)[1],((Byte *)value)[2],((Byte *)value)[3]];
		case OSCValBool:
			if (*(BOOL *)value)
				return @"True";
			else
				return @"False";
		case OSCValNil:
			return [NSString stringWithFormat:@"nil"];
		case OSCValInfinity:
			return [NSString stringWithFormat:@"infinity"];
		case OSCValArray:
			return [NSString stringWithFormat:@"array %@",value];
		case OSCValBlob:
			return [NSString stringWithFormat:@"<Data Blob>"];
		case OSCValSMPTE:
			return [NSString stringWithFormat:@"<SMPTE %@>",[self SMPTEString]];
	}
	return [NSString stringWithFormat:@"?"];
}


+ (NSString *) typeTagStringForType:(OSCValueType)t	{
	switch (t)	{
		case OSCValUnknown:
			return @"";
		case OSCValInt:
			return @"i";
		case OSCValFloat:
			return @"f";
		case OSCValString:
			return @"s";
		case OSCValTimeTag:
			//return [NSString stringWithFormat:@"Time Tag %ld-%ld",(unsigned long)(*((uint64_t *)value)>>32),(unsigned long)((*(uint64_t *)value) & 0x00000000FFFFFFFF)];
			return @"t";
		case OSCVal64Int:
			return @"h";
		case OSCValDouble:
			return @"d";
		case OSCValChar:
			return @"c";
		case OSCValColor:
			return @"r";
		case OSCValMIDI:
			return @"m";
		case OSCValBool:
			return @"T";
		case OSCValNil:
			return @"N";
		case OSCValInfinity:
			return @"I";
		case OSCValArray:
			return @"";
		case OSCValBlob:
			return @"b";
		case OSCValSMPTE:
			return @"E";
	}
	return @"";
}
+ (OSCValueType) typeForTypeTagString:(NSString *)t	{
	if (t==nil || [t length]<1)
		return OSCValUnknown;
	unichar		tmpChar = [t characterAtIndex:0];
	return [self typeForTypeTagChar:tmpChar];
}
+ (OSCValueType) typeForTypeTagChar:(unichar)c	{
	OSCValueType		returnMe = OSCValUnknown;
	switch (c)	{
	case 'i':		returnMe = OSCValInt;		break;
	case 'f':		returnMe = OSCValFloat;		break;
	case 's':
	case 'S':		returnMe = OSCValString;		break;
	case 'b':		returnMe = OSCValBlob;		break;
	case 'h':		returnMe = OSCVal64Int;		break;
	case 't':		returnMe = OSCValTimeTag;		break;
	case 'd':		returnMe = OSCValDouble;		break;
	case 'c':		returnMe = OSCValChar;		break;
	case 'r':		returnMe = OSCValColor;		break;
	case 'm':		returnMe = OSCValMIDI;		break;
	case 'T':
	case 'F':		returnMe = OSCValBool;		break;
	case 'N':		returnMe = OSCValNil;		break;
	case 'I':		returnMe = OSCValInfinity;		break;
	case '[':
	case ']':		returnMe = OSCValArray;		break;
	case 'E':		returnMe = OSCValSMPTE;		break;
	}
	return returnMe;
}
+ (id) createWithInt:(int)n	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithInt:n];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithFloat:(float)n	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithFloat:n];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithString:(NSString *)n	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithString:n];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithTimeSeconds:(unsigned long)s microSeconds:(unsigned long)ms	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithTimeSeconds:s microSeconds:ms];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithOSCTimetag:(uint64_t)n	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithOSCTimetag:n];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createTimeWithDate:(NSDate *)n	{
	OSCValue		*returnMe = [[OSCValue alloc] initTimeWithDate:n];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithLongLong:(long long)n	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithLongLong:n];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithDouble:(double)n	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithDouble:n];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithChar:(char)n	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithChar:n];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithColor:(id)n	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithColor:n];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithMIDIChannel:(Byte)c status:(Byte)s data1:(Byte)d1 data2:(Byte)d2	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithMIDIChannel:c status:s data1:d1 data2:d2];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithBool:(BOOL)n	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithBool:n];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithNil	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithNil];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithInfinity	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithInfinity];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createArray	{
	OSCValue		*returnMe = [[OSCValue alloc] initArray];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithNSDataBlob:(NSData *)d	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithNSDataBlob:d];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithSMPTEVals:(OSCSMPTEFPS)fps :(int)d :(int)h :(int)m :(int)s :(int)f	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithSMPTEVals:fps:d:h:m:s:f];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithSMPTEChunk:(int)n	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithSMPTEChunk:n];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}


- (id) initWithInt:(int)n	{
	self = [super init];
	if (self != nil)	{
		value = malloc(sizeof(int));
		*(int *)value = n;
		type = OSCValInt;
	}
	return self;
}
- (id) initWithFloat:(float)n	{
	self = [super init];
	if (self != nil)	{
		value = malloc(sizeof(float));
		*(float *)value = n;
		type = OSCValFloat;
	}
	return self;
}
- (id) initWithString:(NSString *)n	{
	if (n == nil)
		goto BAIL;
	if (self = [super init])	{
		value = [n retain];
		type = OSCValString;
		return self;
	}
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	[self release];
	return nil;
}
- (id) initWithTimeSeconds:(unsigned long)s microSeconds:(unsigned long)ms	{
	self = [super init];
	if (self != nil)	{
		value = malloc(sizeof(uint64_t));
		*(uint64_t *)value = ((((uint64_t)s)<<32)&(0xFFFFFFFF00000000)) | ((uint64_t)ms);
		type = OSCValTimeTag;
	}
	return self;
}
- (id) initWithOSCTimetag:(uint64_t)n	{
	self = [super init];
	if (self != nil)	{
		value = malloc(sizeof(uint64_t));
		*(uint64_t *)value = n;
		type = OSCValTimeTag;
	}
	return self;
}
- (id) initTimeWithDate:(NSDate *)n	{
	self = [super init];
	if (self != nil)	{
		//	...the "reference date" in OSC is 1/1/1900, so we have to account for one century plus one year's worth of seconds to this...
		double		tmpVal = [n timeIntervalSinceReferenceDate];
		tmpVal += 3187296000.;
		uint64_t	time_s = floor(tmpVal);
		uint64_t	time_us = (tmpVal - (double)time_s) * 4294967296.0;
		value = malloc(sizeof(uint64_t));
		*(uint64_t *)value = time_s<<32 | time_us;
		//NSLog(@"\t\tvalue is %qu",*(uint64_t *)value);
		type = OSCValTimeTag;
	}
	return self;
}
- (id) initWithLongLong:(long long)n	{
	self = [super init];
	if (self != nil)	{
		value = malloc(sizeof(long long));
		*(long long *)value = n;
		type = OSCVal64Int;
	}
	return self;
}
- (id) initWithDouble:(double)n	{
	self = [super init];
	if (self != nil)	{
		value = malloc(sizeof(double));
		*(double *)value = n;
		type = OSCValDouble;
	}
	return self;
}
- (id) initWithChar:(char)n	{
	self = [super init];
	if (self != nil)	{
		value = malloc(sizeof(char));
		*(char *)value = n;
		type = OSCValChar;
	}
	return self;
}
- (id) initWithColor:(id)n	{
	if (n == nil)
		goto BAIL;
	if (self = [super init])	{
#if TARGET_OS_IPHONE
		UIColor			*calibratedColor = n;
#else
		NSColorSpace	*devRGBColorSpace = [NSColorSpace deviceRGBColorSpace];
		NSColor			*calibratedColor = ((void *)[n colorSpace]==(void *)devRGBColorSpace) ? n :[n colorUsingColorSpaceName:NSDeviceRGBColorSpace];
#endif
		value = [calibratedColor retain];
		type = OSCValColor;
		return self;
	}
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	[self release];
	return nil;
}
- (id) initWithMIDIChannel:(Byte)c status:(Byte)s data1:(Byte)d1 data2:(Byte)d2	{
	self = [super init];
	if (self != nil)	{
		value = malloc(sizeof(Byte)*4);
		((Byte *)value)[0] = c;
		((Byte *)value)[1] = s;
		((Byte *)value)[2] = d1;
		((Byte *)value)[3] = d2;
		type = OSCValMIDI;
	}
	return self;
}
- (id) initWithBool:(BOOL)n	{
	self = [super init];
	if (self != nil)	{
		value = malloc(sizeof(BOOL));
		*(BOOL *)value = n;
		type = OSCValBool;
	}
	return self;
}
- (id) initWithNil	{
	self = [super init];
	if (self != nil)	{
		value = nil;
		type = OSCValNil;
	}
	return self;
}
- (id) initWithInfinity	{
	self = [super init];
	if (self != nil)	{
		value = nil;
		type = OSCValInfinity;
	}
	return self;
}
- (id) initArray	{
	self = [super init];
	if (self != nil)	{
		value = [[NSMutableArray alloc] initWithCapacity:0];
		type = OSCValArray;
	}
	return self;
}
- (id) initWithNSDataBlob:(NSData *)d	{
	if (d == nil)	{
		[self release];
		return nil;
	}
	if (self = [super init])	{
		value = [d retain];
		type = OSCValBlob;
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithSMPTEVals:(OSCSMPTEFPS)fps :(int)d :(int)h :(int)m :(int)s :(int)f	{
	self = [super init];
	if (self != nil)	{
		UInt32		tmpVal = 0x00000000;
		//	first 4 bits are the FPS mode (OSCSMPTEFPS)
		tmpVal = tmpVal | (fps & 0x0F);
		tmpVal = tmpVal << 4;
		//	next 3 bits are days
		tmpVal = tmpVal | (d & 0x07);
		tmpVal = tmpVal << 3;
		//	next 5 bits are hours
		tmpVal = tmpVal | (d & 0x1F);
		tmpVal = tmpVal << 5;
		//	next 6 bits are minutes
		tmpVal = tmpVal | (d & 0x3F);
		tmpVal = tmpVal << 6;
		//	next 6 bits are seconds
		tmpVal = tmpVal | (d & 0x3F);
		tmpVal = tmpVal << 6;
		//	next 8 bits are frames
		tmpVal = tmpVal | (d & 0xFF);
		
		value = malloc(sizeof(int));
		*(int *)value = tmpVal;
		type = OSCValSMPTE;
		//NSLog(@"\t\tchecking: %@",[self SMPTEString]);
	}
	return self;
}
- (id) initWithSMPTEChunk:(int)n	{
	self = [super init];
	if (self != nil)	{
		value = malloc(sizeof(int));
		*(int *)value = n;
		type = OSCValSMPTE;
	}
	return self;
}
- (id) init	{
	self = [super init];
	if (self != nil)	{
		value = nil;
		type = OSCValUnknown;
	}
	return self;
}
- (id) copyWithZone:(NSZone *)z	{
	OSCValue		*returnMe = nil;
	switch (type)	{
		case OSCValUnknown:
			returnMe = [[OSCValue allocWithZone:z] init];
			break;
		case OSCValInt:
			returnMe = [[OSCValue allocWithZone:z] initWithInt:*((int *)value)];
			break;
		case OSCValFloat:
			returnMe = [[OSCValue allocWithZone:z] initWithFloat:*((float *)value)];
			break;
		case OSCValString:
			returnMe = [[OSCValue allocWithZone:z] initWithString:((NSString *)value)];
			break;
		case OSCValTimeTag:
			//returnMe = [[OSCValue allocWithZone:z] initWithTimeSeconds:*((long *)(value)) microSeconds:*((long *)(value+1))];
			//returnMe = [[OSCValue allocWithZone:z] initWithTimeSeconds:(unsigned long)(*((uint64_t *)value)>>32) microSeconds:(unsigned long)((*(uint64_t *)value) & 0x00000000FFFFFFFF)];
			returnMe = [[OSCValue allocWithZone:z] initWithOSCTimetag:*(uint64_t *)value];
			break;
		case OSCVal64Int:
			returnMe = [[OSCValue allocWithZone:z] initWithLongLong:*(long long *)value];
			break;
		case OSCValDouble:
			returnMe = [[OSCValue allocWithZone:z] initWithDouble:*(double *)value];
			break;
		case OSCValChar:
			returnMe = [[OSCValue allocWithZone:z] initWithChar:*(char *)value];
			break;
		case OSCValColor:
			returnMe = [[OSCValue allocWithZone:z] initWithColor:((id)value)];
			break;
		case OSCValMIDI:
			returnMe = [[OSCValue allocWithZone:z]
				initWithMIDIChannel:*((Byte *)value+0)
				status:*((Byte *)value+1)
				data1:*((Byte *)value+2)
				data2:*((Byte *)value+3)];
			break;
		case OSCValBool:
			returnMe = [[OSCValue allocWithZone:z] initWithBool:*((BOOL *)value)];
			break;
		case OSCValNil:
			returnMe = [[OSCValue allocWithZone:z] initWithNil];
			break;
		case OSCValInfinity:
			returnMe = [[OSCValue allocWithZone:z] initWithInfinity];
			break;
		case OSCValArray:
			returnMe = [[OSCValue allocWithZone:z] initArray];
			for (OSCValue *valPtr in (NSMutableArray *)value)	{
				OSCValue		*newVal = [valPtr copy];
				if (newVal != nil)	{
					[returnMe addValue:newVal];
					[newVal release];
				}
			}
			break;
		case OSCValBlob:
			returnMe = [[OSCValue allocWithZone:z] initWithNSDataBlob:value];
			break;
		case OSCValSMPTE:
			returnMe = [[OSCValue allocWithZone:z] initWithSMPTEChunk:*((int *)value)];
			break;
	}
	return returnMe;
}


- (void) dealloc	{
	switch (type)	{
		case OSCValInt:
		case OSCValFloat:
		case OSCValTimeTag:
		case OSCVal64Int:
		case OSCValDouble:
		case OSCValChar:
		case OSCValMIDI:
		case OSCValBool:
		case OSCValSMPTE:
			if (value != nil)
				free(value);
			value = nil;
			break;
		case OSCValString:
		case OSCValColor:
		case OSCValArray:
			if (value != nil)
				[(id)value release];
			value = nil;
			break;
		case OSCValNil:
		case OSCValInfinity:
		case OSCValUnknown:
			break;
		case OSCValBlob:
			if (value != nil)
				[(NSData *)value release];
			value = nil;
			break;
	}
	value = nil;
	[super dealloc];
}


- (int) intValue	{
	return *(int *)value;
}
- (float) floatValue	{
	return *(float *)value;
}
- (NSString *) stringValue	{
	return (NSString *)value;
}
- (struct timeval) timeValue	{
	struct timeval		returnMe;
	returnMe.tv_sec = (*((uint64_t *)value)>>32);
	returnMe.tv_usec = ((*(uint64_t *)value) & 0xFFFFFFFF);
	return returnMe;
	/*
	struct timeval		returnMe;
	long				*longPtr = nil;
	longPtr = value;
	returnMe.tv_sec = *longPtr;
	++longPtr;
	returnMe.tv_usec = *longPtr;
	return returnMe;
	*/
}
- (NSDate *) dateValue	{
	double		tmpTime = 0.;
	tmpTime = (double)(*((uint64_t *)value)>>32);
	tmpTime += (double)((*(uint64_t *)value) & 0xFFFFFFFF) / 4294967296.0;
	//	...the "reference date" in OSC is 1/1/1900, so we have to account for one century plus one year's worth of seconds to this...
	tmpTime -= 3187296000.;
	NSDate		*returnMe = [NSDate dateWithTimeIntervalSinceReferenceDate:tmpTime];
	return returnMe;
}
- (long long) longLongValue	{
	return *(long long *)value;
}
- (double) doubleValue	{
	return *(double *)value;
}
- (char) charValue	{
	return *(char *)value;
}
- (id) colorValue	{
	return (id)value;
}
- (Byte) midiPort	{
	return ((Byte *)value)[0];
}
- (OSCMIDIType) midiStatus	{
	return ((Byte *)value)[1];
}
- (Byte) midiData1	{
	return ((Byte *)value)[2];
}
- (Byte) midiData2	{
	return ((Byte *)value)[3];
}
- (BOOL) boolValue	{
	return *(BOOL *)value;
}
- (NSData *) blobNSData	{
	return (NSData *)value;
}
- (void) addValue:(OSCValue *)n	{
	if (n==nil || type!=OSCValArray || value==nil)
		return;
	[(NSMutableArray *)value addObject:n];
}
- (NSMutableArray *) valueArray	{
	if (type!=OSCValArray || value==nil)
		return nil;
	return (NSMutableArray *)value;
}
- (int) SMPTEValue	{
	return *(int *)value;
}
- (NSString *) SMPTEString	{
	/*	first 4 bits define FPS (OSCSMPTEFPS). 
		next 3 bits define days. 
		next 5 bits define hours. 
		next 6 bits define minutes. 
		next 6 bits define seconds. 
		last 8 bits define frame.		*/
	
	UInt32		tmpVal = *(int *)value;
	int			vals[6];	//	mode, days, hours, minutes, seconds, frames
	vals[0] = (tmpVal >> 28);
	vals[1] = (tmpVal >> 25) & 0x07;
	vals[2] = (tmpVal >> 20) & 0x1F;
	vals[3] = (tmpVal >> 14) & 0x3F;
	vals[4] = (tmpVal >> 8) & 0x3F;
	vals[5] = tmpVal & 0xFF;
	
	NSString	*returnMe = nil;
	int			leadingZeroCount = 1;
	while (vals[leadingZeroCount] == 0)	{
		++leadingZeroCount;
	}
	--leadingZeroCount;
	switch (leadingZeroCount)	{
		case 0:
			returnMe = [NSString stringWithFormat:@"%d:%d:%d:%d.%d",vals[1],vals[2],vals[3],vals[4],vals[5]];
			break;
		case 1:
			returnMe = [NSString stringWithFormat:@"%d:%d:%d.%d",vals[2],vals[3],vals[4],vals[5]];
			break;
		case 2:
			returnMe = [NSString stringWithFormat:@"%d:%d.%d",vals[3],vals[4],vals[5]];
			break;
		case 3:
		case 4:
			returnMe = [NSString stringWithFormat:@"%d.%d",vals[4],vals[5]];
			break;
	}
	return returnMe;
}


- (float) calculateFloatValue	{
	float		returnMe = 0.0;
	double		tmp = [self calculateDoubleValue];
	returnMe = tmp;
	return returnMe;
}
- (double) calculateDoubleValue	{
	double		returnMe = (double)0.0;
	CGFloat		comps[4];
	switch (type)	{
		case OSCValUnknown:
			break;
		case OSCValInt:
			returnMe = (double)(*(int *)value);
			break;
		case OSCValFloat:
			returnMe = (double)*(float *)value;
			break;
		case OSCValString:
			//	OSC STRINGS REQUIRE A NULL CHARACTER AFTER THEM!
			//return ROUNDUP4(([(NSString *)value length] + 1));
			break;
		case OSCValTimeTag:
			returnMe = (double)(*((uint64_t *)value)>>32);
			returnMe += (double)((*(uint64_t *)value) & 0xFFFFFFFF) / 4294967296.0;
			/*
			returnMe = *((long *)(value));
			returnMe += *((long *)(value+1));
			*/
			break;
		case OSCVal64Int:
			returnMe = (double)(*(long long *)value);
			break;
		case OSCValDouble:
			returnMe = (double)(*(double *)value);
			break;
		case OSCValChar:
			returnMe = (double)(*(char *)value);
			break;
		case OSCValColor:
#if TARGET_OS_IPHONE
			*comps = *(CGColorGetComponents([(UIColor *)value CGColor]));
#else
			[(NSColor *)value getComponents:comps];
#endif
			returnMe = (double)(comps[0]+comps[1]+comps[2])/(double)3.0;
			break;
		case OSCValMIDI:
			//	if it's a MIDI-type OSC value, return the note velocity or the controller value
			switch ((OSCMIDIType)(((Byte *)value)[1]))	{
				case OSCMIDINoteOffVal:
				case OSCMIDIBeginSysexDumpVal:
				case OSCMIDIUndefinedCommon1Val:
				case OSCMIDIUndefinedCommon2Val:
				case OSCMIDIEndSysexDumpVal:
					returnMe = (double)0.0;
					break;
				case OSCMIDINoteOnVal:
				case OSCMIDIAfterTouchVal:
				case OSCMIDIControlChangeVal:
					returnMe = ((double)([self midiData2]))/(double)127.0;
					break;
				case OSCMIDIProgramChangeVal:
				case OSCMIDIChannelPressureVal:
				case OSCMIDIMTCQuarterFrameVal:
				case OSCMIDISongSelectVal:
					returnMe = ((double)([self midiData1]))/(double)127.0;
					break;
				case OSCMIDIPitchWheelVal:
				case OSCMIDISongPosPointerVal:
					returnMe = ((double)	((long)(([self midiData2] << 7) | ([self midiData1])))	)/(double)16383.0;
					break;
				case OSCMIDITuneRequestVal:
				case OSCMIDIClockVal:
				case OSCMIDITickVal:
				case OSCMIDIStartVal:
				case OSCMIDIContinueVal:
				case OSCMIDIStopVal:
				case OSCMIDIUndefinedRealtime1Val:
				case OSCMIDIActiveSenseVal:
				case OSCMIDIResetVal:
					returnMe = (double)1.0;
					break;
			}
			break;
		case OSCValBool:
			returnMe = (*(BOOL *)value) ? (double)1.0 : (double)0.0;
			break;
		case OSCValNil:
			returnMe = (double)0.0;
			break;
		case OSCValInfinity:
			returnMe = (double)1.0;
			break;
		case OSCValArray:
			returnMe = (double)0.0;
			break;
		case OSCValBlob:
			returnMe = (double)1.0;
			break;
		case OSCValSMPTE:
			returnMe = 0.0;
			//	switching the "osc smpte fps mode", so i can convert frames into a double/seconds
			switch ((*(int *)value) >> 28)	{
				case OSCSMPTEFPS24:
					returnMe += (double)((*(int *)value) & 0xFF)/24.0;
					break;
				case OSCSMPTEFPS25:
					returnMe += (double)((*(int *)value) & 0xFF)/25.0;
					break;
				case OSCSMPTEFPS30:
					returnMe += (double)((*(int *)value) & 0xFF)/30.0;
					break;
				case OSCSMPTEFPS48:
					returnMe += (double)((*(int *)value) & 0xFF)/48.0;
					break;
				case OSCSMPTEFPS50:
					returnMe += (double)((*(int *)value) & 0xFF)/50.0;
					break;
				case OSCSMPTEFPS60:
					returnMe += (double)((*(int *)value) & 0xFF)/60.0;
					break;
				case OSCSMPTEFPS120:
					returnMe += (double)((*(int *)value) & 0xFF)/120.0;
					break;
				case OSCSMPTEFPSUnknown:
				default:
					break;
			}
			returnMe += (double)(((*(int *)value) >> 8) & 0x3F);	//	seconds
			returnMe += (double)(((*(int *)value) >> 14) & 0x3F) * 60.0;	//	minutes
			returnMe += (double)(((*(int *)value) >> 20) & 0x1F) * 60.0 * 60.0;	//	hours
			returnMe += (double)(((*(int *)value) >> 25) & 0x07) * 60.0 * 60.0 * 24.0;	//	days
			break;
	}
	return returnMe;
}
- (int) calculateIntValue	{
	int		returnMe = (int)0;
	CGFloat		comps[4];
	switch (type)	{
		case OSCValUnknown:
			break;
		case OSCValInt:
			returnMe = (int)(*(int *)value);
			break;
		case OSCValFloat:
			returnMe = (int)*(float *)value;
			break;
		case OSCValString:
			//	OSC STRINGS REQUIRE A NULL CHARACTER AFTER THEM!
			//return ROUNDUP4(([(NSString *)value length] + 1));
			break;
		case OSCValTimeTag:
			returnMe = (int)(*((uint64_t *)value)>>32);
			returnMe += (int)((*(uint64_t *)value) & 0xFFFFFFFF) / 4294967296.0;
			/*
			returnMe = *((long *)(value));
			returnMe += *((long *)(value+1));
			*/
			break;
		case OSCVal64Int:
			returnMe = (int)(*(long long *)value);
			break;
		case OSCValDouble:
			returnMe = (int)(*(double *)value);
			break;
		case OSCValChar:
			returnMe = (int)(*(char *)value);
			break;
		case OSCValColor:
#if TARGET_OS_IPHONE
			*comps = *(CGColorGetComponents([(UIColor *)value CGColor]));
#else
			[(NSColor *)value getComponents:comps];
#endif
			returnMe = (int)(comps[0]+comps[1]+comps[2])/(double)3.0;
			break;
		case OSCValMIDI:
			//	if it's a MIDI-type OSC value, return the note velocity or the controller value
			switch ((OSCMIDIType)(((Byte *)value)[1]))	{
				case OSCMIDINoteOffVal:
				case OSCMIDIBeginSysexDumpVal:
				case OSCMIDIUndefinedCommon1Val:
				case OSCMIDIUndefinedCommon2Val:
				case OSCMIDIEndSysexDumpVal:
					returnMe = (int)0;
					break;
				case OSCMIDINoteOnVal:
				case OSCMIDIAfterTouchVal:
				case OSCMIDIControlChangeVal:
					returnMe = [self midiData2];
					break;
				case OSCMIDIProgramChangeVal:
				case OSCMIDIChannelPressureVal:
				case OSCMIDIMTCQuarterFrameVal:
				case OSCMIDISongSelectVal:
					returnMe = [self midiData1];
					break;
				case OSCMIDIPitchWheelVal:
				case OSCMIDISongPosPointerVal:
					returnMe = (int)(([self midiData2] << 7) | ([self midiData1]));
					break;
				case OSCMIDITuneRequestVal:
				case OSCMIDIClockVal:
				case OSCMIDITickVal:
				case OSCMIDIStartVal:
				case OSCMIDIContinueVal:
				case OSCMIDIStopVal:
				case OSCMIDIUndefinedRealtime1Val:
				case OSCMIDIActiveSenseVal:
				case OSCMIDIResetVal:
					returnMe = (int)1;
					break;
			}
			break;
		case OSCValBool:
			returnMe = (*(BOOL *)value) ? (int)1 : (int)0;
			break;
		case OSCValNil:
			returnMe = (int)0;
			break;
		case OSCValInfinity:
			returnMe = (int)1;
			break;
		case OSCValArray:
			returnMe = (int)0;
			break;
		case OSCValBlob:
			returnMe = (int)1;
			break;
		case OSCValSMPTE:
			/*
			returnMe = 0.0;
			//	switching the "osc smpte fps mode", so i can convert frames into a double/seconds
			switch ((*(int *)value) >> 28)	{
				case OSCSMPTEFPS24:
					returnMe += (double)((*(int *)value) & 0xFF)/24.0;
					break;
				case OSCSMPTEFPS25:
					returnMe += (double)((*(int *)value) & 0xFF)/25.0;
					break;
				case OSCSMPTEFPS30:
					returnMe += (double)((*(int *)value) & 0xFF)/30.0;
					break;
				case OSCSMPTEFPS48:
					returnMe += (double)((*(int *)value) & 0xFF)/48.0;
					break;
				case OSCSMPTEFPS50:
					returnMe += (double)((*(int *)value) & 0xFF)/50.0;
					break;
				case OSCSMPTEFPS60:
					returnMe += (double)((*(int *)value) & 0xFF)/60.0;
					break;
				case OSCSMPTEFPS120:
					returnMe += (double)((*(int *)value) & 0xFF)/120.0;
					break;
				case OSCSMPTEFPSUnknown:
				default:
					break;
			}
			returnMe += (double)(((*(int *)value) >> 8) & 0x3F);	//	seconds
			returnMe += (double)(((*(int *)value) >> 14) & 0x3F) * 60.0;	//	minutes
			returnMe += (double)(((*(int *)value) >> 20) & 0x1F) * 60.0 * 60.0;	//	hours
			returnMe += (double)(((*(int *)value) >> 25) & 0x07) * 60.0 * 60.0 * 24.0;	//	days
			*/
			break;
	}
	return returnMe;
}
- (long long) calculateLongLongValue	{
	long long	returnMe = (long long)0;
	CGFloat		comps[4];
	switch (type)	{
		case OSCValUnknown:
			break;
		case OSCValInt:
			returnMe = (long long)(*(int *)value);
			break;
		case OSCValFloat:
			returnMe = (long long)*(float *)value;
			break;
		case OSCValString:
			//	OSC STRINGS REQUIRE A NULL CHARACTER AFTER THEM!
			//return ROUNDUP4(([(NSString *)value length] + 1));
			break;
		case OSCValTimeTag:
			returnMe = (long long)(*((uint64_t *)value)>>32);
			returnMe += (long long)((*(uint64_t *)value) & 0xFFFFFFFF) / 4294967296.0;
			/*
			returnMe = *((long *)(value));
			returnMe += *((long *)(value+1));
			*/
			break;
		case OSCVal64Int:
			returnMe = (long long)(*(long long *)value);
			break;
		case OSCValDouble:
			returnMe = (long long)(*(double *)value);
			break;
		case OSCValChar:
			returnMe = (long long)(*(char *)value);
			break;
		case OSCValColor:
#if TARGET_OS_IPHONE
			*comps = *(CGColorGetComponents([(UIColor *)value CGColor]));
#else
			[(NSColor *)value getComponents:comps];
#endif
			returnMe = (long long)(comps[0]+comps[1]+comps[2])/(double)3.0;
			break;
		case OSCValMIDI:
			//	if it's a MIDI-type OSC value, return the note velocity or the controller value
			switch ((OSCMIDIType)(((Byte *)value)[1]))	{
				case OSCMIDINoteOffVal:
				case OSCMIDIBeginSysexDumpVal:
				case OSCMIDIUndefinedCommon1Val:
				case OSCMIDIUndefinedCommon2Val:
				case OSCMIDIEndSysexDumpVal:
					returnMe = (long long)0;
					break;
				case OSCMIDINoteOnVal:
				case OSCMIDIAfterTouchVal:
				case OSCMIDIControlChangeVal:
					returnMe = (long long)[self midiData2];
					break;
				case OSCMIDIProgramChangeVal:
				case OSCMIDIChannelPressureVal:
				case OSCMIDIMTCQuarterFrameVal:
				case OSCMIDISongSelectVal:
					returnMe = (long long)[self midiData1];
					break;
				case OSCMIDIPitchWheelVal:
				case OSCMIDISongPosPointerVal:
					returnMe = (long long)(([self midiData2] << 7) | ([self midiData1]));
					break;
				case OSCMIDITuneRequestVal:
				case OSCMIDIClockVal:
				case OSCMIDITickVal:
				case OSCMIDIStartVal:
				case OSCMIDIContinueVal:
				case OSCMIDIStopVal:
				case OSCMIDIUndefinedRealtime1Val:
				case OSCMIDIActiveSenseVal:
				case OSCMIDIResetVal:
					returnMe = (long long)1;
					break;
			}
			break;
		case OSCValBool:
			returnMe = (*(BOOL *)value) ? (long long)1 : (long long)0;
			break;
		case OSCValNil:
			returnMe = (long long)0;
			break;
		case OSCValInfinity:
			returnMe = (long long)1;
			break;
		case OSCValArray:
			returnMe = (long long)0;
			break;
		case OSCValBlob:
			returnMe = (long long)1;
			break;
		case OSCValSMPTE:
			/*
			returnMe = 0.0;
			//	switching the "osc smpte fps mode", so i can convert frames into a double/seconds
			switch ((*(int *)value) >> 28)	{
				case OSCSMPTEFPS24:
					returnMe += (double)((*(int *)value) & 0xFF)/24.0;
					break;
				case OSCSMPTEFPS25:
					returnMe += (double)((*(int *)value) & 0xFF)/25.0;
					break;
				case OSCSMPTEFPS30:
					returnMe += (double)((*(int *)value) & 0xFF)/30.0;
					break;
				case OSCSMPTEFPS48:
					returnMe += (double)((*(int *)value) & 0xFF)/48.0;
					break;
				case OSCSMPTEFPS50:
					returnMe += (double)((*(int *)value) & 0xFF)/50.0;
					break;
				case OSCSMPTEFPS60:
					returnMe += (double)((*(int *)value) & 0xFF)/60.0;
					break;
				case OSCSMPTEFPS120:
					returnMe += (double)((*(int *)value) & 0xFF)/120.0;
					break;
				case OSCSMPTEFPSUnknown:
				default:
					break;
			}
			returnMe += (double)(((*(int *)value) >> 8) & 0x3F);	//	seconds
			returnMe += (double)(((*(int *)value) >> 14) & 0x3F) * 60.0;	//	minutes
			returnMe += (double)(((*(int *)value) >> 20) & 0x1F) * 60.0 * 60.0;	//	hours
			returnMe += (double)(((*(int *)value) >> 25) & 0x07) * 60.0 * 60.0 * 24.0;	//	days
			*/
			break;
	}
	return returnMe;
}
- (NSString *) calculateStringValue	{
	switch (type)	{
		case OSCValUnknown:
			return @"?";
		case OSCValInt:
			return [NSString stringWithFormat:@"%d",*(int *)value];
		case OSCValFloat:
			return [NSString stringWithFormat:@"%f",*(float *)value];
		case OSCValString:
			return [NSString stringWithFormat:@"%@",(id)value];
		case OSCValTimeTag:
			//return [NSString stringWithFormat:@"<OSCVal t: %ld-%ld>",*(long *)(value),*(long *)(value+1)];
			//return [NSString stringWithFormat:@"<OSCVal t: %ld-%ld>",(unsigned long)(*((uint64_t *)value)>>32),(unsigned long)((*(uint64_t *)value) & 0x00000000FFFFFFFF)];
			//return [NSString stringWithFormat:@"<OSCVal t: %@>",[self dateValue]];
			{
				NSDateFormatter		*fmt = [[[NSDateFormatter alloc] init] autorelease];
				[fmt setDateFormat:@"dd/MM, HH:mm:ss.SSSSS"];
				return [fmt stringFromDate:[self dateValue]];
			}
		case OSCVal64Int:
			return [NSString stringWithFormat:@"%qi",*(long long *)value];
		case OSCValDouble:
			return [NSString stringWithFormat:@"%f",*(double *)value];
		case OSCValChar:
			return [NSString stringWithFormat:@"%s",(char *)value];
		case OSCValColor:
			return [NSString stringWithFormat:@"%@",(id)value];
		case OSCValMIDI:
			return [NSString stringWithFormat:@"%d-%d-%d-%d",((Byte *)value)[0],((Byte *)value)[1],((Byte *)value)[2],((Byte *)value)[3]];
		case OSCValBool:
			if (*(BOOL *)value)
				return @"T";
			else
				return @"F";
		case OSCValNil:
			return [NSString stringWithFormat:@"<OSCVal N>"];
		case OSCValInfinity:
			return [NSString stringWithFormat:@"<OSCVal I>"];
		case OSCValArray:
			{
				NSMutableString		*mutString = [[[NSMutableString alloc] initWithCapacity:0] autorelease];
				[mutString appendString:@"["];
				for (OSCValue *tmpVal in [self valueArray])	{
					[mutString appendString:[tmpVal calculateStringValue]];
				}
				[mutString appendString:@"]"];
				return mutString;
			}
		case OSCValBlob:
			return [NSString stringWithFormat:@"<OSCVal b: %@>",value];
		case OSCValSMPTE:
			return [NSString stringWithFormat:@"<OSCVal E: %d>",*(int *)value];
	}
	return [NSString stringWithFormat:@"??"];
}
- (OSCValue *) createValByConvertingToType:(OSCValueType)t	{
	//	if i'm already of the passed type, just return self immediately
	if (type == t)
		return self;
	//	if i'm here, i need to actually convert stuff...
	switch (t)	{
	case OSCValUnknown:
		return nil;
	case OSCValInt:
		return [OSCValue createWithInt:[self calculateIntValue]];
	case OSCValFloat:
		return [OSCValue createWithFloat:[self calculateFloatValue]];
	case OSCValString:
		return [OSCValue createWithString:[self calculateStringValue]];
	case OSCValTimeTag:
		return nil;
	case OSCVal64Int:
		return [OSCValue createWithLongLong:[self calculateLongLongValue]];
	case OSCValDouble:
		return [OSCValue createWithDouble:[self calculateDoubleValue]];
	case OSCValChar:
		return [OSCValue createWithChar:(char)[self calculateIntValue]];
	case OSCValColor:
		{
			double		tmpVal = [self calculateDoubleValue];
#if TARGET_OS_IPHONE
			return [OSCValue createWithColor:[UIColor colorWithRed:tmpVal green:tmpVal blue:tmpVal alpha:1.0]];
#else
			return [OSCValue createWithColor:[NSColor colorWithDeviceRed:tmpVal green:tmpVal blue:tmpVal alpha:1.0]];
#endif
		}
	case OSCValMIDI:
	case OSCValArray:
	case OSCValBlob:
	case OSCValSMPTE:
		return nil;	//	unhandled, returns nil!
	case OSCValBool:
		return [OSCValue createWithBool:([self calculateIntValue]>0) ? YES : NO];
	case OSCValNil:
		return [OSCValue createWithNil];
	case OSCValInfinity:
		return [OSCValue createWithInfinity];
	}
	return nil;
}
- (id) jsonValue	{
	switch (type)	{
	case OSCValUnknown:
		return nil;
	case OSCValInt:
		return [NSNumber numberWithInteger:[self intValue]];
	case OSCValFloat:
		{
			//return [NSNumber numberWithFloat:[self floatValue]];
			float		tmpFloat = [self floatValue];
			if (isnan(tmpFloat))
				tmpFloat = 0.0;
			return [NSNumber numberWithFloat:tmpFloat];
		}
	case OSCValString:
		return [self stringValue];
	case OSCValTimeTag:
		return [NSNumber numberWithLongLong:*((long long *)value)];
	case OSCVal64Int:
		return [NSNumber numberWithLongLong:[self longLongValue]];
	case OSCValDouble:
		{
			//return [NSNumber numberWithDouble:[self doubleValue]];
			double		tmpDouble = [self doubleValue];
			if (isnan(tmpDouble))
				tmpDouble = 0.0;
			return [NSNumber numberWithDouble:tmpDouble];
		}
	case OSCValChar:
		return [NSString stringWithFormat:@"%c",[self charValue]];
	case OSCValColor:
		{
			NSColor		*tmpColor = [self colorValue];
			CGFloat		components[6];
			[tmpColor getComponents:components];
			//NSArray		*returnMe = @[
			//	[NSNumber numberWithFloat:components[0]],
			//	[NSNumber numberWithFloat:components[1]],
			//	[NSNumber numberWithFloat:components[2]],
			//	[NSNumber numberWithFloat:components[3]],
			//];
			NSString		*returnMe = [NSString stringWithFormat:@"#%0.2X%0.2X%0.2X%0.2X",(int)round(components[0]*255.0),(int)round(components[1]*255.0),(int)round(components[2]*255.0),(int)round(components[3]*255.0)];
			return returnMe;
		}
	case OSCValMIDI:
		return nil;
	case OSCValBool:
		return [NSNumber numberWithBool:[self boolValue]];
	case OSCValNil:
	case OSCValInfinity:
		return nil;
	case OSCValArray:
		{
			NSMutableArray		*returnMe = [[NSMutableArray alloc] init];
			for (OSCValue *tmpVal in [self valueArray])	{
				id			tmpNSVal = [tmpVal jsonValue];
				if (tmpNSVal != nil)
					[returnMe addObject:tmpNSVal];
			}
			return [returnMe autorelease];
		}
	case OSCValBlob:
		return [self blobNSData];
	case OSCValSMPTE:
		return [NSNumber numberWithInteger:[self SMPTEValue]];
	}
	return nil;
}


@synthesize type;


- (long) bufferLength	{
	//NSLog(@"%s",__func__);
	switch (type)	{
		case OSCValTimeTag:
			return 8;
			break;
		case OSCValInt:
		case OSCValFloat:
		case OSCValChar:
		case OSCValColor:
		case OSCValMIDI:
		case OSCValSMPTE:
			return 4;
			break;
		case OSCVal64Int:
		case OSCValDouble:
			return 8;
			break;
		case OSCValString:
			//	OSC STRINGS REQUIRE A NULL CHARACTER AFTER THEM!
			return ROUNDUP4((strlen([(NSString *)value UTF8String]) + 1));
			break;
		case OSCValBool:
		case OSCValNil:
		case OSCValInfinity:
		case OSCValUnknown:
			return 0;
			break;
		case OSCValArray:
			{
				int		tmpVal = 0;
				if (value!=nil)	{
					for (OSCValue *valPtr in (NSMutableArray *)value)	{
						tmpVal += [valPtr bufferLength];
					}
				}
				return tmpVal;
			}
			break;
		case OSCValBlob:
			if (value == nil)
				return 0;
			//	BLOBS DON'T REQUIRE A NULL CHARACTER AFTER THEM!
			return ROUNDUP4((4 + [(NSData *)value length]));
			break;
	}
	return 0;
}
- (long) typeSignatureLength	{
	long		returnMe = 0;
	switch (type)	{
		case OSCValUnknown:
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
		case OSCValBool:
		case OSCValNil:
		case OSCValInfinity:
		case OSCValBlob:
		case OSCValSMPTE:
			returnMe += 1;
			break;
		case OSCValArray:
			returnMe += 2;
			if (value != nil)	{
				for (OSCValue *valPtr in (NSMutableArray *)value)	{
					returnMe += [valPtr typeSignatureLength];
				}
			}
			break;
	}
	return returnMe;
}
- (void) writeToBuffer:(unsigned char *)b typeOffset:(int *)t dataOffset:(int *)d	{
	//NSLog(@"%s ... %p, %d, %d, %@",__func__,b,*t,*d,self);
	
	int					i;
	long				tmpLong = 0;
	//float				tmpFloat = (float)0.0;
	unsigned char		*charPtr = NULL;
	void				*voidPtr = NULL;
	unsigned char		tmpChar = 0;
#if TARGET_OS_IPHONE
	CGColorRef			tmpColor;
	const CGFloat		*tmpCGFloatPtr;
#endif
	
	switch (type)	{
		case OSCValUnknown:
			break;
		case OSCValInt:
			//*((uint32_t *)(b+*d)) = CFSwapInt32HostToBig(*((uint32_t *)(value)));
			*((unsigned int *)(b+*d)) = NSSwapHostIntToBig(*((unsigned int *)(value)));
			*d += 4;
			
			b[*t] = 'i';
			++*t;
			/*
			tmpLong = *(int *)value;
			tmpLong = htonl((int)tmpLong);
			
			for (i=0; i<4; ++i)
				b[*d+i] = 255 & (tmpLong >> (i*8));
			*d += 4;
			
			b[*t] = 'i';
			++*t;
			*/
			break;
		case OSCValFloat:
			*((NSSwappedFloat *)(b+*d)) = NSSwapHostFloatToBig(*((float *)(value)));
			*d += 4;
			
			b[*t] = 'f';
			++*t;
			/*
			tmpFloat = *(float *)value;
			tmpLong = htonl(*((int *)(&tmpFloat)));
			strncpy((char *)(b+*d), (char *)(&tmpLong), 4);
			*d += 4;
			
			b[*t] = 'f';
			++*t;
			*/
			break;
		case OSCValString:
			tmpLong = strlen([(NSString *)value UTF8String]);
			charPtr = (unsigned char *)[(NSString *)value UTF8String];
			strncpy((char *)(b+*d),(char *)charPtr,tmpLong);
			*d = *d + (int)tmpLong + (int)1;
			*d = ROUNDUP4(*d);
			
			b[*t] = 's';
			++*t;
			break;
		case OSCValTimeTag:
			*((uint64_t *)(b+*d)) = NSSwapHostLongLongToBig(*(uint64_t *)value);
			*d += 8;
			
			b[*t] = 't';
			++*t;
			break;
		case OSCVal64Int:
			*((long long *)(b+*d)) = NSSwapHostLongLongToBig(*((long long *)(value)));
			*d += 8;
			
			b[*t] = 'h';
			++*t;
			break;
		case OSCValDouble:
			*((NSSwappedDouble *)(b+*d)) = NSSwapHostDoubleToBig(*((double *)(value)));
			*d += 8;
			
			b[*t] = 'd';
			++*t;
			break;
		case OSCValChar:
			*((unsigned int *)(b+*d)) = NSSwapHostIntToBig(*((unsigned int *)(value)));
			*d += 4;
			
			b[*t] = 'c';
			++*t;
			break;
		case OSCValColor:
#if TARGET_OS_IPHONE
			tmpColor = [(UIColor *)value CGColor];
			tmpCGFloatPtr = CGColorGetComponents(tmpColor);
			for (i=0;i<4;++i)	{
				tmpChar = *(tmpCGFloatPtr + i) * 255.0;
				b[*d+i] = tmpChar;
			}
#else
			tmpChar = [(NSColor *)value redComponent] * 255.0;
			b[*d] = tmpChar;
			tmpChar = [(NSColor *)value greenComponent] * 255.0;
			b[*d+1] = tmpChar;
			tmpChar = [(NSColor *)value blueComponent] * 255.0;
			b[*d+2] = tmpChar;
			tmpChar = [(NSColor *)value alphaComponent] * 255.0;
			b[*d+3] = tmpChar;
#endif
			*d += 4;
			
			b[*t] = 'r';
			++*t;
			break;
		case OSCValMIDI:
			memcpy(b+*d, value, sizeof(Byte)*4);
			*d += 4;
			
			b[*t] = 'm';
			++*t;
			break;
		case OSCValBool:
			if (*(BOOL *)value)
				b[*t] = 'T';
			else
				b[*t] = 'F';
			++*t;
			break;
		case OSCValNil:
			b[*t] = 'N';
			++*t;
			break;
		case OSCValInfinity:
			b[*t] = 'I';
			++*t;
			break;
		case OSCValArray:
			b[*t] = '[';
			++*t;
			
			if (value != nil)	{
				for (OSCValue *tmpVal in (NSMutableArray *)value)	{
					[tmpVal writeToBuffer:b typeOffset:t dataOffset:d];
				}
			}
			
			b[*t] = ']';
			++*t;
			break;
		case OSCValBlob:
			//	calculate the size of the blob, write it to the buffer
			tmpLong = [(NSData *)value length];
			tmpLong = htonl((int)tmpLong);
			for (i=0;i<4;++i)
				b[*d+i] = 255 & (tmpLong >> (i*8));
			*d += 4;
			//	now write the actual contents of the blob to the buffer
			tmpLong = [(NSData *)value length];
			voidPtr = (void *)[(NSData *)value bytes];
			memcpy((void *)(b+*d),(void *)voidPtr,tmpLong);
			*d = *d + (int)tmpLong;
			*d = ROUNDUP4(*d);
			b[*t] = 'b';
			++*t;
			break;
		case OSCValSMPTE:	//	AD-HOC DATA TYPE!  ONLY SUPPORTED BY THIS FRAMEWORK!
			*((unsigned int *)(b+*d)) = NSSwapHostIntToBig(*((unsigned int *)(value)));
			*d += 4;
			
			b[*t] = 'E';
			++*t;
			break;
	}
	
}
- (NSString *) typeTagString	{
	if (type != OSCValArray)	{
		if (type == OSCValBool)	{
			if ([self boolValue])
				return @"T";
			else
				return @"F";
		}
		return [OSCValue typeTagStringForType:type];
	}
	NSMutableString		*returnMe = [[NSMutableString alloc] initWithCapacity:[self typeSignatureLength]];
	[returnMe appendString:@"["];
	
	NSArray				*tmpArray = [self valueArray];
	for (OSCValue *tmpVal in tmpArray)	{
		[returnMe appendString:[tmpVal typeTagString]];
	}
	
	[returnMe appendString:@"]"];
	
	return [returnMe autorelease];
}
- (NSComparisonResult) compare:(OSCValue *)n	{
	if (n==nil)
		return NSOrderedDescending;
	
	OSCValueType		otherType = [n type];
	if (type==OSCValString && otherType==OSCValString)	{
		return [[self stringValue] compare:[n stringValue]];
	}
	else if (type == otherType)	{
		switch (type)	{
		case OSCValUnknown:
		case OSCValBool:
		case OSCValNil:
		case OSCValInfinity:
			return NSOrderedSame;
		case OSCValInt:
			{
				int		myVal = [self intValue];
				int		otherVal = [n intValue];
				if (myVal < otherVal)
					return NSOrderedAscending;
				else if (myVal > otherVal)
					return NSOrderedDescending;
				return NSOrderedSame;
			}
			break;
		case OSCVal64Int:
			{
				long long		myVal = [self longLongValue];
				long long		otherVal = [n longLongValue];
				if (myVal < otherVal)
					return NSOrderedAscending;
				else if (myVal > otherVal)
					return NSOrderedDescending;
				return NSOrderedSame;
			}
			break;
		case OSCValFloat:
			{
				float		myVal = [self floatValue];
				float		otherVal = [n floatValue];
				if (myVal < otherVal)
					return NSOrderedAscending;
				else if (myVal > otherVal)
					return NSOrderedDescending;
				return NSOrderedSame;
			}
			break;
		case OSCValDouble:
			{
				double		myVal = [self doubleValue];
				double		otherVal = [n doubleValue];
				if (myVal < otherVal)
					return NSOrderedAscending;
				else if (myVal > otherVal)
					return NSOrderedDescending;
				return NSOrderedSame;
			}
			break;
		case OSCValString:
			return [[self stringValue] compare:[n stringValue]];
		case OSCValChar:
			{
				char		myVal = [self charValue];
				char		otherVal = [n charValue];
				if (myVal < otherVal)
					return NSOrderedAscending;
				else if (myVal > otherVal)
					return NSOrderedDescending;
				return NSOrderedSame;
			}
			break;
		case OSCValColor:
		case OSCValMIDI:
		case OSCValTimeTag:
		case OSCValArray:
		case OSCValBlob:
		case OSCValSMPTE:
			return NSOrderedSame;
		}
	}
	return NSOrderedSame;
	/*
	NSNumber		*myNum = [NSNumber numberWithDouble:[self calculateDoubleValue]];
	NSNumber		*compNum = [NSNumber numberWithDouble:[n calculateDoubleValue]];
	if (myNum!=nil && compNum!=nil)
		return [myNum compare:compNum];
	
	return NSOrderedSame;
	*/
}
- (BOOL) isEqual:(id)object	{
	if (([object isKindOfClass:[OSCValue class]]) &&
	([self compare:object]==NSOrderedSame))
		return YES;
	return NO;
}


@end

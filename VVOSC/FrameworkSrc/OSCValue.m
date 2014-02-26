
#import "OSCValue.h"




@implementation OSCValue


- (NSString *) description	{
	switch (type)	{
		case OSCValInt:
			return [NSString stringWithFormat:@"<OSCVal i %d>",*(int *)value];
		case OSCValFloat:
			return [NSString stringWithFormat:@"<OSCVal f %f>",*(float *)value];
		case OSCValString:
			return [NSString stringWithFormat:@"<OSCVal s %@>",(id)value];
		case OSCValTimeTag:
			//return [NSString stringWithFormat:@"<OSCVal t: %ld-%ld>",*(long *)(value),*(long *)(value+1)];
			return [NSString stringWithFormat:@"<OSCVal t: %ld-%ld>",(long)(*((long long *)value)>>32),(long)((*(long long *)value) & 0x00000000FFFFFFFF)];
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
#if !IPHONE
	float		colorComps[4];
#endif
	switch (type)	{
		case OSCValInt:
			return [NSString stringWithFormat:@"integer %d",*(int *)value];
		case OSCValFloat:
			return [NSString stringWithFormat:@"float %f",*(float *)value];
		case OSCValString:
			return [NSString stringWithFormat:@"string \"%@\"",(id)value];
		case OSCValTimeTag:
			return [NSString stringWithFormat:@"Time Tag %ld-%ld",(long)(*((long long *)value)>>32),(long)((*(long long *)value) & 0x00000000FFFFFFFF)];
		case OSCVal64Int:
			return [NSString stringWithFormat:@"64-bit Integer %qi",*(long long *)value];
		case OSCValDouble:
			return [NSString stringWithFormat:@"64-bit Float %f",*(double *)value];
		case OSCValChar:
			return [NSString stringWithFormat:@"Character \"%s\"",(char *)value];
		case OSCValColor:
#if IPHONE
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
+ (id) createWithTimeSeconds:(long)s microSeconds:(long)ms	{
	OSCValue		*returnMe = [[OSCValue alloc] initWithTimeSeconds:s microSeconds:ms];
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
	if (self = [super init])	{
		value = malloc(sizeof(int));
		*(int *)value = n;
		type = OSCValInt;
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithFloat:(float)n	{
	if (self = [super init])	{
		value = malloc(sizeof(float));
		*(float *)value = n;
		type = OSCValFloat;
		return self;
	}
	[self release];
	return nil;
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
- (id) initWithTimeSeconds:(long)s microSeconds:(long)ms	{
	if (self = [super init])	{
		value = malloc(sizeof(long long));
		*(long long *)value = ((((long long)s)<<32)&(0xFFFFFFFF00000000)) | ((long long)ms);
		type = OSCValTimeTag;
		return self;
		/*
		value = malloc(sizeof(long)*2);
		long		*valPtr;
		valPtr = value;
		*valPtr = s;
		valPtr += 1;
		*valPtr = ms;
		type = OSCValTimeTag;
		return self;
		*/
	}
	[self release];
	return nil;
}
- (id) initWithLongLong:(long long)n	{
	if (self = [super init])	{
		value = malloc(sizeof(long long));
		*(long long *)value = n;
		type = OSCVal64Int;
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithDouble:(double)n	{
	if (self = [super init])	{
		value = malloc(sizeof(double));
		*(double *)value = n;
		type = OSCValDouble;
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithChar:(char)n	{
	if (self = [super init])	{
		value = malloc(sizeof(char));
		*(char *)value = n;
		type = OSCValChar;
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithColor:(id)n	{
	if (n == nil)
		goto BAIL;
	if (self = [super init])	{
#if IPHONE
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
	if (self = [super init])	{
		value = malloc(sizeof(Byte)*4);
		((Byte *)value)[0] = c;
		((Byte *)value)[1] = s;
		((Byte *)value)[2] = d1;
		((Byte *)value)[3] = d2;
		type = OSCValMIDI;
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithBool:(BOOL)n	{
	if (self = [super init])	{
		value = malloc(sizeof(BOOL));
		*(BOOL *)value = n;
		type = OSCValBool;
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithNil	{
	if (self = [super init])	{
		value = nil;
		type = OSCValNil;
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithInfinity	{
	if (self = [super init])	{
		value = nil;
		type = OSCValInfinity;
		return self;
	}
	[self release];
	return nil;
}
- (id) initArray	{
	if (self = [super init])	{
		value = [[NSMutableArray alloc] initWithCapacity:0];
		type = OSCValArray;
		return self;
	}
	[self release];
	return nil;
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
	//NSLog(@"%s ... %d, %d, %d, %d, %d",__func__,fps,d,h,m,s,f);
	if (self = [super init])	{
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
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithSMPTEChunk:(int)n	{
	if (self = [super init])	{
		value = malloc(sizeof(int));
		*(int *)value = n;
		type = OSCValSMPTE;
		return self;
	}
	[self release];
	return nil;
}
- (id) copyWithZone:(NSZone *)z	{
	OSCValue		*returnMe = nil;
	switch (type)	{
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
			returnMe = [[OSCValue allocWithZone:z] initWithTimeSeconds:(long)(*((long long *)value)>>32) microSeconds:(long)((*(long long *)value) & 0x00000000FFFFFFFF)];
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
	returnMe.tv_sec = (*((long long *)value)>>32);
	returnMe.tv_usec = ((*(long long *)value) & 0xFFFFFFFF);
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
	double		tmpTime = 0;
	tmpTime = (float)(*((long long *)value)>>32);
	tmpTime += (float)((*(long long *)value) & 0xFFFFFFFF) / 1000000.0;
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
			returnMe = (double)(*((long long *)value)>>32);
			returnMe += (double)((*(long long *)value) & 0xFFFFFFFF) / 1000000.0;
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
#if IPHONE
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
	//NSLog(@"%s ... %d, %d, %@",__func__,*t,*d,self);
	
	int					i;
	long				tmpLong = 0;
	//float				tmpFloat = (float)0.0;
	unsigned char		*charPtr = NULL;
	void				*voidPtr = NULL;
	unsigned char		tmpChar = 0;
#if IPHONE
	CGColorRef			tmpColor;
	const CGFloat		*tmpCGFloatPtr;
#endif
	
	switch (type)	{
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
			*((long *)(b+*d)) = NSSwapHostLongToBig((long)(*((long long *)value)>>32));
			*d += 4;
			*((long *)(b+*d)) = NSSwapHostLongToBig((long)((*(long long *)value) & 0xFFFFFFFF));
			*d += 4;
			/*
			*((long *)(b+*d)) = NSSwapHostLongToBig(*((long *)(value)));
			*d += 4;
			*((long *)(b+*d)) = NSSwapHostLongToBig(*((long *)(value+1)));
			*d += 4;
			*/
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
			
			break;
		case OSCValColor:
#if IPHONE
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


@end

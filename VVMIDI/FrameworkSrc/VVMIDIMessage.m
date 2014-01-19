
#import "VVMIDIMessage.h"
#import "VVMIDI.h"




@implementation VVMIDIMessage


- (NSString *) description	{
	return [NSString stringWithFormat:@"<VVMIDIMessage: 0x%X : %d : %d : %d : %d : %lli>",type,channel,data1,data2,data3, timestamp];
}
- (NSString *) lengthyDescription	{
	switch (type)	{
		//	status byte
		case VVMIDINoteOffVal:
			return [NSString stringWithFormat:@"NoteOff, ch.%hhd, note.%hhd, val.%hhd, time.%lli",channel,data1,data2,timestamp];
			break;
		case VVMIDINoteOnVal:
			return [NSString stringWithFormat:@"NoteOn, ch.%hhd, note.%hhd, val.%hhd, time.%lli",channel,data1,data2,timestamp];
			break;
		case VVMIDIAfterTouchVal:
			return [NSString stringWithFormat:@"AfterTouch, ch.%hhd, note.%hhd, val.%hhd, time.%lli",channel,data1,data2,timestamp];
			break;
		case VVMIDIControlChangeVal:
			return [NSString stringWithFormat:@"Ctrl, ch.%hhd, ctrl.%hhd, val.%hhd, time.%lli",channel,data1,data2,timestamp];
			break;
		case VVMIDIProgramChangeVal:
			return [NSString stringWithFormat:@"PgmChange, ch.%hhd, pgm.%hhd, time.%lli",channel,data1,timestamp];
			break;
		case VVMIDIChannelPressureVal:
			return [NSString stringWithFormat:@"ChannelPressure, ch.%hhd, val.%hhd, time.%lli",channel,data1,timestamp];
			break;
		case VVMIDIPitchWheelVal:
			return [NSString stringWithFormat:@"PitchWheel, ch.%hhd, val.%d, time.%lli",channel,(data2<<7)|data1,timestamp];
			break;
		//	common messages
		case VVMIDIMTCQuarterFrameVal:
			return [NSString stringWithFormat:@"Quarter-Frame: %hhd, time.%lli",data1,timestamp];
			break;
		case VVMIDISongPosPointerVal:
			return [NSString stringWithFormat:@"Song Pos'n ptr: %d, time.%lli",(data2 << 7) | data1,timestamp];
			break;
		case VVMIDISongSelectVal:
			return [NSString stringWithFormat:@"Song Select: %hhd, time.%lli",data1,timestamp];
			break;
		case VVMIDIUndefinedCommon1Val:
			return @"Undefined common";
			break;
		case VVMIDIUndefinedCommon2Val:
			return @"Undefined common 2";
			break;
		case VVMIDITuneRequestVal:
			return @"Tune Request";
			break;
		//	sysex!
		case VVMIDIBeginSysexDumpVal:
			return [NSString stringWithFormat:@"Sysex: %@, time.%lli",sysexArray,timestamp];
			break;
		//	realtime messages- insert these immediately
		case VVMIDIClockVal:
			return @"Clock";
			break;
		case VVMIDITickVal:
			return @"Tick";
			break;
		case VVMIDIStartVal:
			return @"Start";
			break;
		case VVMIDIContinueVal:
			return @"Continue";
			break;
		case VVMIDIStopVal:
			return @"Stop";
			break;
		case VVMIDIUndefinedRealtime1Val:
			return @"Undefined Realtime";
			break;
		case VVMIDIActiveSenseVal:
			return @"Active Sense";
			break;
		case VVMIDIResetVal:
			return @"MIDI Reset";
			break;
	}
	return nil;
}
- (BOOL) isFullFrameSMPTE	{
	if (sysexArray==nil)
		return NO;
	if ([sysexArray count]==10 && 
	[[sysexArray objectAtIndex:0] intValue]==240 &&
	[[sysexArray objectAtIndex:1] intValue]==127 &&
	[[sysexArray objectAtIndex:2] intValue]==127 &&
	[[sysexArray objectAtIndex:3] intValue]==1 &&
	[[sysexArray objectAtIndex:4] intValue]==1 &&
	[[sysexArray objectAtIndex:9] intValue]==247)	{
		return YES;
	}
	return NO;
}

+ (id) createWithType:(Byte)t channel:(Byte)c {
    return [self createWithType:t channel:c timestamp:nil];
}
+ (id) createFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2 {
    return [self createFromVals:t :c :d1 :d2 timestamp:nil];
}
+ (id) createFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2 :(Byte)d3 {
    return [self createFromVals:t :c :d1 :d2 :d3 timestamp:nil];
}
+ (id) createWithSysexArray:(NSMutableArray *)s {
    return [self createWithSysexArray:s timestamp:nil];
}
- (id) initWithType:(Byte)t channel:(Byte)c {
    return [self initWithType:t channel:c timestamp:nil];
}
- (id) initFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2 {
    return [self initFromVals:t :c :d1 :d2 timestamp:nil];
}
- (id) initFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2 :(Byte)d3 {
    return [self initFromVals:t :c :d1 :d2 :d3 timestamp:nil];
}
- (id) initWithSysexArray:(NSMutableArray *)s {
    return [self initWithSysexArray:s timestamp:nil];
}

+ (id) createWithType:(Byte)t channel:(Byte)c timestamp:(uint64_t)time;	{
	return [[[VVMIDIMessage alloc] initWithType:t channel:c timestamp:time] autorelease];
}
+ (id) createFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2 timestamp:(uint64_t)time;	{
	return [[[VVMIDIMessage alloc] initFromVals:t :c :d1 :d2 timestamp:time] autorelease];
}
+ (id) createFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2 :(Byte)d3 timestamp:(uint64_t)time;	{
	return [[[VVMIDIMessage alloc] initFromVals:t :c :d1 :d2 :d3 timestamp:time] autorelease];
}
+ (id) createWithSysexArray:(NSMutableArray *)s timestamp:(uint64_t)time;	{
	id			returnMe = [[VVMIDIMessage alloc] initWithSysexArray:s timestamp:time];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithType:(Byte)t channel:(Byte)c timestamp:(uint64_t)time;	{
	if (self = [super init])	{
		type = t;
		channel = c;
		data1 = -1;
		data2 = -1;
		data3 = -1;
		sysexArray = nil;
        timestamp = time;
		return self;
	}
	[self release];
	return nil;
}
- (id) initFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2 timestamp:(uint64_t)time;	{
	if (self = [super init])	{
		type = t;
		channel = c;
		data1 = d1;
		data2 = d2;
		data3 = -1;
		sysexArray = nil;
        timestamp = time;
		return self;
	}
	[self release];
	return nil;
}
- (id) initFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2 :(Byte)d3 timestamp:(uint64_t)time;	{
	if (self = [super init])	{
		type = t;
		channel = c;
		data1 = d1;
		data2 = d2;
		data3 = d3;
		sysexArray = nil;
        timestamp = time;
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithSysexArray:(NSMutableArray *)s timestamp:(uint64_t)time;	{
	if ((s==nil)||([s count]<1))
		goto BAIL;
	//	if any vals in sysex array are improperly sized, release & return nil
	for (NSNumber *numPtr in s)	{
		if ([numPtr intValue] > 0x7F)	{
			NSLog(@"\terr: bailing, val in passed sysex array (%X) was > 0x7F",[numPtr intValue]);
			goto BAIL;
		}
	}
	
	if (self = [super init])	{
		type = VVMIDIBeginSysexDumpVal;
		channel = -1;
		data1 = -1;
		data2 = -1;
		data3 = -1;
		sysexArray = [s mutableCopy];
        timestamp = time;
		return self;
	}
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	[self release];
	return nil;
}

- (id) copyWithZone:(NSZone *)z	{
	VVMIDIMessage		*copy = nil;
	if (type == VVMIDIBeginSysexDumpVal)
		copy = [[[self class] allocWithZone:z] initWithSysexArray:sysexArray timestamp:timestamp];
	else
		copy = [[[self class] allocWithZone:z] initFromVals:type :channel :data1 :data2 :data3 timestamp:timestamp];
	return copy;
	/*
	VVMIDIMessage		*copy = [[[self class] allocWithZone:z] initWithType:type channel:channel];
	[copy setData1:data1];
	[copy setData2:data2];
	return copy;
	*/
}



- (void) dealloc	{
	if (sysexArray != nil)	{
		[sysexArray release];
		sysexArray = nil;
	}
	[super dealloc];
}


- (Byte) type	{
	return type;
}
- (void) setType:(Byte)newType	{
	type = newType;
}
- (Byte) channel	{
	return channel;
}
- (void) setData1:(Byte)newData	{
	data1 = newData;
}
- (Byte) data1	{
	return data1;
}
- (void) setData2:(Byte)newData	{
	data2 = newData;
}
- (Byte) data2	{
	return data2;
}
- (void) setData3:(Byte)newData	{
	data3 = newData;
}
- (Byte) data3	{
	return data3;
}
- (NSMutableArray *) sysexArray	{
	return sysexArray;
}
- (void) setTimestamp:(uint64_t)newTimestamp {
	timestamp = newTimestamp;
}
- (uint64_t) timestamp	{
	return timestamp;
}
- (double) doubleValue	{
	//NSLog(@"%s ... %@",__func__,self);
	double		returnMe = 0.0;
	if (data3<0 || data3>127)	{
		//NSLog(@"\t\t7-bit, %d",data2);
		returnMe = (double)((double)data2/(double)127.0);
	}
	else	{
		//NSLog(@"\t\t14-bit, %d / %d, %f",data2,data3,((double)((((long)data2 & 0x7F)<<7) | ((long)data3 & 0x7F))/16383.0));
		returnMe = (double)((double)((((long)data2 & 0x7F)<<7) | ((long)data3 & 0x7F))/(double)16383.0);
	}
	//NSLog(@"\t\treturning %0.32f",returnMe);
	return returnMe;
}


@end

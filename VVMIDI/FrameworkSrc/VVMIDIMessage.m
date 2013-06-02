
#import "VVMIDIMessage.h"
#import "VVMIDI.h"




@implementation VVMIDIMessage


- (NSString *) description	{
	return [NSString stringWithFormat:@"<VVMIDIMessage: 0x%X : %d : %d : %d : %d>",type,channel,data1,data2,data3];
}
- (NSString *) lengthyDescription	{
	switch (type)	{
		//	status byte
		case VVMIDINoteOffVal:
			return [NSString stringWithFormat:@"NoteOff, ch.%hhd, note.%hhd, val.%hhd",channel,data1,data2];
			break;
		case VVMIDINoteOnVal:
			return [NSString stringWithFormat:@"NoteOn, ch.%hhd, note.%hhd, val.%hhd",channel,data1,data2];
			break;
		case VVMIDIAfterTouchVal:
			return [NSString stringWithFormat:@"AfterTouch, ch.%hhd, note.%hhd, val.%hhd",channel,data1,data2];
			break;
		case VVMIDIControlChangeVal:
			return [NSString stringWithFormat:@"Ctrl, ch.%hhd, ctrl.%hhd, val.%hhd",channel,data1,data2];
			break;
		case VVMIDIProgramChangeVal:
			return [NSString stringWithFormat:@"PgmChange, ch.%hhd, pgm.%hhd",channel,data1];
			break;
		case VVMIDIChannelPressureVal:
			return [NSString stringWithFormat:@"ChannelPressure, ch.%hhd, val.%hhd",channel,data1];
			break;
		case VVMIDIPitchWheelVal:
			return [NSString stringWithFormat:@"PitchWheel, ch.%hhd, val.%d",channel,(data2<<7)|data1];
			break;
		//	common messages
		case VVMIDIMTCQuarterFrameVal:
			return [NSString stringWithFormat:@"Quarter-Frame: %hhd",data1];
			break;
		case VVMIDISongPosPointerVal:
			return [NSString stringWithFormat:@"Song Pos'n ptr: %d",(data2 << 7) | data1];
			break;
		case VVMIDISongSelectVal:
			return [NSString stringWithFormat:@"Song Select: %hhd",data1];
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
			return [NSString stringWithFormat:@"Sysex: %@",sysexArray];
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
+ (id) createWithType:(Byte)t channel:(Byte)c	{
	return [[[VVMIDIMessage alloc] initWithType:t channel:c] autorelease];
}
+ (id) createFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2	{
	return [[[VVMIDIMessage alloc] initFromVals:t:c:d1:d2] autorelease];
}
+ (id) createFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2 :(Byte)d3	{
	return [[[VVMIDIMessage alloc] initFromVals:t:c:d1:d2:d3] autorelease];
}
+ (id) createWithSysexArray:(NSMutableArray *)s	{
	id			returnMe = [[VVMIDIMessage alloc] initWithSysexArray:s];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithType:(Byte)t channel:(Byte)c	{
	if (self = [super init])	{
		type = t;
		channel = c;
		data1 = -1;
		data2 = -1;
		data3 = -1;
		sysexArray = nil;
		return self;
	}
	[self release];
	return nil;
}
- (id) initFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2	{
	if (self = [super init])	{
		type = t;
		channel = c;
		data1 = d1;
		data2 = d2;
		data3 = -1;
		sysexArray = nil;
		return self;
	}
	[self release];
	return nil;
}
- (id) initFromVals:(Byte)t :(Byte)c :(Byte)d1 :(Byte)d2 :(Byte)d3	{
	if (self = [super init])	{
		type = t;
		channel = c;
		data1 = d1;
		data2 = d2;
		data3 = d3;
		sysexArray = nil;
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithSysexArray:(NSMutableArray *)s	{
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
		sysexArray = [s retain];
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
		copy = [[[self class] allocWithZone:z] initWithSysexArray:sysexArray];
	else
		copy = [[[self class] allocWithZone:z] initFromVals:type:channel:data1:data2:data3];
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
- (double) doubleValue	{
	if (data3<0 || data3>127)	{
		//NSLog(@"\t\t7-bit, %d",data2);
		return ((double)data2/127.0);
	}
	else	{
		//NSLog(@"\t\t14-bit, %d / %d, %f",data2,data3,((double)((((long)data2 & 0x7F)<<7) | ((long)data3 & 0x7F))/16383.0));
		return ((double)((((long)data2 & 0x7F)<<7) | ((long)data3 & 0x7F))/16383.0);
	}
}


@end

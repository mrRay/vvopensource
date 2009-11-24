
#import "VVMIDIMessage.h"
#import "VVMIDI.h"




@implementation VVMIDIMessage


- (NSString *) description	{
	return [NSString stringWithFormat:@"<VVMIDIMessage: 0x%X : %d : %d : %d>",type,channel,data1,data2];
}
- (NSString *) lengthyDescription	{
	switch (type)	{
		//	status byte
		case VVMIDINoteOffVal:
			return [NSString stringWithFormat:@"NoteOff, ch.%ld, note.%ld, val.%ld",channel,data1,data2];
			break;
		case VVMIDINoteOnVal:
			return [NSString stringWithFormat:@"NoteOn, ch.%ld, note.%ld, val.%ld",channel,data1,data2];
			break;
		case VVMIDIAfterTouchVal:
			return [NSString stringWithFormat:@"AfterTouch, ch.%ld, note.%ld, val.%ld",channel,data1,data2];
			break;
		case VVMIDIControlChangeVal:
			return [NSString stringWithFormat:@"Ctrl, ch.%ld, ctrl.%ld, val.%ld",channel,data1,data2];
			break;
		case VVMIDIProgramChangeVal:
			return [NSString stringWithFormat:@"PgmChange, ch.%ld, pgm.%ld",channel,data1];
			break;
		case VVMIDIChannelPressureVal:
			return [NSString stringWithFormat:@"ChannelPressure, ch.%ld, val.%ld",channel,data1];
			break;
		case VVMIDIPitchWheelVal:
			return [NSString stringWithFormat:@"PitchWheel, ch.%ld, val.%ld",channel,(data2<<7)|data1];
			break;
		//	common messages
		case VVMIDIMTCQuarterFrameVal:
			return [NSString stringWithFormat:@"Quarter-Frame: %ld",data1];
			break;
		case VVMIDISongPosPointerVal:
			return [NSString stringWithFormat:@"Song Pos'n ptr: %ld",(data2 << 7) | data1];
			break;
		case VVMIDISongSelectVal:
			return [NSString stringWithFormat:@"Song Select: %ld",data1];
			break;
		case VVMIDIUndefinedCommon1Val:
			return [NSString stringWithString:@"Undefined common"];
			break;
		case VVMIDIUndefinedCommon2Val:
			return [NSString stringWithString:@"Undefined common 2"];
			break;
		case VVMIDITuneRequestVal:
			return [NSString stringWithString:@"Tune Request"];
			break;
		//	sysex!
		case VVMIDIBeginSysexDumpVal:
			return [NSString stringWithFormat:@"Sysex: %@",sysexArray];
			break;
		//	realtime messages- insert these immediately
		case VVMIDIClockVal:
			return [NSString stringWithString:@"Clock"];
			break;
		case VVMIDITickVal:
			return [NSString stringWithString:@"Tick"];
			break;
		case VVMIDIStartVal:
			return [NSString stringWithString:@"Start"];
			break;
		case VVMIDIContinueVal:
			return [NSString stringWithString:@"Continue"];
			break;
		case VVMIDIStopVal:
			return [NSString stringWithString:@"Stop"];
			break;
		case VVMIDIUndefinedRealtime1Val:
			return [NSString stringWithString:@"Undefined Realtime"];
			break;
		case VVMIDIActiveSenseVal:
			return [NSString stringWithString:@"Active Sense"];
			break;
		case VVMIDIResetVal:
			return [NSString stringWithString:@"MIDI Reset"];
			break;
	}
	return nil;
}
+ (id) createWithType:(Byte)t channel:(Byte)c	{
	return [[[VVMIDIMessage alloc] initWithType:t channel:c] autorelease];
}
+ (id) createFromVals:(Byte)t:(Byte)c:(Byte)d1:(Byte)d2	{
	return [[[VVMIDIMessage alloc] initFromVals:t:c:d1:d2] autorelease];
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
		data2 = -2;
		sysexArray = nil;
		return self;
	}
	[self release];
	return nil;
}
- (id) initFromVals:(Byte)t:(Byte)c:(Byte)d1:(Byte)d2	{
	if (self = [super init])	{
		type = t;
		channel = c;
		data1 = d1;
		data2 = d2;
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
		copy = [[[self class] allocWithZone:z] initFromVals:type:channel:data1:data2];
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
- (NSMutableArray *) sysexArray	{
	return sysexArray;
}


@end

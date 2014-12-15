
/*

	a brief intro on how midi works
	
		all messages have something in common: the first byte of the message is the status byte.
	the status byte is special, because it's the only byte that has bit #7 set.  any of the bytes
	following the status byte will *not* have bit #7 set.  this is how you detect the start of
	a midi message.  status bytes will be in the range of 0x80 - 0xFF.  all remaining data bytes
	will be in the range of 0x00 - 0x7F.
	
	the byte	0x80	is	1000	0000
	the byte	0xFF	is	1111	1111
	
		the status bytes in the range 0x80 to 0xEF are for messages that broadcast to any of
	the 16 MIDI channels.  these are called the voice messages.  for voice messages, break the
	8-bit byte into 2, 4-bit nibbles.  a status byte of 0x92 would be broken up into two
	nibbles: 9 (high nibble), and 2 (low nibble).  the high nibble tells you what type of message
	it is, the low nibble tells you what channel the message is on.  here's what the high
	nibbles mean:
	
	8	note off
	9	note on
	A	afterTouch (key pressure)
	B	control change
	C	program (patch) change
	D	channel pressure
	E	pitch wheel
	
		the status bytes in the range 0xF0 to 0xFF are for messages that aren't going to a
	specific channel; these messages can be rececived by anything in a daisy chain.  these
	status bytes are therefore typically reserved for messages that synchronize playback
	between all the instruments, and other such tasks.  these status bytes are divided into
	two categories:
	
	0xF0 - 0xF7		system common messages
	0xF8 - 0xFF		system realtime messages

*/
 
 
 
/*
 //	these are all STATUS MESSAGES: all status mesages have bit 7 set.  ONLY status msgs have bit 7 set to 1!
//	these status messages go to a specific channel (these are voice messages)
#define VVMIDINoteOffVal 0x80			//	+2 data bytes
#define VVMIDINoteOnVal 0x90			//	+2 data bytes
#define VVMIDIAfterTouchVal 0xA0		//	+2 data bytes
#define VVMIDIControlChangeVal 0xB0		//	+2 data bytes
#define VVMIDIProgramChangeVal 0xC0		//	+1 data byte
#define VVMIDIChannelPressureVal 0xD0	//	+1 data byte
#define VVMIDIPitchWheelVal 0xE0		//	+2 data bytes
//	these status messages go anywhere/everywhere
//	0xF0 - 0xF7		system common messages
#define VVMIDIBeginSysexDumpVal 0xF0	//	signals the start of a sysex dump; unknown amount of data to follow
#define VVMIDIMTCQuarterFrameVal 0xF1	//	+1 data byte, rep. time code; 0-127
#define VVMIDISongPosPointerVal 0xF2	//	+ 2 data bytes, rep. 14-bit val; this is MIDI beat on which to start song.
#define VVMIDISongSelectVal 0xF3		//	+1 data byte, rep. song number; 0-127
#define VVMIDIUndefinedCommon1Val 0xF4
#define VVMIDIUndefinedCommon2Val 0xF5
#define VVMIDITuneRequestVal 0xF6		//	no data bytes!
#define VVMIDIEndSysexDumpVal 0xF7		//	signals the end of a sysex dump
//	0xF8 - 0xFF		system realtime messages
#define VVMIDIClockVal	 0xF8			//	no data bytes! 24 of these per. quarter note/96 per. measure.
#define VVMIDITickVal 0xF9				//	no data bytes! when master clock playing back, sends 1 tick every 10ms.
#define VVMIDIStartVal 0xFA				//	no data bytes!
#define VVMIDIContinueVal 0xFB			//	no data bytes!
#define VVMIDIStopVal 0xFC				//	no data bytes!
#define VVMIDIUndefinedRealtime1Val 0xFD
#define VVMIDIActiveSenseVal 0xFE		//	no data bytes! sent every 300 ms. to make sure device is active
#define VVMIDIResetVal	 0xFF			//	no data bytes! never received/don't send!
*/

#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
typedef NS_ENUM(NSInteger, VVMIDIMsgType)	{
#else
typedef enum VVMIDIMsgType	{
#endif
	VVMIDIMsgUnknown = 0x00,
	//	these are all STATUS MESSAGES: all status mesages have bit 7 set.  ONLY status msgs have bit 7 set to 1!
	//	these status messages go to a specific channel (these are voice messages)
	VVMIDINoteOffVal = 0x80,			//	+2 data bytes
	VVMIDINoteOnVal = 0x90,			//	+2 data bytes
	VVMIDIAfterTouchVal = 0xA0,		//	+2 data bytes
	VVMIDIControlChangeVal = 0xB0,		//	+2 data bytes
	VVMIDIProgramChangeVal = 0xC0,		//	+1 data byte
	VVMIDIChannelPressureVal = 0xD0,	//	+1 data byte
	VVMIDIPitchWheelVal = 0xE0,		//	+2 data bytes
	//	these status messages go anywhere/everywhere
	//	0xF0 - 0xF7		system common messages
	VVMIDIBeginSysexDumpVal = 0xF0,	//	signals the start of a sysex dump; unknown amount of data to follow
	VVMIDIMTCQuarterFrameVal = 0xF1,	//	+1 data byte, rep. time code; 0-127
	VVMIDISongPosPointerVal = 0xF2,	//	+ 2 data bytes, rep. 14-bit val; this is MIDI beat on which to start song.
	VVMIDISongSelectVal = 0xF3,		//	+1 data byte, rep. song number; 0-127
	VVMIDIUndefinedCommon1Val = 0xF4,
	VVMIDIUndefinedCommon2Val = 0xF5,
	VVMIDITuneRequestVal = 0xF6,		//	no data bytes!
	VVMIDIEndSysexDumpVal = 0xF7,		//	signals the end of a sysex dump
	//	0xF8 - 0xFF		system realtime messages
	VVMIDIClockVal = 0xF8,			//	no data bytes! 24 of these per. quarter note/96 per. measure.
	VVMIDITickVal = 0xF9,				//	no data bytes! when master clock playing back, sends 1 tick every 10ms.
	VVMIDIStartVal = 0xFA,				//	no data bytes!
	VVMIDIContinueVal = 0xFB,			//	no data bytes!
	VVMIDIStopVal = 0xFC,				//	no data bytes!
	VVMIDIUndefinedRealtime1Val = 0xFD,
	VVMIDIActiveSenseVal = 0xFE,		//	no data bytes! sent every 300 ms. to make sure device is active
	VVMIDIResetVal  = 0xFF,			//	no data bytes! never received/don't send!
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
};
#else
} VVMIDIMsgType;
#endif




#import "VVMIDIMessage.h"
#import "VVMIDINode.h"
#import "VVMIDIManager.h"

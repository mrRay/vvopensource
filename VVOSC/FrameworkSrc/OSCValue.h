
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "OSCConstants.h"




///	OSCValue encapsulates any value you can send or receive via OSC.  It is NOT mutable at this time.
/*!
When you send or receive values via OSC, you'll be working with OSCValue objects in an OSCMessage.  Internaly, OSCValue isn't mutable, and it attempts to store its value in its native format (int for an int, float for a float) instead of relying on NSNumber.  The exceptions to this are NSColor/UIColor and NSString.  This object has to exist because there needs to be a place where data can be cleanly munged, and the standard NS* data types can't represent nil or infinity satisfactorily.
*/




///	The OSC spec has a data type for MIDI messages- these describe the various data type to make it easier to work with MIDI-type OSC data.  Refer to the documentation for the VVMIDI framework (especially VVMIDI.h) for a more in-depth description of how MIDI works.
typedef enum	{
	VVOSCMIDINoteOffVal = 0x80,
	VVOSCMIDINoteOnVal = 0x90,
	VVOSCMIDIAfterTouchVal = 0xA0,
	VVOSCMIDIControlChangeVal = 0xB0,
	VVOSCMIDIProgramChangeVal = 0xC0,
	VVOSCMIDIChannelPressureVal = 0xD0,
	VVOSCMIDIPitchWheelVal = 0xE0,
	VVOSCMIDIBeginSysexDumpVal = 0xF0,
	VVOSCMIDIMTCQuarterFrameVal = 0xF1,
	VVOSCMIDISongPosPointerVal = 0xF2,
	VVOSCMIDISongSelectVal = 0xF3,
	VVOSCMIDIUndefinedCommon1Val = 0xF4,
	VVOSCMIDIUndefinedCommon2Val = 0xF5,
	VVOSCMIDITuneRequestVal = 0xF6,
	VVOSCMIDIEndSysexDumpVal = 0xF7,
	VVOSCMIDIClockVal = 0xF8,
	VVOSCMIDITickVal = 0xF9,
	VVOSCMIDIStartVal = 0xFA,
	VVOSCMIDIContinueVal = 0xFB,
	VVOSCMIDIStopVal = 0xFC,
	VVOSCMIDIUndefinedRealtime1Val = 0xFD,
	VVOSCMIDIActiveSenseVal = 0xFE,
	VVOSCMIDIResetVal = 0xFF
} VVOSCMIDIStatus;




@interface OSCValue : NSObject <NSCopying> {
	OSCValueType	type;	//!<The type of the OSCValue
	void			*value;
}

///	Creates & returns an auto-released instance of OSCValue with an int
+ (id) createWithInt:(int)n;
///	Creates & returns an auto-released instance of OSCValue with a float
+ (id) createWithFloat:(float)n;
///	Creates & returns an auto-released instance of OSCValue with an NSString
+ (id) createWithString:(NSString *)n;

//+ (id) createWithTimeTag:???
//+ (id) createWithChar:???

///	Creates & returns an auto-released instance of OSCValue with a color
+ (id) createWithColor:(id)n;
///	Creates & returns an auto-released instance of OSCValue with the passed MIDI data
+ (id) createWithMIDIChannel:(Byte)c status:(Byte)s data1:(Byte)d1 data2:(Byte)d2;
///	Creates & returns an auto-released instance of OSCValue with a BOOL
+ (id) createWithBool:(BOOL)n;
///	Creates & returns an auto-released instance of OSCValue representing nil
+ (id) createWithNil;
///	Creates & returns an auto-released instance of OSCValue representing infinity
+ (id) createWithInfinity;
///	Creates & returns an auto-released instance of OSCValue with an NSData blob
+ (id) createWithNSDataBlob:(NSData *)d;

- (id) initWithInt:(int)n;
- (id) initWithFloat:(float)n;
- (id) initWithString:(NSString *)n;
//- (id) initWithTimeTag:???
//- (id) initWithChar:???
- (id) initWithColor:(id)n;
- (id) initWithMIDIChannel:(Byte)c status:(Byte)s data1:(Byte)d1 data2:(Byte)d2;
- (id) initWithBool:(BOOL)n;
- (id) initWithNil;
- (id) initWithInfinity;
- (id) initWithNSDataBlob:(NSData *)d;

///	Returns an int value corresponding to the instance's value
- (int) intValue;
///	Returns a float value corresponding to the instance's value
- (float) floatValue;
///	Returns an NSString corresponding to the instance's value
- (NSString *) stringValue;
///	Returns a color value corresponding to the instance's value
- (id) colorValue;
///	Returns various parameters related to the instance's MIDI value
- (Byte) midiPort;
- (VVOSCMIDIStatus) midiStatus;
- (Byte) midiData1;
- (Byte) midiData2;
///	Returns a BOOL value corresponding to the instance's value
- (BOOL) boolValue;
- (NSData *) blobNSData;

///	Returns a float value, regardless as to the type of the OSCValue
- (float) calculateFloatValue;

@property (nonatomic, readonly) OSCValueType type;

- (int) bufferLength;
- (void) writeToBuffer:(unsigned char *)b typeOffset:(int *)t dataOffset:(int *)d;

@end

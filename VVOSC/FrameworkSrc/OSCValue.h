
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "OSCConstants.h"




///	OSCValue encapsulates any value you can send or receive via OSC.  It is NOT mutable at this time.
/*!
\ingroup VVOSC
When you send or receive values via OSC, you'll be working with OSCValue objects in an OSCMessage.  Internally, OSCValue isn't mutable, and it attempts to store its value in its native format (int for an int, float for a float) instead of relying on NSNumber.  The exceptions to this are NSColor/UIColor and NSString.
*/




@interface OSCValue : NSObject <NSCopying> {
	OSCValueType	type;	//!<The type of the OSCValue
	void			*value;	//!<The actual value is stored here; this memory is allocated dynamically, and the size of this pointer varies depending on the type.  Whenever possible the value is stored as a basic C data type, but it falls back to NSObjects (NSString, NSColor/UIColor, etc) for more complex data types.
}

///	Creates & returns an auto-released instance of OSCValue with an int
+ (id) createWithInt:(int)n;
///	Creates & returns an auto-released instance of OSCValue with a float
+ (id) createWithFloat:(float)n;
///	Creates & returns an auto-released instance of OSCValue with an NSString
+ (id) createWithString:(NSString *)n;
///	Creates & returns an auto-released instance of OSCValue with the timeval represented as two 32-bit unsigned ints- seconds and microseconds
+ (id) createWithTimeSeconds:(long)s microSeconds:(long)ms;
///	Creates & returns an auto-released instance of OSCValue with a 64-bit signed integer
+ (id) createWithLongLong:(long long)n;
///	Creates & returns an auto-released instance of OSCValue with a 64-bit float (double)
+ (id) createWithDouble:(double)n;
///	Creates & returns an auto-released instance of OSCValue with a character
+ (id) createWithChar:(char)n;
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
///	Creates & returns an auto-released instance of OSCValue that contains a mutable array (of other OSCValue instances)
+ (id) createArray;
///	Creates & returns an auto-released instance of OSCValue with an NSData blob
+ (id) createWithNSDataBlob:(NSData *)d;
///	Creates & returns an auto-released instance of OSCValue with an SMPTE timecode
+ (id) createWithSMPTEVals:(OSCSMPTEFPS)fps :(int)d :(int)h :(int)m :(int)s :(int)f;
+ (id) createWithSMPTEChunk:(int)n;

- (NSString *) lengthyDescription;

- (id) initWithInt:(int)n;
- (id) initWithFloat:(float)n;
- (id) initWithString:(NSString *)n;
- (id) initWithTimeSeconds:(long)s microSeconds:(long)ms;
- (id) initWithLongLong:(long long)n;
- (id) initWithDouble:(double)n;
- (id) initWithChar:(char)n;
- (id) initWithColor:(id)n;
- (id) initWithMIDIChannel:(Byte)c status:(Byte)s data1:(Byte)d1 data2:(Byte)d2;
- (id) initWithBool:(BOOL)n;
- (id) initWithNil;
- (id) initWithInfinity;
- (id) initArray;
- (id) initWithNSDataBlob:(NSData *)d;
- (id) initWithSMPTEVals:(OSCSMPTEFPS)fps :(int)d :(int)h :(int)m :(int)s :(int)f;
- (id) initWithSMPTEChunk:(int)n;

///	Returns an int value corresponding to the instance's value
- (int) intValue;
///	Returns a float value corresponding to the instance's value
- (float) floatValue;
///	Returns an NSString corresponding to the instance's value
- (NSString *) stringValue;
///	Returns the standard unix timeval struct, with two 32-bit longs- one for seconds, one for microseconds
- (struct timeval) timeValue;
///	Returns an NSDate created from the time value
- (NSDate *) dateValue;
///	Returns a 64-bit signed integer value corresponding to the instance's value
- (long long) longLongValue;
///	Returns a 64-bit float (a double) corresopnding to the instance's value
- (double) doubleValue;
///	Returns a char value corresponding to the instance's value
- (char) charValue;
///	Returns a color value corresponding to the instance's value
- (id) colorValue;
///	Returns the midi port (if the value type is OSCValMIDI)
- (Byte) midiPort;
///	Returns the midi status byte (if the value type is OSCValMIDI)
- (OSCMIDIType) midiStatus;
///	Returns the first midi data byte (if the value type is OSCValMIDI)
- (Byte) midiData1;
///	Returns the second midi data byte (if the value type is OSCValMIDI)
- (Byte) midiData2;
///	Returns a BOOL value corresponding to the instance's value
- (BOOL) boolValue;
///	Adds the passed (non-nil) value to the array (only works if receiver is an array-type OSCValue)
- (void) addValue:(OSCValue *)n;
///	Returns this value's NSMutableArray, which contains zero or more OSCValue instances
- (NSMutableArray *) valueArray;
///	Returns an auto-released NSData instance containing the "blob" data
- (NSData *) blobNSData;
///	Returns a 32-bit value representing the SMPTE time.
- (int) SMPTEValue;
- (NSString *) SMPTEString;

///	Returns a float value, regardless as to the type of the OSCValue
- (float) calculateFloatValue;
///	Returns a double value, regardless as to the type of the OSCValue
- (double) calculateDoubleValue;

@property (nonatomic, readonly) OSCValueType type;

- (long) bufferLength;
- (long) typeSignatureLength;
- (void) writeToBuffer:(unsigned char *)b typeOffset:(int *)t dataOffset:(int *)d;

@end

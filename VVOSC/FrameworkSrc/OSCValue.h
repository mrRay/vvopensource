#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <VVOSC/OSCConstants.h>




///	OSCValue encapsulates any value you can send or receive via OSC.  It is NOT mutable at this time.
/*!
\ingroup VVOSC
When you send or receive values via OSC, you'll be working with OSCValue objects in an OSCMessage.  Internally, OSCValue isn't mutable, and it attempts to store its value in its native format (int for an int, float for a float) instead of relying on NSNumber.  The exceptions to this are NSColor/UIColor and NSString.
*/




@interface OSCValue : NSObject <NSCopying> {
	OSCValueType	type;	//!<The type of the OSCValue
	void			*value;	//!<The actual value is stored here; this memory is allocated dynamically, and the size of this pointer varies depending on the type.  Whenever possible the value is stored as a basic C data type, but it falls back to NSObjects (NSString, NSColor/UIColor, etc) for more complex data types.
}

+ (NSString *) typeTagStringForType:(OSCValueType)t;
+ (OSCValueType) typeForTypeTagString:(NSString *)t;
+ (OSCValueType) typeForTypeTagChar:(unichar)c;
///	Creates & returns an auto-released instance of OSCValue with an int
+ (instancetype) createWithInt:(int)n;
///	Creates & returns an auto-released instance of OSCValue with a float
+ (instancetype) createWithFloat:(float)n;
///	Creates & returns an auto-released instance of OSCValue with an NSString
+ (instancetype) createWithString:(NSString *)n;
///	Creates & returns an auto-released instance of OSCValue with the timeval represented as two 32-bit unsigned ints- seconds and microseconds
+ (instancetype) createWithTimeSeconds:(unsigned long)s microSeconds:(unsigned long)ms;
+ (instancetype) createWithOSCTimetag:(uint64_t)n;
+ (instancetype) createTimeWithDate:(NSDate *)n;
///	Creates & returns an auto-released instance of OSCValue with a 64-bit signed integer
+ (instancetype) createWithLongLong:(long long)n;
///	Creates & returns an auto-released instance of OSCValue with a 64-bit float (double)
+ (instancetype) createWithDouble:(double)n;
///	Creates & returns an auto-released instance of OSCValue with a character
+ (instancetype) createWithChar:(char)n;
///	Creates & returns an auto-released instance of OSCValue with a color
+ (instancetype) createWithColor:(id)n;
///	Creates & returns an auto-released instance of OSCValue with the passed MIDI data
+ (instancetype) createWithMIDIChannel:(Byte)c status:(Byte)s data1:(Byte)d1 data2:(Byte)d2;
///	Creates & returns an auto-released instance of OSCValue with a BOOL
+ (instancetype) createWithBool:(BOOL)n;
///	Creates & returns an auto-released instance of OSCValue representing nil
+ (instancetype) createWithNil;
///	Creates & returns an auto-released instance of OSCValue representing infinity
+ (instancetype) createWithInfinity;
///	Creates & returns an auto-released instance of OSCValue that contains a mutable array (of other OSCValue instances)
+ (instancetype) createArray;
///	Creates & returns an auto-released instance of OSCValue with an NSData blob
+ (instancetype) createWithNSDataBlob:(NSData *)d;
///	Creates & returns an auto-released instance of OSCValue with an SMPTE timecode
+ (instancetype) createWithSMPTEVals:(OSCSMPTEFPS)fps :(int)d :(int)h :(int)m :(int)s :(int)f;
+ (instancetype) createWithSMPTEChunk:(int)n;

- (NSString *) lengthyDescription;

- (instancetype) initWithInt:(int)n;
- (instancetype) initWithFloat:(float)n;
- (instancetype) initWithString:(NSString *)n;
- (instancetype) initWithTimeSeconds:(unsigned long)s microSeconds:(unsigned long)ms;
- (instancetype) initWithOSCTimetag:(uint64_t)n;
- (instancetype) initTimeWithDate:(NSDate *)n;
- (instancetype) initWithLongLong:(long long)n;
- (instancetype) initWithDouble:(double)n;
- (instancetype) initWithChar:(char)n;
- (instancetype) initWithColor:(id)n;
- (instancetype) initWithMIDIChannel:(Byte)c status:(Byte)s data1:(Byte)d1 data2:(Byte)d2;
- (instancetype) initWithBool:(BOOL)n;
- (instancetype) initWithNil;
- (instancetype) initWithInfinity;
- (instancetype) initArray;
- (instancetype) initWithNSDataBlob:(NSData *)d;
- (instancetype) initWithSMPTEVals:(OSCSMPTEFPS)fps :(int)d :(int)h :(int)m :(int)s :(int)f;
- (instancetype) initWithSMPTEChunk:(int)n;

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
///	Returns an int value, regardless as to the type of the OSCValue
- (int) calculateIntValue;
///	Returns a long long value, regardless as to the type of the OSCValue
- (long long) calculateLongLongValue;
///	Returns a string value, regardless as to the type of the OSCValue
- (NSString *) calculateStringValue;
///	Returns an OSCValue of the specified type, attempts to convert existing value to the given type.  Returns 'self' is receiver is already of passed type.
- (OSCValue *) createValByConvertingToType:(OSCValueType)t;

- (id) jsonValue;

@property (nonatomic, readonly) OSCValueType type;

- (long) bufferLength;
- (long) typeSignatureLength;
- (void) writeToBuffer:(unsigned char *)b typeOffset:(int *)t dataOffset:(int *)d;
- (NSString *) typeTagString;
- (NSComparisonResult) compare:(OSCValue *)n;
- (BOOL) isEqual:(id)object;

@end

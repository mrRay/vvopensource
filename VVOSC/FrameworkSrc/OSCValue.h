//
//  OSCValue.h
//  VVOSC
//
//  Created by bagheera on 2/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif




typedef enum	{
	OSCValInt = 1,
	OSCValFloat = 2,
	OSCValString = 3,
	OSCValTimeTag = 4,
	OSCValChar = 5,
	OSCValColor = 6,
	OSCValMIDI = 7,
	OSCValBool = 8,
	OSCValNil = 9,
	OSCValInfinity = 10
} OSCValueType;




//	this macro just rounds a number up to the nearest multiple of 4
#define ROUNDUP4(A) ((((A)%4)!=0) ? (4-((A)%4)+(A)) : ((A)+4))




///	OSCValue encapsulates any value you can send or receive via OSC.  It is NOT mutable at this time.
/*!
When you send or receive values via OSC, you'll be working with OSCValue objects in an OSCMessage.  Internaly, OSCValue isn't mutable, and it attempts to store its value in its native format (int for an int, float for a float) instead of relying on NSNumber.  The exceptions to this are NSColor/UIColor and NSString.  This object has to exist because there needs to be a place where data can be cleanly munged, and the standard NS* data types can't represent nil or infinity satisfactorily.
*/
@interface OSCValue : NSObject <NSCopying> {
	int			type;
	void		*value;
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
- (Byte) midiStatus;
- (Byte) midiData1;
- (Byte) midiData2;
///	Returns a BOOL value corresponding to the instance's value
- (BOOL) boolValue;

@property (nonatomic, readonly) int type;

- (int) bufferLength;
- (void) writeToBuffer:(unsigned char *)b typeOffset:(int *)t dataOffset:(int *)d;

@end


#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "OSCValue.h"
#import <pthread.h>



///	Corresponds to an OSC message: contains zero or more values, and the address path the values have to get sent to.
/*!
According to the OSC spec, a message consists of an address path (where the message should be sent) and zero or more arguments.  An OSCMessage must be created with an address path- once the OSCMessage exists, you may add as many arguments to it as you'd like.
*/
@interface OSCMessage : NSObject <NSCopying> {
	NSString			*address;	//!<The address this message is being sent to
	int					valueCount;	//!<The # of values in this message
	OSCValue			*value;	//!<Only used if 'valueCount' is < 2
	NSMutableArray		*valueArray;//!<Only used if 'valCount' is > 1

}

+ (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l toInPort:(id)p;
///	Creates & returns an auto-released instance of OSCMessage which will be sent to the passed path
+ (id) createWithAddress:(NSString *)a;
- (id) initWithAddress:(NSString *)a;

///	Add the passed int to the message
- (void) addInt:(int)n;
///	Add the passed float to the message
- (void) addFloat:(float)n;
///	Add the passed string to the message
- (void) addString:(NSString *)n;
#if IPHONE
///	Add the passed color to the message
- (void) addColor:(UIColor *)c;
#else
///	Add the passed color to the message
- (void) addColor:(NSColor *)c;
#endif
///	Add the passed bool to the message
- (void) addBOOL:(BOOL)n;

///	Adds the passed OSCValue object to the mesage
- (void) addValue:(OSCValue *)n;

///	NOT A KEY-VALUE METHOD- function depends on valueCount!  'value' either returns "val" or the first object in "valArray", depending on "valCount"
- (OSCValue *) value;
- (OSCValue *) valueAtIndex:(int)i;

///	Returns 0.0 if 'valueArray' is empty, otherwise calculates the float val for the first OSCValue in 'valueArray'
- (float) calculateFloatValue;
///	Returns 0.0 if 'valueArray' is empty, otherwise calculates the float val for the OSCValue in 'valueArray' at the specified index
- (float) calculateFloatValueAtIndex:(int)i;

- (NSString *) address;
- (int) valueCount;
- (NSMutableArray *) valueArray;

- (int) bufferLength;
- (void) writeToBuffer:(unsigned char *)b;

@end

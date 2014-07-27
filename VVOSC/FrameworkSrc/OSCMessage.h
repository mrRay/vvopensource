
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "OSCValue.h"
#import <pthread.h>




///	Corresponds to an OSC message: contains zero or more values, and the address path the values have to get sent to.
/*!
\ingroup VVOSC
According to the OSC spec, a message consists of an address path (where the message should be sent) and zero or more arguments.  An OSCMessage must be created with an address path- once the OSCMessage exists, you may add as many arguments to it as you'd like.
*/
@interface OSCMessage : NSObject <NSCopying> {
	NSString			*address;	//!<The address this message is being sent to.  does NOT include any address formatting related to OSC query stuff!  this is literally just the address of the destination node!
	
	int					valueCount;	//!<The number of values in this message
	OSCValue			*value;	//!<Only used if 'valueCount' is < 2
	NSMutableArray		*valueArray;//!<Only used if 'valCount' is > 1
	
	NSDate				*timeTag;	//!<Nil, or the NSDate at which this message should be executed.  If nil, assume immediate execution.
	
	BOOL				wildcardsInAddress;	//!<Calculated while OSCMessage is being parsed or created.  Used to expedite message dispatch by allowing regex to be skipped when unnecessary.
	OSCMessageType		messageType;//!<OSCMessageTypeControl by default
	OSCQueryType		queryType;	//!<OSCQueryTypeUnknown by default
	unsigned int		queryTXAddress;	//!<0 by default, set when parsing received data- NETWORK BYTE ORDER.  technically, it's a 'struct in_addr'- this is the IP address from which the message was received.  queries need to send their replies back somewhere!
	unsigned short		queryTXPort;	//!<0 by default, set when parsing received data- NETWORK BYTE ORDER.  this is the port from which the UDP message that created this message was received
	
	id					msgInfo;	//	a RETAINED var that isn't used by this class at all- this is open for use by users/subclasses
}

+ (OSCMessage *) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l fromAddr:(unsigned int)txAddr port:(unsigned short)txPort;
///	Creates & returns an auto-released instance of OSCMessage which will be sent to the passed path
+ (id) createWithAddress:(NSString *)a;
+ (id) createQueryType:(OSCQueryType)t forAddress:(NSString *)a;
+ (id) createReplyForAddress:(NSString *)a;
+ (id) createReplyForMessage:(OSCMessage *)m;
+ (id) createErrorForAddress:(NSString *)a;
+ (id) createErrorForMessage:(OSCMessage *)m;

- (id) initWithAddress:(NSString *)a;
- (id) initQueryType:(OSCQueryType)t forAddress:(NSString *)a;
- (id) initReplyForAddress:(NSString *)a;
- (id) initReplyForMessage:(OSCMessage *)m;
- (id) initErrorForAddress:(NSString *)a;
- (id) initErrorForMessage:(OSCMessage *)m;
- (id) initFast:(NSString *)addr :(BOOL)addrHasWildcards :(OSCMessageType)mType :(OSCQueryType)qType :(unsigned int)qTxAddr :(unsigned short)qTxPort;

///	Add the passed int to the message
- (void) addInt:(int)n;
///	Add the passed float to the message
- (void) addFloat:(float)n;
///	Add the passed double to the message
- (void) addDouble:(double)n;
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
///	Add the passed NSData instance to the message as an OSC-blob
- (void) addNSDataBlob:(NSData *)b;

///	Adds the passed OSCValue object to the mesage
- (void) addValue:(OSCValue *)n;

///	NOT A KEY-VALUE METHOD- function depends on valueCount!  'value' either returns "val" or the first object in "valArray", depending on "valCount"
- (OSCValue *) value;
- (OSCValue *) valueAtIndex:(int)i;

///	Returns 0.0 if 'valueArray' is empty, otherwise calculates the float val for the first OSCValue in 'valueArray'
- (float) calculateFloatValue;
///	Returns 0.0 if 'valueArray' is empty, otherwise calculates the float val for the OSCValue in 'valueArray' at the specified index
- (float) calculateFloatValueAtIndex:(int)i;

///	Returns 0.0 if 'valueArray' is empty, otherwise calculates the float val for the first OSCValue in 'valueArray'
- (double) calculateDoubleValue;
///	Returns 0.0 if 'valueArray' is empty, otherwise calculates the float val for the OSCValue in 'valueArray' at the specified index
- (double) calculateDoubleValueAtIndex:(int)i;

///	Returns the address variable
- (NSString *) address;
///	Returns the reply address for this message.  If this was a query its address includes the query specifier in it, so I can't just return the 'address' variable (which explicitly does NOT contain any OSC query protocol data)
- (NSString *) replyAddress;
- (int) valueCount;
- (NSMutableArray *) valueArray;
- (NSDate *) timeTag;
- (void) setTimeTag:(NSDate *)n;

- (long) bufferLength;
- (void) writeToBuffer:(unsigned char *)b;
- (NSData *) writeToNSData;

- (BOOL) wildcardsInAddress;
- (OSCMessageType) messageType;
- (OSCQueryType) queryType;
- (unsigned int) queryTXAddress;
- (unsigned short) queryTXPort;

- (void) _setWildcardsInAddress:(BOOL)n;
- (void) _setMessageType:(OSCMessageType)n;
- (void) _setQueryType:(OSCQueryType)n;
- (NSString *) _description;

- (void) setMsgInfo:(id)n;
- (id) msgInfo;

@end

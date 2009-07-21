
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "OSCMessage.h"




///	An OSCBundle is a "container" for multiple OSC messages or bundles (bundles may also be nested)
/*!
According to the OSC spec, an OSC bundle is basically a wrapper for multiple OSC messages (or other bundles).  Instead of sending a bunch of individual messages, you can wrap them all into a bundle, and send the bundle (messages will still be sent to their individual address paths).  OSCBundle’s interface is correspondingly simple: you can create a bundle from some elements, or you can create a bundle and then add some elements (OSCMessages or OSCBundles) to it.
*/




@interface OSCBundle : NSObject {
	NSMutableArray		*elementArray;	//	array of messages or bundles
}

+ (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l toInPort:(id)p;
///	Creates and returns an auto-released bundle
+ (id) create;
///	Creates and returns an auto-released bundle with the single passed element
+ (id) createWithElement:(id)n;
///	Creates and returns an auto-released bundle with the array of passed elements
+ (id) createWithElementArray:(id)a;

///	Adds the passed element to the bundle
- (void) addElement:(id)n;
///	Adds the array of passed elements to the bundle
- (void) addElementArray:(NSArray *)a;

- (int) bufferLength;
- (void) writeToBuffer:(unsigned char *)b;

@end

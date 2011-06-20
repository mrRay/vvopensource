
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif


@interface NSHost (NSHostAdditions)

- (NSArray *) IPv4Addresses;

@end


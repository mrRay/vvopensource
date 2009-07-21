
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif


@interface NSString (OSCStringAdditions)

- (NSString *) trimFirstAndLastSlashes;
- (NSString *) stringByDeletingFirstPathComponent;
- (NSString *) firstPathComponent;
- (NSString *) stringBySanitizingForOSCPath;

@end

#import <TargetConditionals.h>
#if !TARGET_OS_IPHONE
#import <Cocoa/Cocoa.h>
#else
#import <UIKit/UIKit.h>
#endif




@interface NSObject (ISFObjectAdditions)

- (NSString *) JSONString;
- (NSString *) prettyJSONString;

@end

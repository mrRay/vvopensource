#import <TargetConditionals.h>
#if !TARGET_OS_IPHONE
#import <Cocoa/Cocoa.h>
#else
#import <UIKit/UIKit.h>
#endif




@interface NSString (ISFStringAdditions)

- (NSString *) stringByDeletingLastAndAddingFirstSlash;
- (NSRange) lexFunctionCallInRange:(NSRange)funcNameRange addVariablesToArray:(NSMutableArray *)varArray;
- (NSUInteger) numberOfLines;
- (id) objectFromJSONString;
- (id) mutableObjectFromJSONString;
- (NSNumber *) parseAsBoolean;

@end

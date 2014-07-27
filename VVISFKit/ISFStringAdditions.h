#import <Cocoa/Cocoa.h>




@interface NSString (ISFStringAdditions)

- (NSString *) stringByDeletingLastAndAddingFirstSlash;
- (NSRange) lexFunctionCallInRange:(NSRange)funcNameRange addVariablesToArray:(NSMutableArray *)varArray;

@end

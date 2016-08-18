#import <Cocoa/Cocoa.h>
//#import "Macros.h"




@interface NSColor (NSColorAdditions)

- (void) getDevRGBComponents:(CGFloat *)components;
+ (NSColor *) devColorFromValArray:(NSArray *)n;

@end

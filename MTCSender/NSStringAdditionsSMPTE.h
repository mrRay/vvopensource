#import <Foundation/Foundation.h>




@interface NSString (NSStringAdditionsSMPTE)

- (NSArray *) componentsSeparatedByRegex:(NSString *)r;
//	this presumes a start time of 0:0:0:1 for when describing the current play time
+ (NSString *) smpteStringForTimeInSeconds:(double)time withFPS:(double)fps;
+ (double) timeInSecondsForSMPTEString:(NSString*)smpte withFPS:(double)fps;

@end

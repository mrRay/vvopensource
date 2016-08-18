#import "NSValueAdditions.h"




@implementation NSValue (NSValueAdditions)


+ (NSValue *) pointValueFromValArray:(NSArray *)n	{
	if (n==nil)
		return nil;
	NSInteger			valCount = [n count];
	if (valCount != 2)
		return nil;
	NSPoint				pointVal = NSMakePoint(0., 0.);
	NSNumber			*tmpNum = nil;
	tmpNum = [n objectAtIndex:0];
	if (tmpNum==nil || ![tmpNum isKindOfClass:[NSNumber class]])
		return nil;
	pointVal.x = [tmpNum doubleValue];
	tmpNum = [n objectAtIndex:1];
	if (tmpNum==nil || ![tmpNum isKindOfClass:[NSNumber class]])
		return nil;
	pointVal.y = [tmpNum doubleValue];
	return [NSValue valueWithPoint:pointVal];
}


@end
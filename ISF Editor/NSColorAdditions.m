#import "NSColorAdditions.h"




@implementation NSColor (NSColorAdditions)


- (void) getDevRGBComponents:(CGFloat *)components	{
	if (components == nil)
		return;
	NSColor				*devColor = nil;
	NSColorSpace		*devCS = [NSColorSpace deviceRGBColorSpace];
	devColor = ([self colorSpace]==devCS) ? self : [self colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	if (devColor != nil)
		[devColor getComponents:components];
}
+ (NSColor *) devColorFromValArray:(NSArray *)n	{
	if (n==nil)
		return nil;
	NSInteger		maxValIndex = [n count] - 1;
	if (maxValIndex<3 || maxValIndex>4)
		return nil;
	double			valArray[] = {1., 1., 1., 1.};
	NSNumber		*tmpNum = nil;
	for (int i=0; i<4; ++i)	{
		if (i <= maxValIndex)	{
			tmpNum = [n objectAtIndex:i];
			if (tmpNum != nil)	{
				if ([tmpNum isKindOfClass:[NSNumber class]])
					valArray[i] = [tmpNum doubleValue];
				else
					valArray[i] = 1.;
			}
			else
				valArray[i] = 1.;
		}
		else
			valArray[i] = 1.;
	}
	return [NSColor colorWithDeviceRed:valArray[0] green:valArray[1] blue:valArray[2] alpha:valArray[3]];
}


@end

#import "NSColorWellNonContinuous.h"

@implementation NSColorWellNonContinuous

- (void) deactivate	{
	//NSLog(@"%s",__func__);
	[super deactivate];
	if (![self isContinuous] && [self target]!=nil)
		[self sendAction:[self action] to:[self target]];
}

@end

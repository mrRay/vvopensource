//
//  NSProgressIndicatorAdditions.m
//  ISF Syphon Filter Tester
//
//  Created by bagheera on 1/20/14.
//  Copyright (c) 2014 zoidberg. All rights reserved.
//

#import "NSProgressIndicatorAdditions.h"




@implementation NSProgressIndicator (NSProgressIndicatorAdditions)


- (void) setNSNumberValue:(NSNumber *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if (n==nil)
		return;
	[self setDoubleValue:[n doubleValue]];
}


@end

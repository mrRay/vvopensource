//
//  NSPopUpButtonAdditions.m
//  ISF Syphon Filter Tester
//
//  Created by bagheera on 1/13/14.
//  Copyright (c) 2014 zoidberg. All rights reserved.
//

#import "NSPopUpButtonAdditions.h"




@implementation NSPopUpButton (NSPopUpButtonAdditions)


- (NSMenuItem *) addAndReturnItemWithTitle:(NSString *)t	{
	NSMenu			*myMenu = [self menu];
	if (myMenu == nil)
		return nil;
	NSMenuItem		*returnMe = [[NSMenuItem alloc] initWithTitle:(t==nil)?@"":t action:nil keyEquivalent:@""];
	if (returnMe == nil)
		return nil;
	[myMenu addItem:returnMe];
	[returnMe release];
	return returnMe;
}


@end

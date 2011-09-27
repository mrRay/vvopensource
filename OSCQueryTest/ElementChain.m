//
//  ElementChain.m
//  VVOpenSource
//
//  Created by bagheera on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ElementChain.h"




@implementation ElementChain


- (id) initWithFrame:(NSRect)f	{
	if (self = [super initWithFrame:f])	{
		[self _generalInit];
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (id) initWithCoder:(NSCoder *)c	{
	if (self = [super initWithCoder:c])	{	
		[self _generalInit];
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (void) dealloc	{
	VVRELEASE(elementArray);
	[super dealloc];
}


- (void) _generalInit	{
	elementArray = [[MutLockArray alloc] init];
}


@end

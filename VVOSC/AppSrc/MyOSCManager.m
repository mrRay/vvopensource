//
//  MyOSCManager.m
//  VVOSC
//
//  Created by bagheera on 10/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "MyOSCManager.h"


@implementation MyOSCManager


- (id) inPortClass	{
	//NSLog(@"MyOSCManager:inPortClass:");
	return [OSCInPortRetainsRaw class];
}
- (OSCOutPort *) createNewOutputToAddress:(NSString *)a atPort:(int)p withLabel:(NSString *)l	{
	//NSLog(@"MyOSCManager:createNewOutputToAddress:atPort:withLabel:");
	OSCOutPort		*returnMe = [super createNewOutputToAddress:a atPort:p withLabel:l];
	//	post a notification that the ports have been changed and need to be reloaded
	[[NSNotificationCenter defaultCenter] postNotificationName:VVOSCOutPortsChangedNotification object:nil];
	return returnMe;
}
- (void) removeInput:(id)p	{
	[super removeInput:p];
	//	post a notification that the ports have been changed and need to be reloaded
	[[NSNotificationCenter defaultCenter] postNotificationName:VVOSCOutPortsChangedNotification object:nil];
}
- (void) removeOutput:(id)p	{
	[super removeOutput:p];
	//	post a notification that the ports have been changed and need to be reloaded
	[[NSNotificationCenter defaultCenter] postNotificationName:VVOSCOutPortsChangedNotification object:nil];
}

@end

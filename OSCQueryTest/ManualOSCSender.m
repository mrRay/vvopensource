//
//  ManualOSCSender.m
//  VVOpenSource
//
//  Created by bagheera on 9/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ManualOSCSender.h"




@implementation ManualOSCSender


- (IBAction) listNodesClicked:(id)sender	{
	NSLog(@"%s",__func__);
	OSCOutPort		*manualOutput = [oscManager findOutputWithLabel:@"ManualOutput"];
	if (manualOutput == nil)	{
		NSLog(@"\t\terr: couldn't find manual output in %s",__func__);
		return;
	}
	NSString		*address = [oscAddressField stringValue];
	OSCMessage		*msg = [OSCMessage createQueryType:OSCQueryTypeNamespaceExploration forAddress:address];
	NSLog(@"\t\tmsg being sent is %@",msg);
	//[manualOutput sendThisMessage:msg];
	[oscManager dispatchQuery:msg toOutput:manualOutput];
}
- (IBAction) documentationClicked:(id)sender	{
	NSLog(@"%s",__func__);
}
- (IBAction) acceptedTypesClicked:(id)sender	{
	NSLog(@"%s",__func__);
}
- (IBAction) currentValClicked:(id)sender	{
	NSLog(@"%s",__func__);
}


@end

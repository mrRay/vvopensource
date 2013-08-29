//
//  NetworkSetupController.m
//  VVOpenSource
//
//  Created by bagheera on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NetworkSetupController.h"




@implementation NetworkSetupController


- (id) init	{
	if (self = [super init])	{
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshDestinations:) name:OSCOutPortsChangedNotification object:nil];
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (void) awakeFromNib	{
	//NSLog(@"%s",__func__);
	[oscManager setInPortLabelBase:@"OSCQueryTest"];
	//	create a new input port, populate the relevant fields
	OSCInPort		*inPort = [oscManager createNewInput];
	if (inPort == nil)
		return;
	NSArray			*addressArray = [OSCManager hostIPv4Addresses];
	[myIPField setStringValue:(addressArray!=nil && [addressArray count]>0) ? [addressArray objectAtIndex:0] : @"127.0.0.1"];
	[myPortField setIntValue:[inPort port]];
	//	create the manual output port, the only port that will actually send data.  by default, it should be pointing at my input port (loopback!)
	NSString		*tmpLabel = @"ManualOutput";
	[oscManager removeOutputWithLabel:tmpLabel];
	[oscManager createNewOutputToAddress:@"127.0.0.1" atPort:[inPort port] withLabel:tmpLabel];
	//	populate the pop-up button with the list of detected OSC destinations
	[self refreshDestinations:nil];
}


- (void) refreshDestinations:(NSNotification *)note	{
	NSLog(@"%s",__func__);
	MutLockArray		*outPorts = [oscManager outPortArray];
	[dstPopUpButton removeAllItems];
	[outPorts rdlock];
	for (OSCOutPort *outPort in [outPorts array])	{
		[dstPopUpButton addItemWithTitle:[outPort portLabel]];
	}
	[outPorts unlock];
}


- (IBAction) myPortFieldUsed:(id)sender	{
	MutLockArray		*inPortArray = [oscManager inPortArray];
	if (inPortArray==nil || [inPortArray count]<1)	{
		NSLog(@"\t\terr: no input ports in %s",__func__);
		return;
	}
	OSCInPort			*inPort = [inPortArray lockObjectAtIndex:0];
	[inPort setPort:[myPortField intValue]];
}


- (IBAction) dstPopUpButtonUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	//	if the sender selected the manual output item, ignore it- this just doesn't do anything
	NSString		*selectedTitle = [sender titleOfSelectedItem];
	if (selectedTitle==nil || [selectedTitle isEqualToString:@"ManualOutput"])
		return;
	
	//	get the IP address & port from the selected output, apply it to the manual output port
	OSCOutPort		*selectedOutput = [oscManager findOutputWithLabel:selectedTitle];
	if (selectedOutput == nil)	{
		NSLog(@"\t\terr: couldn't find selectedOutput in %s",__func__);
		return;
	}
	OSCOutPort		*manualOutput = [oscManager findOutputWithLabel:@"ManualOutput"];
	if (manualOutput == nil)	{
		NSLog(@"\t\terr: couldn't find manualOutput in %s",__func__);
		return;
	}
	[dstIPField setStringValue:[selectedOutput addressString]];
	[manualOutput setAddressString:[selectedOutput addressString]];
	[dstPortField setIntValue:[selectedOutput port]];
	[manualOutput setPort:[selectedOutput port]];
	//	select 'manual output' from the pop-up button
	[dstPopUpButton selectItemWithTitle:@"ManualOutput"];
}
- (IBAction) dstFieldUsed:(id)sender	{
	OSCOutPort		*manualOutput = [oscManager findOutputWithLabel:@"ManualOutput"];
	if (manualOutput == nil)	{
		NSLog(@"\t\terr: couldn't find manual output in %s",__func__);
		return;
	}
	
	if (sender == dstIPField)	{
		[manualOutput setAddressString:[dstIPField stringValue]];
	}
	else if (sender == dstPortField)	{
		[manualOutput setPort:[dstPortField intValue]];
	}
}


@end

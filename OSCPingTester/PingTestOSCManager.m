//
//  PingTestOSCManager.m
//  VVOpenSource
//
//  Created by bagheera on 3/29/13.
//
//

#import "PingTestOSCManager.h"




@implementation PingTestOSCManager


- (void) _generalInit	{
	[super _generalInit];
	[self setInPortLabelBase:@"OSC Ping Test"];
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	inPort = [self createNewInput];
	ignoreReceivedVals = NO;
	swatch = [[VVStopwatch alloc] init];
	
	NSString			*tmpString = nil;
	NSNumber			*tmpNum = nil;
	//	if there's a saved default for the IP address/port, put 'em in the fields
	tmpString = [def objectForKey:@"IPAddress"];
	tmpNum = [def objectForKey:@"Port"];
	if (tmpString!=nil && tmpNum!=nil)
		outPort = [self createNewOutputToAddress:tmpString atPort:[tmpNum intValue] withLabel:@"OSC Ping Test"];
	else
		outPort = [self createNewOutputToAddress:@"127.0.0.1" atPort:[inPort port] withLabel:@"OSC Ping Test"];
}
- (void) awakeFromNib	{
	//NSLog(@"%s",__func__);
	
	//	push the out port's values to the text fields
	[ipField setStringValue:[outPort addressString]];
	[portField setIntValue:[outPort port]];
	
	
	//	populate the text field with the IP address & port of this machine
	NSArray		*ips = [OSCManager hostIPv4Addresses];
	if (ips!=nil)
		[networkAddressField setStringValue:[NSString stringWithFormat:@"%@, port %hd",[ips objectAtIndex:0],[inPort port]]];
	//	fake an outputs-changed notification to make sure my list of destinations updates (in case it refreshes before i'm awake)
	[self oscOutputsChangedNotification:nil];
	//	register to receive notifications that the list of osc outputs has changed
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:VVOSCOutPortsChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:OSCOutPortsChangedNotification object:nil];
}
/*
- (NSString *) inPortLabelBase	{
	return [NSString stringWithString:@"MIDI via OSC"];
}
*/
/*
- (OSCOutPort *) createNewOutputToAddress:(NSString *)a atPort:(int)p withLabel:(NSString *)l	{
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
*/

- (void) oscOutputsChangedNotification:(NSNotification *)note	{
	//NSLog(@"%s",__func__);
	
	NSMutableArray			*portLabelArray = nil;
	
	//	remove the items in the pop-up button
	[outputDestinationButton removeAllItems];
	//	get an array of the out port labels
	portLabelArray = [[[self outPortLabelArray] mutableCopy] autorelease];
	//	remove the output corresponding to my out port
	[portLabelArray removeObject:@"OSC Ping Test"];
	//	push the labels to the pop-up button of destinations
	[outputDestinationButton addItemsWithTitles:portLabelArray];
	
}
- (IBAction) outputDestinationButtonUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	OSCOutPort		*selectedPort = nil;
	selectedPort = [self findOutputWithLabel:[outputDestinationButton titleOfSelectedItem]];
	if (selectedPort == nil)
		return;
	//	push the data of the selected output to the fields
	[ipField setStringValue:[selectedPort addressString]];
	[portField setStringValue:[NSString stringWithFormat:@"%d",[selectedPort port]]];
	//	bump the fields (which updates the manualOutPort, which is the only out port sending data)
	[self setupFieldUsed:nil];
}

- (IBAction) setupFieldUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	
	//	now take care of the ports which relate to sending data
	//	push the settings on the ui items to the manualOutPort, which is the only out port actually sending data
	[outPort setAddressString:[ipField stringValue]];
	[ipField setStringValue:[outPort addressString]];
	[outPort setPort:[portField intValue]];
	[portField setIntValue:[outPort port]];
	//	update the user defaults
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	[def setObject:[outPort addressString] forKey:@"IPAddress"];
	[def setObject:[NSNumber numberWithInt:[outPort port]] forKey:@"Port"];
	[def synchronize];
}

- (IBAction) pingClicked:(id)sender	{
	NSLog(@"%s",__func__);
	OSCMessage		*msg = [OSCMessage createWithAddress:@"/a"];
	[msg addBOOL:YES];
	ignoreReceivedVals = YES;
	[swatch start];
	//[outPort sendThisMessage:msg];
	[inPort _dispatchQuery:msg toOutPort:outPort];
}
- (void) receivedOSCMessage:(OSCMessage *)n	{
	NSLog(@"%s ... %@",__func__,n);
	double		roundTripPing = 0.0;
	if (ignoreReceivedVals)	{
		roundTripPing = [swatch timeSinceStart];
		ignoreReceivedVals = NO;
		NSLog(@"\t\tping was %f",roundTripPing);
	}
	else	{
		NSLog(@"\t\tshould be returning the message!");
		unsigned int		txAddr = [n queryTXAddress];
		unsigned int		txPort = [n queryTXPort];
		NSLog(@"\t\ttxPort is  %d",txPort);
		if (txAddr==0 || txPort==0)
			NSLog(@"\t\terr, addr or port 0 at %s",__func__);
		else	{
			OSCOutPort		*thePort = [self findOutputWithRawAddress:txAddr andPort:txPort];
			if (thePort == nil)	{
				NSLog(@"\t\tcouldn't find port at first...");
				struct in_addr		tmpAddr;
				tmpAddr.s_addr = txAddr;
				thePort = [self
					createNewOutputToAddress:[NSString stringWithCString:inet_ntoa(tmpAddr) encoding:NSASCIIStringEncoding]
					atPort:txPort];
			}
			if (thePort == nil)
				NSLog(@"\t\tcouldn't find port a second time!");
			else	{
				NSLog(@"\t\tsending to port %@",thePort);
				[thePort sendThisMessage:n];
			}
		}
	}
}


@end

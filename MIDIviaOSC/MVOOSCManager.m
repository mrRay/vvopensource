#import "MVOOSCManager.h"
#import <VVMIDI/VVMIDI.h>




@implementation MVOOSCManager


- (void) _generalInit	{
	[super _generalInit];
	[self setInPortLabelBase:@"MIDI via OSC"];
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	receivedMIDIStringArray = [[MutLockArray alloc] init];
	outgoingBuffer = [[MutLockArray alloc] init];
	oscSendingThread = [[VVThreadLoop alloc] initWithTimeInterval:0.01 target:self selector:@selector(sendOSC)];
	inPort = [self createNewInput];
	[inPort setInterval:0.01];
	
	NSString			*tmpString = nil;
	NSNumber			*tmpNum = nil;
	//	if there's a saved default for the IP address/port, put 'em in the fields
	tmpString = [def objectForKey:@"IPAddress"];
	tmpNum = [def objectForKey:@"Port"];
	if (tmpString!=nil && tmpNum!=nil)
		outPort = [self createNewOutputToAddress:tmpString atPort:[tmpNum intValue] withLabel:@"MIDI via OSC"];
	else
		outPort = [self createNewOutputToAddress:@"127.0.0.1" atPort:[inPort port] withLabel:@"MIDI via OSC"];
}
- (void) awakeFromNib	{
	//NSLog(@"%s",__func__);
	
	//	push the out port's values to the text fields
	[ipField setStringValue:[outPort addressString]];
	[portField setIntValue:[outPort port]];
	
	
	//	populate the text field with the IP address & port of this machine
	NSArray			*ips = [OSCManager hostIPv4Addresses];
	if (ips != nil)
		[networkAddressField setStringValue:[NSString stringWithFormat:@"%@, port %hd",[ips objectAtIndex:0],[inPort port]]];
	//	fake an outputs-changed notification to make sure my list of destinations updates (in case it refreshes before i'm awake)
	[self oscOutputsChangedNotification:nil];
	//	register to receive notifications that the list of osc outputs has changed
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:VVOSCOutPortsChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:OSCOutPortsChangedNotification object:nil];
	//	start the osc-sending thread
	[oscSendingThread start];
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

- (void) setupChanged	{
	//NSLog(@"%s",__func__);
	[midiSourcesTable reloadData];
	[midiDestTable reloadData];
}

- (void) receivedMIDI:(NSArray *)a	{
	//NSLog(@"%s, %ld",__func__,[a count]);
	if (outPort == nil)
		return;
	
	OSCValue		*tmpVal;
	OSCMessage		*tmpMsg;
	for (VVMIDIMessage *msg in a)	{
		tmpVal = [[[OSCValue alloc]
			initWithMIDIChannel:[msg channel]
			status:[msg type]
			data1:[msg data1]
			data2:[msg data2]] autorelease];
		if (tmpVal != nil)	{
			tmpMsg = [OSCMessage createWithAddress:@"/MIDIviaOSC"];
			if (tmpMsg != nil)	{
				[tmpMsg addValue:tmpVal];
				//	if it's a realtime message, send it immediately
				if (([msg type]>=0xF8)&&([msg type]<=0xFD))
					[outPort sendThisMessage:tmpMsg];
				//	else it's not a realtime message- add it to the buffer to send later
				else	{
					//[outPort sendThisMessage:tmpMsg];
					[outgoingBuffer lockAddObject:tmpMsg];
				}
				//	if the received message wasn't a clock pulse...
				if ([msg type] != VVMIDIClockVal)	{
					//	put together the string for the UI...
					NSMutableString		*tmpString = [NSMutableString stringWithCapacity:0];
					[receivedMIDIStringArray wrlock];
						[receivedMIDIStringArray addObject:[msg lengthyDescription]];
						while ([receivedMIDIStringArray count]>20)
							[receivedMIDIStringArray removeObjectAtIndex:0];
						NSEnumerator	*it = [[receivedMIDIStringArray array] reverseObjectEnumerator];
						for (NSString *midiString in it)
							[tmpString appendString:[NSString stringWithFormat:@"%@\n",midiString]];
					[receivedMIDIStringArray unlock];
					if ([receivedMIDIPreviewToggle intValue] == NSOnState)
						[receivedMIDIField setStringValue:tmpString];
				}
			}
		}
	}
}
- (void) sendOSC	{
	if ((outgoingBuffer==nil)||([outgoingBuffer count]<1))
		return;
	
	OSCBundle		*bundleToSend = nil;
	[outgoingBuffer wrlock];
		bundleToSend = [OSCBundle createWithElementArray:[outgoingBuffer array]];
		[outgoingBuffer removeAllObjects];
	[outgoingBuffer unlock];
	if (bundleToSend != nil)
		[outPort sendThisBundle:bundleToSend];
}
- (void) oscOutputsChangedNotification:(NSNotification *)note	{
	//NSLog(@"%s",__func__);
	
	NSMutableArray			*portLabelArray = nil;
	
	//	remove the items in the pop-up button
	[outputDestinationButton removeAllItems];
	//	get an array of the out port labels
	portLabelArray = [[[self outPortLabelArray] mutableCopy] autorelease];
	//	remove the output corresponding to my out port
	[portLabelArray removeObject:@"MIDI via OSC"];
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


@end

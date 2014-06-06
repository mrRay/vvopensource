//
//  AppController.m
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "AppController.h"
#import "OSCInPortRetainsRaw.h"




@implementation AppController


- (id) init	{
	if (self = [super init])	{
		//	make an osc manager- i'm using i'm using a custom in-port to record a bunch of extra conversion for the display, but you can just make a "normal" manager
		manager = [[OSCManager alloc] initWithInPortClass:[OSCInPortRetainsRaw class] outPortClass:nil];
		//	by default, the osc manager's delegate will be told when osc messages are received
		[manager setDelegate:self];
	}
	
	return self;
}

- (void) awakeFromNib	{
	NSString		*ipFieldString;
	id				anObj = nil;
	
	//	tell the osc manager to make an input to receive from a given port
	inPort = [manager createNewInput];
	
	//	make an out port to my machine's dedicated in port
	anObj = [manager createNewOutputToAddress:@"127.0.0.1" atPort:[inPort port] withLabel:@"This app"];
	if (anObj == nil)
		NSLog(@"\t\terror creating output A");
	//	make another out port to hold the manual settings
	manualOutPort = [manager createNewOutputToAddress:@"127.0.0.1" atPort:[inPort port] withLabel:@"Manual Output"];
	if (manualOutPort == nil)
		NSLog(@"\t\terror creating output B");
	
	
	//	populate the IP field string with  this machine's IP and the port of my dedicated input
	NSArray			*ips = [OSCManager hostIPv4Addresses];
	if (ips!=nil && [ips count]>0)	{
		ipFieldString = [NSString stringWithFormat:@"%@, port",[ips objectAtIndex:0]];
		[receivingAddressField setStringValue:ipFieldString];
	}
	//	populate the receiving port field with the in port's port
	[receivingPortField setIntValue:[inPort port]];
	//	populate the sending port field from the current manual out port
	[portField setIntValue:[manualOutPort port]];
	
	//	register to receive notifications that the list of osc outputs has changed
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:OSCOutPortsChangedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(oscOutputsChangedNotification:) name:OSCInPortsChangedNotification object:nil];
	
	//	fake an outputs-changed notification to make sure my list of destinations updates (in case it refreshes before i'm awake)
	[self oscOutputsChangedNotification:nil];
	
	
	/*
	OSCAddressSpace		*addressSpace = [manager addressSpace];
	[addressSpace findNodeForAddress:@"/asdf/" createIfMissing:YES];
	[addressSpace findNodeForAddress:@"/asdf/a" createIfMissing:YES];
	
	[addressSpace findNodeForAddress:@"/asdf/a/1" createIfMissing:YES];
	[addressSpace findNodeForAddress:@"/asdf/a/2" createIfMissing:YES];
	[addressSpace findNodeForAddress:@"/asdf/a/3" createIfMissing:YES];
	
	[addressSpace findNodeForAddress:@"/asdf/s" createIfMissing:YES];
	
	[addressSpace findNodeForAddress:@"/asdf/s/1" createIfMissing:YES];
	[addressSpace findNodeForAddress:@"/asdf/s/2" createIfMissing:YES];
	[addressSpace findNodeForAddress:@"/asdf/s/3" createIfMissing:YES];
	//NSLog(@"%@",addressSpace);
	*/
}

- (void) receivedOSCMessage:(OSCMessage *)m	{
	//NSLog(@"%s ... %@",__func__,m);
	[self displayPackets];
	
	/*
	OSCAddressSpace		*addressSpace = [manager addressSpace];
	[addressSpace dispatchMessage:m];
	*/
}

- (void) displayPackets	{
	//NSLog(@"%s",__func__);
	NSArray				*localPacketArray = [NSArray arrayWithArray:[(OSCInPortRetainsRaw *)inPort packetStringArray]];
	NSEnumerator		*it = [localPacketArray reverseObjectEnumerator];
	NSDictionary		*dictPtr;
	NSMutableString		*mutString = [NSMutableString stringWithCapacity:0];
	NSString			*localKey = nil;
	
	//	figure out what kind of string i'm going to be assembling
	switch ([displayTypeRadioGroup selectedColumn])	{
		case 0:		//	parsed
			localKey = @"serial";
			break;
		//case 1:
		//	localKey = [NSString stringWithString:@"coalesced"];
		//	break;
		case 1:		//	char
			localKey = @"char";
			break;
		case 2:		//	dec
			localKey = @"dec";
			break;
		case 3:		//	hex
			localKey = @"hex";
			break;
	}
	//	assemble a string from the custom osc in port
	while (dictPtr = [it nextObject])	{
		//NSLog(@"%@",dictPtr);
		if ([dictPtr objectForKey:localKey] != nil)
			[mutString appendFormat:@"%@\n",[dictPtr objectForKey:localKey]];
	}
	//	push the assembled string to the view
	[receivingTextView performSelectorOnMainThread:@selector(setString:) withObject:[[mutString copy] autorelease] waitUntilDone:NO];
}

- (void) oscOutputsChangedNotification:(NSNotification *)note	{
	//NSLog(@"%s",__func__);
	NSArray			*portLabelArray = nil;
	
	//	remove the items in the pop-up button
	[outputDestinationButton removeAllItems];
	//	get an array of the out port labels
	portLabelArray = [manager outPortLabelArray];
	//	push the labels to the pop-up button of destinations
	[outputDestinationButton addItemsWithTitles:portLabelArray];
}
- (IBAction) outputDestinationButtonUsed:(id)sender	{
	int				selectedIndex = [outputDestinationButton indexOfSelectedItem];
	OSCOutPort		*selectedPort = nil;
	//	figure out the index of the selected item
	if (selectedIndex == -1)
		return;
	//	find the output port corresponding to the index of the selected item
	selectedPort = [manager findOutputForIndex:selectedIndex];
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
	//	first take care of the port (there's only one) which is receiving data
	//	push the settings in the port field to the in port
	[inPort setPort:[receivingPortField intValue]];
	//	push the actual port i'm receiving on to the text field (if anything went wrong when changing the port, it should revert to the last port #)
	[receivingPortField setIntValue:[inPort port]];
	
	//	now take care of the ports which relate to sending data
	//	push the settings on the ui items to the manualOutPort, which is the only out port actually sending data
	[manualOutPort setAddressString:[ipField stringValue]];
	[ipField setStringValue:[manualOutPort addressString]];
	[manualOutPort setPort:[portField intValue]];
	//[portField setStringValue:[NSString stringWithFormat:@"%d",[manualOutPort port]]];
	[portField setIntValue:[manualOutPort port]];
	//	since the port this app receives on may have changed, i have to adjust the out port for the "This app" output so it continues to point to the correct address
	id			anObj = [manager findOutputWithLabel:@"This app"];
	if (anObj != nil)	{
		[(OSCOutPort *)anObj setPort:[receivingPortField intValue]];
	}
	
	//	select the "manual output" item in the pop-up button
	[outputDestinationButton selectItemWithTitle:@"Manual Output"];
}
- (IBAction) valueFieldUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	OSCMessage		*msg = nil;
	OSCBundle		*bundle = nil;
	OSCPacket		*packet = nil;
	
	
	//	make a message to the specified address
	msg = [OSCMessage createWithAddress:[oscAddressField stringValue]];
	
	
	//	fill the message with values from the relevant UI item
	if (sender == floatSlider)	{
		[msg addFloat:[floatSlider floatValue]];
	}
	else if (sender == floatField)	{
		[msg addFloat:[floatField floatValue]];
	}
	else if (sender == intField)	{
		[msg addInt:[intField intValue]];
	}
	else if (sender == longLongField)	{
		OSCValue		*tmpVal = [OSCValue createWithLongLong:[[sender stringValue] longLongValue]];
		if (tmpVal != nil)
			[msg addValue:tmpVal];
	}
	else if (sender == colorWell)	{
		[msg addColor:[colorWell color]];
	}
	else if (sender == trueButton)	{
		[msg addBOOL:YES];
	}
	else if (sender == falseButton)	{
		[msg addBOOL:NO];
	}
	else if (sender == stringField)	{
		[msg addString:[stringField stringValue]];
	}
	
	//	if i'm sending as a bundle...
	if ([bundleMsgsButton intValue] == NSOnState)	{
		//	make a bundle
		bundle = [OSCBundle create];
		//	add the message to the bundle
		[bundle addElement:msg];
		//	make the packet from the bundle
		packet = [OSCPacket createWithContent:bundle];
	}
	//	else if i'm just sending the msg
	else	{
		//	make the packet from the msg
		packet = [OSCPacket createWithContent:msg];
	}
	
	//	tell the out port to send the packet
	[manualOutPort sendThisPacket:packet];
}
- (IBAction) displayTypeMatrixUsed:(id)sender	{
	[self displayPackets];
}
//	called when the user clicks the "clear" button
- (IBAction) clearButtonUsed:(id)sender	{
	if (inPort != nil)	{
		[(OSCInPortRetainsRaw *)inPort setPacketStringArray:nil];
		[self displayPackets];
	}
}


- (IBAction) logAddressSpace:(id)sender	{
	//NSLog(@"%@",[manager addressSpace]);
}
- (IBAction) timeTestUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	struct timeval	currentTime;
	gettimeofday(&currentTime,NULL);
	OSCValue		*val = [OSCValue createWithTimeSeconds:currentTime.tv_sec microSeconds:currentTime.tv_usec];
	if (val == nil)
		return;
	OSCMessage		*msg = [OSCMessage createWithAddress:@"/test/address"];
	if (msg == nil)
		return;
	[msg addValue:val];
	//NSLog(@"\t\tmsg is %@",msg);
	OSCPacket		*pack = [OSCPacket createWithContent:msg];
	if (pack == nil)
		return;
	//NSLog(@"\t\tpack is %@",pack);
	//NSLog(@"\t\t...should be sending the time test");
	//NSLog(@"\t\tmanualOutPort is %@",manualOutPort);
	[manualOutPort sendThisPacket:pack];
}


- (IBAction) intTest:(id)sender	{
	//NSLog(@"%s",__func__);
	OSCValue		*arrayVal = [OSCValue createArray];
	[arrayVal addValue:[OSCValue createWithInt:0]];
	[arrayVal addValue:[OSCValue createWithInt:5]];
	[arrayVal addValue:[OSCValue createWithInt:10]];
	OSCMessage		*msg = [OSCMessage createWithAddress:@"/destAddress"];
	[msg addValue:arrayVal];
	
	OSCBundle		*bundle = [OSCBundle create];
	[bundle addElement:msg];
	
	arrayVal = [OSCValue createArray];
	[arrayVal addValue:[OSCValue createWithString:@"a"]];
	[arrayVal addValue:[OSCValue createWithString:@"s"]];
	[arrayVal addValue:[OSCValue createWithString:@"d"]];
	msg = [OSCMessage createWithAddress:@"/destAddress2"];
	[msg addValue:arrayVal];
	
	[bundle addElement:msg];
	
	//[msg addValue:[OSCValue createWithFloat:1.0]];
	[manualOutPort sendThisBundle:bundle];
	
	/*
	OSCBundle		*bundle = nil;
	OSCBundle		*altBundle = nil;
	OSCBundle		*mainBundle = nil;
	OSCMessage		*msg1 = nil;
	OSCMessage		*msg2 = nil;
	OSCMessage		*msg3 = nil;
	OSCPacket		*pack = nil;
	
	
	mainBundle = [OSCBundle create];
	
	//	make a bundle with a single message of the appropriate type
	bundle = [OSCBundle create];
	msg1 = [OSCMessage createWithAddress:@"/singleInt"];
	[msg1 addInt:2147483647];
	[bundle addElement:msg1];
	//	make a bundle with several messages (with several vals each) of the appropriate type
	altBundle = [OSCBundle create];
	msg1 = [OSCMessage createWithAddress:@"/multipleInts1"];
	[msg1 addInt:1];
	[msg1 addInt:2];
	[msg1 addInt:3];
	msg2 = [OSCMessage createWithAddress:@"/multipleInts2"];
	[msg2 addInt:4];
	[msg2 addInt:5];
	[msg2 addInt:6];
	msg3 = [OSCMessage createWithAddress:@"/multiplierInts3"];
	[msg3 addInt:7];
	[msg3 addInt:8];
	[msg3 addInt:9];
	[altBundle addElement:msg1];
	[altBundle addElement:msg2];
	[altBundle addElement:msg3];
	//	also add the single-message bundle to the bundle with several messages
	[altBundle addElement:bundle];
	//	add them to the main bundle
	[mainBundle addElement:bundle];
	[mainBundle addElement:altBundle];
	
	//	create a packet from the bundle (this actually makes the buffer that you'll send)
	pack = [OSCPacket createWithContent:mainBundle];
	//	tell the out port to send the packet
	[manualOutPort sendThisPacket:pack];
	*/
}
- (IBAction) floatTest:(id)sender	{
	//NSLog(@"%s",__func__);
	OSCBundle		*bundle = nil;
	OSCBundle		*altBundle = nil;
	OSCBundle		*mainBundle = nil;
	OSCMessage		*msg1 = nil;
	OSCMessage		*msg2 = nil;
	OSCMessage		*msg3 = nil;
	OSCPacket		*pack = nil;
	
	
	mainBundle = [OSCBundle create];
	
	//	make a bundle with a single message of the appropriate type
	bundle = [OSCBundle create];
	msg1 = [OSCMessage createWithAddress:@"/singleFloat"];
	[msg1 addFloat:1.1];
	[bundle addElement:msg1];
	//	make a bundle with several messages (with several vals each) of the appropriate type
	altBundle = [OSCBundle create];
	msg1 = [OSCMessage createWithAddress:@"/multipleFloats1"];
	[msg1 addFloat:2.1];
	[msg1 addFloat:3.2];
	[msg1 addFloat:4.3];
	msg2 = [OSCMessage createWithAddress:@"/multipleFloats2"];
	[msg2 addFloat:5.4];
	[msg2 addFloat:6.5];
	[msg2 addFloat:7.6];
	msg3 = [OSCMessage createWithAddress:@"/multiplierFloats3"];
	[msg3 addFloat:8.7];
	[msg3 addFloat:9.8];
	[msg3 addFloat:10.9];
	[altBundle addElement:msg1];
	[altBundle addElement:msg2];
	[altBundle addElement:msg3];
	//	also add the single-message bundle to the bundle with several messages
	[altBundle addElement:bundle];
	//	add them to the main bundle
	[mainBundle addElement:bundle];
	[mainBundle addElement:altBundle];
	
	//	create a packet from the bundle (this actually makes the buffer that you'll send)
	pack = [OSCPacket createWithContent:mainBundle];
	//	tell the out port to send the packet
	[manualOutPort sendThisPacket:pack];
}
- (IBAction) colorTest:(id)sender	{
	//NSLog(@"%s",__func__);
	OSCBundle		*bundle = nil;
	OSCBundle		*altBundle = nil;
	OSCBundle		*mainBundle = nil;
	OSCMessage		*msg1 = nil;
	OSCMessage		*msg2 = nil;
	OSCMessage		*msg3 = nil;
	OSCPacket		*pack = nil;
	
	
	mainBundle = [OSCBundle create];
	
	//	make a bundle with a single message of the appropriate type
	bundle = [OSCBundle create];
	msg1 = [OSCMessage createWithAddress:@"/singleColor"];
	[msg1 addColor:[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:0.1]];
	[bundle addElement:msg1];
	//	make a bundle with several messages (with several vals each) of the appropriate type
	altBundle = [OSCBundle create];
	msg1 = [OSCMessage createWithAddress:@"/multipleColors1"];
	[msg1 addColor:[NSColor colorWithDeviceRed:0.0 green:0.0 blue:1.0 alpha:0.1]];
	[msg1 addColor:[NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:0.1]];
	[msg1 addColor:[NSColor colorWithDeviceRed:0.0 green:1.0 blue:1.0 alpha:0.1]];
	msg2 = [OSCMessage createWithAddress:@"/multipleColors2"];
	[msg2 addColor:[NSColor colorWithDeviceRed:1.0 green:0.0 blue:0.0 alpha:0.1]];
	[msg2 addColor:[NSColor colorWithDeviceRed:1.0 green:0.0 blue:1.0 alpha:0.1]];
	[msg2 addColor:[NSColor colorWithDeviceRed:1.0 green:1.0 blue:0.0 alpha:0.1]];
	msg3 = [OSCMessage createWithAddress:@"/multiplierColors3"];
	[msg3 addColor:[NSColor colorWithDeviceRed:1.0 green:1.0 blue:1.0 alpha:0.1]];
	[msg3 addColor:[NSColor colorWithDeviceRed:0.0 green:0.0 blue:1.0 alpha:0.1]];
	[msg3 addColor:[NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:0.1]];
	[altBundle addElement:msg1];
	[altBundle addElement:msg2];
	[altBundle addElement:msg3];
	//	also add the single-message bundle to the bundle with several messages
	[altBundle addElement:bundle];
	//	add them to the main bundle
	[mainBundle addElement:bundle];
	[mainBundle addElement:altBundle];
	
	//	create a packet from the bundle (this actually makes the buffer that you'll send)
	pack = [OSCPacket createWithContent:mainBundle];
	//	tell the out port to send the packet
	[manualOutPort sendThisPacket:pack];
}
- (IBAction) stringTest:(id)sender	{
	//NSLog(@"%s",__func__);
	/*
	OSCBundle		*bundle = nil;
	OSCMessage		*msg = nil;
	
	bundle = [OSCBundle create];
	msg = [OSCMessage createWithAddress:@"/path"];
	[msg addInt:1];
	[msg addInt:2];
	[msg addString:@"three"];
	[msg addString:@"four"];
	[msg addInt:5];
	[msg addString:@"six"];
	[msg addInt:7];
	[msg addInt:8];
	[bundle addElement:msg];
	
	OSCPacket		*pack = [OSCPacket createWithContent:bundle];
	[manualOutPort sendThisPacket:pack];
	*/
	
	OSCBundle		*bundle = nil;
	OSCBundle		*altBundle = nil;
	OSCBundle		*mainBundle = nil;
	OSCMessage		*msg1 = nil;
	OSCMessage		*msg2 = nil;
	OSCMessage		*msg3 = nil;
	OSCPacket		*pack = nil;
	
	
	mainBundle = [OSCBundle create];
	
	
	//	make a bundle with a single message of the appropriate type
	bundle = [OSCBundle create];
	msg1 = [OSCMessage createWithAddress:@"/singleString"];
	[msg1 addString:@"singlestring"];
	[bundle addElement:msg1];
	//	make a bundle with several messages (with several vals each) of the appropriate type
	altBundle = [OSCBundle create];
	msg1 = [OSCMessage createWithAddress:@"/multipleStrings1"];
	[msg1 addString:@"first mult string"];
	[msg1 addString:@"second mult string"];
	[msg1 addString:@"third mult string"];
	msg2 = [OSCMessage createWithAddress:@"/multipleStrings2"];
	[msg2 addString:@"first mult string B"];
	[msg2 addString:@"second mult string B"];
	[msg2 addString:@"third mult string B"];
	msg3 = [OSCMessage createWithAddress:@"/multiplierStrings3"];
	[msg3 addString:@"first mult string 3"];
	[msg3 addString:@"second mult string 3"];
	[msg3 addString:@"third mult string 3"];
	[altBundle addElement:msg1];
	[altBundle addElement:msg2];
	[altBundle addElement:msg3];
	//	also add the single-message bundle to the bundle with several messages
	[altBundle addElement:bundle];
	//	add them to the main bundle
	[mainBundle addElement:bundle];
	[mainBundle addElement:altBundle];
	
	
	//	create a packet from the bundle (this actually makes the buffer that you'll send)
	pack = [OSCPacket createWithContent:mainBundle];
	//	tell the out port to send the packet
	[manualOutPort sendThisPacket:pack];
	
}
- (IBAction) lengthTest:(id)sender	{
	//NSLog(@"%s",__func__);
	OSCBundle		*mainBundle = [OSCBundle create];
	NSString		*addressPath = @"/aSingleButFairlyLongAddressPath";
	OSCMessage		*msgPtr;
	int				i;
	OSCPacket		*pack;
	
	for (i=0; i<100; ++i)	{
		msgPtr = [OSCMessage createWithAddress:addressPath];
		[msgPtr addFloat:(i/100.0)];
		[mainBundle addElement:msgPtr];
	}
	//NSLog(@"\t\tdone making bundle");
	pack = [OSCPacket createWithContent:mainBundle];
	//NSLog(@"\t\tdone making packet");
	[manualOutPort sendThisPacket:pack];
	//NSLog(@"\t\tdone sending packet");
}
- (IBAction) blobTest:(id)sender	{
	NSLog(@"%s",__func__);
	[manager deleteAllInputs];
	return;
	/*
	int				rawBufferSize = 5;
	void			*rawBuffer = malloc(rawBufferSize);
	memset(rawBuffer,9,rawBufferSize);
	NSData			*tmpData = [NSData dataWithBytes:rawBuffer length:rawBufferSize];
	OSCValue		*valuePtr = [OSCValue createWithNSDataBlob:tmpData];
	NSLog(@"\t\tabout to send %@",valuePtr);
	OSCMessage		*tmpMsg = [OSCMessage createWithAddress:@"/thePathForBlobs"];
	[tmpMsg addInt:1];
	[tmpMsg addInt:2];
	[tmpMsg addValue:valuePtr];
	[tmpMsg addInt:4];
	[tmpMsg addInt:5];
	[manualOutPort sendThisMessage:tmpMsg];
	*/
	
	//NSString		*tmpString = [NSString stringWithString:@"This is my sample string"];
	//NSData			*tmpData = [NSData dataWithBytes:[tmpString UTF8String] length:[tmpString length]];
	NSArray			*tmpArray = [NSArray arrayWithObjects:@"first object",@"second object",nil];
	NSData			*tmpData = [NSKeyedArchiver archivedDataWithRootObject:tmpArray];
	OSCValue		*valuePtr = [OSCValue createWithNSDataBlob:tmpData];
	NSLog(@"\t\tabout to send %@",valuePtr);
	OSCMessage		*tmpMsg = [OSCMessage createWithAddress:@"/thePathForBlobs"];
	[tmpMsg addInt:1];
	[tmpMsg addInt:2];
	[tmpMsg addValue:valuePtr];
	[tmpMsg addInt:4];
	[tmpMsg addInt:5];
	[manualOutPort sendThisMessage:tmpMsg];
	
}


@end

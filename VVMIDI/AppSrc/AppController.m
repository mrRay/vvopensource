//
//  AppController.m
//  VVMIDI
//
//  Created by bagheera on 10/21/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "AppController.h"




@implementation AppController


- (id) init	{
	//NSLog(@"AppController:init:");
	self = [super init];
	msgArray = [[NSMutableArray arrayWithCapacity:0] retain];
	return self;
}

- (void) setupChanged	{
	//NSLog(@"AppController:setupChanged:");
	[sourcesTableView reloadData];
	[receiversTableView reloadData];
}
- (void) receivedMIDI:(NSArray *)a fromNode:(VVMIDINode *)n	{
	//NSLog(@"AppController:receivedMIDI:");
	NSEnumerator		*it = [a objectEnumerator];
	VVMIDIMessage		*msgPtr;
	NSMutableString		*mutString = [NSMutableString stringWithCapacity:0];
	
	//	technically, the @synchronized protocol isn't very fast- but hey, this is just a demo app...
	@synchronized(msgArray)	{
		//	add the received messages to the array
		while (msgPtr = [it nextObject])
			[msgArray addObject:[msgPtr lengthyDescription]];
		//	make sure the array only has 10 objects
		while ([msgArray count] > 10)
			[msgArray removeObjectAtIndex:0];
		//	assemble a string from the msg array
		it = [msgArray reverseObjectEnumerator];
		while (msgPtr = [it nextObject])
			[mutString appendFormat:@"%@\n",msgPtr];
		//	push the string to the view
		[receivedView performSelectorOnMainThread:@selector(setString:) withObject:[[mutString copy] autorelease] waitUntilDone:NO];
	}
}

- (IBAction) ctrlValSliderUsed:(id)sender	{
	//NSLog(@"AppController:ctrlValSliderUsed:");
	VVMIDIMessage		*msg = nil;
	
	//	create a message
	msg = [VVMIDIMessage createFromVals:
		VVMIDIControlChangeVal:
		[channelField intValue]:
		[ctrlField intValue]:
		floor(127*[sender floatValue])];
	
	/*
	NSArray		*tmpArray = [NSArray arrayWithObjects:[NSNumber numberWithUnsignedChar:0x7F],[NSNumber numberWithUnsignedChar:0x7E],nil];
	msg = [VVMIDIMessage createWithSysexArray:tmpArray];
	*/
	//	tell the midi manager to send it
	if (msg != nil)
		[midiManager sendMsg:msg];
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tv	{
	if (tv == sourcesTableView)
		return [[midiManager sourceArray] count];
	else if (tv == receiversTableView)
		return [[midiManager destArray] count];
	
	return 0;
}
- (id) tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tc row:(NSInteger)row	{
	if (tv == sourcesTableView)	{
		//NSLog(@"\t\tsources");
		id			midiSource = [[midiManager sourceArray] lockObjectAtIndex:row];
		
		if (midiSource == nil)
			return nil;
		
		if (tc == sourcesNameColumn)	{
			return [midiSource name];
		}
		else if (tc == sourcesEnableColumn)	{
			if ([midiSource enabled])
				return [NSNumber numberWithInt:NSOnState];
			else
				return [NSNumber numberWithInt:NSOffState];
		}
	}
	else if (tv == receiversTableView)	{
		//NSLog(@"\t\treceivers");
		id			midiSource = [[midiManager destArray] lockObjectAtIndex:row];
		
		if (midiSource == nil)
			return nil;
		
		if (tc == receiversNameColumn)	{
			return [midiSource name];
		}
		else if (tc == receiversEnableColumn)	{
			if ([midiSource enabled])
				return [NSNumber numberWithInt:NSOnState];
			else
				return [NSNumber numberWithInt:NSOffState];
		}
	}
	
	return nil;
}
- (void) tableView:(NSTableView *)tv setObjectValue:(id)v forTableColumn:(NSTableColumn *)tc row:(NSInteger)row	{
	//NSLog(@"AppController:tableView:setObjectValue:forTableColun:row:");
	if (tv == sourcesTableView)	{
		//NSLog(@"\t\tsources");
		id			midiSource = [[midiManager sourceArray] lockObjectAtIndex:row];
		
		if (midiSource == nil)
			return;
		
		if (tc == sourcesEnableColumn)	{
			if ([v intValue] == NSOnState)
				[midiSource setEnabled:YES];
			else
				[midiSource setEnabled:NO];
		}
	}
	else if (tv == receiversTableView)	{
		//NSLog(@"\t\treceivers");
		id			midiSource = [[midiManager destArray] lockObjectAtIndex:row];
		
		if (midiSource == nil)
			return;
		
		if (tc == receiversEnableColumn)	{
			if ([v intValue] == NSOnState)
				[midiSource setEnabled:YES];
			else
				[midiSource setEnabled:NO];
		}
	}
}


@end

#import "MVOMIDIManager.h"
#import <VVOSC/VVOSC.h>




@implementation MVOMIDIManager


- (void) generalInit	{
	//NSLog(@"%s",__func__);
	receivedOSCStringArray = [[MutLockArray alloc] init];
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	NSDictionary		*tmpDict = [def objectForKey:@"snap"];
	//NSLog(@"\tsnap is %@",tmpDict);
	if (tmpDict != nil)	{
		sourceEnableStateDict = [tmpDict objectForKey:@"src"];
		destEnableStateDict = [tmpDict objectForKey:@"dst"];
	}
	
	if (sourceEnableStateDict != nil)
		[sourceEnableStateDict retain];
	else
		sourceEnableStateDict = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	
	if (destEnableStateDict != nil)
		[destEnableStateDict retain];
	else
		destEnableStateDict = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	
	//NSLog(@"\tsourceEnableStateDict = %@",sourceEnableStateDict);
	//NSLog(@"\tdestEnableStateDict = %@",destEnableStateDict);
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(appWillTerminateNotification:)
		name:NSApplicationWillTerminateNotification
		object:nil];
	
	receivedOSCStringArray = [[MutLockArray alloc] init];
	
	[super generalInit];
}
- (void) awakeFromNib	{
	[sourcesTableView reloadData];
	[receiversTableView reloadData];
}
- (void) appWillTerminateNotification:(NSNotification *)note	{
	//NSLog(@"%s",__func__);
	//NSLog(@"\tsourceEnableStateDict = %@",sourceEnableStateDict);
	//NSLog(@"\tdestEnableStateDict = %@",destEnableStateDict);
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	//[def setObject:sourceEnableStateDict forKey:@"sourceEnableStateDict"];
	//[def setObject:destEnableStateDict forKey:@"destEnableStateDict"];
	NSMutableDictionary	*tmpDict = [NSMutableDictionary dictionaryWithCapacity:0];
	[tmpDict setObject:sourceEnableStateDict forKey:@"src"];
	[tmpDict setObject:destEnableStateDict forKey:@"dst"];
	[def setObject:tmpDict forKey:@"snap"];
	[def synchronize];
}
- (NSString *) receivingNodeName	{
	return @"To 'MIDI via OSC'";
}
- (NSString *) sendingNodeName	{
	return @"From 'MIDI via OSC'";
}
- (void) receivedOSCMessage:(OSCMessage *)m	{
	//NSLog(@"%s",__func__);
	
	if (m == nil)
		return;
	OSCValue		*val = [m value];
	if (val == nil)
		return;
	if ([val type] != OSCValMIDI)
		return;
	VVMIDIMessage	*msg = nil;
	msg = [VVMIDIMessage createFromVals:[val midiStatus]:[val midiPort]:[val midiData1]:[val midiData2]];
	if (msg != nil)
		[self sendMsg:msg];
	//	if the received message wasn't a clock pulse...
	if ([msg type] != VVMIDIClockVal)	{
		//	put together the string for the UI...
		NSMutableString		*tmpString = [NSMutableString stringWithCapacity:0];
		[receivedOSCStringArray wrlock];
			[receivedOSCStringArray addObject:[msg lengthyDescription]];
			while ([receivedOSCStringArray count]>20)
				[receivedOSCStringArray removeObjectAtIndex:0];
			NSEnumerator		*it = [[receivedOSCStringArray array] reverseObjectEnumerator];
			for (NSString *midiString in it)
				[tmpString appendString:[NSString stringWithFormat:@"%@\n",midiString]];
		[receivedOSCStringArray unlock];
		if ([receivedOSCPreviewToggle intValue] == NSOnState)
			[receivedOSCField setStringValue:tmpString];
	}
}

- (void) loadMIDIInputSources	{
	//NSLog(@"%s",__func__);
	//	before i load anything, run through and save the enable state of the midi nodes in my dict
	if ((sourceArray!=nil)&&([sourceArray count]>0))	{
		//pthread_mutex_lock(&arrayLock);
		[sourceArray rdlock];
			for (VVMIDINode *nodePtr in [sourceArray array])
				[sourceEnableStateDict setValue:[NSNumber numberWithBool:[nodePtr enabled]] forKey:[nodePtr name]];
		//pthread_mutex_unlock(&arrayLock);
		[sourceArray unlock];
	}
	//	tell the super to load the midi input sources (this actually does the loading)
	[super loadMIDIInputSources];
	//	now that i'm done loading, run through and either disable or restore the enable state of the nodes
	if ((sourceArray!=nil) && ([sourceArray count]>0))	{
		//pthread_mutex_lock(&arrayLock);
		[sourceArray rdlock];
			NSNumber		*tmpNum = nil;
			for (VVMIDINode *nodePtr in [sourceArray array])	{
				tmpNum = [sourceEnableStateDict valueForKey:[nodePtr name]];
				if (tmpNum != nil)
					[nodePtr setEnabled:[tmpNum boolValue]];
				else
					[nodePtr setEnabled:NO];
			}
		//pthread_mutex_unlock(&arrayLock);
		[sourceArray unlock];
	}
}
- (void) loadMIDIOutputDestinations	{
	//	before i load anything, run through and save the enable state of the midi nodes in my dict
	if ((destArray!=nil)&&([destArray count]>0))	{
		//pthread_mutex_lock(&arrayLock);
		[destArray rdlock];
			for (VVMIDINode *nodePtr in [destArray array])
				[destEnableStateDict setValue:[NSNumber numberWithBool:[nodePtr enabled]] forKey:[nodePtr name]];
		//pthread_mutex_unlock(&arrayLock);
		[destArray unlock];
	}
	//	tell the super to load the midi input destinations (this actually does the loading)
	[super loadMIDIOutputDestinations];
	//	now that i'm done loading, run through and either disable or restore the enable state of the nodes
	if ((destArray!=nil) && ([destArray count]>0))	{
		//pthread_mutex_lock(&arrayLock);
		[destArray rdlock];
			NSNumber		*tmpNum = nil;
			for (VVMIDINode *nodePtr in [destArray array])	{
				tmpNum = [destEnableStateDict valueForKey:[nodePtr name]];
				if (tmpNum != nil)
					[nodePtr setEnabled:[tmpNum boolValue]];
				else
					[nodePtr setEnabled:NO];
			}
		//pthread_mutex_unlock(&arrayLock);
		[destArray unlock];
	}
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tv	{
	if (tv == sourcesTableView)
		return [sourceArray count];
	else if (tv == receiversTableView)
		return [destArray count];
	
	return 0;
}
- (id) tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tc row:(NSInteger)row	{
	if (tv == sourcesTableView)	{
		//NSLog(@"\t\tsources");
		id			midiSource = [sourceArray lockObjectAtIndex:row];
		
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
		id			midiSource = [destArray lockObjectAtIndex:row];
		
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
	if (tv == sourcesTableView)	{
		//NSLog(@"\t\tsources");
		id			midiSource = [sourceArray lockObjectAtIndex:row];
		
		if (midiSource == nil)
			return;
		
		if (tc == sourcesEnableColumn)	{
			if ([v intValue] == NSOnState)
				[midiSource setEnabled:YES];
			else
				[midiSource setEnabled:NO];
		}
		
		if ((sourceArray!=nil)&&([sourceArray count]>0))	{
			[sourceArray rdlock];
				for (VVMIDINode *nodePtr in [sourceArray array])
					[sourceEnableStateDict setValue:[NSNumber numberWithBool:[nodePtr enabled]] forKey:[nodePtr name]];
			[sourceArray unlock];
		}
	}
	else if (tv == receiversTableView)	{
		//NSLog(@"\t\treceivers");
		id			midiSource = [destArray lockObjectAtIndex:row];
		
		if (midiSource == nil)
			return;
		
		if (tc == receiversEnableColumn)	{
			if ([v intValue] == NSOnState)
				[midiSource setEnabled:YES];
			else
				[midiSource setEnabled:NO];
		}
		
		if ((destArray!=nil)&&([destArray count]>0))	{
			[destArray rdlock];
				for (VVMIDINode *nodePtr in [destArray array])
					[destEnableStateDict setValue:[NSNumber numberWithBool:[nodePtr enabled]] forKey:[nodePtr name]];
			[destArray unlock];
		}
	}
}


@end

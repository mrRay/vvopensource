#import "MTCSenderAppDelegate.h"
#import "NSStringAdditionsSMPTE.h"




@implementation MTCSenderAppDelegate


- (id) init	{
	self = [super init];
	if (self != nil)	{
		mm = [[MTCMIDIManager alloc] init];
		[mm setDelegate:self];
		outputNode = nil;
		smpteFormat = kSMPTETimeType30;
		startTimeInSeconds = 0.;
		running = NO;
		outputClock = NULL;
	}
	return self;
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[self setupChanged];
	[startTimeField setStringValue:[NSString smpteStringForTimeInSeconds:[self startTimeInSeconds] withFPS:[self fps]]];
	statusTimer = [NSTimer
		scheduledTimerWithTimeInterval:1./10.
		target:self
		selector:@selector(statusTimerCallback:)
		userInfo:nil
		repeats:YES];
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {
	[self stop];
}


#pragma mark -


- (IBAction) startTimeFieldUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	double				fps = [self fps];
	NSString			*rawString = [startTimeField stringValue];
	double				timeInSeconds = [NSString timeInSecondsForSMPTEString:rawString withFPS:fps];
	@synchronized (self)	{
		startTimeInSeconds = timeInSeconds;
	}
	[startTimeField setStringValue:[NSString smpteStringForTimeInSeconds:timeInSeconds withFPS:[self fps]]];
}
- (IBAction) formatPUBUsed:(id)sender	{
	NSInteger		selIndex = [formatPUB indexOfSelectedItem];
	if (selIndex<0 || selIndex==NSNotFound)
		return;
	BOOL			wasRunning = [self running];
	[self stop];
	@synchronized (self)	{
		smpteFormat = selIndex;
	}
	if (wasRunning)
		[self start];
}
- (IBAction) targetDevicePUBUsed:(id)sender	{
	BOOL			wasRunning = [self running];
	[self stop];
	@synchronized (self)	{
		if (outputNode != nil)	{
			[outputNode release];
			outputNode = nil;
		}
	}
	NSString		*newNodeName = [targetDevicePUB titleOfSelectedItem];
	VVMIDINode		*newNode = [mm findDestNodeWithFullName:newNodeName];
	@synchronized (self)	{
		if (newNode != nil)
			outputNode = [newNode retain];
	}
	if (wasRunning)
		[self start];
}


#pragma mark -


- (IBAction) startClicked:(id)sender	{
	[self start];
}
- (IBAction) stopClicked:(id)sender	{
	[self stop];
}


#pragma mark -


- (void) setupChanged	{
	//	stop the clock
	BOOL			wasRunning = [self running];
	[self stop];
	//	get the name of the originally-selected item
	NSString		*origDestTitle = [targetDevicePUB titleOfSelectedItem];
	if (origDestTitle!=nil && [origDestTitle length]<1)
		origDestTitle = nil;
	//	get the name of the dst nodes, repopulate the PUB with them
	@synchronized (self)	{
		[targetDevicePUB removeAllItems];
		NSArray			*newDestNodeNames = [mm destNodeFullNameArray];
		for (NSString *nodeName in newDestNodeNames)	{
			[targetDevicePUB addItemWithTitle:nodeName];
		}
		//	try to select the originally-selected item again- if it doesn't exist, select the first item
		if (origDestTitle==nil || [targetDevicePUB itemWithTitle:origDestTitle]==nil)	{
			if ([[targetDevicePUB itemArray] count]>0)
				[targetDevicePUB selectItemAtIndex:0];
		}
		else	{
			[targetDevicePUB selectItemWithTitle:origDestTitle];
		}
		//	get the midi node corresponding to the selected item, update my midi node
		if (outputNode != nil)	{
			[outputNode release];
			outputNode = nil;
		}
		NSString		*newDestTitle = [targetDevicePUB titleOfSelectedItem];
		outputNode = (newDestTitle==nil) ? nil : [[mm findDestNodeWithFullName:newDestTitle] retain];
	}
	//	start the clock again
	if (wasRunning)
		[self start];
}
- (void) receivedMIDI:(NSArray *)a fromNode:(VVMIDINode *)n	{
	//	do nothing (we're only interested in outputting MIDI in this app)
}


#pragma mark -


- (void) statusTimerCallback:(NSTimer *)t	{
	NSString		*currentVal = [statusField stringValue];
	NSString		*newVal = nil;
	@synchronized (self)	{
		if (!running || outputClock==NULL)
			newVal = @"Stopped/Not Running";
		else	{
			CAClockTime			nowTime;
			OSStatus			err = noErr;
			err = CAClockGetCurrentTime(outputClock, kCAClockTimeFormat_SMPTESeconds, &nowTime);
			if (err != noErr)	{
				NSLog(@"\t\terr %d at CAClockGetCurrentTime() in %s",(int)err,__func__);
				newVal = @"can't get clock time!";
			}
			else	{
				//NSLog(@"\t\ton display callback, timeInSeconds is %f",nowTime.time.seconds);
				SMPTETime		nowTimeSMPTE;
				err = CAClockSecondsToSMPTETime(outputClock, nowTime.time.seconds, 4, &nowTimeSMPTE);
				if (err != noErr)
					NSLog(@"\t\terr %d at CAClockSecondsToSMPTETime() in %s",(int)err,__func__);
				newVal = VVFMTSTRING(@"%d:%d:%d:%d",nowTimeSMPTE.mHours, nowTimeSMPTE.mMinutes, nowTimeSMPTE.mSeconds, nowTimeSMPTE.mFrames);
			}
		}
	}
	
	if (newVal == nil)
		newVal = @"";
	if (currentVal==nil || ![currentVal isEqualToString:newVal])
		[statusField setStringValue:newVal];
	
}
- (void) start	{
	//NSLog(@"%s",__func__);
	//	if i'm currently running, stop.
	if ([self running])
		[self stop];
	
	@synchronized (self)	{
		//	only proceed if there's an output node
		if (outputNode != nil)	{
			OSStatus			err = noErr;
			err = CAClockNew(0, &outputClock);
			if (err != noErr)	{
				NSLog(@"\t\terr %d at CAClockNew() in %s",(int)err,__func__);
			}
			else	{
				CAClockTimebase		timebase = kCAClockTimebase_HostTime;
				UInt32				size = 0;
				size = sizeof(timebase);
				err = CAClockSetProperty(outputClock, kCAClockProperty_InternalTimebase, size, &timebase);
				if (err != noErr)	{
					NSLog(@"\t\terr %d setting property kCAClockProperty_InternalTimebase in %s",(int)err,__func__);
				}
				else	{
					CAClockSyncMode		syncMode = kCAClockSyncMode_Internal;
					size = sizeof(syncMode);
					err = CAClockSetProperty(outputClock, kCAClockProperty_SyncMode, size, &syncMode);
					if (err != noErr)	{
						NSLog(@"\t\terr %d setting property kCAClockProperty_SyncMode in %s",(int)err,__func__);
					}
					else	{
						CAClockSMPTEFormat					tmpFormat = (CAClockSMPTEFormat)smpteFormat;
						size = sizeof(tmpFormat);
						err = CAClockSetProperty(outputClock, kCAClockProperty_SMPTEFormat, size, &tmpFormat);
						if (err != noErr)	{
							NSLog(@"\t\terr %d setting property kCAClockProperty_SMPTEFormat in %s",(int)err,__func__);
						}
						else	{
							MIDIEndpointRef		mtcEndpoint = (outputNode==nil) ? 0 : [outputNode endpointRef];
							size = sizeof(mtcEndpoint);
							err = CAClockSetProperty(outputClock, kCAClockProperty_MTCDestinations, size, &mtcEndpoint);
							if (err != noErr)	{
								NSLog(@"\t\terr %d setting property kCAClockProperty_MTCDestinations in %s",(int)err,__func__);
							}
							else	{
								
								CAClockTime			tmpTime;
								tmpTime.format = kCAClockTimeFormat_SMPTESeconds;
								tmpTime.reserved = 0;
								tmpTime.time.seconds = startTimeInSeconds;
								err = CAClockSetCurrentTime(outputClock, &tmpTime);
								if (err != noErr)	{
									NSLog(@"\t\terr %d at CAClockSetCurrentTime() in %s",(int)err,__func__);
								}
								else	{
									
									err = CAClockStart(outputClock);
									if (err != noErr)	{
										NSLog(@"\t\terr %d at CAClockStart() in %s",(int)err,__func__);
									}
									else	{
										running = YES;
									}
								}
								
							}
						}
					}
				}
			
			}
		}
	}
	
	//	if i'm not running, something went wrong- call my 'stop' method to clear out my clock
	if (![self running])
		[self stop];
}
- (void) stop	{
	//NSLog(@"%s",__func__);
	@synchronized (self)	{
		if (outputClock != NULL)	{
			CAClockStop(outputClock);
			CAClockDispose(outputClock);
			outputClock = NULL;
		}
		running = NO;
	}
}
- (BOOL) running	{
	BOOL			returnMe = NO;
	@synchronized (self)	{
		returnMe = running;
	}
	return returnMe;
}
- (double) startTimeInSeconds	{
	double		returnMe = 0.;
	@synchronized (self)	{
		returnMe = startTimeInSeconds;
	}
	return returnMe;
}
- (double) fps	{
	double		returnMe = 30.;
	@synchronized (self)	{
		switch (smpteFormat)	{
		case 0:
			returnMe = 24.;
			break;
		case 1:
			returnMe = 25.;
			break;
		case 2:
			returnMe = 29.97;
			break;
		case 3:
			returnMe = 30.;
			break;
		case 4:
			returnMe = 29.97;
			break;
		case 5:
			returnMe = 29.97;
			break;
		}
	}
	return returnMe;
}


@end

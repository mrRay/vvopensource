#import "VVCrashReporter.h"
#import "VVBasicMacros.h"




@implementation VVCrashReporter


- (id) init	{
	//NSLog(@"%s",__func__);
	if (self = [super init])	{
		uploadURL = nil;
		developerEmail = nil;
		delegate = nil;
		crashLogArray = [[MutLockArray alloc] init];
		systemProfilerDict = nil;
		consoleLog = nil;
		jobSize = 0;
		jobCurrentIndex = 0;
		currentCrashLogTimeout = 0;
		currentCrashLogTimer = nil;
		//	load the nib
		theNib = [[NSNib alloc] initWithNibNamed:[self _nibName] bundle:[NSBundle bundleForClass:[self class]]];
		if (theNib == nil)
			goto BAIL;
		//	unpack the nib, instantiating its contents
		[theNib instantiateNibWithOwner:self topLevelObjects:&nibTopLevelObjects];
		//	retain the array of top-level objects (they have to be explicitly freed)
		[nibTopLevelObjects retain];
		return self;
	}
	BAIL:
	[self release];
	return nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	VVRELEASE(uploadURL);
	VVRELEASE(developerEmail);
	VVRELEASE(crashLogArray);
	VVRELEASE(systemProfilerDict);
	VVRELEASE(consoleLog);
	delegate = nil;
	//	explicitly release all the objects in the array of top level objects
	if ((nibTopLevelObjects!=nil)&&([nibTopLevelObjects count]>0))
		[nibTopLevelObjects makeObjectsPerformSelector:@selector(release)];
	//	release the actual array of top level objects
	VVRELEASE(nibTopLevelObjects);
	//	release the nib
	VVRELEASE(theNib);
	[super dealloc];
}
- (void) awakeFromNib	{
	//NSLog(@"%s",__func__);
	[window setLevel:NSModalPanelWindowLevel];
}


- (void) check	{
	//	clear the crash log array
	[crashLogArray lockRemoveAllObjects];
	//	if the upload URL is nil, bail
	if (uploadURL == nil)
		goto BAIL;
	
	//	get the last crash date from the prefs
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	NSDate				*lastCrashDate = [def objectForKey:@"lastCrashDate"];
	//	if there's no last crash date, the app hasn't been run yet or there aren't any prefs- register the last crash date as this date & bail
	if (lastCrashDate == nil)	{
		NSDate			*tmpDate = [NSDate date];
		[def registerDefaults:[NSDictionary dictionaryWithObject:tmpDate forKey:@"lastCrashDate"]];
		[def setObject:tmpDate forKey:@"lastCrashDate"];
		[def synchronize];
		goto BAIL;
	}
	
	//	make an array with all the crash logs that need to be submitted
	NSFileManager		*fm = [NSFileManager defaultManager];
	NSString			*pathToLogFolder = [[NSString stringWithString:@"~/Library/Logs/CrashReporter"] stringByExpandingTildeInPath];
	NSArray				*logFolderArray = [fm directoryContentsAtPath:pathToLogFolder];
	if ((logFolderArray!=nil)&&([logFolderArray count]>0))	{
		NSString		*appNameString = [[[[NSBundle mainBundle] bundlePath] lastPathComponent] stringByDeletingPathExtension];
		//NSLog(@"\t\tappNameString = %@",appNameString);
		for (NSString *logFileName in logFolderArray)	{
			if ([logFileName hasPrefix:appNameString])	{
				NSString		*logPath = nil;
				NSDictionary	*fileAttribDict = nil;
				NSDate			*fileModDate = nil;
				logPath = [NSString stringWithFormat:@"%@/%@",pathToLogFolder,logFileName];
				//NSLog(@"\t\tlogPath = %@",logPath);
				if (logPath != nil)
					fileAttribDict = [fm fileAttributesAtPath:logPath traverseLink:NO];
				if (fileAttribDict != nil)
					fileModDate = [fileAttribDict objectForKey:NSFileModificationDate];
				if ((fileModDate!=nil)&&([fileModDate compare:lastCrashDate]==NSOrderedDescending))
					[crashLogArray lockAddObject:logPath];
			}
		}
	}
	//	if the array of crash logs that need to be submitted is empty, bail
	if ([crashLogArray count]<1)
		goto BAIL;
	
	//	extract the domain from the upload url
	NSArray				*pathComponents = [uploadURL pathComponents];
	if ((pathComponents==nil)||([pathComponents count]<1))
		goto BAIL;
	NSString			*domainString = nil;
	domainString = [NSString stringWithFormat:@"http://%@",[pathComponents objectAtIndex:0]];
	//	check to see if the domain's reachable with the given network configuration
	BOOL						foundServer = NO;
	SCNetworkConnectionFlags	status;
	foundServer = SCNetworkCheckReachabilityByName([domainString UTF8String],&status);
	BOOL						reachable = NO;
	reachable = foundServer && (status & kSCNetworkFlagsReachable) && !(status & kSCNetworkFlagsConnectionRequired);
	//	if it's not reachable, bail
	if (!reachable)
		goto BAIL;
	
	//	if i'm here, there are logs which need to be sent and the server's available- open the reporter!
	[self openCrashReporter];
	return;
	
	//	jump here if check gets cancelled or there's nothing to send in!
	BAIL:
	//	tell the delegate that the check's been finished
	if ((delegate!=nil)&&([delegate respondsToSelector:@selector(crashReporterCheckDone)]))
		[delegate crashReporterCheckDone];
}
- (void) openCrashReporter	{
	//NSLog(@"%s",__func__);
	//	make sure i'm only opening the actual window on the main thread!
	if (![NSThread isMainThread])	{
		[self performSelectorOnMainThread:@selector(openCrashReporter) withObject:nil waitUntilDone:NO];
		return;
	}
	//	populate the email field with whatever email address was stored in the prefs last time
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	NSString			*tmp = nil;
	tmp = [def objectForKey:@"crashReporterEmail"];
	if (tmp != nil)
		[emailField setStringValue:tmp];
	//	actually open the window
	[window makeKeyAndOrderFront:nil];
	//[[NSApplication sharedApplication] runModalForWindow:crashReporterWindow];
}
- (IBAction) doneClicked:(id)sender	{
	//NSLog(@"%s",__func__);
	//	if the user entered an email address, store it in the prefs
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	NSString			*tmp = nil;
	tmp = [emailField stringValue];
	if ((tmp!=nil)&&([tmp length]>0))	{
		[def setObject:tmp forKey:@"crashReporterEmail"];
		[def synchronize];
	}
	//	else if the user didn't enter an email address- nag them to (make sure to only nag once!)
	//else	{
		//NSLog(@"\t\tshould be nagging user to enter an email address now!");
	//}
	
	//	set up the job details
	jobSize = [crashLogArray count];
	jobCurrentIndex = 1;
	
	//	configure the submitting label so it displays what's going on (and is visible)
	[submittingLabel setHidden:NO];
	
	//	get the system profile (do this 1st, so any errors show up in the console log!)
	[submittingLabel setStringValue:@"Getting basic machine profile..."];
	[submittingLabel display];
	systemProfilerDict = [[self _systemProfilerDict] retain];
	//	get the console log string
	[submittingLabel setStringValue:@"Getting relevant console log..."];
	[submittingLabel display];
	consoleLog = [[self _consoleLogString] retain];
	
	//	show the progress indicator and countdown label
	[progressIndicator setHidden:NO];
	[countdownLabel setStringValue:@""];
	[countdownLabel setHidden:NO];
	
	//	start sending the crash logs
	[self sendACrashLog];
}
- (void) sendACrashLog	{
	//	make sure this method always executes on the main thread, or the timer stuff won't be added/removed properly
	if (![NSThread isMainThread])	{
		[self performSelectorOnMainThread:@selector(sendACrashLog) withObject:nil waitUntilDone:NO];
		return;
	}
	//	if there's a timer, kill it
	if (currentCrashLogTimer != nil)	{
		[currentCrashLogTimer invalidate];
		[currentCrashLogTimer release];
		currentCrashLogTimer = nil;
	}
	//	update the label so it displays which log is being sent
	[submittingLabel setStringValue:[NSString stringWithFormat:@"Sending log %ld/%ld",jobCurrentIndex,jobSize]];
	//	update the progress indicator, too
	[progressIndicator setDoubleValue:(float)jobCurrentIndex/(float)jobSize];
	
	//	assemble the transmit string
	NSMutableString		*transmitString = [NSMutableString stringWithCapacity:0];
	NSString			*tmpString = nil;
	//	get the email string- if it's non-nil, add it to the transmit string
	tmpString = [emailField stringValue];
	if ((tmpString!=nil)&&([tmpString length]>0))
		[transmitString appendFormat:@"email=%@VVAMPERSANDVV",tmpString];
	//	if this is the last log, send the description
	if ([crashLogArray count]==1)	{
		tmpString = [descriptionField string];
		[transmitString appendFormat:@"description=%@VVAMPERSANDVV",tmpString];
	}
	//	else it's not the last log- the description should be OLDERLOG
	else
		[transmitString appendString:@"description=OLDERLOGVVAMPERSANDVV"];
	//	add the crash log string
	tmpString = [NSString stringWithContentsOfFile:[crashLogArray lockFirstObject] usedEncoding:nil error:nil];
	[transmitString appendFormat:@"crash=Host Name: %@\n",CSCopyMachineName()];
	if (tmpString!=nil)
		[transmitString appendFormat:@"%@VVAMPERSANDVV",tmpString];
	else
		[transmitString appendString:@"COULDNTLOADVVAMPERSANDVV"];
	//	if this is the last log, add the console log
	if ([crashLogArray count]==1)	{
		[transmitString appendFormat:@"console=%@VVAMPERSANDVV",consoleLog];
	}
	//	else this isn't the last console log- add OLDERLOG
	else
		[transmitString appendString:@"console=OLDERLOGVVAMPERSANDVV"];
	//	on with the rest!
	tmpString = [systemProfilerDict objectForKey:@"hardware"];
	if (tmpString != nil)
		[transmitString appendFormat:@"hardware=%@VVAMPERSANDVV",tmpString];
	tmpString = [systemProfilerDict objectForKey:@"software"];
	if (tmpString != nil)
		[transmitString appendFormat:@"software=%@VVAMPERSANDVV",tmpString];
	tmpString = [systemProfilerDict objectForKey:@"usb"];
	if (tmpString != nil)
		[transmitString appendFormat:@"usb=%@VVAMPERSANDVV",tmpString];
	tmpString = [systemProfilerDict objectForKey:@"firewire"];
	if (tmpString != nil)
		[transmitString appendFormat:@"firewire=%@VVAMPERSANDVV",tmpString];
	tmpString = [systemProfilerDict objectForKey:@"graphics"];
	if (tmpString != nil)
		[transmitString appendFormat:@"graphics=%@VVAMPERSANDVV",tmpString];
	tmpString = [systemProfilerDict objectForKey:@"memory"];
	if (tmpString != nil)
		[transmitString appendFormat:@"memory=%@VVAMPERSANDVV",tmpString];
	tmpString = [systemProfilerDict objectForKey:@"pci"];
	if (tmpString != nil)
		[transmitString appendFormat:@"pci=%@",tmpString];
	//	replace the ampersands with USERAMPERSAND
	[transmitString replaceOccurrencesOfString:@"&"
		withString:@"USERAMPERSAND"
		options:NSCaseInsensitiveSearch
		range:NSMakeRange(0,[transmitString length])];
	//	replace VVAMPERSAND with &
	[transmitString replaceOccurrencesOfString:@"VVAMPERSANDVV"
		withString:@"&"
		options:NSCaseInsensitiveSearch
		range:NSMakeRange(0,[transmitString length])];
	
	//	create & set up the VVCURLDL
	VVCURLDL			*url = [VVCURLDL createWithAddress:uploadURL];
	[url appendStringToPOST:transmitString];
	[url setReturnOnMain:YES];
	//	make sure the VVCURLDL is retained- release it when it's done (on the delegate callback, so i don't need to keep a pointer to it)
	[url retain];
	
	//	start a timer which counts down from 60 (the libcurl timeout) so the user knows the app hasn't hung
	currentCrashLogTimeout = 60;
	currentCrashLogTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateCrashLogTimeout:) userInfo:nil repeats:YES];
	if (currentCrashLogTimer != nil)	{
		[currentCrashLogTimer retain];
		NSRunLoop		*runLoop = [NSRunLoop currentRunLoop];
		if (runLoop != nil)	{
			[runLoop addTimer:currentCrashLogTimer forMode:NSDefaultRunLoopMode];
			[runLoop addTimer:currentCrashLogTimer forMode:NSEventTrackingRunLoopMode];
			[runLoop addTimer:currentCrashLogTimer forMode:NSModalPanelRunLoopMode];
			[runLoop addTimer:currentCrashLogTimer forMode:NSConnectionReplyMode];
		}
	}
	
	//	start the network operation asynchronously- i'm the delegate, so it'll notify me when it's done (whether it works or fails)
	[url performAsync:YES withDelegate:self];
	
	//	increment the job index
	++jobCurrentIndex;
}
- (void) closeCrashReporter	{
	//NSLog(@"%s",__func__);
	//	make sure i'm only closing the actual window on the main thread!
	if (![NSThread isMainThread])	{
		[self performSelectorOnMainThread:@selector(closeCrashReporter) withObject:nil waitUntilDone:NO];
		return;
	}
	//	close the window
	[window orderOut:nil];
	//	tell the delegate that the check's been finished
	if ((delegate!=nil)&&([delegate respondsToSelector:@selector(crashReporterCheckDone)]))
		[delegate crashReporterCheckDone];
}




//	this method exists so i can specify an alternate nib via a subclass (nibs get loaded on init, so i can't do this with a variable- there's no opportunity to set it)
- (NSString *) _nibName	{
	return [NSString stringWithString:@"VVCrashReporter"];
}
//	this method returns an auto-released NSString with the last 200 lines this application printed to the console log
- (NSString *) _consoleLogString	{
	NSString			*appNameString = [[[[NSBundle mainBundle] bundlePath] lastPathComponent] stringByDeletingPathExtension];
	NSMutableArray		*mutArray = [NSMutableArray arrayWithCapacity:0];
	aslmsg				q = asl_new(ASL_TYPE_QUERY);
	aslmsg				m;
	aslresponse			r;
	char				*timeString;
	char				*msgString;
	
	asl_set_query(q, ASL_KEY_SENDER, [appNameString UTF8String], ASL_QUERY_OP_EQUAL);
	r = asl_search(NULL, q);
	while (NULL != (m = aslresponse_next(r)))	{
		//NSLog(@"\t\t********");
		//for (i=0; (NULL != (key = asl_key(m,i))); ++i)	{
		//	val = asl_get(m,key);
			//NSLog(@"\t\t%s",val);
			//NSLog(@"\t\t%s",key);
		//}
		timeString = (char *)asl_get(m,(const char *)"CFLog Local Time");
		msgString = (char *)asl_get(m,(const char *)"Message");
		if ((timeString != nil) && (msgString != nil))	{
			[mutArray addObject:[NSString stringWithFormat:@"%s::%s",timeString,msgString]];
		}
	}
	aslresponse_free(r);
	while ([mutArray count] > 200)	{
		[mutArray removeObjectAtIndex:0];
	}
	return [mutArray componentsJoinedByString:@"\n"];
}
//	this method returns a dictionary with various pieces of system profiler information stored at their respective keys
- (NSMutableDictionary *) _systemProfilerDict	{
	NSMutableDictionary		*returnMe = [NSMutableDictionary dictionaryWithCapacity:0];
	NSString				*tmp = nil;
	//	these are assembled one-at-a-time because i've observed hangs when trying to do 3 or more at once
	tmp = [self _stringForSystemProfilerDataType:@"SPHardwareDataType"];
	if (tmp != nil)
		[returnMe setObject:tmp forKey:@"hardware"];
	tmp = [self _stringForSystemProfilerDataType:@"SPSoftwareDataType"];
	if (tmp != nil)
		[returnMe setObject:tmp forKey:@"software"];
	tmp = [self _stringForSystemProfilerDataType:@"SPUSBDataType"];
	if (tmp != nil)
		[returnMe setObject:tmp forKey:@"usb"];
	tmp = [self _stringForSystemProfilerDataType:@"SPFireWireDataType"];
	if (tmp != nil)
		[returnMe setObject:tmp forKey:@"firewire"];
	tmp = [self _stringForSystemProfilerDataType:@"SPDisplaysDataType"];
	if (tmp != nil)
		[returnMe setObject:tmp forKey:@"graphics"];
	tmp = [self _stringForSystemProfilerDataType:@"SPMemoryDataType"];
	if (tmp != nil)
		[returnMe setObject:tmp forKey:@"memory"];
	//tmp = [self _stringForSystemProfilerDataType:@"SPPCCardDataType"];
	//if (tmp != nil)
	//	[returnMe setObject:tmp forKey:@"hardware"];
	tmp = [self _stringForSystemProfilerDataType:@"SPPCIDataType"];
	if (tmp != nil)
		[returnMe setObject:tmp forKey:@"pci"];
	
	return returnMe;
}
- (NSString *) _stringForSystemProfilerDataType:(NSString *)t	{
	//NSLog(@"%s ... %@",__func__,t);
	if (t == nil)
		return nil;
	NSTask				*theTask = nil;
	NSData				*data = nil;
	NSString			*returnMe = nil;
	
	//	if i can't find the binary for the system profiler, bail
	if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/sbin/system_profiler"])	{
		NSLog(@"\t\terr: couldn't locate system_profiler binary");
		goto BAIL;
	}
	//	start an exception catcher so if anything goes wrong i won't crash the app
	@try	{
		//	create & set up an NSTask which will execute the system_profiler
		theTask = [[NSTask alloc] init];
		[theTask setLaunchPath:@"/usr/sbin/system_profiler"];
		[theTask setArguments:[NSArray arrayWithObjects:
			[NSString stringWithString:@"-detailLevel"],
			[NSString stringWithString:@"mini"],
			t,
			nil]	];
		//	create a pipe, attach it to stdout of the task, get a file handle to the pipe
		NSPipe				*outputPipe = [NSPipe pipe];
		[theTask setStandardOutput:outputPipe];
		NSFileHandle		*fileHandle = [outputPipe fileHandleForReading];
		
		//	launch the task
		[theTask launch];
		
		//	make sure the task doesn't hang- start a loop that executes 20 times/sec which will kill the task after a terminate date
		NSDate				*terminateDate = [[NSDate date] addTimeInterval:5.0];
		while ((theTask != nil) && ([theTask isRunning]))	{
			if ([[NSDate date] compare:(id)terminateDate] == NSOrderedDescending)	{
				NSLog(@"\t\terr: terminating SP task");
				[theTask terminate];
			}
			[NSThread sleepForTimeInterval:0.05];
		}
		//	read the data at the file handle
		data = [fileHandle readDataToEndOfFile];
		if (data == nil)	{
			NSLog(@"\t\terr: couldn't read SP data from file handle");
			goto BAIL;
		}
		//	make a string from the data
		returnMe = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		if (returnMe == nil)
			NSLog(@"\t\terror: couldn't create SP string from data");
		else
			[returnMe autorelease];
	}
	@catch (NSException *err)	{
		NSLog(@"\t\terr: caught exception: %s, %@",__func__,t);
	}
	BAIL:
	VVRELEASE(theTask);
	return returnMe;
}




//	this is a timer callback.  the timer is launched in sendACrashLog, and exists to update a countdown timer so users don't think the app has hung.  that is the ONLY thing this timer should do.
- (void) updateCrashLogTimeout:(NSTimer *)t	{
	//NSLog(@"%s",__func__);
	//	update the countdown label
	[countdownLabel setStringValue:[NSString stringWithFormat:@"%ld",currentCrashLogTimeout]];
	//	update the countdown
	--currentCrashLogTimeout;
	//	if the timeout's run out, invalidate the timer
	if (currentCrashLogTimeout < 0)	{
		if (currentCrashLogTimer != nil)	{
			[currentCrashLogTimer invalidate];
			[currentCrashLogTimer release];
			currentCrashLogTimer = nil;
		}
		NSLog(@"\t\tshould be killing the download or it should be dying now");
	}
}
- (void) dlFinished:(id)h	{
	//NSLog(@"%s",__func__);
	/*
			the instance of VVCURLDL that called this was configured to return on the main thread when done!
	*/
	//	kill the timer
	if (currentCrashLogTimer != nil)	{
		[currentCrashLogTimer invalidate];
		[currentCrashLogTimer release];
		currentCrashLogTimer = nil;
	}
	//	wait a bit to make absolutely sure the timer's dead
	[NSThread sleepForTimeInterval:0.05];
	//	get the path to the log i just finished sending
	NSString			*finishedPath = [crashLogArray lockFirstObject];
	
	//	determine the network error
	int				networkErr = [h err];
	//	if there's no error, check to see if there's a 404 (page not found).  if there is, consider it an error!
	NSRange			notFoundRange = [[h responseString] rangeOfString:@"404"];
	if ((notFoundRange.location!=NSNotFound)&&(notFoundRange.length!=0))
		networkErr = 404;
	
	//	if there was an error
	if (networkErr != 0)	{
		//	release the VVCURLDL
		[h autorelease];
		//	the last crash date should be BEFORE the last modification date of the log i just finished sending!
		NSDictionary		*attribDict = [[NSFileManager defaultManager] fileAttributesAtPath:finishedPath traverseLink:NO];
		NSDate				*crashModDate = [attribDict objectForKey:NSFileModificationDate];
		NSDate				*newLastCrashDate = [crashModDate addTimeInterval:-60.0];
		NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
		[def setObject:newLastCrashDate forKey:@"lastCrashDate"];
		[def synchronize];
		//	 throw up an alert that describes the error
		if (developerEmail == nil)
			NSRunAlertPanel(@"Network error!",@"There's a problem contacting the server- please email the developers and say that a network error of type %ld occurred.",@"OK",nil,nil,networkErr);
		else	{
			NSLog(@"\t\tfound dev email!");
			NSRunAlertPanel(@"Network error!",@"There's a problem contacting the server- please email the developers and say that a network error of type %ld occurred.\n\n%@",@"OK",nil,nil,networkErr,developerEmail);
		}
		//	close the window
		[self closeCrashReporter];
		//	release system profiler dict
		VVRELEASE(systemProfilerDict);
		//	release the console log
		VVRELEASE(consoleLog);
		//	return
		return;
	}
	//	else there was no error
	else	{
		//	release the VVCURLDL
		[h autorelease];
		
		//	retain the path to the crash log, just in case
		[finishedPath retain];
		//	take the log i just sent out of the array
		[crashLogArray lockRemoveFirstObject];
		//	delete the actual crash log
		[[NSFileManager defaultManager] removeFileAtPath:finishedPath handler:nil];
		//	release the path to the crash log
		[finishedPath release];
		//	if there aren't any crash logs left in the array, i'm done!
		if ([crashLogArray count]==0)	{
			//	close the window
			[self closeCrashReporter];
			//	update the last crash date
			NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
			[def setObject:[NSDate date] forKey:@"lastCrashDate"];
			[def synchronize];
			//	release system profiler dict
			VVRELEASE(systemProfilerDict);
			//	release the console log
			VVRELEASE(consoleLog);
			//	return
			return;
		}
		//	else there are still logs to send
		else	{
			//	send the next crash log
			[self sendACrashLog];
		}
	}
}




- (void) setDeveloperEmail:(NSString *)n	{
	VVRELEASE(developerEmail);
	if (n != nil)
		developerEmail = [n retain];
}
- (NSString *) developerEmail	{
	return developerEmail;
}
- (void) setUploadURL:(NSString *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	VVRELEASE(uploadURL);
	if (n != nil)	{
		//uploadURL = [n retain];
		NSString		*tmpString = [n stringByReplacingOccurrencesOfString:@"http://" withString:@""];
		if (tmpString != nil)
			uploadURL = [tmpString retain];
		//NSLog(@"\t\tuploadURL = %@",uploadURL);
	}
}
- (NSString *) uploadURL	{
	return uploadURL;
}
@synthesize delegate;


@end

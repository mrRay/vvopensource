#import "DocController.h"
#import "ISFController.h"
#import "JSONGUIController.h"




@implementation DocController


- (id) init	{
	self = [super init];
	if (self!=nil)	{
		fragFilePath = nil;
		fragFilePathContentsOnOpen = nil;
		fragEditsPerformed = NO;
		vertFilePath = nil;
		vertFilePathContentsOnOpen = nil;
		vertEditsPerformed = NO;
		tmpFileSaveTimer = nil;
		
		//
		// assign user defaults.
		// a number of properties are derived from the user defaults system rather than the doc spec.
		//
		// see MGSFragariaPreferences.h for details
		//
		[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:MGSFragariaPrefsAutocompleteSuggestAutomatically];
		
		fragFileFragaria = [[MGSFragaria alloc] init];
		vertFileFragaria = [[MGSFragaria alloc] init];
		
		jsonFragaria = [[MGSFragaria alloc] init];
		errorFragaria = [[MGSFragaria alloc] init];
		vertTextFragaria = [[MGSFragaria alloc] init];
		fragTextFragaria = [[MGSFragaria alloc] init];
		
		[fragFileFragaria setObject:@"GLSL" forKey:MGSFOSyntaxDefinitionName];
		[vertFileFragaria setObject:@"GLSL" forKey:MGSFOSyntaxDefinitionName];
		[jsonFragaria setObject:@"GLSL" forKey:MGSFOSyntaxDefinitionName];
		[errorFragaria setObject:@"GLSL" forKey:MGSFOSyntaxDefinitionName];
		[vertTextFragaria setObject:@"GLSL" forKey:MGSFOSyntaxDefinitionName];
		[fragTextFragaria setObject:@"GLSL" forKey:MGSFOSyntaxDefinitionName];
	}
	return self;
}
- (void) awakeFromNib	{
	//NSLog(@"%s",__func__);
	
	[splitView setPosition:[splitView maxPossiblePositionOfDividerAtIndex:0] ofDividerAtIndex:0];
	[fileSplitView setPosition:[fileSplitView maxPossiblePositionOfDividerAtIndex:0] ofDividerAtIndex:0];
	
	[fragFileFragaria embedInView:fragFileTextView];
	[vertFileFragaria embedInView:vertFileTextView];
	[jsonFragaria embedInView:jsonTextView];
	[errorFragaria embedInView:errorTextView];
	[vertTextFragaria embedInView:vertTextView];
	[fragTextFragaria embedInView:fragTextView];
	
	NSTextView		*tmpTextView = nil;
	tmpTextView = [jsonFragaria objectForKey:ro_MGSFOTextView];
	[tmpTextView setEditable:NO];
	tmpTextView = [errorFragaria objectForKey:ro_MGSFOTextView];
	[tmpTextView setEditable:NO];
	tmpTextView = [vertTextFragaria objectForKey:ro_MGSFOTextView];
	[tmpTextView setEditable:NO];
	tmpTextView = [fragTextFragaria objectForKey:ro_MGSFOTextView];
	[tmpTextView setEditable:NO];
	
	[fragFileFragaria setObject:self forKey:MGSFODelegate];
	[vertFileFragaria setObject:self forKey:MGSFODelegate];
}


- (void) createNewFile	{
	//NSLog(@"%s",__func__);
	//	kill the save timer if it exists
	@synchronized (self)	{
		if (tmpFileSaveTimer!=nil)	{
			[tmpFileSaveTimer invalidate];
			tmpFileSaveTimer = nil;
		}
	}
	//	first of all, assemble a new empty file, located at "/tmp/ISFTesterTmpFile.fs"
	NSString		*newFilePath = @"/tmp/ISFTesterTmpFile.fs";
	NSString		*newFileGuts = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"NewFileTemplate" ofType:@"txt"] encoding:NSUTF8StringEncoding error:nil];
	if (![newFileGuts writeToFile:newFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil])	{
		NSLog(@"\t\terr: couldn't create tmp file in %s",__func__);
		return;
	}
	//else
		//NSLog(@"\t\ti appear to have correctly written to the path %@",newFilePath);
	
	//	load the tmp file i just created
	[self loadFile:newFilePath];
}
- (void) loadFile:(NSString *)p	{
	NSLog(@"%s ... %@",__func__,p);
	//	kill the save timer if it exists
	@synchronized (self)	{
		if (tmpFileSaveTimer!=nil)	{
			[tmpFileSaveTimer invalidate];
			tmpFileSaveTimer = nil;
		}
	}
	/*
	//	clear out everything in the non-file text views
	NSLog(@"\t\tclearing out contents with a non-file content dict...");
	dispatch_async(dispatch_get_main_queue(), ^{
		[self loadNonFileContentDict:nil];
	});
	*/
	
	
	
	//	load the file at the passed path (a .fs or .frag file) to an NSString
	NSFileManager	*fm = [NSFileManager defaultManager];
	NSString		*fileContents = (p==nil || ![fm fileExistsAtPath:p]) ? nil : [NSString stringWithContentsOfFile:p encoding:NSUTF8StringEncoding error:nil];
	//	if i loaded stuff from a file, replace the relevant vars & update the file text view
	@synchronized (self)	{
		VVRELEASE(fragFilePath);
		VVRELEASE(fragFilePathContentsOnOpen);
		fragEditsPerformed = NO;
		if (fileContents!=nil)	{
			fragFilePath = [p retain];
			fragFilePathContentsOnOpen = [fileContents retain];
			dispatch_async(dispatch_get_main_queue(), ^{
				[fragFileFragaria setString:fileContents];
			});
		}
		else	{
			dispatch_async(dispatch_get_main_queue(), ^{
				[fragFileFragaria setString:@""];
			});
		}
		
	}
	
	
	//	i'm also going to want to load the stuff from the vertex shader file to the corresponding editor...
	//	look for a vert shader that matches the name of the frag shader
	NSString		*noExtPath = [p stringByDeletingPathExtension];
	NSString		*tmpVertPath = nil;
	tmpVertPath = VVFMTSTRING(@"%@.vs",noExtPath);
	if ([fm fileExistsAtPath:tmpVertPath])
		fileContents = [NSString stringWithContentsOfFile:tmpVertPath encoding:NSUTF8StringEncoding error:nil];
	else	{
		tmpVertPath = VVFMTSTRING(@"%@.vert",noExtPath);
		if ([fm fileExistsAtPath:tmpVertPath])
			fileContents = [NSString stringWithContentsOfFile:tmpVertPath encoding:NSUTF8StringEncoding error:nil];
		else	{
			fileContents = nil;
		}
	}
	//	if i loaded stuff from a file, replace the relevant vars & update the file text view
	@synchronized (self)	{
		VVRELEASE(vertFilePath);
		VVRELEASE(vertFilePathContentsOnOpen);
		vertEditsPerformed = NO;
		if (fileContents!=nil)	{
			vertFilePath = [tmpVertPath retain];
			vertFilePathContentsOnOpen = [fileContents retain];
			dispatch_async(dispatch_get_main_queue(), ^{
				[vertFileFragaria setString:fileContents];
			});
		}
		else	{
			dispatch_async(dispatch_get_main_queue(), ^{
				[vertFileFragaria setString:@""];
			});
		}
	}
	
	
	//	tell the JSON GUI controller to refresh its UI (loads the outline view with the GUI for editing inputs/passes/etc)
	[jsonController refreshUI];
}
- (void) saveOpenFile	{
	NSLog(@"********************************");
	NSLog(@"%s",__func__);
	//	get the current strings- if it's nil or empty, bail
	NSString		*currentFragString = [[[fragFileFragaria string] copy] autorelease];
	if (currentFragString!=nil && [currentFragString length]<1)
		currentFragString = nil;
	NSString		*currentVertString = [[[vertFileFragaria string] copy] autorelease];
	if (currentVertString!=nil && [currentVertString length]<1)
		currentVertString = nil;
	if ((currentFragString==nil || [currentFragString length]<1) && (currentVertString==nil || [currentVertString length]<1))	{
		NSLog(@"\t\tbailing on save, currentFragString and currentVertString empty");
		return;
	}
	
	
	
	
	
	@synchronized (self)	{
		//	kill the save timer if it exists
		if (tmpFileSaveTimer!=nil)	{
			[tmpFileSaveTimer invalidate];
			tmpFileSaveTimer = nil;
		}
		//	if the current string matches the contents on open, bail- nothing to save anywhere
		BOOL		fragContentsChanged = NO;
		BOOL		vertContentsChanged = NO;
		/*
		if (fragFilePathContentsOnOpen==nil)
			NSLog(@"\t\tfragFilePathContentsOnOpen is nil");
		else
			NSLog(@"\t\tfragFilePathContentsOnOpen is non-nil");
		if (vertFilePathContentsOnOpen==nil)
			NSLog(@"\t\tvertFilePathContentsOnOpen is nil");
		else
			NSLog(@"\t\tvertFilePathContentsOnOpen is non-nil");
		
		if (currentFragString==nil)
			NSLog(@"\t\tcurrentFragString is nil");
		else
			NSLog(@"\t\tcurrentFragString is non-nil");
		if (currentVertString==nil)
			NSLog(@"\t\tcurrentVertString is nil");
		else
			NSLog(@"\t\tcurrentVertString is non-nil");
		*/
		//	check to see if the actual file contents have changed
		if ((fragFilePathContentsOnOpen==nil && currentFragString!=nil) || (fragFilePathContentsOnOpen!=nil && currentFragString!=nil && ![fragFilePathContentsOnOpen isEqualToString:currentFragString]))
			fragContentsChanged = YES;
		if ((vertFilePathContentsOnOpen==nil && currentVertString!=nil) || (vertFilePathContentsOnOpen!=nil && currentVertString!=nil && ![vertFilePathContentsOnOpen isEqualToString:currentVertString]))
			vertContentsChanged = YES;
		
		//	if the frag file is in /tmp/, we're going to pretend that its contents have changed (so it gets written to disk)
		if (!fragContentsChanged && fragFilePath!=nil && [fragFilePath rangeOfString:@"/tmp/"].location==0)
			fragContentsChanged = YES;
		if (!vertContentsChanged && vertFilePath!=nil && [vertFilePath rangeOfString:@"/tmp/"].location==0)
			vertContentsChanged = YES;
		
		if (!fragContentsChanged && !vertContentsChanged)	{
			//NSLog(@"\t\tbailing on save, contents haven't changed since file opened");
			return;
		}
		
		//NSLog(@"\t\tfragContentsChanged is %d, vertContentsChanged is %d",fragContentsChanged,vertContentsChanged);
		//	if the file path is nil or this is a temp file, open an alert so the user can supply a name and save location for the file
		if (fragFilePath==nil || [fragFilePath rangeOfString:@"/tmp/"].location==0)	{
			//NSLog(@"\t\tfile paths are in tmp, need to show a save panel...");
			
			NSSavePanel			*savePanel = [[NSSavePanel savePanel] retain];
			//	the default save directory should be the directory currently listed in the window at left (default to system ISF folder if not specified yet)
			NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
			NSString			*tmpPath = [def objectForKey:@"fxPath"];
			//	if there's no default path yet, try to use the system-level default path (if it exists)
			if (tmpPath==nil)	{
				NSFileManager		*fm = [NSFileManager defaultManager];
				BOOL				defaultIsFolder = NO;
				if ([fm fileExistsAtPath:tmpPath isDirectory:&defaultIsFolder] && defaultIsFolder)
					tmpPath = @"/Library/Graphics/ISF";
			}
			[savePanel setDirectoryURL:[NSURL fileURLWithPath:tmpPath]];
			[savePanel setExtensionHidden:YES];
			[savePanel setAllowsOtherFileTypes:NO];
			[savePanel setAllowedFileTypes:OBJARRAY(@"fs")];
			[savePanel
				beginSheetModalForWindow:window
				completionHandler:^(NSInteger result)	{
					//	if the user clicked okay, save the file(s)
					if (result == NSFileHandlingPanelOKButton)	{
						NSString		*pathToSave = [[savePanel URL] path];
						NSString		*noExtPathToSave = [pathToSave stringByDeletingPathExtension];
						if (fragContentsChanged)	{
							NSString		*localWritePath = VVFMTSTRING(@"%@.fs",noExtPathToSave);
							@synchronized (self)	{
								VVRELEASE(fragFilePath);
								fragFilePath = [localWritePath retain];
								VVRELEASE(fragFilePathContentsOnOpen);
								fragFilePathContentsOnOpen = [currentFragString retain];
								fragEditsPerformed = NO;
							}
							if (![currentFragString writeToFile:localWritePath atomically:YES encoding:NSUTF8StringEncoding error:nil])	{
								NSLog(@"\t\tERR: problem writing frag file to path %@",localWritePath);
							}
							//else
								//NSLog(@"********************* wrote .fs file to disk A");
						}
						if (vertContentsChanged)	{
							NSString		*localWritePath = VVFMTSTRING(@"%@.vs",noExtPathToSave);
							@synchronized (self)	{
								VVRELEASE(vertFilePath);
								vertFilePath = [localWritePath retain];
								VVRELEASE(vertFilePathContentsOnOpen);
								vertFilePathContentsOnOpen = [currentVertString retain];
								vertEditsPerformed = NO;
							}
							if (![currentVertString writeToFile:localWritePath atomically:YES encoding:NSUTF8StringEncoding error:nil])	{
								NSLog(@"\t\tERR: problem writing vert file to path %@",localWritePath);
							}
							//else
								//NSLog(@"********************* wrote .vs file to disk A");
						}
						
						if (fragContentsChanged || vertContentsChanged)
							[isfController loadFile:pathToSave];
						
					}
					//	else the user clicked cancel- we don't want to save
					else	{
						@synchronized (self)	{
							NSLog(@"**** not sure if i want to comment this out, refer here if file stuff is broken, %s",__func__);
							/*
							VVRELEASE(fragFilePath);
							VVRELEASE(fragFilePathContentsOnOpen);
							fragEditsPerformed = NO;
							VVRELEASE(vertFilePath);
							VVRELEASE(vertFilePathContentsOnOpen);
							vertEditsPerformed = NO;
							*/
						}
					}
				}];
		}
		//	else the file path is non-nil and not in /tmp/, just save the file to disk
		else	{
			//NSLog(@"\t\tfile paths aren't in tmp, just saving to disk...");
			if (fragContentsChanged)	{
				//	if i successfully wrote the file to disk
				if ([currentFragString writeToFile:fragFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil])	{
					//NSLog(@"********************* wrote .fs file to disk B");
					VVRELEASE(fragFilePathContentsOnOpen);
					fragFilePathContentsOnOpen = [currentFragString retain];
					fragEditsPerformed = NO;
				}
				//else
					//NSLog(@"\t\tERR: problem saving frag file %@ to disk",fragFilePath);
			}
			if (vertContentsChanged)	{
				//	if the vert file path is nil, it means that i just created a vert shader by jotting down some text in an empty editor, and i need to save it as a new file
				if (vertFilePath==nil && fragFilePath!=nil)	{
					vertFilePath = [[[fragFilePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"vs"] retain];
				}
				//	if i successfully wrote the file to disk
				//NSLog(@"\t\tshould be dumping currentVertString to file %@ in %s",vertFilePath,__func__);
				if ([currentVertString writeToFile:vertFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil])	{
					//NSLog(@"********************* wrote .vs file to disk B");
					VVRELEASE(vertFilePathContentsOnOpen);
					vertFilePathContentsOnOpen = [currentVertString retain];
					vertEditsPerformed = NO;
				}
				//else
					//NSLog(@"\t\tERR: problem saving vert file %@ to disk",vertFilePath);
			}
		}
	}
	
}
- (void) reloadFileFromTableView	{
	
}


- (void) loadNonFileContentDict:(NSDictionary *)n	{
	//NSLog(@"%s ... %p",__func__,n);
	//NSLog(@"%s ... %@",__func__,n);
	BOOL			openSplitView = NO;
	NSString		*tmpString = nil;
	NSArray			*syntaxErrs = [n objectForKey:@"syntaxErr"];
	
	tmpString = (n==nil) ? nil : [n objectForKey:@"error"];
	if (tmpString==nil)
		tmpString = @"//	No errors!";
	else	{
		//	if there's an error string, we need to make sure the split view is open!
		openSplitView = YES;
	}
	dispatch_async(dispatch_get_main_queue(), ^{
		[errorFragaria setString:tmpString];
		[fragFileFragaria setSyntaxErrors:syntaxErrs];
	});
	
	tmpString = (n==nil) ? nil : [n objectForKey:@"json"];
	if (tmpString==nil)
		tmpString = @"";
	dispatch_async(dispatch_get_main_queue(), ^{
		[jsonFragaria setString:tmpString];
	});
	
	tmpString = (n==nil) ? nil : [n objectForKey:@"vertex"];
	if (tmpString==nil)
		tmpString = @"";
	dispatch_async(dispatch_get_main_queue(), ^{
		[vertTextFragaria setString:tmpString];
	});
	
	tmpString = (n==nil) ? nil : [n objectForKey:@"fragment"];
	if (tmpString==nil)
		tmpString = @"";
	dispatch_async(dispatch_get_main_queue(), ^{
		[fragTextFragaria setString:tmpString];
	});
	
	/*
	//	tell the JSON GUI controller to refresh its UI (loads the outline view with the GUI for editing inputs/passes/etc)
	[jsonController refreshUI];
	*/
	
	//	if we have to pop open the split view containing the error info, do so now
	if (openSplitView)	{
		//	open the split view if necessary
		if ([splitView isSubviewCollapsed:splitViewNonFileSubview])	{
			[splitView setPosition:[splitView frame].size.height-250.0 ofDividerAtIndex:0];
		}
		//	switch to the error tab
		[nonFileTabView selectTabViewItemAtIndex:0];
	}
}
- (NSString *) fragFilePath	{
	NSString		*returnMe = nil;
	@synchronized (self)	{
		returnMe = [[fragFilePath retain] autorelease];
	}
	return returnMe;
}


#pragma mark -
#pragma mark NSSplitViewDelegate protocol


- (BOOL)splitView:(NSSplitView *)sv canCollapseSubview:(NSView *)subview	{
	if (subview==splitViewFileSubview)
		return NO;
	if (subview == fileSplitviewVertSubview)	{
		//if ([sv isSubviewCollapsed:fileSplitViewFragSubview] && ![sv isSubviewCollapsed:fileSplitViewJSONSubview])
		//	return NO;
		//else
		//	return YES;
	}
	return YES;
}
- (BOOL)splitView:(NSSplitView *)sv shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex	{
	//NSLog(@"%s ... %d",__func__,dividerIndex);
	return YES;
}
- (CGFloat)splitView:(NSSplitView *)sv constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex	{
	//NSLog(@"%s ... %d, %f",__func__,dividerIndex,proposedMax);
	if (sv==splitView)	{
		NSRect			splitViewFrame = [splitView frame];
		return splitViewFrame.size.height - 250.0;
	}
	else if (sv==fileSplitView)	{
		//NSLog(@"%s ... %d, %f",__func__,dividerIndex,proposedMax);
		NSRect			splitViewFrame = [sv frame];
		CGFloat			returnMe = splitViewFrame.size.width;
		if (dividerIndex == 0)	{
			//return proposedMax;
			if (![sv isSubviewCollapsed:fileSplitViewJSONSubview])
				returnMe -= 360.;
			returnMe -= [sv dividerThickness];
			returnMe -= 180.;
			//if (![sv isSubviewCollapsed:fileSplitviewVertSubview])
			//	returnMe -= [fileSplitviewVertSubview frame].size.width;
			//returnMe -= [sv dividerThickness];
		}
		else if (dividerIndex == 1)	{
			return [sv frame].size.width-360.-[sv dividerThickness]-[sv dividerThickness];
			//if (![sv isSubviewCollapsed:fileSplitViewJSONSubview])
			//	returnMe -= 360.;
			//returnMe -= [sv dividerThickness];
		}
		return returnMe;
		
		/*
		NSRect			splitViewFrame = [sv frame];
		return splitViewFrame.size.width - 250.0;
		*/
	}
	return proposedMax;
}
- (CGFloat)splitView:(NSSplitView *)sv constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex	{
	//NSLog(@"%s ... %d, %f",__func__,dividerIndex,proposedMin);
	if (sv==splitView)	{
		return 250.0;
	}
	else if (sv==fileSplitView)	{
		//NSLog(@"%s ... %d, %f",__func__,dividerIndex,proposedMin);
		CGFloat			returnMe = 0.;
		if (dividerIndex == 0)	{
			returnMe = 180.;
		}
		else if (dividerIndex == 1)	{
			return [sv frame].size.width-360.-[sv dividerThickness]-[sv dividerThickness];
			//if (![sv isSubviewCollapsed:fileSplitViewFragSubview])
			//	returnMe += [fileSplitViewFragSubview frame].size.width;
			//returnMe += [sv dividerThickness];
			//if (![sv isSubviewCollapsed:fileSplitviewVertSubview])
			//	returnMe += [fileSplitviewVertSubview frame].size.width;
			//returnMe += [sv dividerThickness];
		}
		return returnMe;
		
		/*
		return 250.0;
		*/
	}
	return proposedMin;
}
/*
- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex	{
	NSLog(@"%s ... %d, %f",__func__,dividerIndex,proposedPosition);
	//NSRectLog(@"\t\tsplitViewPagesSubview frame is",[splitViewPagesSubview frame]);
	//if (splitView==fileSplitView && dividerIndex==1)	{
	//	return fmax(proposedPosition, [splitView frame].size.width-360.);
	//}
	return proposedPosition;
}
*/
- (BOOL)splitView:(NSSplitView *)sv shouldAdjustSizeOfSubview:(NSView *)subview	{
	if (sv == fileSplitView)	{
		if (subview == fileSplitViewJSONSubview)
			return NO;
	}
	return YES;
}


#pragma mark -
#pragma mark NSTextDelegate


- (void)textDidChange:(NSNotification *)notification	{
	//NSLog(@"%s ... %@",__func__,notification);
	if ([notification object]==[fragFileFragaria textView])
		[self fragEditPerformed];
	else if ([notification object]==[vertFileFragaria textView])
		[self vertEditPerformed];
}
- (void)textDidBeginEditing:(NSNotification *)aNotification	{
	//NSLog(@"%s",__func__);
	//[self editPerformed];
}
- (void)textDidEndEditing:(NSNotification *)aNotification	{
	//NSLog(@"%s",__func__);
	//[self editPerformed];
}
- (BOOL)textShouldBeginEditing:(NSText *)aTextObject	{
	return YES;
}
- (BOOL)textShouldEndEditing:(NSText *)aTextObject	{
	return YES;
}
- (void) fragEditPerformed	{
	@synchronized (self)	{
		fragEditsPerformed = YES;
		//	kill the save timer if it exists
		if (tmpFileSaveTimer!=nil)	{
			[tmpFileSaveTimer invalidate];
			tmpFileSaveTimer = nil;
		}
		//	if this file is saved in /tmp/, start a timer to save it in a couple seconds
		if (fragFilePath!=nil && [fragFilePath rangeOfString:@"/tmp/"].location==0)	{
			tmpFileSaveTimer = [NSTimer
				scheduledTimerWithTimeInterval:2.0
				target:self
				selector:@selector(tmpFileSaveTimerProc:)
				userInfo:nil
				repeats:NO];
		}
	}
}
- (void) vertEditPerformed	{
	@synchronized (self)	{
		vertEditsPerformed = YES;
		//	kill the save timer if it exists
		if (tmpFileSaveTimer!=nil)	{
			[tmpFileSaveTimer invalidate];
			tmpFileSaveTimer = nil;
		}
		//	if this file is saved in /tmp/, start a timer to save it in a couple seconds
		if (vertFilePath!=nil && [vertFilePath rangeOfString:@"/tmp/"].location==0)	{
			tmpFileSaveTimer = [NSTimer
				scheduledTimerWithTimeInterval:2.0
				target:self
				selector:@selector(tmpFileSaveTimerProc:)
				userInfo:nil
				repeats:NO];
		}
	}
}
- (void) tmpFileSaveTimerProc:(NSTimer *)t	{
	//NSLog(@"%s",__func__);
	NSString		*currentFragString = [[[fragFileFragaria string] copy] autorelease];
	NSString		*currentVertString = [[[vertFileFragaria string] copy] autorelease];
	@synchronized (self)	{
		tmpFileSaveTimer = nil;
		BOOL			needsToReload = NO;
		if (fragFilePath!=nil && [fragFilePath rangeOfString:@"/tmp/"].location==0)	{
			if (![currentFragString writeToFile:fragFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil])
				NSLog(@"\t\terr: problem writing file to path %@",fragFilePath);
			//else
				//NSLog(@"********************* wrote .fs file to disk C");
			needsToReload = YES;
		}
		if (vertFilePath!=nil && [vertFilePath rangeOfString:@"/tmp/"].location==0)	{
			//NSLog(@"\t\tshould be dumping currentVertString to file %@ in %s",vertFilePath,__func__);
			if (![currentVertString writeToFile:vertFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil])
				NSLog(@"\t\terr: problem writing file to path %@",vertFilePath);
			//else
				//NSLog(@"********************* wrote .vs file to disk C");
			needsToReload = YES;
		}
		if (needsToReload)
			[isfController reloadTargetFile];
	}
}


#pragma mark -
#pragma mark key-val


- (BOOL) contentsNeedToBeSaved	{
	BOOL			returnMe = NO;
	@synchronized (self)	{
		if (fragEditsPerformed)	{
			NSString		*currentContents = [fragFileFragaria string];
			if (currentContents!=nil && [currentContents length]>0)	{
				if (fragFilePathContentsOnOpen==nil || ![fragFilePathContentsOnOpen isEqualToString:currentContents])	{
					returnMe = YES;
				}
			}
		}
		if (vertEditsPerformed)	{
			NSString		*currentContents = [vertFileFragaria string];
			if (currentContents!=nil && [currentContents length]>0)	{
				if (vertFilePathContentsOnOpen==nil || ![vertFilePathContentsOnOpen isEqualToString:currentContents])	{
					returnMe = YES;
				}
			}
		}
	}
	return returnMe;
}


@end

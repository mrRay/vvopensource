//
//	ISFEditorAppDelegate.m
//	ISF Syphon Filter Tester
//
//	Created by bagheera on 11/2/13.
//	Copyright (c) 2013 zoidberg. All rights reserved.
//

#import "ISFEditorAppDelegate.h"
#import "VVMetadataItem.h"
#import <MGSFragaria/MGSFragaria.h>
#import "MGSPreferencesController.h"
#import "AudioController.h"




@implementation ISFEditorAppDelegate


/*===================================================================================*/
#pragma mark --------------------- init/dealloc
/*------------------------------------*/


- (id) init {
	if (self = [super init])	{
		/*
		//	enable the professional video workflow
		if ([VVSysVersion majorSysVersion] >= VVMavericks)	{
			NSLog(@"\t\trunning mavericks or better, enabling decoders");
			VTRegisterProfessionalVideoWorkflowVideoDecoders();
			if ([VVSysVersion majorSysVersion] >= VVYosemite)	{
				NSLog(@"\t\trunning yosemite or better, enabling encoders");
				VTRegisterProfessionalVideoWorkflowVideoEncoders();
			}
		}
		*/
		
		sharedContext = nil;
		syphonServer = nil;
		syphonServerContext = nil;
		lastSourceBuffer = nil;
		outputSource = -1;
		outputFreeze = NO;
		outputDict = nil;
		
		videoSource = nil;
		filterList = [[MutLockArray alloc] init];
		//NSLog(@"\t\tfetchShaders is YES in %s",__func__);
		fetchShaders = YES;
		respondToTableSelectionChanges = YES;
		respondToFileChanges = YES;
		
		//	create the shared context and a buffer pool, set them up
		sharedContext = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:nil];
		VVBufferPool		*bp = [[VVBufferPool alloc] initWithSharedContext:sharedContext pixelFormat:[GLScene defaultPixelFormat] sized:NSMakeSize(640,480)];
		[VVBufferPool setGlobalVVBufferPool:bp];
		
		[QCGLScene prepCommonQCBackendToRenderOnContext:sharedContext pixelFormat:[GLScene defaultPixelFormat]];
		
		syphonServerContext = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:sharedContext];
		syphonServer = [[SyphonServer alloc]
			initWithName:@"ISF Test App"
			context:[syphonServerContext CGLContextObj]
			options:nil];
		
		videoSource = [[DynamicVideoSource alloc] init];
		[videoSource setDelegate:self];
		return self;
	}
	[self release];
	return nil;
}
- (void)dealloc {
	VVRELEASE(lastSourceBuffer);
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- launch setup/teardown
/*------------------------------------*/


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification	{
	
	//	the buffer view, glsl controller, and copy thing need to use the shared context!
	[outputView setSharedGLContext:sharedContext];
	[isfController setSharedGLContext:sharedContext];
	[VVBufferCopier createGlobalVVBufferCopierWithSharedContext:sharedContext];
	
	lastSourceBuffer = [_globalVVBufferPool allocBGRTexSized:NSMakeSize(800,600)];
	[VVBufferCopier class];
	[_globalVVBufferCopier copyBlackFrameToThisBuffer:lastSourceBuffer];
	
	//NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	/*
	//	load the syphon stuff, fake a click on the syphon PUB
	syphonClient = nil;
	syphonLastSelectedName = [def objectForKey:@"syphonLastSelectedName"];
	if (syphonLastSelectedName != nil)
		[syphonLastSelectedName retain];
	[self _reloadSyphonPUB];
	*/
	[self listOfStaticSourcesUpdated:nil];
	
	//	register the table view to receive file drops
	[filterTV registerForDraggedTypes:[NSArray arrayWithObjects: NSFilenamesPboardType,NSURLPboardType,nil]];
	//	if there's a folder from last time in the prefs, restore it now
	[self _loadFilterList];
	//	reload the table view
	[filterTV reloadData];
	
	/*
	//	register for notifications when syphon servers change
	for (NSString *notificationName in [NSArray arrayWithObjects:SyphonServerAnnounceNotification, SyphonServerUpdateNotification, SyphonServerRetireNotification,nil]) {
		[[NSNotificationCenter defaultCenter]
			addObserver:self
			selector:@selector(_syphonServerChangeNotification:)
			name:notificationName
			object:nil];
	}
	*/
	//	i want a quit notification so i can save stuff
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(_appAboutToQuitNotification:)
		name:NSApplicationWillTerminateNotification
		object:nil];
	
	
	//	make the displaylink, which will drive rendering
	CVReturn				err = kCVReturnSuccess;
	CGOpenGLDisplayMask		totalDisplayMask = 0;
	GLint					virtualScreen = 0;
	GLint					displayMask = 0;
	NSOpenGLPixelFormat		*format = [GLScene defaultPixelFormat];
	
	for (virtualScreen=0; virtualScreen<[format numberOfVirtualScreens]; ++virtualScreen)	{
		[format getValues:&displayMask forAttribute:NSOpenGLPFAScreenMask forVirtualScreen:virtualScreen];
		totalDisplayMask |= displayMask;
	}
	err = CVDisplayLinkCreateWithOpenGLDisplayMask(totalDisplayMask, &displayLink);
	if (err)	{
		NSLog(@"\t\terr %d creating display link in %s",err,__func__);
		displayLink = NULL;
	}
	else	{
		CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, self);
		CVDisplayLinkStart(displayLink);
	}
	
	
	//	load the cube array QTZ included with the app so we have a default video source to work with
	[videoSourcePUB selectItemWithTitle:@"Cube Array"];
	[self videoSourcePUBUsed:videoSourcePUB];
	//NSString		*compPath = [[NSBundle mainBundle] pathForResource:@"Cube Array" ofType:@"qtz"];
	//[videoSource loadQCCompAtPath:compPath];
	
	//	we want to check and see if an ISF folder exists at /Library/Graphics/ISF- if it doesn't, we want to run the installer!
	NSFileManager		*fm = [NSFileManager defaultManager];
	BOOL				isDirectory = NO;
	if (![fm fileExistsAtPath:@"/Library/Graphics/ISF" isDirectory:&isDirectory] || !isDirectory)	{
		NSInteger			alertRet = 0;
		alertRet = VVRunAlertPanel(@"Install ISF files?", @"Do you want to install some standard ISF resources on your machine?\n\nYou can install them later from the \"Help\" menu if you decline.", @"Yes", @"No",nil);
		if (alertRet == NSAlertFirstButtonReturn)
			[self installISFMediaFilesUsed:nil];
	}
	
	//	has the ISF editor been updated since it was last launched/is this a "new" vsn of the ISF editor?
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	NSString			*lastVersString = [def objectForKey:@"lastLaunchVersion"];
	NSDictionary		*infoDict = [[NSBundle mainBundle] infoDictionary];
	NSString			*thisVersString = [infoDict objectForKey:@"CFBundleGetInfoString"];
	if (lastVersString==nil		||
	(lastVersString!=nil && thisVersString!=nil && ![lastVersString isEqualToString:thisVersString]))	{
		//	if the ISF quicklook plugin doesn't exist
		if (![fm fileExistsAtPath:@"/Library/QuickLook/ISFQL"])	{
			//	show an alert asking if the user would like to install the ISF quicklook plugin
			NSInteger		alertRet = 0;
			alertRet = VVRunAlertPanel(@"Install ISF QuickLook plugin?", @"Do you want to install a QuickLook plugin that will let you preview ISF files in the Finder?\n\nYou can install it later from the \"Help\" menu if you decline.", @"Yes", @"No", nil);
			if (alertRet == NSAlertFirstButtonReturn)
				[self installISFQuickLookUsed:nil];
		}
		[def setObject:thisVersString forKey:@"lastLaunchVersion"];
		[def synchronize];
	}
}
- (void) _appAboutToQuitNotification:(NSNotification *)note {
	/*
	NSString			*tmpString = nil;
	@synchronized (self)	{
		tmpString = (syphonLastSelectedName==nil) ? nil : [syphonLastSelectedName copy];
	}
	if (tmpString==nil)
		return;
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	[def setObject:tmpString forKey:@"syphonLastSelectedName"];
	*/
}


/*===================================================================================*/
#pragma mark --------------------- callbacks in response to changes
/*------------------------------------*/


- (void) listOfStaticSourcesUpdated:(id)ds	{
	//NSLog(@"%s",__func__);
	//	get the title of the currently-selected item
	NSString		*lastTitle = [videoSourcePUB titleOfSelectedItem];
	//	reload the contents of the pop-up button
	NSMenu			*newMenu = [videoSource allocStaticSourcesMenu];
	[videoSourcePUB setMenu:newMenu];
	[newMenu release];
	newMenu = nil;
	//	try to select an item with the same title as the last-selected item- if i can't, select nil and stop the source
	NSMenuItem		*newLastItem = (lastTitle==nil) ? nil : [videoSourcePUB itemWithTitle:lastTitle];
	if (newLastItem != nil)
		[videoSourcePUB selectItem:newLastItem];
	else	{
		[videoSourcePUB selectItem:nil];
		[videoSource eject];
	}
}
- (void) file:(NSString *)p changed:(u_int)fflag	{
	//NSLog(@"%s ... %@",__func__,p);
	[self _loadFilterList];
	[filterTV reloadData];
	//[self setFetchShaders:YES];
	
	if (![self respondToFileChanges])
		return;
	
	//	if the scene's file is nil, but the controller's target file isn't, tell the scene to reload
	if ([[isfController scene] filePath]==nil && [isfController targetFile]!=nil)	{
		[isfController reloadTargetFile];
		//NSLog(@"\t\tfetchShaders is YES in %s",__func__);
		fetchShaders = YES;
	}
}
- (void) _isfFileReloaded	{
	if (![NSThread isMainThread])	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self _isfFileReloaded];
		});
		return;
	}
	//NSLog(@"%s",__func__);
	NSNumber		*oldRepObj = [[outputSourcePUB selectedItem] representedObject];
	NSMenu			*theMenu = [outputSourcePUB menu];
	NSMenuItem		*tmpItem = nil;
	int				maxPassCount = [[isfController scene] passCount];
	int				imageInputsCount = [[isfController scene] imageInputsCount];
	int				audioInputsCount = [[isfController scene] audioInputsCount];
	//	remove all the items from the existing pop-up button
	[outputSourcePUB removeAllItems];
	//	add an item for the main output
	tmpItem = [[NSMenuItem alloc]
		initWithTitle:@"Main Output"
		action:nil
		keyEquivalent:@""];
	[tmpItem setRepresentedObject:NUMINT(-1)];
	[theMenu addItem:tmpItem];
	[tmpItem release];
	
	if (maxPassCount > 1)	{
		//	add a separator
		[theMenu addItem:[NSMenuItem separatorItem]];
		//	add menu items for the passes
		NSArray			*passTargetNames = [[isfController scene] passTargetNames];
		if (passTargetNames!=nil && [passTargetNames count]!=maxPassCount)
			passTargetNames = nil;
		for (int i=0; i<maxPassCount; ++i)	{
			NSString		*tmpName = (passTargetNames!=nil)
				? [NSString stringWithFormat:@"%d: %@",i,[passTargetNames objectAtIndex:i]]
				: [NSString stringWithFormat:@"PASSINDEX %d",i];
			tmpItem = [[NSMenuItem alloc]
				//initWithTitle:[NSString stringWithFormat:@"Pass %d",i+1]
				//initWithTitle:[NSString stringWithFormat:@"PASSINDEX %d",i]
				initWithTitle:tmpName
				action:nil
				keyEquivalent:@""];
			[tmpItem setRepresentedObject:NUMINT(i)];
			[theMenu addItem:tmpItem];
			[tmpItem release];
			tmpItem = nil;
		}
	}
	if (imageInputsCount > 0)	{
		//	add a separator
		[theMenu addItem:[NSMenuItem separatorItem]];
		//	add menu items for the image inputs
		for (int i=0; i<imageInputsCount; ++i)	{
			ISFAttrib		*attrib = [[[isfController scene] imageInputs] lockObjectAtIndex:i];
			if (attrib != nil)	{
				[attrib retain];
				tmpItem = [[NSMenuItem alloc]
					initWithTitle:[NSString stringWithFormat:@"Image Input \"%@\"",[attrib attribName]]
					action:nil
					keyEquivalent:@""];
				[tmpItem setRepresentedObject:NUMINT(100+i)];
				//[tmpItem setRepresentedObject:[attrib attribName]];
				[theMenu addItem:tmpItem];
				[tmpItem release];
				tmpItem = nil;
				[attrib release];
			}
		}
	}
	if (audioInputsCount > 0)	{
		//	add a separator
		[theMenu addItem:[NSMenuItem separatorItem]];
		//	add menu items for the audio inputs
		for (int i=0; i<audioInputsCount; ++i)	{
			ISFAttrib		*attrib = [[[isfController scene] audioInputs] lockObjectAtIndex:i];
			if (attrib != nil)	{
				[attrib retain];
				tmpItem = [[NSMenuItem alloc]
					initWithTitle:[NSString stringWithFormat:@"Audio Input \"%@\"",[attrib attribName]]
					action:nil
					keyEquivalent:@""];
				[tmpItem setRepresentedObject:NUMINT(200+i)];
				//[tmpItem setRepresentedObject:[attrib attribName]];
				[theMenu addItem:tmpItem];
				[tmpItem release];
				tmpItem = nil;
				[attrib release];
			}
		}
	}
	
	@synchronized (self)	{
		if (oldRepObj==nil || [oldRepObj intValue]==-1)	{
			[outputSourcePUB selectItemAtIndex:0];
			outputSource = -1;
		}
		else	{
			if ([outputSourcePUB numberOfItems]<=([oldRepObj intValue]+2))	{
				[outputSourcePUB selectItemAtIndex:0];
				outputSource = -1;
			}
			else
				[outputSourcePUB selectItemAtIndex:[oldRepObj intValue]+2];
		}
	}
}
- (void) _loadFilterList	{
	//NSLog(@"%s",__func__);
	[VVKQueueCenter removeObserver:self];
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	NSString			*tmpPath = [def objectForKey:@"fxPath"];
	
	
	//NSLog(@"%@",[ISFFileManager imageFiltersForPath:tmpPath]);
	//NSLog(@"%@",[ISFFileManager generativeSourcesForPath:tmpPath recursive:NO]);
	
	[filterList wrlock];
	[filterList removeAllObjects];
	
	NSFileManager		*fm = [NSFileManager defaultManager];
	BOOL				isDirectory = NO;
	if (tmpPath!=nil && [fm fileExistsAtPath:tmpPath isDirectory:&isDirectory] && isDirectory)	{
		[VVKQueueCenter addObserver:self forPath:tmpPath];
		NSArray				*dirContents = [ISFFileManager allFilesForPath:tmpPath recursive:NO];
		[filterList addObjectsFromArray:dirContents];
	}
	
	[filterList unlock];
}


/*===================================================================================*/
#pragma mark --------------------- UI item shit
/*------------------------------------*/


- (IBAction) importFromISFSite:(id)sender	{
	[downloader openModalWindow];
}
- (IBAction) importFromGLSLSandbox:(id)sender	{
	[isfConverter openGLSLSheet];
}
- (IBAction) importFromShadertoy:(id)sender	{
	[isfConverter openShadertoySheet];
}
- (IBAction) openDocument:(id)sender	{
	//NSLog(@"%s",__func__);
	NSUserDefaults	*def = [NSUserDefaults standardUserDefaults];
	NSString		*importDir = [def objectForKey:@"lastOpenDocumentFolder"];
	if (importDir == nil)
		importDir = [@"~/Desktop" stringByExpandingTildeInPath];
	NSString		*importFile = [def objectForKey:@"lastOpenDocumentFile"];
	NSOpenPanel		*op = [[NSOpenPanel openPanel] retain];
	[op setAllowsMultipleSelection:NO];
	[op setCanChooseDirectories:YES];
	[op setResolvesAliases:YES];
	[op setMessage:@"Select and ISF file or folder of ISF files"];
	[op setTitle:@"Open file"];
	//[op setAllowedFileTypes:OBJSARRAY(@"mov",@"mp4",@"mpg",@"qtz","tiff","jpg","jpeg","png")];
	//[op setDirectoryURL:[NSURL fileURLWithPath:importDir]];
	if (importFile != nil)
		[op setDirectoryURL:[NSURL fileURLWithPath:importFile]];
	else
		[op setDirectoryURL:[NSURL fileURLWithPath:importDir]];
	
	[op
		beginSheetModalForWindow:mainWindow
		completionHandler:^(NSInteger result)	{
			if (result == NSFileHandlingPanelOKButton)	{
				//	get the inspected object
				NSArray			*fileURLs = [op URLs];
				NSURL			*urlPtr = (fileURLs==nil) ? nil : [fileURLs objectAtIndex:0];
				NSString		*urlPath = (urlPtr==nil) ? nil : [urlPtr path];
				VVMetadataItem	*mdItem = (urlPath==nil) ? nil : [VVMetadataItem createWithPath:urlPath];
				NSArray			*typeTree = (mdItem==nil) ? nil : [mdItem valueForAttribute:(id)kMDItemContentTypeTree];
				//NSLog(@"\t\ttypeTree is %@",typeTree);
				
				if (typeTree!=nil && [typeTree count]>0)	{
					if ([typeTree containsObject:@"org.khronos.glsl.fragment-shader"])	{
						//[docController listDirectoryAndLoadFile:urlPath];
						[[NSUserDefaults standardUserDefaults] setObject:[urlPath stringByDeletingLastPathComponent] forKey:@"fxPath"];
						[[NSUserDefaults standardUserDefaults] synchronize];
						//	reload the filter list (loads the files from "fxPath" from the user defaults)
						[self _loadFilterList];
						//	reload the table view
						[filterTV reloadData];
						
						NSInteger		fileIndex = [filterList lockIndexOfObject:urlPath];
						if (fileIndex>=0 && fileIndex!=NSNotFound)	{
							[filterTV selectRowIndexes:[NSIndexSet indexSetWithIndex:fileIndex] byExtendingSelection:NO];
						}
						//	make sure that the change in selection is reflected by the backend!
						[self tableViewSelectionDidChange:nil];
					}
					else if ([typeTree containsObject:@"public.folder"])	{
						//[docController listDirectory:urlPath];
						[[NSUserDefaults standardUserDefaults] setObject:urlPath forKey:@"fxPath"];
						[[NSUserDefaults standardUserDefaults] synchronize];
						//	reload the filter list (loads the files from "fxPath" from the user defaults)
						[self _loadFilterList];
						//	reload the table view
						[filterTV reloadData];
						
						//	tell the table view to select the item at the dst index
						[filterTV deselectAll:nil];
						//	make sure that the change in selection is reflected by the backend!
						[self tableViewSelectionDidChange:nil];
					}
					else
						NSLog(@"\t\terr: unrecognized type tree in %s for item \"%@\": %@",__func__,urlPath,typeTree);
				}
				
				//	update the defaults so i know where the law directory i browsed was
				NSString		*directoryString = [urlPath stringByDeletingLastPathComponent];
				[[NSUserDefaults standardUserDefaults] setObject:directoryString forKey:@"lastOpenDocumentFolder"];
				[[NSUserDefaults standardUserDefaults] setObject:urlPath forKey:@"lastOpenDocumentFile"];
				[[NSUserDefaults standardUserDefaults] synchronize];
			}
		}];
	VVRELEASE(op);
}
- (IBAction) openMediaDocument:(id)sender	{
	NSUserDefaults	*def = [NSUserDefaults standardUserDefaults];
	NSString		*importDir = [def objectForKey:@"lastOpenMediaDocumentFolder"];
	if (importDir == nil)
		importDir = [@"~/Desktop" stringByExpandingTildeInPath];
	NSString		*importFile = [def objectForKey:@"lastOpenMediaDocumentFile"];
	NSOpenPanel		*op = [[NSOpenPanel openPanel] retain];
	[op setAllowsMultipleSelection:NO];
	[op setCanChooseDirectories:NO];
	[op setResolvesAliases:YES];
	[op setMessage:@"Select a movie, image file, or QC composition to open"];
	[op setTitle:@"Open file"];
	//[op setAllowedFileTypes:OBJSARRAY(@"mov",@"mp4",@"mpg",@"qtz","tiff","jpg","jpeg","png")];
	//[op setDirectoryURL:[NSURL fileURLWithPath:importDir]];
	if (importFile != nil)
		[op setDirectoryURL:[NSURL fileURLWithPath:importFile]];
	else
		[op setDirectoryURL:[NSURL fileURLWithPath:importDir]];
	
	[op
		beginSheetModalForWindow:mainWindow
		completionHandler:^(NSInteger result)	{
			if (result == NSFileHandlingPanelOKButton)	{
				//	get the inspected object
				NSArray			*fileURLs = [op URLs];
				NSURL			*urlPtr = (fileURLs==nil) ? nil : [fileURLs objectAtIndex:0];
				NSString		*urlPath = (urlPtr==nil) ? nil : [urlPtr path];
				VVMetadataItem	*mdItem = (urlPath==nil) ? nil : [VVMetadataItem createWithPath:urlPath];
				NSArray			*typeTree = (mdItem==nil) ? nil : [mdItem valueForAttribute:(id)kMDItemContentTypeTree];
				if (typeTree!=nil && [typeTree count]>0)	{
					if ([typeTree containsObject:@"public.movie"])
						[videoSource loadMovieAtPath:urlPath];
					else if ([typeTree containsObject:@"com.apple.quartz-composer-composition"])
						[videoSource loadQCCompAtPath:urlPath];
					else if ([typeTree containsObject:@"public.image"])
						[videoSource loadImgAtPath:urlPath];
					else
						NSLog(@"\t\terr: unrecognized type tree in %s for item \"%@\": %@",__func__,urlPath,typeTree);
				}
				
				//	update the defaults so i know where the law directory i browsed was
				NSString		*directoryString = [urlPath stringByDeletingLastPathComponent];
				[[NSUserDefaults standardUserDefaults] setObject:directoryString forKey:@"lastOpenMediaDocumentFolder"];
				[[NSUserDefaults standardUserDefaults] setObject:urlPath forKey:@"lastOpenMediaDocumentFile"];
				[[NSUserDefaults standardUserDefaults] synchronize];
			}
		}];
	VVRELEASE(op);
}
- (IBAction) saveDocument:(id)sender	{
	//NSLog(@"%s",__func__);
	[docController saveOpenFile];
}
- (IBAction) newDocument:(id)sender	{
	//NSLog(@"%s",__func__);
	[docController createNewFile];
	[isfController loadFile:@"/tmp/ISFTesterTmpFile.fs"];
}
- (IBAction)showPreferencesWindow:(id)sender	{
	[[MGSPreferencesController sharedPrefsWindowController] showWindow:self];
}
- (IBAction) openSystemISFFolderClicked:(id)sender	{
	NSFileManager	*fm = [NSFileManager defaultManager];
	NSURL			*fileURL = [NSURL fileURLWithPath:@"/Library/Graphics/ISF/"];
	if (![fm fileExistsAtPath:[fileURL path] isDirectory:nil])	{
		[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:OBJARRAY(fileURL)];
	}
}
- (IBAction) loadUserISFsClicked:(id)sender	{
	
	NSString			*tmpPath = [@"~/Library/Graphics/ISF/" stringByExpandingTildeInPath];
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	[def setObject:tmpPath forKey:@"fxPath"];
	[def synchronize];
	
	//	if the path doesn't exist, create it
	NSFileManager	*fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:tmpPath isDirectory:nil])	{
		//NSLog(@"\t\tfolder %@ doesn't exist yet, needs to be created...",tmpPath);
		NSError			*nsErr = nil;
		if (![fm createDirectoryAtPath:tmpPath withIntermediateDirectories:YES attributes:nil error:&nsErr])	{
			NSLog(@"\t\terr creating directory for path %@",tmpPath);
			NSLog(@"\t\terr was %@",nsErr);
		}
		//else
		//	NSLog(@"\t\tfolder %@ successfully created",tmpPath);
	}
	
	//	reload the filter list (loads the files from "fxPath" from the user defaults)
	[self _loadFilterList];
	
	//	reload the table view
	[filterTV reloadData];
	//	tell the table view to select the item at the dst index
	[filterTV deselectAll:nil];
	//	make sure that the change in selection is reflected by the backend!
	[self tableViewSelectionDidChange:nil];
}
- (IBAction) loadSystemISFsClicked:(id)sender	{
	NSString			*tmpPath = @"/Library/Graphics/ISF/";
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	[def setObject:tmpPath forKey:@"fxPath"];
	[def synchronize];
	
	//	reload the filter list (loads the files from "fxPath" from the user defaults)
	[self _loadFilterList];
	
	//	reload the table view
	[filterTV reloadData];
	//	tell the table view to select the item at the dst index
	[filterTV deselectAll:nil];
	//	make sure that the change in selection is reflected by the backend!
	[self tableViewSelectionDidChange:nil];
}
- (IBAction) outputSourcePUBUsed:(id)sender	{
	NSMenuItem		*selectedItem = [outputSourcePUB selectedItem];
	id				repObj = [selectedItem representedObject];
	@synchronized (self)	{
		if (repObj != nil)	{
			if ([repObj isKindOfClass:[NSNumber class]])	{
				outputSource = [(NSNumber *)repObj intValue];
				//NSLog(@"\t\toutputSource is %d",outputSource);
			}
			/*
			else if ([repObj isKindOfClass:[NSString class]])	{
				ISFAttrib		*attrib = [[isfController scene] attribForInputWithKey:repObj];
				outputSource = 100+[[[isfController scene] imageInputs] lockIndexOfIdenticalPtr:attrib];
			}
			*/
		}
	}
	
	
	/*
	NSMenuItem		*selectedItem = [outputSourcePUB selectedItem];
	NSNumber		*representedNum = [selectedItem representedObject];
	@synchronized (self)	{
		if (representedNum!=nil && [representedNum isKindOfClass:[NSNumber class]])	{
			outputSource = [representedNum intValue];
			//NSLog(@"\t\toutputSource is now %ld",outputSource);
		}
	}
	*/
}
- (IBAction) outputFreezeToggleUsed:(id)sender	{
	@synchronized (self)	{
		outputFreeze = ([sender intValue]!=NSOnState) ? NO : YES;
	}
}
- (IBAction) outputShowAlphaToggleUsed:(id)sender	{
	@synchronized (self)	{
		ISFGLScene		*scene = [outputView localISFScene];
		if (scene != nil)	{
			[scene
				setNSObjectVal:([sender intValue]==NSOnState) ? NUMBOOL(YES) : NUMBOOL(NO)
				forInputKey:@"viewAlpha"];
		}
	}
}
/*
- (IBAction) syphonPUBUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	
	
	int				selectedIndex = [syphonPUB indexOfSelectedItem];
	NSMenuItem		*selectedItem = [syphonPUB selectedItem];
	if (selectedItem!=nil && selectedIndex>0 && selectedIndex!=NSNotFound)	{
		@synchronized (self)	{
			if (syphonLastSelectedName!=nil)
				[syphonLastSelectedName release];
			syphonLastSelectedName = [[selectedItem title] retain];
		}
		
		NSDictionary		*serverDict = [selectedItem representedObject];
		@synchronized (self)	{
			if (syphonClient != nil)
				[syphonClient release];
			syphonClient = nil;
			if (serverDict != nil)	{
				syphonClient = [[SyphonClient alloc]
					initWithServerDescription:serverDict
					options:nil
					newFrameHandler:nil];
			}
		}
	}
	else	{
		if (syphonClient != nil)	{
			[syphonClient release];
			syphonClient = nil;
		}
	}
}
*/
- (IBAction) videoSourcePUBUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	NSMenuItem		*selectedItem = [videoSourcePUB selectedItem];
	id				repObj = [selectedItem representedObject];
	@synchronized (self)	{
		if (repObj != nil)	{
			//NSLog(@"\t\trepresentedObject is \"%@\"",(id)repObj);
			if ([repObj isKindOfClass:[NSURL class]])	{
				[videoSource loadQCCompAtPath:(NSString *)[repObj path]];
			}
			else if ([repObj isKindOfClass:[NSString class]])	{
				[videoSource loadVidInWithUniqueID:repObj];
			}
			else if ([repObj isKindOfClass:[NSDictionary class]])	{
				[videoSource loadSyphonServerWithDescription:repObj];
			}
		}
	}
}
- (IBAction) installISFMediaFilesUsed:(id)sender	{
	NSTask			*task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/open"];
	NSString		*installerPath = [[NSBundle mainBundle] pathForResource:@"Vidvox ISF resources" ofType:@"pkg"];
	if (installerPath != nil)	{
		[task setArguments:[NSArray arrayWithObject:installerPath]];
		[task launch];
	}
	[task autorelease];
}
- (IBAction) installISFQuickLookUsed:(id)sender	{
	NSTask			*task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/open"];
	NSString		*installerPath = [[NSBundle mainBundle] pathForResource:@"ISF QuickLook Plugin" ofType:@"pkg"];
	if (installerPath != nil)	{
		[task setArguments:[NSArray arrayWithObject:installerPath]];
		[task launch];
	}
	[task autorelease];
}


/*
- (void) _syphonServerChangeNotification:(NSNotification *)note {
	//NSLog(@"%s",__func__);
	[self _reloadSyphonPUB];
}
- (void) _reloadSyphonPUB	{
	//NSLog(@"%s",__func__);
	//	first reload the pop up button
	SyphonServerDirectory	*sd = [SyphonServerDirectory sharedDirectory];
	NSArray		*servers = (sd==nil) ? nil : [sd servers];
	if (servers!=nil)	{
		NSMenu		*pubMenu = [syphonPUB menu];
		[pubMenu removeAllItems];
		[pubMenu addItemWithTitle:@"-" action:nil keyEquivalent:@""];
		for (NSDictionary *serverDict in servers)	{
			NSString		*serverName = [NSString stringWithFormat:@"%@-%@",[serverDict objectForKey:SyphonServerDescriptionAppNameKey],[serverDict objectForKey:SyphonServerDescriptionNameKey]];
			NSMenuItem		*serverItem = [[NSMenuItem alloc]
				initWithTitle:serverName
				action:nil
				keyEquivalent:@""];
			[serverItem setEnabled:YES];
			[serverItem setRepresentedObject:[[serverDict copy] autorelease]];
			[pubMenu addItem:serverItem];
		}
	}
	//	try to select the last-selected syphon server
	NSString		*tmpString = nil;
	@synchronized (self)	{
		tmpString = (syphonLastSelectedName==nil) ? nil : [syphonLastSelectedName retain];
	}
	if (tmpString==nil)
		[syphonPUB selectItemAtIndex:0];
	else	{
		[syphonPUB selectItemWithTitle:tmpString];
		[tmpString release];
		tmpString = nil;
	}
	[self syphonPUBUsed:syphonPUB];
}
*/


/*===================================================================================*/
#pragma mark --------------------- rendering
/*------------------------------------*/


- (void) _renderCallback	{
	//NSLog(@"%s",__func__);
	
	//	tell the audio controller to task
	[_globalAudioController updateAudioResults];
	
	//	get a frame from syphon
	//VVBuffer			*syphonBuffer = nil;
	VVBuffer			*buffer2d = nil;
	VVBuffer			*outBuffer = nil;
	//BOOL				use2D = ([textureToggle intValue]==NSOnState) ? YES : NO;
	NSUInteger			textureMatrixVal = (textureMatrix==nil) ? 0 : [textureMatrix selectedRow];
	NSMutableDictionary		*newOutDict = MUTDICT;
	int					localOutputSource = -1;
	BOOL				localOutputFreeze = NO;
	
	@synchronized (self)	{
		if (videoSource!=nil)	{
			VVRELEASE(lastSourceBuffer);
			lastSourceBuffer = [videoSource allocBuffer];
		}
		/*
		if (syphonClient!=nil && [syphonClient hasNewFrame])	{
			syphonBuffer = [_globalVVBufferPool allocBufferForSyphonClient:syphonClient];
			VVRELEASE(lastSourceBuffer);
			lastSourceBuffer = [syphonBuffer retain];
		}
		*/
		localOutputSource = outputSource;
		localOutputFreeze = outputFreeze;
	}
	
	if (lastSourceBuffer != nil)	{
		@try	{
			//	this bit here makes a GL_TEXTURE_2D-based buffer and copies the syphon image into it
			/*
			if (use2D)	{
				buffer2d = [_globalVVBufferPool allocBGR2DPOTTexSized:[lastSourceBuffer srcRect].size];
				[_globalVVBufferCopier ignoreSizeCopyThisBuffer:lastSourceBuffer toThisBuffer:buffer2d];
				[buffer2d setSrcRect:[lastSourceBuffer srcRect]];
			}
			*/
			//NSLog(@"\t\tlastSourceBuffer is %@",lastSourceBuffer);
			VVBuffer		*srcBuffer = nil;
			if (lastSourceBuffer!=nil)	{
				switch (textureMatrixVal)	{
				case 0:	//	nothing specified/rect
					//NSLog(@"\t\ttexture mode is rect");
					if ([lastSourceBuffer target]!=GL_TEXTURE_RECTANGLE_EXT)	{
						srcBuffer = [_globalVVBufferPool allocBGRTexSized:[lastSourceBuffer srcRect].size];
						[_globalVVBufferCopier ignoreSizeCopyThisBuffer:lastSourceBuffer toThisBuffer:srcBuffer];
						[srcBuffer setSrcRect:[lastSourceBuffer srcRect]];
						//NSLog(@"\t\tsrcBuffer is %@",srcBuffer);
					}
					else
						srcBuffer = [lastSourceBuffer retain];
					break;
				case 1:	//	2D
					//NSLog(@"\t\ttexture mode is 2D");
					if (![lastSourceBuffer isPOT2DTex])	{
						srcBuffer = [_globalVVBufferPool allocBGR2DPOTTexSized:[lastSourceBuffer srcRect].size];
						[_globalVVBufferCopier ignoreSizeCopyThisBuffer:lastSourceBuffer toThisBuffer:srcBuffer];
						[srcBuffer setSrcRect:[lastSourceBuffer srcRect]];
						//NSLog(@"\t\tsrcBuffer is %@",srcBuffer);
					}
					else
						srcBuffer = [lastSourceBuffer retain];
					break;
				case 2:	//	NPOT 2D
					//NSLog(@"\t\ttexture mode is NPOT 2D");
					if (![lastSourceBuffer isNPOT2DTex])	{
						srcBuffer = [_globalVVBufferPool allocBGR2DTexSized:[lastSourceBuffer srcRect].size];
						[_globalVVBufferCopier ignoreSizeCopyThisBuffer:lastSourceBuffer toThisBuffer:srcBuffer];
						[srcBuffer setSrcRect:[lastSourceBuffer srcRect]];
						//NSLog(@"\t\tsrcBuffer is %@",srcBuffer);
					}
					else
						srcBuffer = [lastSourceBuffer retain];
					break;
				}
			}
			
			outBuffer = [isfController renderFXOnThisBuffer:srcBuffer passDict:newOutDict];
			
			@synchronized (self)	{
				if (fetchShaders)	{
					NSString				*tmpString = nil;
					NSMutableDictionary		*contentDict = MUTDICT;
					
					tmpString = [[isfController scene] jsonString];
					if (tmpString!=nil)
						[contentDict setObject:tmpString forKey:@"json"];
					tmpString = [[isfController scene] vertexShaderString];
					if (tmpString!=nil)
						[contentDict setObject:tmpString forKey:@"vertex"];
					tmpString = [[isfController scene] fragmentShaderString];
					if (tmpString!=nil)
						[contentDict setObject:tmpString forKey:@"fragment"];
					
					//	we only want to proceed if we have a json/vert/frag shader (if we don't, we need to try again later)
					if ([contentDict count]==3)	{
						NSMutableArray	*syntaxErrArray = [self createSyntaxErrorsForForbiddenTermsInRawISFFile];
						NSArray			*origSyntaxErrArray = [contentDict objectForKey:@"syntaxErr"];
						if (origSyntaxErrArray!=nil && [origSyntaxErrArray count]>0)	{
							if (syntaxErrArray == nil)
								syntaxErrArray = MUTARRAY;
							[syntaxErrArray addObjectsFromArray:origSyntaxErrArray];
						}
						NSLog(@"\t\tsyntaxErrArray is %@",syntaxErrArray);
						if (syntaxErrArray != nil && [syntaxErrArray count]>0)
							[contentDict setObject:syntaxErrArray forKey:@"syntaxErr"];
						
						/*
						//	run through the raw frag shader string, looking for "forbidden" terms (texture2D, texture2DRect, sampler2D, sampler2DRect), and creating errors for them
						NSArray			*forbiddenTerms = @[@"texture2DRectProjLod",@"texture2DRectProj",@"texture2DRect",@"texture2DProjLod",@"texture2DProj",@"texture2D",@"sampler2DRect",@"sampler2D"];
						NSString		*forbiddenTermsRegex = @"((texture2D(Rect)?(Proj)?(Lod)?)|(sampler2D(Rect)?))";
						NSString		*precompiledFragSrc = [[isfController scene] fragShaderSource];
						NSString		*jsonSrc = [[isfController scene] jsonSource];
						//NSInteger		lineDelta = [jsonSrc numberOfLines];
						__block NSInteger	lineIndex = [jsonSrc numberOfLines] + 1;
						NSMutableArray	*syntaxErrArray = MUTARRAY;
						//	run through all the lines in the precompiled shader
						[precompiledFragSrc enumerateLinesUsingBlock:^(NSString *line, BOOL *stop)	{
							//	if the line matches the 'forbidden terms' regex...
							if ([line isMatchedByRegex:forbiddenTermsRegex])	{
								//	run through all the forbidden terms to figure out which one is in the line
								for (NSString *forbiddenTerm in forbiddenTerms)	{
									if ([line containsString:forbiddenTerm])	{
										//	make a syntax error, add it to the array
										SMLSyntaxError	*err = [[[SMLSyntaxError alloc] init] autorelease];
										[err setLine:(int)lineIndex];
										[err setCharacter:0];
										[err setCode:forbiddenTerm];
										[err setDescription:VVFMTSTRING(@"Warning: \'%@\' may not always work!",forbiddenTerm)];
										[err setLength:1];
										[syntaxErrArray addObject:err];
									
										break;
									}
								}
							}
							++lineIndex;
						}];
						//	if there are syntax errors, add the array of errors to the content dict
						if ([syntaxErrArray count]>0)
							[contentDict setObject:syntaxErrArray forKey:@"syntaxErr"];
						*/
					
					
						//NSLog(@"\t\tfetching shaders- loading non-file content dict %p in %s",contentDict,__func__);
						dispatch_async(dispatch_get_main_queue(), ^{
							[docController loadNonFileContentDict:contentDict];
						});
					
						//NSLog(@"\t\tfetchShaders is NO in %s",__func__);
						fetchShaders = NO;
					}
				}
				
				//	if the local output isn't frozen, update the output dict
				if (!localOutputFreeze)	{
					VVRELEASE(outputDict);
					outputDict = [newOutDict retain];
				}
				//	else the output's frozen- get rid of the new output dict, use the old one
				else	{
					[newOutDict removeAllObjects];
					newOutDict = outputDict;
				}
			}
			
			
			//NSLog(@"\t\tlocalOutputSource is %d",localOutputSource);
			//NSLog(@"\t\tnewOutDict is %@",newOutDict);
			VVBuffer		*displayBuffer = [newOutDict objectForKey:NUMINT(localOutputSource)];
			//NSLog(@"\t\tdisplayBuffer is %@",displayBuffer);
			if (displayBuffer==nil)	{
				//NSLog(@"\t\terr: displayBuffer was nil, localOutputSource was %d dict was %@",localOutputSource,newOutDict);
				displayBuffer = srcBuffer;
			}
			[outputView drawBuffer:displayBuffer];
			/*
			[outputView drawBuffer:(outBuffer!=nil) ? outBuffer : ((use2D) ? buffer2d : lastSourceBuffer)];
			*/
			NSSize			bufferSize = [displayBuffer srcRect].size;
			NSString		*resString = VVFMTSTRING(@"%d x %d",(int)bufferSize.width,(int)bufferSize.height);
			NSString		*currentResString = [outputResLabel stringValue];
			if (currentResString==nil || ![currentResString isEqualToString:resString])	{
				//dispatch_async(dispatch_get_main_queue(), ^{
					[outputResLabel setStringValue:resString];
				//});
			}
			
			//	pass the rendered frame to the syphon server
			if (syphonServer!=nil)	{
				VVBuffer		*preFXBuffer = srcBuffer;
				if (outBuffer!=nil)	{
					[syphonServer
						publishFrameTexture:[outBuffer name]
						textureTarget:[outBuffer target]
						imageRegion:[outBuffer srcRect]
						textureDimensions:[outBuffer size]
						flipped:[outBuffer flipped]];
				}
				else if (preFXBuffer!=nil)	{
					[syphonServer
						publishFrameTexture:[preFXBuffer name]
						textureTarget:[preFXBuffer target]
						imageRegion:[preFXBuffer srcRect]
						textureDimensions:[preFXBuffer size]
						flipped:[preFXBuffer flipped]];
				}
			}
			
			VVRELEASE(srcBuffer);
		}
		@catch (NSException *err)	{
			NSLog(@"\t\t%scaught exception %@",__func__,err);
			@synchronized (self)	{
				//NSLog(@"\t\tfetchShaders is NO in %s",__func__);
				fetchShaders = NO;
			}
			//dispatch_async(dispatch_get_main_queue(), ^{
				//	assemble a dictionary (contentDict) that describes the error
				NSMutableDictionary		*contentDict = MUTDICT;
				NSString				*reason = [err name];
				NSMutableString			*errString = [NSMutableString stringWithCapacity:0];
				__block NSMutableArray	*syntaxErrorArray = MUTARRAY;
				[errString appendString:@""];
				if ([reason isEqualToString:@"Shader Problem"])	{
					NSDictionary		*userInfo = [err userInfo];
					NSString			*tmpLog = nil;
					tmpLog = (userInfo==nil) ? nil : [userInfo objectForKey:@"linkErrLog"];
					if (tmpLog!=nil)
						[errString appendFormat:@"OpenGL link error:\n%@",tmpLog];
					
					
					//	this block parses a passed string, locates a specific number value, and adds to it the passed "_lineDelta" value.  used to locate and change GLSL error logs.  if _syntaxErrArray is non-nil, SMLSyntaxErrors will be created and added to it.
					NSString*	(^glslErrLogLineNumberChanger)(NSString *_lineIn, NSInteger _lineDelta, NSMutableArray *_syntaxErrArray) = ^(NSString *_lineIn, NSInteger _lineDelta, NSMutableArray *_syntaxErrArray)	{
						NSString		*returnMe = nil;
						NSString		*regexString = @"([0-9]+[\\W])([0-9]+)";
						NSRange			regexRange = [_lineIn rangeOfRegex:regexString];
						//	if this line doesn't match the regex string, just append it
						if (regexRange.location==NSNotFound || regexRange.length<1)	{
							returnMe = _lineIn;
						}
						//	else this line contains the numbers i want to modify, replace them
						else	{
							//	capture the vals i want
							NSArray			*capturedValsArray = [_lineIn captureComponentsMatchedByRegex:regexString];
							//NSLog(@"\t\tcapturedValsArray is %@",capturedValsArray);
							//	if i couldn't capture the numbers i want, just append the whole line
							if (capturedValsArray==nil || [capturedValsArray count]!=3)	{
								NSLog(@"\t\terr: capturedValsArray didn't have the correct number of elements, unable to correct line numbers in %s",__func__);
								returnMe = _lineIn;
							}
							//	else i captured vals- time to put together the new line!
							else	{
								//	first, copy everything in the line *before* the regex
								//[errString appendString:[_lineIn substringToIndex:regexRange.location]];
								//	now copy the first thing i captured (index 1 in the array)- this is presumably the file number
								//[errString appendString:[capturedValsArray objectAtIndex:1]];
								//	the second thing i captured (index 2 in the array) is the line number- modify it, then add it to the string
								//[errString appendFormat:@"%d",[[[capturedValsArray objectAtIndex:2] numberByEvaluatingString] intValue] + _lineDelta];
								//	copy everything in the line *after* the regex
								//[errString appendString:[_lineIn substringFromIndex:regexRange.location+regexRange.length]];
								
								//	...this is all of the above in one line
								returnMe = VVFMTSTRING(@"%@%@%ld%@",[_lineIn substringToIndex:regexRange.location],[capturedValsArray objectAtIndex:1],([[[capturedValsArray objectAtIndex:2] numberByEvaluatingString] intValue] + _lineDelta),[_lineIn substringFromIndex:regexRange.location+regexRange.length]);
								
								//	if i was passed a syntax error array to populate, create a syntax error and add it to the array
								if (_syntaxErrArray!=nil)	{
									SMLSyntaxError		*err = [[[SMLSyntaxError alloc] init] autorelease];
									[err setLine:[[[capturedValsArray objectAtIndex:2] numberByEvaluatingString] intValue] + (int)_lineDelta];
									[err setCharacter:0];
									//[err setCode:@"CodeString"];
									[err setCode:[_lineIn substringFromIndex:regexRange.location+regexRange.length]];
									[err setDescription:[_lineIn substringFromIndex:regexRange.location+regexRange.length]];
									[err setLength:1];
									[_syntaxErrArray addObject:err];
								}
							}
						}
						return returnMe;
					};
					
					
					
					//	if there's a vertex error log, parse it line-by-line, adjusting the line numbers to compensate for changes to the shader
					tmpLog = (userInfo==nil) ? nil : [userInfo objectForKey:@"vertErrLog"];
					if (tmpLog!=nil)	{
						[errString appendString:@"OpenGL vertex shader error:\n"];
						//	figure out the difference in line numbers between the compiled vert shader and the raw ISF file
						NSInteger		lineDelta = 0;
						NSString		*compiledVertSrc = [userInfo objectForKey:@"vertSrc"];
						NSString		*precompiledVertSrc = [[isfController scene] vertShaderSource];
						if (compiledVertSrc!=nil && precompiledVertSrc!=nil)	{
							//	the compiled vertex shader has stuff added to both the beginning and the end- the first line added to the end of the raw vertex shader source is:
							NSString			*firstLineAppendedToVS = @"\nvoid vv_vertShaderInit(void)\t{";
							NSRange				rangeOfEndOfVS = [compiledVertSrc rangeOfString:firstLineAppendedToVS];
							if (rangeOfEndOfVS.location==NSNotFound || rangeOfEndOfVS.length!=[firstLineAppendedToVS length])	{
								NSLog(@"\t\tERR: couldn't locate end of precompiled shader in compiled vertex shader, %s",__func__);
								lineDelta = 0;
							}
							else	{
								NSInteger			numberOfLinesAppendedToVS = [[compiledVertSrc substringFromIndex:rangeOfEndOfVS.location] numberOfLines];
								lineDelta = [precompiledVertSrc numberOfLines] - ([compiledVertSrc numberOfLines]-numberOfLinesAppendedToVS);
							}
						}
						//	if there's no difference in line numbers, just copy the error log in its entirety
						if (lineDelta==0)	{
							[errString appendString:tmpLog];
						}
						//	else there's a difference in line numbers, run through each line of the log- i'm looking for line numbers to replace
						else	{
							[tmpLog enumerateLinesUsingBlock:^(NSString *line, BOOL *stop)	{
								//	run the block that changes the line numbers for the glsl error log
								[errString appendString:glslErrLogLineNumberChanger(line, lineDelta, nil)];
								//	always append a newline!
								[errString appendString:@"\n"];
							}];
						}
						
						/*
						[errString appendFormat:@"OpenGL vertex shader error:\n%@",tmpLog];
						*/
					}
					
					//	if there's a fragment error log, parse it line-by-line, adjusting the line numbers to compensate for changes to the shader
					tmpLog = (userInfo==nil) ? nil : [userInfo objectForKey:@"fragErrLog"];
					if (tmpLog!=nil)	{
						[errString appendString:@"OpenGL fragment shader error:\n"];
						//	figure out the difference in line numbers between the compiled frag shader and the raw ISF file
						NSInteger		lineDelta = 0;
						NSString		*compiledFragSrc = [userInfo objectForKey:@"fragSrc"];
						NSString		*precompiledFragSrc = [[isfController scene] fragShaderSource];
						NSString		*jsonSrc = [[isfController scene] jsonSource];
						if (compiledFragSrc!=nil && precompiledFragSrc!=nil && jsonSrc!=nil)	{
							lineDelta = ([precompiledFragSrc numberOfLines]+[jsonSrc numberOfLines]) - [compiledFragSrc numberOfLines];
						}
						//	if there's no difference in line numbers, just copy the error log in its entirety
						if (lineDelta==0)	{
							[errString appendString:tmpLog];
						}
						//	else there's a difference in line numbers, run through each line of the log- i'm looking for line numbers to replace
						else	{
							[tmpLog enumerateLinesUsingBlock:^(NSString *line, BOOL *stop)	{
								//	run the block that changes the line numbers for the glsl error log
								[errString appendString:glslErrLogLineNumberChanger(line, lineDelta, syntaxErrorArray)];
								//	always append a newline!
								[errString appendString:@"\n"];
							}];
						}
					}
				}
				else	{
					[errString appendFormat:@"%@-%@",[err name],[err reason]];
				}
				[contentDict setObject:errString forKey:@"error"];
				
				//[contentDict setObject:syntaxErrorArray forKey:@"syntaxErr"];
				NSArray			*origSyntaxErrArray = [contentDict objectForKey:@"syntaxErr"];
				if (origSyntaxErrArray!=nil && [origSyntaxErrArray count]>0)	{
					[syntaxErrorArray addObjectsFromArray:origSyntaxErrArray];
				}
				if (syntaxErrorArray != nil)
					[contentDict setObject:syntaxErrorArray forKey:@"syntaxErr"];
				
				
				//	populate contentDict with the source code compiled and in use by the GL scene
				NSString		*tmpString = nil;
				
				tmpString = [[isfController scene] jsonString];
				if (tmpString==nil)
					tmpString = @"";
				[contentDict setObject:tmpString forKey:@"json"];
				
				tmpString = [[isfController scene] vertexShaderString];
				if (tmpString == nil)
					tmpString = @"";
				[contentDict setObject:tmpString forKey:@"vertex"];
				
				tmpString = [[isfController scene] fragmentShaderString];
				if (tmpString == nil)
					tmpString = @"";
				[contentDict setObject:tmpString forKey:@"fragment"];
				
				
				//	kill stuff so i don't keep displaying the error...
				[isfController loadFile:nil];
				
				
				NSLog(@"\t\tcaught exception: loading non-file content dict %p in %s",contentDict,__func__);
				//	tell the doc controller to load the dict of error stuff i assembled
				dispatch_async(dispatch_get_main_queue(), ^{
					[docController loadNonFileContentDict:contentDict];
				});
				
				
			//});
			
		}
		
		
		
		
		
		
		VVRELEASE(outBuffer);
		VVRELEASE(buffer2d);
		//VVRELEASE(syphonCopy);
		//VVRELEASE(syphonBuffer);
		
	}
	[_globalVVBufferPool housekeeping];
}
//	used to render for recording
- (void) renderIntoBuffer:(VVBuffer *)b atTime:(double)t	{
	if (b==nil)
		return;
	[isfController renderIntoBuffer:b atTime:t];
}


/*===================================================================================*/
#pragma mark --------------------- misc
/*------------------------------------*/


- (void) exportCompleteSelectFileAtPath:(NSString *)p	{
	//NSLog(@"%s ... %@",__func__,p);
	if (p==nil)
		return;
	NSFileManager		*fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:p isDirectory:nil])	{
		NSLog(@"\t\terr: bailing in %s, file doesn't exist at path %@",__func__,p);
		return;
	}
	//	i don't want the table selection to change anything during this
	[self setRespondToTableSelectionChanges:NO];
	[self setRespondToFileChanges:NO];
	
	//	i need to figure out if selecting this file requires me to change the "fxPath" (the list of files displayed), and reload the list of filters
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	NSString			*currentFXPath = [def objectForKey:@"fxPath"];
	NSString			*newFXPath = [p stringByDeletingLastPathComponent];
	BOOL				fxPathNeedsChanging = NO;
	if (currentFXPath==nil || ![currentFXPath isEqualToString:newFXPath])	{
		fxPathNeedsChanging = YES;
		[def setObject:newFXPath forKey:@"fxPath"];
		[def synchronize];
		[self _loadFilterList];
		[filterTV reloadData];
	}
	//	figure out which filter i want to select, then select it
	NSInteger			filterIndex = [filterList lockIndexOfObject:p];
	if (filterIndex<0 || filterIndex==NSNotFound)	{
		NSLog(@"\t\terr: %s, souldn't find filter %@ in filterList %@",__func__,p,filterList);
		[self setRespondToTableSelectionChanges:YES];
		[self setRespondToFileChanges:YES];
		return;
	}
	[filterTV selectRowIndexes:[NSIndexSet indexSetWithIndex:filterIndex] byExtendingSelection:NO];
	[self setRespondToTableSelectionChanges:YES];
	[self setRespondToFileChanges:YES];
	[self tableViewSelectionDidChange:nil];
}
- (void) reloadSelectedISF	{
	//NSLog(@"%s",__func__);
	[isfController reloadTargetFile];
}
- (NSString *) targetFile	{
	NSString		*returnMe = nil;
	returnMe = [isfController targetFile];
	return returnMe;
}
- (void) setFetchShaders:(BOOL)n	{
	@synchronized (self)	{
		fetchShaders = n;
		//if (fetchShaders)
		//	NSLog(@"\t\tfetchShaders is YES in %s",__func__);
		//else
		//	NSLog(@"\t\tfetchShaders is NO in %s",__func__);
	}
}
- (BOOL) fetchShaders	{
	BOOL		returnMe = NO;
	@synchronized (self)	{
		returnMe = fetchShaders;
	}
	return returnMe;
}
- (void) reloadFileFromTableView	{
	NSUInteger			selectedIndex = [[filterTV selectedRowIndexes] firstIndex];
	if (selectedIndex == NSNotFound)	{
		[isfController loadFile:nil];
		[docController loadFile:nil];
	}
	else	{
		NSString		*newFilterPath = [filterList lockObjectAtIndex:selectedIndex];
		[isfController loadFile:newFilterPath];
		[docController loadFile:newFilterPath];
	}
	
	@synchronized (self)	{
		//NSLog(@"\t\tfetchShaders is YES in %s",__func__);
		//fetchShaders = YES;
	}
}
@synthesize respondToTableSelectionChanges;
@synthesize respondToFileChanges;
- (NSMutableArray *) createSyntaxErrorsForForbiddenTermsInRawISFFile	{
	__block NSMutableArray		*syntaxErrArray = MUTARRAY;
	//	run through the raw frag shader string, looking for "forbidden" terms (texture2D, texture2DRect, sampler2D, sampler2DRect), and creating errors for them
	NSArray			*forbiddenTerms = @[@"texture2DRectProjLod",@"texture2DRectProj",@"texture2DRect",@"texture2DProjLod",@"texture2DProj",@"texture2D",@"sampler2DRect",@"sampler2D"];
	NSString		*forbiddenTermsRegex = @"((texture2D(Rect)?(Proj)?(Lod)?)|(sampler2D(Rect)?))";
	NSString		*precompiledFragSrc = [[isfController scene] fragShaderSource];
	NSString		*jsonSrc = [[isfController scene] jsonSource];
	//NSInteger		lineDelta = [jsonSrc numberOfLines];
	__block NSInteger	lineIndex = [jsonSrc numberOfLines] + 1;
	//NSMutableArray	*syntaxErrArray = MUTARRAY;
	//	run through all the lines in the precompiled shader
	[precompiledFragSrc enumerateLinesUsingBlock:^(NSString *line, BOOL *stop)	{
		//	if the line matches the 'forbidden terms' regex...
		if ([line isMatchedByRegex:forbiddenTermsRegex])	{
			//	run through all the forbidden terms to figure out which one is in the line
			for (NSString *forbiddenTerm in forbiddenTerms)	{
				if ([line containsString:forbiddenTerm])	{
					//	make a syntax error, add it to the array
					SMLSyntaxError	*err = [[[SMLSyntaxError alloc] init] autorelease];
					[err setLine:(int)lineIndex];
					[err setCharacter:0];
					[err setCode:forbiddenTerm];
					[err setDescription:VVFMTSTRING(@"Warning: \'%@\' may not always work!",forbiddenTerm)];
					[err setLength:1];
					[syntaxErrArray addObject:err];
				
					break;
				}
			}
		}
		++lineIndex;
	}];
	
	NSMutableArray			*returnMe = nil;
	if ([syntaxErrArray count]>0)	{
		returnMe = MUTARRAY;
		[returnMe addObjectsFromArray:syntaxErrArray];
	}
	return returnMe;
}



/*===================================================================================*/
#pragma mark --------------------- table view data source/delegate
/*------------------------------------*/


- (NSUInteger) numberOfRowsInTableView:(NSTableView *)tv	{
	//NSLog(@"%s",__func__);
	return [filterList lockCount];
}
- (id) tableView:(NSTableView *)tv objectValueForTableColumn:(NSTableColumn *)tc row:(int)row	{
	NSString		*fileName = [[filterList lockObjectAtIndex:row] lastPathComponent];
	return fileName;
}
- (BOOL) tableView:(NSTableView *)tv shouldTrackCell:(NSCell *)cell forTableColumn:(NSTableColumn *)col row:(int)row	{
	//NSLog(@"%s",__func__);
	return YES;
}
- (BOOL)tableView:(NSTableView *)tv shouldSelectRow:(NSInteger)row	{
	//	if the doc controller's contents need to be saved, throw up an alert
	if ([docController contentsNeedToBeSaved])	{
		NSInteger		saveResult = VVRunAlertPanel(@"Unsaved Changes!",
			@"The ISF file you were editing has unsaved changes- do you want to save your changes before closing it?",
			@"Save",
			@"Don't Save",
			@"Cancel");
		if (saveResult == NSAlertFirstButtonReturn)	{
			//	save the file, then select the row
			[docController saveOpenFile];
			return YES;
		}
		else if (saveResult == NSAlertSecondButtonReturn)	{
			//	don't save the file- just select the row
			return YES;
		}
		else if (saveResult == NSAlertThirdButtonReturn)	{
			//	don't save the file, don't select the row
			return NO;
		}
		else
			return YES;
	}
	//	else just select it
	else
		return YES;
	return YES;
}
- (void) tableViewSelectionDidChange:(NSNotification *)aNotification	{
	//NSLog(@"%s",__func__);
	if (![self respondToTableSelectionChanges])
		return;
	[self reloadFileFromTableView];
}


/*===================================================================================*/
#pragma mark --------------------- table view drag & drop
/*------------------------------------*/


- (unsigned int) tableView:(NSTableView *)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op {
	//NSLog(@"%s",__func__);
	if (op == NSTableViewDropOn)
		[tv setDropRow:row dropOperation:NSTableViewDropAbove];
	
	return op;
}
- (BOOL) tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op	{
	//NSLog(@"%s",__func__);
	NSPasteboard		*pboard = [info draggingPasteboard];
	NSString			*tmpPath = nil;
	//NSFileManager		*fm = [NSFileManager defaultManager];
	//BOOL				isDirectory = NO;
	if ([[pboard types] containsObject:NSFilenamesPboardType]) {
		//	Load the files
		NSArray		*pathsArray = [pboard propertyListForType:NSFilenamesPboardType];
		tmpPath = (pathsArray==nil) ? nil : [pathsArray objectAtIndex:0];
	}
	else if ([[pboard types] containsObject:NSURLPboardType])	{
		NSURL		*fileURL = [NSURL URLFromPasteboard:pboard];
		tmpPath = (fileURL==nil) ? nil : [fileURL absoluteString];
	}
	
	NSString			*folderPath = nil;
	NSString			*filePath = nil;
	//	if there's a tmp path
	if (tmpPath != nil)	{
		NSFileManager		*fm = [NSFileManager defaultManager];
		BOOL				isDir = NO;
		[fm fileExistsAtPath:tmpPath isDirectory:&isDir];
		//	is it a folder?  if it's a folder, just load that
		if (isDir)	{
			folderPath = tmpPath;
		}
		//	else it's not a folder
		else	{
			filePath = tmpPath;
			folderPath = [tmpPath stringByDeletingLastPathComponent];
		}
		//	get the path to the folder, load that
		if (folderPath != nil)	{
			[[NSUserDefaults standardUserDefaults] setObject:folderPath forKey:@"fxPath"];
			[[NSUserDefaults standardUserDefaults] synchronize];
			[self _loadFilterList];
			[filterTV reloadData];
		}
		//	get the index of the file in the array, select it in the table view
		if (filePath != nil)	{
			NSInteger		fileIndex = [filterList lockIndexOfObject:filePath];
			if (fileIndex>=0 && fileIndex!=NSNotFound)	{
				[filterTV selectRowIndexes:[NSIndexSet indexSetWithIndex:fileIndex] byExtendingSelection:NO];
			}
		}
		else
			[filterTV deselectAll:nil];
		//	make sure that the change in selection is reflected by the backend!
		[self tableViewSelectionDidChange:nil];
	}
	/*
	//	if there's a tmp path, store it in the user defaults
	if (tmpPath != nil)	{
		NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
		[def setObject:tmpPath forKey:@"fxPath"];
		[def synchronize];
	}
	
	//	reload the filter list (loads the files from "fxPath" from the user defaults)
	[self _loadFilterList];
	
	
	//	reload the table view
	[filterTV reloadData];
	//	tell the table view to select the item at the dst index
	[filterTV deselectAll:nil];
	//	make sure that the change in selection is reflected by the backend!
	[self tableViewSelectionDidChange:nil];
	*/
	return YES;
}


@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, 
	const CVTimeStamp *inNow, 
	const CVTimeStamp *inOutputTime, 
	CVOptionFlags flagsIn, 
	CVOptionFlags *flagsOut, 
	void *displayLinkContext)
{
	//NSLog(@"%s",__func__);
	NSAutoreleasePool		*pool =[[NSAutoreleasePool alloc] init];
	[(ISFEditorAppDelegate *)displayLinkContext _renderCallback];
	[pool release];
	return kCVReturnSuccess;
}

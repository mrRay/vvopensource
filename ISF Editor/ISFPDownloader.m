#import "ISFPDownloader.h"
#import <VVISFKit/VVISFKit.h>
#import "ISFPDownload.h"
#import "ISFPDownloadTableCellView.h"
#import "RegexKitLite.h"
#import "ISFEditorAppDelegate.h"




#define LOCK OSSpinLockLock
#define UNLOCK OSSpinLockUnlock
#define DOWNLOADCOUNT 20
#define SIMULTANEOUSDOWNLOADS 5




@implementation ISFPDownloader


- (id) init	{
	//NSLog(@"%s",__func__);
	self = [super init];
	if (self != nil)	{
		alreadyAwake = NO;
		isfScene = [[ISFGLScene alloc] initWithSharedContext:[_globalVVBufferPool sharedContext] pixelFormat:[GLScene defaultPixelFormat] sized:NSMakeSize(810,432)];
		pageStartIndex = 0;
		//pageBaseURL = nil;
		pageQueryTerms = nil;
		browseType = ISFPDownloaderBrowseType_MostStars;
		completedDownloads = [[MutLockArray alloc] init];
		imagesToDownload = [[MutLockArray alloc] init];
		downloadQueue = dispatch_queue_create("IMIDownloader", DISPATCH_QUEUE_SERIAL);
		reloadTableTimer = nil;
	}
	return self;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	VVRELEASE(completedDownloads);
	VVRELEASE(imagesToDownload);
	dispatch_release(downloadQueue);
	downloadQueue = NULL;
	[super dealloc];
}
- (void) awakeFromNib	{
	//NSLog(@"%s",__func__);
	//	this method gets called every time a new ISFPDownloadTableCellView is instantiated, which is just....fucking awful.
	
	if (!alreadyAwake)	{
		//[self browseTypePUBUsed:browseTypePUB];
		
		[self populateCategoriesPUB];
		
		[functionPUB removeAllItems];
		NSMenu		*tmpMenu = [functionPUB menu];
		NSMenuItem	*tmpMenuItem = nil;
		
		tmpMenuItem = [[[NSMenuItem alloc]
			initWithTitle:@"<All>"
			action:nil
			keyEquivalent:@""] autorelease];
		[tmpMenu addItem:tmpMenuItem];
		
		NSArray		*functionTypes = @[@"generator", @"filter", @"transition"];
		for (NSString *functionType in functionTypes)	{
			tmpMenuItem = [[[NSMenuItem alloc]
				initWithTitle:functionType
				action:nil
				keyEquivalent:@""] autorelease];
			[tmpMenuItem setRepresentedObject:functionType];
			[tmpMenu addItem:tmpMenuItem];
		}
		
		[functionPUB selectItemAtIndex:0];
	}
	
	alreadyAwake = YES;
}


#pragma mark -


- (void) populateCategoriesPUB	{
	NSLog(@"%s",__func__);
	//	first, populate the categories PUB with a list of standard categories that will be used until we download the official list of categories from the server
	NSArray			*defaultCats = @[@"Generator", @"Color Effect", @"Color Adjustment",@"Halftone Effect", @"Geometry Adjustment",@"Blur",@"Sharpen",@"Stylize",@"Glitch",@"Tile Effect",@"Distortion Effect",@"Film",@"Masking",@"Patterns"];
	[self populateCategoriesPUBWithCategories:defaultCats];
	//	now begin downloading the array of categories from the server
	
	VVCURLDL		*dl = [[VVCURLDL alloc] initWithAddress:@"https://www.interactiveshaderformat.com/api/v1/categories"];
	[dl setDNSCacheTimeout:10];
	[dl setConnectTimeout:10];
	[dl appendStringToHeader:@"Accept: application/json"];
	[dl performAsync:YES withBlock:^(VVCURLDL *finished)	{
		NSString		*responseString = [finished responseString];
		NSDictionary	*topLevelJSONObj = [responseString objectFromJSONString];
		NSLog(@"\t\traw categories are %@",topLevelJSONObj);
		NSMutableArray	*tmpCatArray = MUTARRAY;
		//NSLog(@"\t\tcategories topLevelJSONObj is %@",topLevelJSONObj);
		if (topLevelJSONObj!=nil && [topLevelJSONObj isKindOfClass:[NSDictionary class]])	{
			NSArray			*catDictArray = [topLevelJSONObj objectForKey:@"categories"];
			for (NSDictionary *catDict in catDictArray)	{
				if ([catDict isKindOfClass:[NSDictionary class]])	{
					NSString		*catName = [catDict objectForKey:@"name"];
					if (catName != nil)
						[tmpCatArray addObject:catName];
				}
			}
		}
		NSLog(@"\t\tfetched categories from server: %@",tmpCatArray);
		[self populateCategoriesPUBWithCategories:tmpCatArray];
	}];
}
- (void) populateCategoriesPUBWithCategories:(NSArray *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	//	get the title of the currently selected menu item
	NSString			*origSelectedItemName = [categoriesPUB titleOfSelectedItem];
	//	clear the menu
	NSMenu				*menu = [categoriesPUB menu];
	NSMenuItem			*tmpItem = nil;
	[menu removeAllItems];
	//	add the "all categories" item
	tmpItem = [[[NSMenuItem alloc]
		initWithTitle:@"<All categories>"
		action:nil
		keyEquivalent:@""] autorelease];
	[tmpItem setRepresentedObject:nil];
	[menu addItem:tmpItem];
	//	run through the passed array, making menu items for each name
	if (n!=nil && [n count]>0)	{
		[menu addItem:[NSMenuItem separatorItem]];
		for (NSString *category in n)	{
			tmpItem = [[[NSMenuItem alloc]
				initWithTitle:category
				action:nil
				keyEquivalent:@""] autorelease];
			[tmpItem setRepresentedObject:category];
			[menu addItem:tmpItem];
		}
	}
	//	if there was a selected menu item when we began, re-select it.
	if (origSelectedItemName != nil)
		[categoriesPUB selectItemWithTitle:origSelectedItemName];
	//	if there wasn't a selected menu item when we began, select the "all categories" item
	else
		[categoriesPUB selectItemAtIndex:0];
}
- (IBAction) categoriesPUBUsed:(id)sender	{
	NSLog(@"%s",__func__);
	[self searchFieldUsed:searchField];
}
- (IBAction) functionTypePUBUsed:(id)sender	{
	NSLog(@"%s",__func__);
	[self searchFieldUsed:searchField];
}
- (IBAction) searchFieldUsed:(id)sender	{
	NSLog(@"%s",__func__);
	//	deselect everything in the categories PUB
	//[browseTypePUB selectItem:nil];
	
	//	parse the string from the search field, generate an array of terms
	NSString		*rawString = [searchField stringValue];
	NSArray			*rawTerms = [rawString componentsSeparatedByRegex:@"[^\\w]+"];
	NSMutableArray	*terms = MUTARRAY;
	for (NSString *rawTerm in rawTerms)	{
		if ([rawTerm length]>0)	{
			[terms addObject:rawTerm];
		}
	}
	//NSLog(@"\t\trefined terms are %@",terms);
	
	//	create and set a page base URL using the terms
	if (terms==nil || [terms count]<1)	{
		[searchField setStringValue:@""];
		//[self setPageBaseURL:nil];
		[self setPageQueryTerms:nil];
	}
	/*
	else if ([terms count]==1)	{
		//[self setPageBaseURL:[terms objectAtIndex:0]];
		XXX;
	}
	*/
	else	{
		[searchField setStringValue:[terms componentsJoinedByString:@" "]];
		//[self setPageBaseURL:[terms objectAtIndex:0]];
		[self setPageQueryTerms:terms];
	}
	
	//	reset the page start indexes
	[self setPageStartIndex:0];
	[self setMaxPageStartIndex:NSNotFound];
	
	//	create the query URL (which is based on the page base URL and the page start index)
	//NSString		*queryURL = [self createSearchQueryURL];
	NSString		*queryURL = [self createQueryURL];
	[self downloadResultsForURLString:queryURL];
}
- (IBAction) browseTypePUBUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	NSString		*selectedTitle = [browseTypePUB titleOfSelectedItem];
	if (selectedTitle==nil)
		return;
	
	/*
	//	clear the search field
	[searchField setStringValue:@""];
	*/
	
	//	set the page base URL
	if ([selectedTitle isEqualToString:@"Latest"])	{
		//[self setPageBaseURL:@"https://www.interactiveshaderformat.com/api/v1/shaders?sort=newest"];
		
		//[self setPageBaseURL:@"?sort=newest"];
		[self setBrowseType:ISFPDownloaderBrowseType_Latest];
	}
	else if ([selectedTitle isEqualToString:@"Most Stars"])	{
		//[self setPageBaseURL:@"https://www.interactiveshaderformat.com/api/v1/shaders?"];
		
		//[self setPageBaseURL:nil];
		[self setBrowseType:ISFPDownloaderBrowseType_MostStars];
	}
	else if ([selectedTitle isEqualToString:@"Name"])	{
		//[self setPageBaseURL:@"https://www.interactiveshaderformat.com/api/v1/shaders?"];
		
		//[self setPageBaseURL:nil];
		[self setBrowseType:ISFPDownloaderBrowseType_Name];
	}
	
	//	reset the page start indexes
	[self setPageStartIndex:0];
	[self setMaxPageStartIndex:NSNotFound];
	
	//	create the query URL (which is based on the page base URL and the page start index)
	//NSString		*queryURL = [self createBrowseQueryURL];
	NSString		*queryURL = [self createQueryURL];
	[self downloadResultsForURLString:queryURL];
}


- (IBAction) nextPageClicked:(id)sender	{
	//NSLog(@"%s",__func__);
	//	calculate a new page start index
	NSInteger		newPageStartIndex = [self pageStartIndex] + DOWNLOADCOUNT;
	//	make sure that the new page start index isn't bigger than the max page start index
	NSInteger		_maxPageStartIndex = [self maxPageStartIndex];
	if (_maxPageStartIndex != NSNotFound)
		newPageStartIndex = fminl(newPageStartIndex, _maxPageStartIndex);
	//	if we aren't actually changing the page start index, bail now
	if (newPageStartIndex == [self pageStartIndex])
		return;
	
	//	set the page start index
	[self setPageStartIndex:newPageStartIndex];
	//	create a query URL (which uses the page start index and the page base url)
	//NSString		*queryURL = [self createBrowseQueryURL];
	NSString		*queryURL = [self createQueryURL];
	//	begin downloading the results
	[self downloadResultsForURLString:queryURL];
}
- (IBAction) prevPageClicked:(id)sender	{
	//NSLog(@"%s",__func__);
	//	calculate a new page start index
	NSInteger		newPageStartIndex = [self pageStartIndex] - DOWNLOADCOUNT;
	//	make sure that the new page start index isn't bigger than the max page start index
	if (newPageStartIndex < 0)
		newPageStartIndex = 0;
	//	if we aren't actually changing the page start index, bail now
	if (newPageStartIndex == [self pageStartIndex])
		return;
	
	//	actually set the page start index
	[self setPageStartIndex:newPageStartIndex];
	//	create a query URL (which uses the page start index and the page base url)
	//NSString		*queryURL = [self createBrowseQueryURL];
	NSString		*queryURL = [self createQueryURL];
	//	begin downloading the results
	[self downloadResultsForURLString:queryURL];
}
- (IBAction) importClicked:(id)sender	{
	//	get the index of the selected item
	NSInteger		selRow = [tableView selectedRow];
	if (selRow<0 || selRow==NSNotFound)
		return;
	ISFPDownload		*dl = [[[completedDownloads lockObjectAtIndex:selRow] retain] autorelease];
	if (dl == nil)
		return;
	[self _importDownload:dl];
	
}
- (IBAction) importAllClicked:(id)sender	{
	NSArray			*copiedDLs = [completedDownloads lockCreateArrayCopy];
	for (ISFPDownload *dl in copiedDLs)	{
		[self _importDownload:dl];
	}
}
- (void) _importDownload:(ISFPDownload *)dl	{
	if (dl==nil)
		return;
	//	calculate the destination directory, make sure it exists (create it if it doesn't)
	NSString		*dstDir = [@"~/Library/Graphics/ISF" stringByExpandingTildeInPath];
	NSFileManager	*fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:dstDir])
		[fm createDirectoryAtPath:dstDir withIntermediateDirectories:YES attributes:nil error:nil];
	//	run through the src files (get the frag path, enumerate the contents of the directory it's within)
	NSString		*fragPath = [dl fragPath];
	NSString		*srcDir = [fragPath stringByDeletingLastPathComponent];
	NSArray			*srcDirContents = [fm contentsOfDirectoryAtPath:srcDir error:nil];
	for (NSString *fileName in srcDirContents)	{
		NSString		*srcPath = VVFMTSTRING(@"%@/%@",srcDir,fileName);
		NSString		*dstPath = VVFMTSTRING(@"%@/%@",dstDir,fileName);
		//	if there's a file at the "dstPath", move it to the trash
		if ([fm fileExistsAtPath:dstPath])
			[fm trashItemAtURL:[NSURL fileURLWithPath:dstPath] resultingItemURL:nil error:nil];
		//	copy the src to the dst
		[fm copyItemAtPath:srcPath toPath:dstPath error:nil];
	}
}
- (IBAction) closeClicked:(id)sender	{
	//	close the modal window
	[self closeModalWindow];
	//	reload the file from the table view (so we aren't viewing something in a tmp directory)
	[appController reloadFileFromTableView];
}


#pragma mark -

/*
- (NSString *) createBrowseQueryURL	{
	NSLog(@"%s",__func__);
	NSString		*returnMe = nil;
	NSString		*_pageBaseURL = [self pageBaseURL];
	NSLog(@"\t\tpageBaseURL is %@",_pageBaseURL);
	NSInteger		_pageStartIndex = [self pageStartIndex];
	if (_pageBaseURL == nil)
		returnMe = VVFMTSTRING(@"https://www.interactiveshaderformat.com/api/v1/shaders?offset=%ld&limit=%d",(long)_pageStartIndex,DOWNLOADCOUNT);
	else
		returnMe = VVFMTSTRING(@"https://www.interactiveshaderformat.com/api/v1/shaders%@&offset=%ld&limit=%d",_pageBaseURL,(long)_pageStartIndex,DOWNLOADCOUNT);
	return returnMe;
}
- (NSString *) createSearchQueryURL	{
	NSLog(@"%s",__func__);
	NSString		*returnMe = nil;
	NSString		*_pageBaseURL = [self pageBaseURL];
	NSLog(@"\t\tpageBaseURL is %@",_pageBaseURL);
	NSInteger		_pageStartIndex = [self pageStartIndex];
	if (_pageBaseURL == nil)
		returnMe = VVFMTSTRING(@"https://www.interactiveshaderformat.com/api/v1/shaders?offset=%ld&limit=%d",(long)_pageStartIndex,DOWNLOADCOUNT);
	else
		returnMe = VVFMTSTRING(@"https://www.interactiveshaderformat.com/api/v1/shaders/query/%@?offset=%ld&limit=%d",_pageBaseURL,(long)_pageStartIndex,DOWNLOADCOUNT);
	return returnMe;
}
*/
- (NSString *) createQueryURL	{
	NSLog(@"%s",__func__);
	NSString		*returnMe = nil;
	NSString		*baseString = @"https://www.interactiveshaderformat.com/api/v1/search";
	NSArray			*searchTermsArray = [self pageQueryTerms];
	NSString		*searchTermsString = (searchTermsArray==nil || [searchTermsArray count]<1) ? nil : VVFMTSTRING(@"query=%@",[searchTermsArray componentsJoinedByString:@","]);
	NSString		*categoryString = [[categoriesPUB selectedItem] representedObject];
	NSString		*categoryTermsString = (categoryString==nil) ? nil : VVFMTSTRING(@"category=%@",categoryString);
	NSString		*functionString = [[functionPUB selectedItem] representedObject];
	NSString		*functionTermsString = (functionString==nil) ? nil : VVFMTSTRING(@"shader_type=%@",functionString);
	//NSString		*sortString = ([self browseType]==ISFPDownloaderBrowseType_Latest) ? @"order=newest" : nil;
	NSString		*sortString = nil;
	switch ([self browseType])	{
	case ISFPDownloaderBrowseType_MostStars:
		sortString = @"order=popular";
		break;
	case ISFPDownloaderBrowseType_Latest:
		sortString = @"order=newest";
		break;
	case ISFPDownloaderBrowseType_Name:
		sortString = @"order=name";
		break;
	}
	NSString		*offsetString = VVFMTSTRING(@"offset=%ld&limit=%d",(long)[self pageStartIndex],DOWNLOADCOUNT);
	//NSLog(@"\t\tcategoryString is %@, functionString is %@",categoryString,functionString);
	
	NSCharacterSet	*urlChars = [NSCharacterSet URLQueryAllowedCharacterSet];
	searchTermsString = [searchTermsString stringByAddingPercentEncodingWithAllowedCharacters:urlChars];
	categoryTermsString = [categoryTermsString stringByAddingPercentEncodingWithAllowedCharacters:urlChars];
	categoryTermsString = [categoryTermsString lowercaseString];
	functionTermsString = [functionTermsString stringByAddingPercentEncodingWithAllowedCharacters:urlChars];
	
	NSMutableArray	*queryArray = [NSMutableArray arrayWithCapacity:0];
	if (searchTermsString != nil)
		[queryArray addObject:searchTermsString];
	if (categoryTermsString != nil)
		[queryArray addObject:categoryTermsString];
	if (functionTermsString != nil)
		[queryArray addObject:functionTermsString];
	if (sortString != nil)
		[queryArray addObject:sortString];
	if (offsetString != nil)
		[queryArray addObject:offsetString];
	
	returnMe = VVFMTSTRING(@"%@?%@",baseString,[queryArray componentsJoinedByString:@"&"]);
	NSLog(@"\t\tquery URL is %@",returnMe);
	
	return returnMe;
}
- (void) downloadResultsForURLString:(NSString *)address	{
	NSLog(@"%s ... %@",__func__,address);
	VVCURLDL		*dl = [[VVCURLDL alloc] initWithAddress:address];
	[dl setDNSCacheTimeout:10];
	[dl setConnectTimeout:10];
	[dl appendStringToHeader:@"Accept: application/json"];
	[dl performAsync:YES withBlock:^(VVCURLDL *finished)	{
		//NSLog(@"\t\tdownloaded string %@",[finished responseString]);
		//NSLog(@"\t\tdownloaded JSON object %@",[[finished responseString] objectFromJSONString]);
		NSString		*responseString = [finished responseString];
		NSArray			*topLevelJSONObj = [responseString objectFromJSONString];
		if (topLevelJSONObj==nil || ![topLevelJSONObj isKindOfClass:[NSArray class]])	{
			if (topLevelJSONObj==nil)
				NSLog(@"\t\terr: %s, topLevelJSONObj nil, string was %@",__func__,responseString);
			else
				NSLog(@"\t\terr: %s, topLevelJSONObj was a %@ instead of an array",__func__,NSStringFromClass([topLevelJSONObj class]));
				NSLog(@"\t\tcontent is %@",topLevelJSONObj);
		}
		else	{
			//	if i'm here then we've got a JSON array to work with, so we most likely have some results...
			
			//	before we go further, make sure that the # of results in this array matches the # of results we tried to download.  if it doesn't, there aren't any more results, and we should set the maxPageStartIndex.
			if ([(NSArray *)topLevelJSONObj count] != DOWNLOADCOUNT)	{
				[self setMaxPageStartIndex:[self pageStartIndex]];
			}
			
			//	the goal here is to assemble an array of ISFPDownload instances we'll pass back to ourself (so we can start downloading them)
			NSMutableArray	*newDownloads = MUTARRAY;
			//	delete then re-create the folder we'll be downloading to
			NSString		*baseDir = @"/tmp/ISFEditor/Downloads";
			NSFileManager	*fm = [NSFileManager defaultManager];
			if ([fm fileExistsAtPath:baseDir])	{
				NSError			*nsErr = nil;
				if (![fm removeItemAtURL:[NSURL fileURLWithPath:baseDir isDirectory:YES] error:&nsErr])
					NSLog(@"\t\terr: %s, couldn't trash path \"%@\", %@",__func__,baseDir,nsErr);
				//if (![fm trashItemAtURL:[NSURL fileURLWithPath:baseDir isDirectory:YES] resultingItemURL:nil error:&nsErr])
				//	NSLog(@"\t\terr: %s, couldn't trash path \"%@\", %@",__func__,baseDir,nsErr);
			}
			[fm createDirectoryAtPath:baseDir withIntermediateDirectories:YES attributes:nil error:nil];
			//	run through dicts we parsed from the JSON blob (each dict describes a shader)
			for (NSDictionary * shaderDict in (NSArray *)topLevelJSONObj)	{
				if (![shaderDict isKindOfClass:[NSDictionary class]])	{
					NSLog(@"\t\terr: %s, shaderDict was a %@ instead of a dict",__func__,NSStringFromClass([shaderDict class]));
					continue;
				}
				//	pull the vals we want from the dict, make sure they exist and are of the correct type
				NSNumber		*idNum = [shaderDict objectForKey:@"id"];
				NSString		*fragString = [shaderDict objectForKey:@"raw_fragment_source"];
				NSString		*vertString = [shaderDict objectForKey:@"raw_vertex_source"];
				NSString		*thumbnailString = [shaderDict objectForKey:@"thumbnail_url"];
				NSString		*title = [shaderDict objectForKey:@"title"];
				NSString		*updateDateString = [shaderDict objectForKey:@"updated_at"];
				
				if ([idNum isKindOfClass:[NSNull class]])
					idNum = nil;
				if ([fragString isKindOfClass:[NSNull class]])
					fragString = nil;
				if ([vertString isKindOfClass:[NSNull class]])
					vertString = nil;
				if ([thumbnailString isKindOfClass:[NSNull class]])
					thumbnailString = nil;
				if ([title isKindOfClass:[NSNull class]])
					title = nil;
				if ([updateDateString isKindOfClass:[NSNull class]])
					updateDateString = nil;
				
				if ((idNum==nil || ![idNum isKindOfClass:[NSNumber class]])	||
				(fragString==nil || ![fragString isKindOfClass:[NSString class]])	||
				(vertString==nil || ![vertString isKindOfClass:[NSString class]])	||
				//(thumbnailString==nil || ![thumbnailString isKindOfClass:[NSString class]])	||
				(title==nil || ![title isKindOfClass:[NSString class]])	||
				(updateDateString==nil || ![updateDateString isKindOfClass:[NSString class]]))	{
					NSLog(@"\t\terr: %s, obj from shader dict is missing or wrong type",__func__);
					//NSLog(@"\t\tid is %@, is class %@",idNum,NSStringFromClass([idNum class]));
					//NSLog(@"\t\tfrag/vert strings are %@/%@",NSStringFromClass([fragString class]),NSStringFromClass([vertString class]));
					//NSLog(@"\t\tthumb string is %@/%@",thumbnailString,NSStringFromClass([thumbnailString class]));
					//NSLog(@"\t\ttitle is %@/%@",title,NSStringFromClass([title class]));
					//NSLog(@"\t\tupdateDateString is %@/%@",updateDateString,NSStringFromClass([updateDateString class]));
					continue;
				}
				
				//	if the vertString is the default vertString, we can skip it
				if ([vertString isEqualToString:@"void main() {\n\tvv_vertShaderInit();\n}"])
					vertString = nil;
				else if ([vertString isEqualToString:@"void main() {\n\tisf_vertShaderInit();\n}"])
					vertString = nil;
				
				//	if the folder doesn't already exist
				NSString		*shaderDir = VVFMTSTRING(@"%@/%d",baseDir,[idNum intValue]);
				if (![fm fileExistsAtPath:shaderDir])	{
					//	create the folder
					if (![fm createDirectoryAtPath:shaderDir withIntermediateDirectories:YES attributes:nil error:nil])
						NSLog(@"\t\terr: couldn't create directory %@, can't save shader",shaderDir);
					else	{
						//	dump the frag/vert files to disk
						NSString		*fragPath = VVFMTSTRING(@"%@/%@.fs",shaderDir,title);
						NSString		*vertPath = VVFMTSTRING(@"%@/%@.vs",shaderDir,title);
						[fragString writeToFile:fragPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
						if (vertString != nil)
							[vertString writeToFile:vertPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
						//	make an ISFPDownload object, populate it
						ISFPDownload	*newDownload = [ISFPDownload create];
						[newDownload setFragPath:fragPath];
						[newDownload setThumbURL:thumbnailString];
						[newDownload setUniqueID:idNum];
						//	convert the date string to an NSDate instance, add it to the download object
						NSDate			*updateDate = nil;
						if (updateDateString!=nil)	{
							NSDateFormatter		*fmt = [[NSDateFormatter alloc] init];
							//[fmt setLocale:enUSPOSIXLocale];
							[fmt setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
							[fmt setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS"];
							updateDate = [fmt dateFromString:updateDateString];
							if (updateDate==nil)	{
								[fmt setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
								updateDate = [fmt dateFromString:updateDateString];
								if (updateDate==nil)	{
									[fmt setDateFormat:@"yyyy-MM-dd'T'HH:mm"];
									updateDate = [fmt dateFromString:updateDateString];
									if (updateDate==nil)	{
										[fmt setDateFormat:@"yyyy-MM-dd HH:mm:ss ZZZ"];
										updateDate = [fmt dateFromString:updateDateString];
									}
								}
							}
							[fmt release];
						}
						if (updateDate != nil)
							[newDownload setUpdateDate:updateDate];
						else
							NSLog(@"\t\tERR: couldn't parse update string \"%@\", %s",updateDateString,__func__);
						
						//	add the download object to the array of completedDownloads i'm assembling
						[newDownloads addObject:newDownload];
					}
				}
			}
			
			//	at this point we should have populated 'newDownloads' with instances of ISFPDownload
			
			//	pass them back to self, we'll update the array and the table and begin downloading in a new method on the main thread
			dispatch_async(dispatch_get_main_queue(), ^{
				//[self setPageStartIndex:p];
				[self parsedNewDownloads:newDownloads];
			});
		}
		
		[dl autorelease];
	}];
}
- (void) clearResults	{
	if (![NSThread isMainThread])	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self clearResults];
		});
		return;
	}
	
	[self setPageStartIndex:0];
	[self setMaxPageStartIndex:NSNotFound];
	//[self setPageBaseURL:nil];
	[self setPageQueryTerms:nil];
	[searchField setStringValue:@""];
	[completedDownloads lockRemoveAllObjects];
	[imagesToDownload lockRemoveAllObjects];
	@synchronized (self)	{
		if (reloadTableTimer != nil)	{
			[reloadTableTimer invalidate];
			reloadTableTimer = nil;
		}
	}
	[tableView reloadData];
}
- (void) openModalWindow	{
	if (![NSThread isMainThread])	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self openModalWindow];
		});
		return;
	}
	
	//[view removeFromSuperview];
	[appWindow beginSheet:myWindow completionHandler:^(NSModalResponse returnCode)	{
		dispatch_async(dispatch_get_main_queue(), ^{
			//[view removeFromSuperview];
		});
	}];
	
	[searchField setStringValue:@""];
	[browseTypePUB selectItemAtIndex:1];
	[self browseTypePUBUsed:browseTypePUB];
}
- (void) closeModalWindow	{
	if (![NSThread isMainThread])	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self closeModalWindow];
		});
		return;
	}
	
	NSWindow		*sheetParent = [myWindow sheetParent];
	if (sheetParent == nil)
		return;
	[self clearResults];
	[sheetParent endSheet:myWindow returnCode:NSModalResponseStop];
	
	//	tell the app controller to reload the list of files- we may have imported stuff while the modal window was open
	[appController _loadFilterList];
}


#pragma mark -


@synthesize pageStartIndex;
@synthesize maxPageStartIndex;
//@synthesize pageBaseURL;
@synthesize pageQueryTerms;
@synthesize browseType;
- (void) parsedNewDownloads:(NSMutableArray *)n	{
	//NSLog(@"%s",__func__);
	//	empty the array of images to download
	[imagesToDownload lockRemoveAllObjects];
	//	empty my completedDownloads folder
	[completedDownloads wrlock];
	[completedDownloads removeAllObjects];
	[completedDownloads addObjectsFromArray:n];
	[completedDownloads unlock];
	//	reload the table view
	[tableView reloadData];
	
	//	run through the array, adding the URLs i need to download to the array
	for (ISFPDownload *download in n)	{
		NSString		*url = [download thumbURL];
		if (url==nil)
			continue;
		
		[imagesToDownload lockAddObject:url];
	}
	
	//	start downloading XXX things at a time
	for (int i=0; i<SIMULTANEOUSDOWNLOADS; ++i)
		[self startDownloadingImage];
	
}
- (void) startDownloadingImage	{
	//NSLog(@"%s",__func__);
	NSString			*imageToDownload = nil;
	
	[imagesToDownload wrlock];
	if ([imagesToDownload count]>0)	{
		imageToDownload = [[[imagesToDownload objectAtIndex:0] retain] autorelease];
		[imagesToDownload removeObjectAtIndex:0];
	}
	[imagesToDownload unlock];
	
	//	if there's nothing to download, bail here
	if (imageToDownload == nil)	{
		//NSLog(@"\t\tbailing, no more images to download, %s",__func__);
		return;
	}
	
	//	make a downloader for the thumbnail- run it on another queue
	VVCURLDL		*newDL = [[VVCURLDL alloc] initWithAddress:imageToDownload];
	[newDL setDNSCacheTimeout:10];
	[newDL setConnectTimeout:10];
	[newDL
		performOnQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0)
		//performOnQueue:dispatch_get_main_queue()
		block:^(VVCURLDL *finished)	{
			//	this block runs after the download is complete- make an image, pass it back to the downloader
			NSData		*data = [finished responseData];
			NSImage		*thumb = [[NSImage alloc] initWithData:data];
			
			[self downloadedImage:thumb fromURL:[finished urlString]];
			
			[thumb autorelease];
			[finished autorelease];
		}];
}
- (void) downloadedImage:(NSImage *)img fromURL:(NSString *)urlString	{
	//NSLog(@"%s ... %@",__func__,urlString);
	if (urlString==nil)
		return;
	//	run through my completedDownloads, pass the image to any completedDownloads that need it
	BOOL			updatedSomething = NO;
	[completedDownloads rdlock];
	for (ISFPDownload *download in [completedDownloads array])	{
		if ([[download thumbURL] isEqualToString:urlString])	{
			[download setThumb:img];
			updatedSomething = YES;
		}
	}
	[completedDownloads unlock];
	
	//	if i updated something, i have to reload the table view...
	if (updatedSomething)	{
		//NSLog(@"\t\tupdated something, should be setting up table redraw timer...");
		//	use a timer to throttle table view redraws (the table won't redraw until there's a pause of 1 sec either between completedDownloads or after completedDownloads)
		//	have to do this on the main queue, can't do it here- this method is called from a low-priority GCD queue, which doesn't have a runloop so you can't attach a timer to it
		dispatch_async(dispatch_get_main_queue(), ^{
			//[self _resetReloadTableTimer];
			[self reloadTableButThrottleThisMethod];
		});
	}
	
	//	i downloaded an image, start downloading another
	[self startDownloadingImage];
}
- (void) reloadTableButThrottleThisMethod	{
	BOOL		needToReloadNow = NO;
	@synchronized (self)	{
		//	if there's no timer, we need to reload now, and start a timer to reload it again in a short while
		if (reloadTableTimer == nil)	{
			needToReloadNow = YES;
			reloadTableTimer = [NSTimer
				scheduledTimerWithTimeInterval:0.75
				target:self
				selector:@selector(timerThrottledTableReloader:)
				userInfo:nil
				repeats:NO];
		}
		//	else there's a timer- don't do anything, just wait for it to run out
		else	{
		
		}
	}
}
- (void) timerThrottledTableReloader:(NSTimer *)t	{
	//NSLog(@"%s",__func__);
	if (![NSThread isMainThread])	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self timerThrottledTableReloader:t];
		});
		return;
	}
	
	@synchronized (self)	{
		reloadTableTimer = nil;
	}
	NSInteger		selRow = [tableView selectedRow];
	[tableView reloadData];
	if (selRow>=0 && selRow!=NSNotFound)
		[tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selRow] byExtendingSelection:NO];
}


#pragma mark -


- (NSInteger) numberOfRowsInTableView:(NSTableView *)tv	{
	return [completedDownloads lockCount];
}
- (NSView *) tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)tc row:(NSInteger)row	{
	NSView			*returnMe = nil;
	returnMe = [tv makeViewWithIdentifier:@"MainCell" owner:self];
	ISFPDownload	*download = [completedDownloads lockObjectAtIndex:row];
	[(ISFPDownloadTableCellView *)returnMe refreshWithDownload:download];
	return returnMe;
}
- (void) tableViewSelectionDidChange:(NSNotification *)note	{
	//NSLog(@"%s",__func__);
	//	get the download corresponding to the selected row
	NSInteger			selectedRow = [tableView selectedRow];
	ISFPDownload		*dl = (selectedRow==NSNotFound) ? nil : [completedDownloads lockObjectAtIndex:selectedRow];
	NSString			*fragPath = (dl==nil) ? nil : [dl fragPath];
	[isfController loadFile:fragPath];
	[docController loadFile:fragPath];
}


@end

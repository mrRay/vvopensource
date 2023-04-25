#import "ISFConverter.h"
#import "ISFEditorAppDelegate.h"




@implementation ISFConverter


#pragma mark -
#pragma mark open and close sheet stuff


- (void) openGLSLSheet	{
	[mainWindow
		beginSheet:glslWindow
		completionHandler:^(NSInteger result)	{
			
		}];
}
- (void) closeGLSLSheet	{
	[mainWindow endSheet:glslWindow];
}
- (void) openShadertoySheet	{
	[mainWindow
		beginSheet:shadertoyWindow
		completionHandler:^(NSInteger result)	{
			
		}];
}
- (void) closeShadertoySheet	{
	[mainWindow endSheet:shadertoyWindow];
}


#pragma mark -
#pragma mark GLSL Sandbox UI item methods


- (IBAction) glslCancelClicked:(id)sender	{
	NSLog(@"%s",__func__);
	[self closeGLSLSheet];
}
- (IBAction) glslOKClicked:(id)sender	{
	NSLog(@"%s",__func__);
	
	//	parse the URL, assemble the URL of the raw file containing the shader source i need to download
	NSString			*rawURLString = [glslURLField stringValue];
	//NSLog(@"\t\tWARNING: rawURLString is hard-coded in %s",__func__);
	//NSString			*rawURLString = @"http://glslsandbox.com/e#23546.2";
	NSArray				*rawURLComponents = [rawURLString componentsSeparatedByString:@"e#"];
	if (rawURLComponents==nil || [rawURLComponents count]!=2)	{
		NSLog(@"\t\terr, couldn't parse user-supplied URL");
		NSLog(@"\t\tURL was %@, components were %@",rawURLString,rawURLComponents);
		return;
	}
	NSString			*shaderIDString = [rawURLComponents objectAtIndex:1];
	NSString			*sourceBlobURL = VVFMTSTRING(@"glslsandbox.com/item/%@",shaderIDString);
	
	//	download the shader source, parse the reply, extract the shader source from it
	VVCURLDL			*sourceBlobDownloader = [VVCURLDL createWithAddress:sourceBlobURL];
	//NSLog(@"\t\tbeginning source blob download...");
	[sourceBlobDownloader perform];
	//NSLog(@"\t\tsource blob download complete");
	NSDictionary		*parsedDownload = [[sourceBlobDownloader responseString] objectFromJSONString];
	NSString			*rawShaderSource = [parsedDownload objectForKey:@"code"];
	if (rawShaderSource==nil)	{
		NSLog(@"\t\terr: couldn't locate raw shader source in parsed reply");
		NSLog(@"\t\tparsed download is %@",parsedDownload);
		NSLog(@"\t\tresponseString was %@",[sourceBlobDownloader responseString]);
		return;
	}
	NSLog(@"\t\tparsedDownload is %@",parsedDownload);
	
	//	convert the shader source string, export to the user-library ISF folder
	NSMutableDictionary		*suppEntries = MUTDICT;
	[suppEntries setObject:VVFMTSTRING(@"Automatically converted from %@",rawURLString) forKey:@"DESCRIPTION"];
	NSString			*convertedShaderSource = [self _convertGLSLSandboxString:rawShaderSource supplementalJSONDictEntries:suppEntries];
	if (convertedShaderSource==nil)	{
		NSLog(@"\t\terr: couldn't convert shader source, bailing");
		NSLog(@"\t\trawShaderSource was %@",rawShaderSource);
		return;
	}
	//	make sure that the user-level ISF folder exists
	NSFileManager		*fm = [NSFileManager defaultManager];
	NSString			*isfFolder = [@"~/Library/Graphics/ISF" stringByExpandingTildeInPath];
	if (![fm fileExistsAtPath:isfFolder])
		[fm createDirectoryAtPath:isfFolder withIntermediateDirectories:YES attributes:nil error:nil];
	
	NSString			*writeLocation = [VVFMTSTRING(@"~/Library/Graphics/ISF/gs_%@.fs",shaderIDString) stringByExpandingTildeInPath];
	NSLog(@"\t\twriteLocation is %@",writeLocation);
	NSError				*nsErr = nil;
	if (![convertedShaderSource writeToFile:writeLocation atomically:YES encoding:NSUTF8StringEncoding error:&nsErr])	{
		NSLog(@"\t\terr: couldn't write converted shader to file %@",writeLocation);
		NSLog(@"\t\tnsErr was %@",nsErr);
		return;
	}
	
	//	close the sheet
	[self closeGLSLSheet];
	
	//	tell the app to select the shader we just created
	[appDelegate exportCompleteSelectFileAtPath:writeLocation];
}
- (IBAction) glslTextFieldUsed:(id)sender	{
	NSLog(@"%s",__func__);
	//[self glslOKClicked:sender];
}


#pragma mark -
#pragma mark Shadertoy UI item methods


- (IBAction) shadertoyCancelClicked:(id)sender	{
	NSLog(@"%s",__func__);
	[self closeShadertoySheet];
}
- (IBAction) shadertoyOKClicked:(id)sender	{
	//NSLog(@"%s",__func__);
	//	parse the URL, assemble the URL of the raw file containing the shader source i need to download
	//NSString			*rawURLString = @"https://www.shadertoy.com/view/XslGRr";
	//NSLog(@"\t\tWARNING: rawURLString is hard-coded in %s to %@",__func__,rawURLString);
	NSString			*rawURLString = [shadertoyURLField stringValue];
	if (rawURLString==nil || [rawURLString length]<1)	{
		NSLog(@"\t\terr: bailing, rawURLString empty, %s",__func__);
		return;
	}
	
	NSString			*shaderIDString = [rawURLString lastPathComponent];
	if (shaderIDString==nil || [shaderIDString length]<1)	{
		NSLog(@"\t\terr: bailing, shaderIDString epmty, %s",__func__);
		return;
	}
	NSString			*sourceBlobURL = @"https://www.shadertoy.com/shadertoy";
	//NSString			*sourceBlobURL = VVFMTSTRING(@"https://www.shadertoy.com/api/v1/shaders/%@?key=rt8KwN",shaderIDString);
	//NSLog(@"\t\tsourceBlobURL is \"%@\"",sourceBlobURL);
	
	
	
	//	download the shader source, parse the reply, extract the shader source from it
	VVCURLDL			*sourceBlobDownloader = [VVCURLDL createWithAddress:sourceBlobURL];
	//[sourceBlobDownloader appendStringToHeader:@"Cookie: sdtd=0lqkh2g9rv9hpiiieb378ih3p6; _gat=1; _ga=GA1.2.1964087794.1443207051"];
	//[sourceBlobDownloader appendStringToHeader:@"Origin: https://www.shadertoy.com"];
	[sourceBlobDownloader setAcceptedEncoding:@"gzip, deflate"];
	[sourceBlobDownloader appendStringToHeader:@"Accept-Language: en-US,en;q=0.8"];
	//[sourceBlobDownloader setUserAgent:@"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.101 Safari/537.36"];
	[sourceBlobDownloader appendStringToHeader:@"Content-Type: application/x-www-form-urlencoded"];
	//[sourceBlobDownloader appendStringToHeader:@"Cache-Control: max-age=0"];
	[sourceBlobDownloader setReferer:VVFMTSTRING(@"https://www.shadertoy.com/view/%@",shaderIDString)];
	//[sourceBlobDownloader appendStringToHeader:@"Connection: keep-alive"];
	NSDictionary		*postDataDict = OBJDICT(OBJARRAY(shaderIDString),@"shaders");
	NSString			*postDataString = (postDataDict==nil) ? nil : [[VVFMTSTRING(@"s=%@",[[postDataDict JSONString] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]) copy] autorelease];
	//NSString			*postDataString = @"s=%7B%20%22shaders%22%20%3A%20%5B%22Mlj3RR%22%5D%20%7D";
	//if (postDataString==nil || [postDataString length]<1)	{
	//	NSLog(@"\t\terr: postDataString nil in %s, bailing",__func__);
	//	return;
	//}
	//NSLog(@"\t\tpostDataString is \"%@\"",postDataString);
	
	//return;
	
	
	//NSString			*postDataString = @"s=%7B%20%22shaders%22%20%3A%20%5B%224df3DS%22%5D%20%7D";
	//NSLog(@"\t\tWARNING: using hard-coded postDataString, is %@",postDataString);
	[sourceBlobDownloader appendStringToPOST:postDataString];
	//NSLog(@"\t\tbeginning source blob download...");
	[sourceBlobDownloader perform];
	//NSLog(@"\t\tsource blob download complete");
	NSString			*responseString = [sourceBlobDownloader responseString];
	//[responseString writeToFile:[@"~/Desktop/ShaderToyLibCURLDump.txt" stringByExpandingTildeInPath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
	id					parsedDownload = [responseString objectFromJSONString];
	
	
	//	uncomment the following line, the comment out the big chunk above it to use a file on disk to test with (instead of repeatedly downloading stuff)
	//id					parsedDownload = [[NSString stringWithContentsOfFile:[@"~/Desktop/ShaderToyLibCURLDump.txt" stringByExpandingTildeInPath] encoding:NSUTF8StringEncoding error:nil] objectFromJSONString];
	
	
	
	
	//NSLog(@"**********************************************");
	//NSLog(@"\t\tparsedDownload is %@",parsedDownload);
	//NSLog(@"**********************************************");
	NSDictionary		*parsedDict = nil;
	if ([parsedDownload respondsToSelector:@selector(objectAtIndex:)])
		parsedDict = [parsedDownload objectAtIndex:0];
	else
		parsedDict = parsedDownload;
	//parsedDict = [parsedDict objectForKey:@"Shader"];
	
	
	//return;
	
	//	get the array of dicts describing render passes
	NSArray				*renderpassArray = [parsedDict objectForKey:@"renderpass"];
	if (renderpassArray==nil || [renderpassArray count]<1)	{
		NSLog(@"\t\tERR: can't proceed, renderpass array in received JSON blob empty, bailing, %s",__func__);
		//NSLog(@"\t\tpostDataString is %@",postDataString);
		NSLog(@"\t\thttpResponseCode was %ld",[sourceBlobDownloader httpResponseCode]);
		NSLog(@"\t\tcurl err was %ld",[sourceBlobDownloader err]);
		NSLog(@"\t\tresponseData is %@",[sourceBlobDownloader responseData]);
		NSLog(@"\t\tresponseString is %@",[sourceBlobDownloader responseString]);
		NSLog(@"\t\tparsedDownload was %@",parsedDownload);
		return;
	}
	//	the renderpass array from shadertoy has a weird order- the first item is the last step.  the second and subsequent items are the first and subsequent steps.  sort this.
	NSMutableArray		*sortedRenderpassArray = MUTARRAY;
	if ([renderpassArray count]==1)
		[sortedRenderpassArray addObject:[renderpassArray objectAtIndex:0]];
	else	{
		for (int i=1; i<[renderpassArray count]; ++i)
			[sortedRenderpassArray addObject:[renderpassArray objectAtIndex:i]];
		[sortedRenderpassArray addObject:[renderpassArray objectAtIndex:0]];
		
		//	run through the sorted renderpass array, removing any passes that render to audio
		NSMutableIndexSet		*indexesToRemove = nil;
		NSInteger		tmpIndex = 0;
		for (NSDictionary *renderpassDict in sortedRenderpassArray)	{
			NSArray			*outputs = [renderpassDict objectForKey:@"outputs"];
			NSDictionary	*output = (outputs==nil || ![outputs isKindOfClass:[NSArray class]]) ? nil : [outputs objectAtIndex:0];
			NSNumber		*tmpNum = (output==nil || ![output isKindOfClass:[NSDictionary class]]) ? nil : [output objectForKey:@"id"];
			if (tmpNum!=nil && [tmpNum isKindOfClass:[NSNumber class]] && [tmpNum intValue]==38)	{
				if (indexesToRemove == nil)
					indexesToRemove = [[[NSMutableIndexSet alloc] init] autorelease];
				[indexesToRemove addIndex:tmpIndex];
			}
			++tmpIndex;
		}
		if (indexesToRemove != nil)
			[sortedRenderpassArray removeObjectsAtIndexes:indexesToRemove];
		
	}
	//NSLog(@"\t\trenderpassArray is %@",renderpassArray);
	NSLog(@"\t\tsortedRenderpassArray is %@",sortedRenderpassArray);
	
	
	/*
	NSDictionary		*renderpassDict = [sortedRenderpassArray objectAtIndex:0];
	NSString			*rawShaderSource = [renderpassDict objectForKey:@"code"];
	if (rawShaderSource==nil)	{
		NSLog(@"\t\terr: couldn't locate raw shader source in parsed reply");
		//NSLog(@"\t\tpostDataString is %@",postDataString);
		NSLog(@"\t\thttpResponseCode was %ld",[sourceBlobDownloader httpResponseCode]);
		NSLog(@"\t\tcurl err was %u",[sourceBlobDownloader err]);
		NSLog(@"\t\tresponseData is %@",[sourceBlobDownloader responseData]);
		NSLog(@"\t\tresponseString is %@",[sourceBlobDownloader responseString]);
		NSLog(@"\t\tparsed download was %@",parsedDownload);
		return;
	}
	*/
	//	after the conversion is finished, i'll want to show an alert if the shader had either a mouse or a keyboard input informing the user that further conversion may be required
	BOOL					hasMouseOrKeyboardInput = NO;
	//	i'm going to need an array with all the audio inputs so i can find-and-replace them later with more appropriate names
	NSMutableArray			*musicInputNames = MUTARRAY;
	//	the first video-type channel will be renamed to "inputImage" under the assumption that this is a filter, so we need to record that...
	NSString				*inputImageChannelName = nil;
	//	assemble a dict of supplemental entries
	NSMutableDictionary		*suppEntries = MUTDICT;
	NSDictionary			*infoDict = [parsedDict objectForKey:@"info"];
	NSString				*shadertoyUsername = [infoDict objectForKey:@"username"];
	if (shadertoyUsername!=nil && [shadertoyUsername length]<1)
		shadertoyUsername = nil;
	NSString				*shadertoyDescription = [infoDict objectForKey:@"description"];
	if (shadertoyDescription==nil)	{
		if (shadertoyUsername!=nil)
			shadertoyDescription = VVFMTSTRING(@"Automatically converted from %@ by %@",rawURLString, shadertoyUsername);
		else
			shadertoyDescription = VVFMTSTRING(@"Automatically converted from %@",rawURLString);
	}
	else	{
		if (shadertoyUsername!=nil)
			shadertoyDescription = VVFMTSTRING(@"Automatically converted from %@ by %@.  %@",rawURLString, shadertoyUsername, shadertoyDescription);
		else
			shadertoyDescription = VVFMTSTRING(@"Automatically converted from %@.  %@",rawURLString, shadertoyDescription);
	}
	[suppEntries setObject:shadertoyDescription forKey:@"DESCRIPTION"];
	
	NSMutableArray			*categories = MUTARRAY;
	[suppEntries setObject:categories forKey:@"CATEGORIES"];
	NSArray					*shadertoyTags = [infoDict objectForKey:@"tags"];
	if (shadertoyTags!=nil && [shadertoyTags count]>0)
		[categories addObjectsFromArray:shadertoyTags];
	[categories addObject:@"Automatically Converted"];
	[categories addObject:@"Shadertoy"];
	
	NSString				*shadertoyName = [infoDict objectForKey:@"name"];
	if (shadertoyName!=nil && [shadertoyName length]<1)
		shadertoyName = nil;
	else	{
		shadertoyName = [shadertoyName stringByReplacingOccurrencesOfString:@" " withString:@"_"];
		shadertoyName = [shadertoyName stringByReplacingOccurrencesOfString:@"," withString:@"_"];
		shadertoyName = [shadertoyName stringByReplacingOccurrencesOfString:@":" withString:@"-"];
		shadertoyName = [shadertoyName stringByReplacingOccurrencesOfString:@"\t" withString:@"_"];
		shadertoyName = [shadertoyName stringByReplacingOccurrencesOfString:@"_-_" withString:@"-"];
		shadertoyName = [shadertoyName stringByReplacingOccurrencesOfString:@"_-" withString:@"-"];
		shadertoyName = [shadertoyName stringByReplacingOccurrencesOfString:@"-_" withString:@"-"];
	}
	
	//	make a dict containing replacement keys- in shadertoy, "iChannel0" may vary from pass to pass, while ISF needs consistent names spanning passes
	NSMutableArray			*passVarNameSwapDicts = MUTARRAY;
	//	if there's more than one renderpass, make the 'passes' array (stores dicts describing passes), and add it to the supplemental entries dict
	NSMutableArray			*passes = nil;
	if ([sortedRenderpassArray count]>1)	{
		passes = MUTARRAY;
		[suppEntries setObject:passes forKey:@"PASSES"];
	}
	
	//	create arrays for inputs and imports, add them to the entries dict
	__block NSMutableArray			*suppInputs = MUTARRAY;
	[suppEntries setObject:suppInputs forKey:@"INPUTS"];
	__block NSMutableArray			*suppImports = MUTARRAY;
	[suppEntries setObject:suppImports forKey:@"IMPORTED"];
	
	//	create a block that checks to see if a given name is being used by an input
	BOOL	(^IsThisInputNameUnique)(NSString *baseName) = ^(NSString *baseName)	{
		BOOL		returnMe = YES;
		for (NSDictionary *suppInput in suppInputs)	{
			if ([[suppInput objectForKey:@"NAME"] isEqualToString:baseName])	{
				returnMe = NO;
				break;
			}
		}
		return returnMe;
	};
	NSString*	(^UniqueNameForInput)(NSString *baseName) = ^(NSString *baseName)	{
		if (IsThisInputNameUnique(baseName))
			return baseName;
		NSString		*returnMe = nil;
		do	{
			int				tmpInt = 2;
			NSString		*tmpString = VVFMTSTRING(@"%@_%d",baseName,tmpInt);
			if (IsThisInputNameUnique(tmpString))
				returnMe = tmpString;
			++tmpInt;
		} while (returnMe == nil);
		return returnMe;
	};
	//	create a block that checks to see if a given name is being used by an import
	BOOL	(^IsThisImportNameUnique)(NSString *baseName) = ^(NSString *baseName)	{
		//NSLog(@"IsThisImportNameUnique(%@)",baseName);
		BOOL		returnMe = YES;
		for (NSDictionary *suppImport in suppImports)	{
			if ([[suppImport objectForKey:@"NAME"] isEqualToString:baseName])	{
				returnMe = NO;
				break;
			}
		}
		return returnMe;
	};
	NSString*	(^UniqueNameForImport)(NSString *baseName) = ^(NSString *baseName)	{
		//NSLog(@"UniqueNameForImport(%@)",baseName);
		if (IsThisImportNameUnique(baseName))
			return baseName;
		NSString		*returnMe = nil;
		int				tmpInt = 2;
		do	{
			NSString		*tmpString = VVFMTSTRING(@"%@_%d",baseName,tmpInt);
			if (IsThisImportNameUnique(tmpString))
				returnMe = tmpString;
			++tmpInt;
		} while (returnMe == nil);
		return returnMe;
	};
	
	
	//	render passes are identified by 'id', which is now a string.
	__block NSMutableArray		*renderOutputNames = MUTARRAY;
	//	after we sort the array of render passes, we run through each pass and store the name of the output id, so we can convert from render pass index to id
	for (NSDictionary *renderpassDict in sortedRenderpassArray)	{
		//	get the array of OUTPUTS for this pass- if there's more than one, bail with error
		NSArray			*renderpassOutputs = [renderpassDict objectForKey:@"outputs"];
		if (renderpassOutputs==nil || [renderpassOutputs count]>1)	{
			NSLog(@"\t\terr: renderpass outputs array is of unexpected length, bailing, %s",__func__);
			return;
		}
		//	if there aren't any render passes, assume we're fine
		if ([renderpassOutputs count]==0)	{
			continue;
		}
		//	get what i'm presently assuming is the main output
		NSDictionary	*outputDict = [renderpassOutputs objectAtIndex:0];
		if (outputDict==nil || ![outputDict isKindOfClass:[NSDictionary class]])	{
			NSLog(@"\t\terr: renderpass output dict is of unexpected type, bailing, %s",__func__);
			return;
		}
		//	get the id of the main output- '4dfGRr' is the last step (draw to screen).
		id				outputIDString = [outputDict objectForKey:@"id"];
		if (outputIDString==nil || ![outputIDString isKindOfClass:[NSString class]])	{
			NSLog(@"\t\terr: not output id found, bailing, %s",__func__);
			return;
		}
		//	add the output string to the array
		if (![outputIDString isEqualToString:@"4dfGRr"])
			[renderOutputNames addObject:outputIDString];
	}
	NSLog(@"\t\trenderOutputNames are %@",renderOutputNames);
	//	create a block that converts a buffer id string to the name of the buffer
	NSString* (^NameForBufferIDString)(NSString *bufferIDString) = ^(NSString *bufferIDString)	{
		NSString		*returnMe = nil;
		if (bufferIDString == nil)
			return returnMe;
		BOOL		found = NO;
		int			tmpInt = 0;
		for (NSString *tmpString in renderOutputNames)	{
			if ([tmpString isEqualToString:bufferIDString])	{
				found = YES;
				break;
			}
			++tmpInt;
		}
		if (found)	{
			switch (tmpInt)	{
			case 0:
				return @"BufferA";
			case 1:
				return @"BufferB";
			case 2:
				return @"BufferC";
			case 3:
				return @"BufferD";
			}
		}
		return returnMe;
	};
	NSString* (^NameForRenderPassIndex)(int tmpIndex) = ^(int tmpIndex)	{
		NSString		*returnMe = nil;
		if (tmpIndex<0 || tmpIndex>=[renderOutputNames count])
			return returnMe;
		switch (tmpIndex)	{
		case 0:
			return @"BufferA";
		case 1:
			return @"BufferB";
		case 2:
			return @"BufferC";
		case 3:
			return @"BufferD";
		}
		return returnMe;
	};
	
	
	//	create an array with the source code for each of the passes- we'll need this later when we're find-and-replacing source
	NSMutableArray		*sortedShaderSourceArray = MUTARRAY;
	for (NSDictionary *renderpassDict in sortedRenderpassArray)	{
		NSString			*rawShaderSource = [renderpassDict objectForKey:@"code"];
		if (rawShaderSource==nil)	{
			NSLog(@"\t\terr: couldn't locate raw shader source in parsed reply");
			return;
		}
		else
			[sortedShaderSourceArray addObject:rawShaderSource];
	}
	
	
	//	run through the sorted array of render pass dicts- parse the inputs and outputs
	NSInteger			passIndex = 0;
	for (NSDictionary *renderpassDict in sortedRenderpassArray)	{
		
		//	get the array of OUTPUTS for this pass- if there's more than one, bail with error
		NSArray			*renderpassOutputs = [renderpassDict objectForKey:@"outputs"];
		if (renderpassOutputs==nil || [renderpassOutputs count]>1)	{
			NSLog(@"\t\terr: renderpass outputs array B is of unexpected length, bailing, %s",__func__);
			return;
		}
		id				outputIDString = nil;
		//	if there aren't any outputs, assume that this is the final output
		if ([renderpassOutputs count]==0)
			outputIDString = @"4dfGRr";
		//	else there are outputs- we have to get the output id string
		else	{
			//	get what i'm presently assuming is the main output
			NSDictionary	*outputDict = [renderpassOutputs objectAtIndex:0];
			if (outputDict==nil || ![outputDict isKindOfClass:[NSDictionary class]])	{
				NSLog(@"\t\terr: renderpass output dict B is of unexpected type, bailing, %s",__func__);
				return;
			}
			//	get the id of the main output- '4dfGRr' is the last step (draw to screen).
			outputIDString = [outputDict objectForKey:@"id"];
			if (outputIDString==nil || ![outputIDString isKindOfClass:[NSString class]])	{
				NSLog(@"\t\terr: not output id B found, bailing, %s",__func__);
				return;
			}
		}
		
		
		//	if there's a 'passes' array, then i need to make a pass dict and add it to the array
		NSMutableDictionary		*newPassDict = nil;
		if (passes != nil)	{
			newPassDict = MUTDICT;
			[passes addObject:newPassDict];
		}
		
		
		//	'4dfGRr' is the last step (draw to screen).
		if ([outputIDString isEqualToString:@"4dfGRr"])	{
			
		}
		//	else the output id string isn't '4dfGRr'- we're outputting to a buffer
		else	{
			NSString		*targetBufferName = NameForBufferIDString(outputIDString);
			if (targetBufferName != nil)	{
				[newPassDict setObject:targetBufferName forKey:@"TARGET"];
				[newPassDict setObject:NUMBOOL(YES) forKey:@"PERSISTENT"];
				[newPassDict setObject:NUMBOOL(YES) forKey:@"FLOAT"];
			}
		}
		
		
		
		//	make a dict that we'll use to store the names we need to swap
		NSMutableDictionary		*passVarNameSwapDict = MUTDICT;
		[passVarNameSwapDicts addObject:passVarNameSwapDict];
		
		
		
		//	get the array of INPUTS for this pass
		NSArray			*renderpassInputs = [renderpassDict objectForKey:@"inputs"];
		//	run through the inputs
		for (NSDictionary *renderpassInput in renderpassInputs)	{
			NSNumber		*channelNum = [renderpassInput objectForKey:@"channel"];
			NSString		*channelType = [renderpassInput objectForKey:@"type"];
			NSString		*channelSrc = [[renderpassInput objectForKey:@"filepath"] lastPathComponent];
			NSString		*channelName = VVFMTSTRING(@"iChannel%@",channelNum);
			
			//	make sure the channel name is unique (a prior pass may have added an input or something with this name)
			NSString		*uniqueChannelName = nil;
			
			if ([channelType isEqualToString:@"texture"])	{
				//	texture are IMPORTs, so check the supplemental imports array for a dict using this name
				uniqueChannelName = UniqueNameForImport(channelName);
				//	if the unique channel name doesn't match the channel name, we're going to have to replace stuff when we convert the shader source
				if (![uniqueChannelName isEqualToString:channelName])
					[passVarNameSwapDict setObject:uniqueChannelName forKey:channelName];

				
				NSMutableDictionary		*channelDict = MUTDICT;
				//[suppImports setObject:channelDict forKey:channelName];
				[suppImports addObject:channelDict];
				[channelDict setObject:uniqueChannelName forKey:@"NAME"];
				[channelDict setObject:channelSrc forKey:@"PATH"];
			}
			else if ([channelType isEqualToString:@"music"] || [channelType isEqualToString:@"mic"] || [channelType isEqualToString:@"musicstream"])	{
				//	texture are IMPORTs, so check the supplemental imports array for a dict using this name
				uniqueChannelName = UniqueNameForInput(channelName);
				//	if the unique channel name doesn't match the channel name, we're going to have to replace stuff when we convert the shader source
				if (![uniqueChannelName isEqualToString:channelName])
					[passVarNameSwapDict setObject:uniqueChannelName forKey:channelName];
				
				
				[musicInputNames addObject:channelName];
				NSMutableDictionary		*channelDict = MUTDICT;
				[suppInputs addObject:channelDict];
				[channelDict setObject:uniqueChannelName forKey:@"NAME"];
				//[channelDict setObject:@"image" forKey:@"TYPE"];
				[channelDict setObject:@"audio" forKey:@"TYPE"];
			}
			else if ([channelType isEqualToString:@"cubemap"])	{
				//	texture are IMPORTs, so check the supplemental imports array for a dict using this name
				uniqueChannelName = UniqueNameForImport(channelName);
				//	if the unique channel name doesn't match the channel name, we're going to have to replace stuff when we convert the shader source
				if (![uniqueChannelName isEqualToString:channelName])
					[passVarNameSwapDict setObject:uniqueChannelName forKey:channelName];
				
				
				NSMutableDictionary		*channelDict = MUTDICT;
				[suppImports addObject:channelDict];
				[channelDict setObject:uniqueChannelName forKey:@"NAME"];
				//	cubemaps only list one path even though there are six.  so we have to parse the string, then synthesize all the path names from that.  weak, right?
				NSMutableArray	*pathArray = MUTARRAY;
				NSString		*regex = @"([\\w]+)(\\.((jpg)|(png)))";
				for (int i=0; i<6; ++i)	{
					NSString		*modString = nil;
					if (i==0)
						modString = channelSrc;
					else
						modString = [channelSrc stringByReplacingOccurrencesOfRegex:regex withString:VVFMTSTRING(@"$1_%d$2",i)];
					if (modString==nil)	{
						NSLog(@"\t\tERR: couldn't calculate cubemap file name in %s",__func__);
						NSLog(@"\t\tsrc string was %@",channelSrc);
						break;
					}
					[pathArray addObject:modString];
				}
				[channelDict setObject:pathArray forKey:@"PATH"];
				[channelDict setObject:@"cube" forKey:@"TYPE"];
			}
			else if ([channelType isEqualToString:@"video"])	{
				//	texture are IMPORTs, so check the supplemental imports array for a dict using this name
				uniqueChannelName = UniqueNameForInput(channelName);
				//	if the unique channel name doesn't match the channel name, we're going to have to replace stuff when we convert the shader source
				if (![uniqueChannelName isEqualToString:channelName])
					[passVarNameSwapDict setObject:uniqueChannelName forKey:channelName];
				
				
				NSMutableDictionary		*channelDict = MUTDICT;
				[suppInputs addObject:channelDict];
				[channelDict setObject:@"image" forKey:@"TYPE"];
				[channelDict setObject:uniqueChannelName forKey:@"NAME"];
				//	if the inputImageChannelName is still nil, then this video-type channel is going to be turned into the default image input for a video filter...
				if (inputImageChannelName==nil)
					inputImageChannelName = [[channelName copy] autorelease];
			}
			//	buffers are the results of prior rendering passes
			else if ([channelType isEqualToString:@"buffer"])	{
				//	results of prior rendering passes have unique names (A, B, C, or D)
				//NSNumber		*tmpNum = [renderpassInput objectForKey:@"id"];
				//NSString		*bufferName = NameForBufferID([tmpNum intValue]);
				NSString		*tmpString = [renderpassInput objectForKey:@"id"];
				NSString		*bufferName = NameForBufferIDString(tmpString);
				//	since we have a static name, we know we need to replace stuff
				[passVarNameSwapDict setObject:bufferName forKey:channelName];
			}
			//	if i found a keyboard-type input, i want to present the user with an alert informing them that the conversion hasn't been complete
			else if ([channelType isEqualToString:@"keyboard"])	{
				hasMouseOrKeyboardInput = YES;
			}
		}
		
		
		++passIndex;
	}
	/*
	NSLog(@"*****************");
	NSLog(@"\t\tsortedShaderSourceArray is %@",sortedShaderSourceArray);
	NSLog(@"*****************");
	NSLog(@"\t\tsuppEntries is %@",suppEntries);
	NSLog(@"*****************");
	NSLog(@"\t\tpassVarNameSwapDicts is %@",passVarNameSwapDicts);
	NSLog(@"*****************");
	*/
	NSString		*convertedShaderSource = [self _converShaderToySourceArray:sortedShaderSourceArray supplementalJSONDictEntries:suppEntries varSwapNameDicts:passVarNameSwapDicts];
	//NSLog(@"\t\tconvertedShaderSource is %@",convertedShaderSource);
		
	//	if there's a "mouse" input, then there's a mouse and i need to show an alert (we check now because the conversion method will add an "iMouse" input if appropriate)
	if (!IsThisInputNameUnique(@"iMouse"))
		hasMouseOrKeyboardInput = YES;
	
	
	//	convert the shader source string, export to the user-library ISF folder
	//NSString			*convertedShaderSource = [self _convertShaderToyString:rawShaderSource supplementalJSONDictEntries:suppEntries];
	
	if (convertedShaderSource==nil)	{
		NSLog(@"\t\terr: couldn't convert shader source, bailing");
		//NSLog(@"\t\trawShaderSource was %@",rawShaderSource);
		return;
	}
	//	okay, so i converted the shader source- now i want to rename any music-based image inputs to something better than "iChannel"
	/*
	if ([musicInputNames count]>0)	{
		int			tmpIndex = 1;
		for (NSString *musicInputName in musicInputNames)	{
			NSString		*uniqueName = (tmpIndex==1) ? @"AudioWaveformImage" : VVFMTSTRING(@"AudioWaveformImage%d",tmpIndex);
			convertedShaderSource = [convertedShaderSource stringByReplacingOccurrencesOfString:musicInputName withString:uniqueName];
		}
	}
	*/
	//	if i have an inputImageChannelName, i want to find-and-replace that as well
	if (inputImageChannelName!=nil)	{
		convertedShaderSource = [convertedShaderSource stringByReplacingOccurrencesOfString:inputImageChannelName withString:@"inputImage"];
	}
	
	
	//	make sure that the user-level ISF folder exists
	NSFileManager		*fm = [NSFileManager defaultManager];
	NSString			*isfFolder = [@"~/Library/Graphics/ISF" stringByExpandingTildeInPath];
	if (![fm fileExistsAtPath:isfFolder])
		[fm createDirectoryAtPath:isfFolder withIntermediateDirectories:YES attributes:nil error:nil];
	//	now i need to figure out a write location/file name.  try to base this off the "name" from shadertoy, appended by the shadertoy username, and then shadertoy ID
	NSString			*writeFolder = [@"~/Library/Graphics/ISF" stringByExpandingTildeInPath];
	NSString			*writeLocation = nil;
	if (shadertoyName!=nil)
		writeLocation = VVFMTSTRING(@"%@/%@_%@.fs",writeFolder,[shadertoyName stringByReplacingOccurrencesOfString:@"/" withString:@"_"],shaderIDString);
	else
		writeLocation = VVFMTSTRING(@"%@/shadertoy_%@.fs",writeFolder,shaderIDString);
	//NSString			*writeLocation = VVFMTSTRING(@"%@/st_%@.fs",writeFolder,shaderIDString);
	NSError				*nsErr = nil;
	if (![convertedShaderSource writeToFile:writeLocation atomically:YES encoding:NSUTF8StringEncoding error:&nsErr])	{
		NSLog(@"\t\terr: couldn't write converted shader to file %@",writeLocation);
		NSLog(@"\t\tnsErr was %@",nsErr);
		return;
	}
	//	if the shader requires any imported assets, make sure they've been copied to the write folder as well
	
	//NSFileManager		*fm = [NSFileManager defaultManager];
	//[suppImports enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)	{
	//	NSDictionary	*importDict = (NSDictionary *)obj;
	//	NSString		*importFileName = [importDict objectForKey:@"PATH"];
	//	NSString		*importSrcImgPath = VVFMTSTRING(@"%@/%@",[[NSBundle mainBundle] resourcePath],importFileName);
	//	NSString		*importDstImgPath = VVFMTSTRING(@"%@/%@",writeFolder,importFileName);
	//	if (![fm fileExistsAtPath:importDstImgPath isDirectory:nil])	{
	//		//NSLog(@"\t\tfile %@ doesn't exist copying from %@",importDstImgPath,importSrcImgPath);
	//		if (![fm copyItemAtPath:importSrcImgPath toPath:importDstImgPath error:nil])	{
	//			NSLog(@"\t\tERR: problem copying src image from %@ to %@",importSrcImgPath,importDstImgPath);
	//		}
	//	}
	//}];
	
	
	
	for (NSDictionary *importDict in suppImports)	{
		NSString		*cubeFlag = [importDict objectForKey:@"TYPE"];
		if (cubeFlag!=nil && ![cubeFlag isEqualToString:@"cube"])
			cubeFlag = nil;
		
		//	if this import describes a cubemap, the PATH is an array
		if (cubeFlag!=nil)	{
			NSArray			*importFileNames = [importDict objectForKey:@"PATH"];
			for (NSString *importFileName in importFileNames)	{
				NSString		*importSrcImgPath = VVFMTSTRING(@"%@/%@",[[NSBundle mainBundle] resourcePath],importFileName);
				NSString		*importDstImgPath = VVFMTSTRING(@"%@/%@",writeFolder,importFileName);
				if (![fm fileExistsAtPath:importDstImgPath isDirectory:nil])	{
					//NSLog(@"\t\tcubemap file %@ doesn't exist, copying from %@",importDstImgPath,importSrcImgPath);
					if (![fm copyItemAtPath:importSrcImgPath toPath:importDstImgPath error:nil])	{
						NSLog(@"\t\tERR: problem copying cube src image from %@ to %@",importSrcImgPath,importDstImgPath);
					}
				}
			}
		}
		//	else this import doesn't describe a cubemap- just a plain ol' image file
		else	{
			NSString		*importFileName = [importDict objectForKey:@"PATH"];
			NSString		*importSrcImgPath = VVFMTSTRING(@"%@/%@",[[NSBundle mainBundle] resourcePath],importFileName);
			NSString		*importDstImgPath = VVFMTSTRING(@"%@/%@",writeFolder,importFileName);
			if (![fm fileExistsAtPath:importDstImgPath isDirectory:nil])	{
				//NSLog(@"\t\tfile %@ doesn't exist copying from %@",importDstImgPath,importSrcImgPath);
				if (![fm copyItemAtPath:importSrcImgPath toPath:importDstImgPath error:nil])	{
					NSLog(@"\t\tERR: problem copying src image from %@ to %@",importSrcImgPath,importDstImgPath);
				}
			}
		}
	}
	
	//	close the sheet
	[self closeShadertoySheet];
	
	//	if there was a mouse or keyboard input, i need to show an alert
	if (hasMouseOrKeyboardInput)	{
		VVRunAlertPanel(@"Further conversion may be necessary...",
			@"The Shadertoy you're converting has a mouse and/or keyboard input, and may require further conversion to function correctly",
			@"OK",
			nil,
			nil);
	}
	
	//	tell the app to select the shader we just created
	[appDelegate exportCompleteSelectFileAtPath:writeLocation];
	
	
}
- (IBAction) shadertoyTextFieldUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	//[self shadertoyOKClicked:sender];
}


#pragma mark -
#pragma mark actual conversion methods


- (NSString *) _convertGLSLSandboxString:(NSString *)rawFragString supplementalJSONDictEntries:(NSDictionary *)suppEntries	{
	//NSLog(@"******************************");
	//NSLog(@"%s",__func__);
	//NSString			*rawFragString = [shaderTextView string];
	NSMutableString		*tmpMutString = [[NSMutableString stringWithCapacity:0] retain];
	__block BOOL		hasAnotherUniform = NO;	//	set to YES if the script has any other uniforms
	__block BOOL		declaresBackbuffer = NO;
	__block NSString	*backbufferName = nil;
	__block	BOOL		backbufferWasRect = NO;
	__block BOOL		declaresSurfacePosition = NO;
	[rawFragString enumerateLinesUsingBlock:^(NSString *line, BOOL *stop)	{
		//	get rid of any 'time', 'mouse', 'resolution', or 'backbuffer' variable declarations
		if (![line isMatchedByRegex:@"uniform[\\s]+float[\\s]+time;"])	{
			if (![line isMatchedByRegex:@"uniform[\\s]+vec2[\\s]+mouse;"])	{
				if (![line isMatchedByRegex:@"uniform[\\s]+vec2[\\s]+resolution;"])	{
					if (![line isMatchedByRegex:@"uniform[\\s]+sampler2D(Rect)?[\\s]+[bB]"/*@"uniform[\\s]+sampler2D(Rect)?[\\s]+[bB]ack[bB]uffer"*/])	{
						if (![line isMatchedByRegex:@"((varying)|(uniform))[\\s]+vec2[\\s]+surfacePosition"])	{
							if (![line isMatchedByRegex:@"uniform[\\s]+vec2[\\s]+((mouse)|(resolution))[\\s]*,[\\s]*((mouse)|(resolution));"])	{
								//	if there's a "uniform" in this line, log it so i can flag the file as having another uniform (which can potentially be controlled externally)
								NSRange		tmpRange = [line rangeOfString:@"uniform"];
								if (tmpRange.length == 6)
									hasAnotherUniform = YES;
								//	else there weren't any uniform var declarations on this line...
								//else	{
									//	remove any and all texture2D or texture2DRect function calls from this line (there may be more than one!) and replace with the appropriate macro for accessing the texture
									NSMutableString		*newLine = [NSMutableString stringWithCapacity:0];
									[newLine appendString:line];
									do	{
										BOOL		textureLookupWas2D = NO;
										tmpRange = [newLine rangeOfString:@"texture2DRect("];
										if (tmpRange.length!=0)	{
											--tmpRange.length;	//	i searched for the string + left parenthesis
										}
										else	{
											tmpRange = [newLine rangeOfString:@"texture2D("];
											if (tmpRange.length!=0)	{
												--tmpRange.length;	//	i searched for the string + left parenthesis
												textureLookupWas2D = YES;
											}
										}
										if (tmpRange.length!=0)	{
											//NSLog(@"\t\tline matches a texture lookup:\n%@",newLine);
											NSRange			funcNameRange = tmpRange;
											NSMutableArray	*tmpVarArray = [NSMutableArray arrayWithCapacity:0];
											NSRange			fullFuncRangeToReplace = [newLine lexFunctionCallInRange:funcNameRange addVariablesToArray:tmpVarArray];
											if ([tmpVarArray count]==2)	{
												NSString		*newFuncString = nil;
												NSString		*samplerName = [tmpVarArray objectAtIndex:0];
												NSString		*samplerCoord = [tmpVarArray objectAtIndex:1];
												if (textureLookupWas2D)	{
													newFuncString = [NSString stringWithFormat:@"IMG_NORM_PIXEL(%@,mod(%@,1.0))",samplerName,samplerCoord];
												}
												else	{
													newFuncString = [NSString stringWithFormat:@"IMG_PIXEL(%@,%@)",samplerName,samplerCoord];
												}
												[newLine replaceCharactersInRange:fullFuncRangeToReplace withString:newFuncString];
											}
											else if ([tmpVarArray count]==3)	{
												NSString		*newFuncString = nil;
												NSString		*samplerName = [tmpVarArray objectAtIndex:0];
												NSString		*samplerCoord = [tmpVarArray objectAtIndex:1];
												NSString		*samplerBias = [tmpVarArray objectAtIndex:2];
												if (textureLookupWas2D)	{
													newFuncString = [NSString stringWithFormat:@"IMG_NORM_PIXEL(%@,mod(%@,1.0),%@)",samplerName,samplerCoord,samplerBias];
												}
												else	{
													newFuncString = [NSString stringWithFormat:@"IMG_PIXEL(%@,%@,%@)",samplerName,samplerCoord,samplerBias];
												}
												[newLine replaceCharactersInRange:fullFuncRangeToReplace withString:newFuncString];
											}
											else	{
												NSLog(@"\t\tERR: variable count wrong searching for texture lookup: %@, %@",newLine,tmpVarArray);
												break;
											}
										}
									} while (tmpRange.length>0);
									[tmpMutString appendString:@"\n"];
									[tmpMutString appendString:newLine];
								//}
							}
						}
						//	else the line is declaring a 'surfacePosition' variable
						else	{
							declaresSurfacePosition = YES;
						}
					}
					else	{
						//	if there's a backbuffer var declaration, figure out what kind of sampler it is (2D or RECT) and pull its exact name
						declaresBackbuffer = YES;
						NSRange		tmpRange = [line rangeOfString:@"sampler2DRect"];
						if (tmpRange.length!=0)
							backbufferWasRect = YES;
						NSArray		*tmpArray = [line captureComponentsMatchedByRegex:@"uniform[\\s]+sampler2D(Rect)?[\\s]+([^;]+);"];
						if (tmpArray!=nil && [tmpArray count]==3)	{
							backbufferName = [[tmpArray objectAtIndex:2] copy];
							NSLog(@"\t\tbackbufferName discovered to be %@",backbufferName);
						}
					}
				}
			}
		}
	}];
	
	//	figure out if the source code uses the mouse var and backbuffer
	BOOL		usesMouseVar = [tmpMutString isMatchedByRegex:@"([^a-zA-Z0-9_])(mouse)([^a-zA-Z0-9_])"];
	//BOOL		usesBackbufferVar = (backbufferName==nil) ? NO : [tmpMutString isMatchedByRegex:[NSString stringWithFormat:@"([^a-zA-Z0-9_])(%@)([^a-zA-Z0-9_])",backbufferName]];
	BOOL		usesBackbufferVar = NO;
	if (backbufferName != nil)	{
		NSString	*regex = [NSString stringWithFormat:@"([^a-zA-Z0-9_])(%@)([^a-zA-Z0-9_])",backbufferName];
		//NSLog(@"\t\tregex is %@",regex);
		usesBackbufferVar = [tmpMutString isMatchedByRegex:regex];
	}
	BOOL		usesSurfacePositionVar = [tmpMutString isMatchedByRegex:@"([^a-zA-Z0-9_])(surfacePosition)([^a-zA-Z0-9_])"];
	
	//	assemble the JSON dict that describes the filter.  make an NSDict, then convert it to a string using JSONKit
	NSMutableDictionary		*isfDict = [NSMutableDictionary dictionaryWithCapacity:0];
	NSMutableArray			*tmpArray = nil;
	NSMutableDictionary		*tmpDict = nil;
	//	add any supplemental entries passed in with the method!
	[isfDict addEntriesFromDictionary:suppEntries];
	//	put it in an "Automatically Converted" category by default
	[isfDict setObject:[NSArray arrayWithObjects:@"Automatically Converted",@"GLSLSandbox",nil] forKey:@"CATEGORIES"];
	//	make an input (if the mouse is being used)
	tmpArray = [NSMutableArray arrayWithCapacity:0];
	[isfDict setObject:tmpArray forKey:@"INPUTS"];
	if (usesMouseVar)	{
		tmpDict = [NSMutableDictionary dictionaryWithCapacity:0];
		[tmpDict setObject:@"mouse" forKey:@"NAME"];
		[tmpDict setObject:@"point2D" forKey:@"TYPE"];
		NSMutableArray		*minArray = [NSMutableArray arrayWithCapacity:0];
		[minArray addObject:[NSNumber numberWithFloat:0.0]];
		[minArray addObject:[NSNumber numberWithFloat:0.0]];
		[tmpDict setObject:minArray forKey:@"MIN"];
		NSMutableArray		*maxArray = [NSMutableArray arrayWithCapacity:0];
		[maxArray addObject:[NSNumber numberWithFloat:1.0]];
		[maxArray addObject:[NSNumber numberWithFloat:1.0]];
		[tmpDict setObject:maxArray forKey:@"MAX"];
		[tmpArray addObject:tmpDict];
	}
	/*
	if (usesSurfacePositionVar)	{
		tmpDict = [NSMutableDictionary dictionaryWithCapacity:0];
		[tmpDict setObject:@"surfacePosition" forKey:@"NAME"];
		[tmpDict setObject:@"point2D" forKey:@"TYPE"];
		[tmpArray addObject:tmpDict];
	}
	*/
	//	if there's a backbuffer...
	if (usesBackbufferVar && backbufferName!=nil)	{
		//	make a persistent buffer for it
		tmpArray = [NSMutableArray arrayWithCapacity:0];
		[tmpArray addObject:backbufferName];
		[isfDict setObject:tmpArray forKey:@"PERSISTENT_BUFFERS"];
		
		
		//	make the last render pass target the backbuffer
		tmpArray = [NSMutableArray arrayWithCapacity:0];
		[isfDict setObject:tmpArray forKey:@"PASSES"];
		
		tmpDict = [NSMutableDictionary dictionaryWithCapacity:0];
		[tmpArray addObject:tmpDict];
		[tmpDict setObject:backbufferName forKey:@"TARGET"];
		[tmpDict setObject:NUMBOOL(YES) forKey:@"PERSISTENT"];
	}
	
	
	//	replace the 'time' and 'resolution' vars
	NSString		*tmpString = [[tmpMutString copy] autorelease];
	NSString		*regexString = nil;
	
	regexString = @"([^a-zA-Z0-9_])(time)([^a-zA-Z0-9_])";
	while ([tmpString isMatchedByRegex:regexString])	{
		tmpString = [tmpString stringByReplacingOccurrencesOfRegex:regexString withString:@"$1TIME$3"];
	}
	regexString = @"([^a-zA-Z0-9_])(resolution)([^a-zA-Z0-9_])";
	while ([tmpString isMatchedByRegex:regexString])	{
		tmpString = [tmpString stringByReplacingOccurrencesOfRegex:regexString withString:@"$1RENDERSIZE$3"];
	}
	
	if (declaresSurfacePosition && usesSurfacePositionVar)	{
		regexString = @"([^a-zA-Z0-9_])(surfacePosition)([^a-zA-Z0-9_])";
		while ([tmpString isMatchedByRegex:regexString])	{
			tmpString = [tmpString stringByReplacingOccurrencesOfRegex:regexString withString:@"$1vv_FragNormCoord$3"];
		}
	}
	
	
	//	...finally assemble the final string
	//tmpString = [NSString stringWithFormat:@"/*\n%@\n*/\n\n%@",[isfDict JSONStringWithOptions:JKSerializeOptionPretty error:nil],tmpString];
	tmpString = [NSString stringWithFormat:@"/*\n%@\n*/\n\n%@",[isfDict prettyJSONString],tmpString];
	//NSLog(@"%@",tmpString);
	
	
	
	if (backbufferName != nil)	{
		[backbufferName release];
		backbufferName = nil;
	}
	if (tmpMutString != nil)	{
		[tmpMutString release];
		tmpMutString = nil;
	}
	
	return tmpString;
}
- (NSString *) _converShaderToySourceArray:(NSArray *)rawFragStrings supplementalJSONDictEntries:(NSMutableDictionary *)suppEntries varSwapNameDicts:(NSArray *)varSwapNameDicts	{
	//NSLog(@"%s",__func__);
	//	while converting, i need to differentiate between texture lookups for image inputs or imported images, and texture lookups in, like, other functions...so i need a list of all the names of the image inputs/imported images
	__block NSMutableArray		*environmentProvidedSamplers = MUTARRAY;
	NSArray				*tmpSuppArray = nil;
	tmpSuppArray = [suppEntries objectForKey:@"IMPORTED"];
	for (NSDictionary *importDict in tmpSuppArray)	{
		NSString		*tmpString = [importDict objectForKey:@"TYPE"];
		if (tmpString==nil || [tmpString isEqualToString:@"cube"])
			[environmentProvidedSamplers addObject:[importDict objectForKey:@"NAME"]];
	}
	tmpSuppArray = [suppEntries objectForKey:@"INPUTS"];
	//NSLog(@"\t\tinputs are %@",tmpSuppArray);
	for (NSDictionary *inputDict in tmpSuppArray)	{
		NSString		*tmpString = [inputDict objectForKey:@"TYPE"];
		if ([tmpString isEqualToString:@"image"] || [tmpString isEqualToString:@"cube"] || [tmpString isEqualToString:@"audio"] || [tmpString isEqualToString:@"audioFFT"])
			[environmentProvidedSamplers addObject:[inputDict objectForKey:@"NAME"]];
	}
	tmpSuppArray = [suppEntries objectForKey:@"PASSES"];
	for (NSDictionary *passDict in tmpSuppArray)	{
		NSString		*tmpString = [passDict objectForKey:@"TARGET"];
		if (tmpString!=nil)
			[environmentProvidedSamplers addObject:tmpString];
	}
	//NSLog(@"\t\tenvironmentProvidedSamplers are %@",environmentProvidedSamplers);
	//NSLog(@"\t\tvarSwapNameDicts are %@",varSwapNameDicts);
	
	NSDictionary* (^ImportedDictForBufferName)(NSString *bufferName) = ^(NSString *bufferName)	{
		NSDictionary		*returnMe = nil;
		for (NSDictionary *tmpDict in [suppEntries objectForKey:@"IMPORTED"])	{
			NSString			*tmpName = [tmpDict objectForKey:@"NAME"];
			if (tmpName!=nil && [tmpName isEqualToString:bufferName])	{
				returnMe = tmpDict;
				break;
			}
		}
		return returnMe;
	};
	
	
	/*	this is a little complicated.
		- i have an array of dictionaries (one dict per pass)- these dicts describe variables that 
		need to be replaced on a pass-by-pass basis (the key in the dict is the string we have to 
		replace, the object is the string to replace it with).
		- there are a number of standard strings i have to find-and-replace
		- the variables passed to shadertoy's "mainImage()" function have to be find-and-replaced 
		with variable names standard to GLSL 1.2.
		- each "renderpass" in shadertoy is a separate GLSL program, possibly with a bunch of 
		external functions (outside the mainImage() function).  because of this, i have to run 
		through all the shadertoy renderpasses, copying everything *before* mainImage into my ISF 
		program.  then i have to run through the passes a second time, taking the contents of each 
		pass's mainImage function and putting them in if/else PASSINDEX statements.  then i have to 
		run through the passes a third time, copying everything *after* mainImage from each pass 
		into my ISF program.
		- ...while i'm doing all of the above, i have to do a lot of find-and-replacing.  the first 
		and third passses, i have to find-and-replace the var swap dict and the standard strings.  
		the second pass i have to find-and-replace the var swap dict, the standard strings, and the 
		variables passed to the "mainImage()" function.
	
	*/
	
	//	make a block that accepts a mutable string and a var swap name dict and find-and-replaces 
	//	the string with the contents of the var swap name dict and also the standard strings.
	void		(^LineFindAndReplaceBlock)(NSMutableString *targetLine, NSDictionary *varSwapNameDict, NSString *rawString, NSRange targetRangeInRaw) = ^(NSMutableString *targetLine, NSDictionary *varSwapNameDict, NSString *rawString, NSRange targetRangeInRaw)	{
		//NSLog(@"LineFindAndReplaceBlock() ... %@",targetLine);
		//	we have a dictionary of names that need to be replaced- iterate through it, checking every entry against this line
		[varSwapNameDict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *newKey, BOOL *stop) {
			//	the key is the string we want to replace, the object is the new value...
			
			NSString		*tmpRegexString = nil;
			NSString		*tmpReplaceString = nil;
			//	first replace all instances where the string being replaced is surrounded by non-words
			tmpRegexString = VVFMTSTRING(@"([^\\w])(%@)([^\\w])",key);
			tmpReplaceString = VVFMTSTRING(@"$1%@$3",newKey);
			while ([targetLine isMatchedByRegex:tmpRegexString])	{
				[targetLine replaceOccurrencesOfRegex:tmpRegexString withString:tmpReplaceString];
			}
			//	replace all instances where the string being replaced occurs at the beginning of the line
			tmpRegexString = VVFMTSTRING(@"(^%@)([^\\w])",key);
			tmpReplaceString = VVFMTSTRING(@"%@$2",newKey);
			while ([targetLine isMatchedByRegex:tmpRegexString])	{
				[targetLine replaceOccurrencesOfRegex:tmpRegexString withString:tmpReplaceString];
			}
		}];
		
		
		//	now do all the standard find-and-replacing
		{
			//	first replace the global uniforms passed by the ISF spec...
			
			//	we supply a dict- the key is the string to replace, the object is the string we want to replace it with
			__block NSDictionary		*srcStrings = @{
				@"iDate": @"DATE",
				@"iGlobalTime": @"TIME",
				@"iTime": @"TIME",
				@"iChannelTime\\[[0-9]\\]": @"TIME",
				@"iTimeDelta": @"TIMEDELTA",
				@"iResolution": @"RENDERSIZE",
				@"iFrame": @"FRAMEINDEX"
			};
			//	the key is the regex string, the value is the replace string.  using a dict simply to keep the association.
			__block NSDictionary		*regexReplaceStrings = @{
				@"([^\\w_])(%@)([^\\w_])": @"$1%@$3",
				@"(^%@)([^\\w_])": @"%@$2",
				@"([^\\w_])(%@$)":  @"$1%@"
			};
			//	enumerate the keys and values in the dict of strings describing what i want to replace and what i want to replace it with
			[srcStrings enumerateKeysAndObjectsUsingBlock:^(NSString *replaceMe, NSString *replacement, BOOL *stop)	{
				//	...for each pair of strings (replace me/replacement), construct a number of different regex/replace string pairs and apply them.  do this by enumerating the dict of regex/replacement strings.
				[regexReplaceStrings enumerateKeysAndObjectsUsingBlock:^(NSString *regexFmtString, NSString *replaceFmtString, BOOL *stop)	{
					NSString		*regexString = [NSString stringWithFormat:regexFmtString,replaceMe];
					NSString		*replaceString = [NSString stringWithFormat:replaceFmtString,replacement];
					while ([targetLine isMatchedByRegex:regexString])
						[targetLine replaceOccurrencesOfRegex:regexString withString:replaceString];
				}];
			}];
			
			
			NSString		*regexString = nil;
			NSString		*replaceString = nil;
			//	replace the "channel resolution" var instances with calls to IMG_SIZE
			regexString = @"iChannelResolution\\[([0-9]+)\\]";
			while ([targetLine isMatchedByRegex:regexString])	{
				NSArray			*channelResCaptures = [targetLine captureComponentsMatchedByRegex:regexString];
				if (channelResCaptures!=nil && [channelResCaptures count]>=2)	{
					NSString		*channelNumberString = [channelResCaptures objectAtIndex:1];
					NSString		*channelStringToCheck = VVFMTSTRING(@"iChannel%d",[channelNumberString intValue]);
					NSString		*uniqueChannelName = [varSwapNameDict objectForKey:channelStringToCheck];
					if (uniqueChannelName == nil)
						uniqueChannelName = channelStringToCheck;
					replaceString = VVFMTSTRING(@"IMG_SIZE(%@)",uniqueChannelName);
					[targetLine replaceOccurrencesOfRegex:regexString withString:replaceString];
				}
				else
					break;
			}
			
			
			//	now remove any and all texture2D or texture2DRect function calls (there may be more than one!) and replace with the appropriate macro for accessing the texture
			NSRange			tmpRange;
			do	{
				BOOL		textureLookupWas2D = NO;
				BOOL		textureLookupWasCube = NO;
				//tmpRange = [targetLine rangeOfString:@"texture2DRect("];
				tmpRange = [targetLine rangeOfRegex:@"texture2DRect[\\s]*\\("];
				if (tmpRange.length!=0)	{
					//NSLog(@"\t\tfound a texture2DRect() call...");
					--tmpRange.length;	//	i searched for the string + left parenthesis
				}
				else	{
					//tmpRange = [targetLine rangeOfString:@"texture2D("];
					tmpRange = [targetLine rangeOfRegex:@"texture2D[\\s]*\\("];
					if (tmpRange.length!=0)	{
						//NSLog(@"\t\tfound a texture2D() call...");
						--tmpRange.length;	//	i searched for the string + left parenthesis
						textureLookupWas2D = YES;
					}
					else	{
						tmpRange = [targetLine rangeOfRegex:@"texture[\\s]*\\("];
						if (tmpRange.length!=0)	{
							//NSLog(@"\t\tfound a texture() call...");
							--tmpRange.length;	//	i searched for the string + left parenthesis
							//	'texture()' implies a newer GL environment, and may be referring to a cube sampler- so we can't just assume it's 2D and replace it...
							NSMutableArray	*tmpVarArray = [NSMutableArray arrayWithCapacity:0];
							NSRange			fullFuncRangeToReplace = [targetLine lexFunctionCallInRange:tmpRange addVariablesToArray:tmpVarArray];
							//NSLog(@"\t\ttexture() call's vars are %@",tmpVarArray);
							if ([tmpVarArray count]>0 && [environmentProvidedSamplers containsObject:[tmpVarArray objectAtIndex:0]])	{
								//NSLog(@"\t\ttexture() call phase A complete");
								NSDictionary		*importDict = ImportedDictForBufferName([tmpVarArray objectAtIndex:0]);
								//NSLog(@"\t\ttexture() call's importDict is %@",importDict);
								if (importDict!=nil && [importDict objectForKey:@"TYPE"]!=nil)	{
									textureLookupWasCube = YES;
								}
								else
									textureLookupWas2D = YES;
							}
							else
								textureLookupWas2D = YES;
							
						}
						else	{
							//NSLog(@"\t\tdidn't find any texture-related calls!");
						}
					}
				}
				if (tmpRange.length!=0)	{
					//NSLog(@"\t\tline matches a texture lookup:\n%@",targetLine);
					NSRange			funcNameRange = tmpRange;
					NSMutableArray	*tmpVarArray = [NSMutableArray arrayWithCapacity:0];
					NSRange			fullFuncRangeToReplace = [targetLine lexFunctionCallInRange:funcNameRange addVariablesToArray:tmpVarArray];
					//NSRange			absoluteFuncNameRange = NSMakeRange(funcNameRange.location+targetRangeInRaw.location, funcNameRange.length);
					//NSRange			fullFuncRangeToReplace = [rawString lexFunctionCallInRange:absoluteFuncNameRange addVariablesToArray:tmpVarArray];
					//NSLog(@"\t\tfullFuncRangeToReplace is %@, variables are %@",NSStringFromRange(fullFuncRangeToReplace),tmpVarArray);
					//	i only want to replace this function if the sampler is one of the samplers i'm converting/replacing
					if ([tmpVarArray count]>0 && [environmentProvidedSamplers containsObject:[tmpVarArray objectAtIndex:0]])	{
						if ([tmpVarArray count]==2)	{
							NSString		*newFuncString = nil;
							NSString		*samplerName = [tmpVarArray objectAtIndex:0];
							NSString		*samplerCoord = [tmpVarArray objectAtIndex:1];
							if (textureLookupWas2D)	{
								newFuncString = [NSString stringWithFormat:@"IMG_NORM_PIXEL(%@,mod(%@,1.0))",samplerName,samplerCoord];
							}
							else if (textureLookupWasCube)	{
								newFuncString = [NSString stringWithFormat:@"textureCube(%@,%@)",samplerName,samplerCoord];
							}
							else	{
								newFuncString = [NSString stringWithFormat:@"IMG_PIXEL(%@,%@)",samplerName,samplerCoord];
							}
							[targetLine replaceCharactersInRange:fullFuncRangeToReplace withString:newFuncString];
						}
						else if ([tmpVarArray count]==3)	{
							NSString		*newFuncString = nil;
							NSString		*samplerName = [tmpVarArray objectAtIndex:0];
							NSString		*samplerCoord = [tmpVarArray objectAtIndex:1];
							NSString		*samplerBias = [tmpVarArray objectAtIndex:2];
							if (textureLookupWas2D)	{
								newFuncString = [NSString stringWithFormat:@"IMG_NORM_PIXEL(%@,mod(%@,1.0),%@)",samplerName,samplerCoord,samplerBias];
							}
							else if (textureLookupWasCube)	{
								newFuncString = [NSString stringWithFormat:@"textureCube(%@,%@)",samplerName,samplerCoord];
							}
							else	{
								newFuncString = [NSString stringWithFormat:@"IMG_PIXEL(%@,%@,%@)",samplerName,samplerCoord,samplerBias];
							}
							[targetLine replaceCharactersInRange:fullFuncRangeToReplace withString:newFuncString];
						}
						else	{
							NSLog(@"\t\tERR: variable count wrong searching for texture lookup: %@, %@",targetLine,tmpVarArray);
							break;
						}
						//NSLog(@"\t\tafter replacing, targetLine is %@",targetLine);
					}
					//	else the sampler in this texture lookup isn't a sampler being controlled by the ISF environment...
					else	{
						tmpRange.length = 0;
					}
				}
			} while (tmpRange.length>0);
		}
		
		
		
	};
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	//	make a mutable string- this is what we're building the results for the source code in
	NSMutableString		*tmpMutString = [[NSMutableString stringWithCapacity:0] retain];
	[tmpMutString appendString:@"\n"];
	
	
	
	int				passIndex = 0;
	//	run through the array of frag shader sources- the goal is to copy everything BEFORE the mainImage() function into the string.
	for (NSString *rawFragString in rawFragStrings)	{
		//	get the variable swap dict, i'll need it for find-and-replacing...
		NSMutableDictionary		*varSwapNameDict = [varSwapNameDicts objectAtIndex:passIndex];
		//	run through the frag shader source, line by line
		__block NSRange		thisLineRange = NSMakeRange(0,0);
		[rawFragString enumerateLinesUsingBlock:^(NSString *line, BOOL *stop)	{
			//	update the range of this line within the raw frag string (we need to know the range because we're going to need to lex function calls that may span multiple lines)
			thisLineRange.location = thisLineRange.location + thisLineRange.length;
			thisLineRange.length = [line length]+1;
			//	make sure that the range is within the bounds of the raw frag string!
			if (thisLineRange.location+thisLineRange.length>=[rawFragString length])
				thisLineRange.length = [rawFragString length]-thisLineRange.location;
			
			//	if this is the mainImage function, stop- we're done, this pass we're only copying the stuff before the mainImage function
			if ([line isMatchedByRegex:@"[\\r\\n\\s]*void[\\s]+mainImage"])	{
				*stop = YES;
			}
			//	else we're still before the mainImage function- we have to do some find-and-replacing while copying stuff...
			else	{
				__block NSMutableString		*newLine = [NSMutableString stringWithCapacity:0];
				[newLine appendString:line];
				
				LineFindAndReplaceBlock(newLine,varSwapNameDict,rawFragString,NSMakeRange(thisLineRange.location,[newLine length]));
				
				[tmpMutString appendString:newLine];
				[tmpMutString appendString:@"\n"];
			}
		}];
		
		++passIndex;
	}
	
	
	
	
	//	make the "main" function entry
	[tmpMutString appendString:@"void main() {"];
	[tmpMutString appendString:@"\n"];
	
	
	
	
	//			this next bit here goes through every pass and replaces the contents of the mainImage functions
	
	//	we need to know if there are multiple passes, and the index of the pass we're parsing
	BOOL			multiplePasses = ([rawFragStrings count]>1) ? YES : NO;
	passIndex = 0;
	//	run through the array of frag shader sources again- this time we're going to find "mainImage" and convert all the code within it
	for (NSString *rawFragString in rawFragStrings)	{
		//	if there are multiple passes, we have to start off by adding a bracket with an if/else defining the PASSINDEX
		if (multiplePasses)	{
			if (passIndex == 0)
				[tmpMutString appendFormat:@"\tif (PASSINDEX == %d)\t{",passIndex];
			else
				[tmpMutString appendFormat:@"\telse if (PASSINDEX == %d)\t{",passIndex];
		}
		
		//	get the variable swap dict
		NSMutableDictionary		*varSwapNameDict = [varSwapNameDicts objectAtIndex:passIndex];
		//	now we have to do all the conversion!
		__block BOOL		beforeMainImage = YES;
		__block BOOL		afterMainImage = NO;
		__block int			mainImageFunctionBracketCount = 0;	//	...in order to determine when i'm parsing text within the mainImage() function i need to keep a count of the brackets- when it hits 0, i've left the function!
		__block NSString	*fragColorVarNameString = [@"fragColor" retain];	//	RETAINED because the pool will drain before we're done converting and it crashes if you don't.  the 'mainImage' function in a shadertoy passes in a 4-element vec named 'fragColor' by default (gl_FragColor in "old school" GLSL) and a 2-element vec named 'fragCoord' by default.  the variable names (fragColor and fragCoord) may be different, so we parse them here
		__block NSString	*fragCoordVarNameString = [@"fragCoord" retain];	//	see above
		__block NSRange		thisLineRange = NSMakeRange(0,0);
		__block NSRange		mainImageFunctionRange = NSMakeRange(0,0);	//	the range of the full "mainImage" function (and all its vars and stuff) in the raw frag string
		__block NSRange		firstBracketOfMainImageFunction = NSMakeRange(0,0);
		[rawFragString enumerateLinesUsingBlock:^(NSString *line, BOOL *stop)	{
			//	update the range of this line within the raw frag string (we need to know the range because we're going to need to lex function calls that may span multiple lines)
			thisLineRange.location = thisLineRange.location + thisLineRange.length;
			thisLineRange.length = [line length]+1;
			//	make sure that the range is within the bounds of the raw frag string!
			if (thisLineRange.location+thisLineRange.length>=[rawFragString length])
				thisLineRange.length = [rawFragString length]-thisLineRange.location;
			
			//	shadertoy shaders don't have a main() function- instead they have a mainImage() function, which isn't really compatible with the GLSL 1.2 environment i'm writing this for right now.
			NSString			*mainImageRegex = @"[\\r\\n\\s]*void[\\s]+(mainImage)";
			if ([line isMatchedByRegex:mainImageRegex])	{
				//	first of all, reset the mainImage function bracket count stuff, then increment it (if appropriate)
				mainImageFunctionBracketCount = 0;
				
				//	the default variable names passed to mainImage (fragColor and fragCoord) may be different in this shader- we have to capture them to find out
				NSRange				mainImageStringRange = [line rangeOfRegex:mainImageRegex capture:1];
				mainImageStringRange.location += thisLineRange.location;
				NSMutableArray		*mainImageVars = MUTARRAY;
				mainImageFunctionRange = [rawFragString lexFunctionCallInRange:mainImageStringRange addVariablesToArray:mainImageVars];
				if ([mainImageVars count]>=1)	{
					VVRELEASE(fragColorVarNameString);
					//fragColorVarNameString = [[mainImageVars objectAtIndex:0] copy];
					NSArray		*tmpArray = [[mainImageVars objectAtIndex:0] componentsSeparatedByRegex:@"[^\\w_]"];
					if (tmpArray!=nil)
						fragColorVarNameString = [[tmpArray lastObject] copy];
				}
				if ([mainImageVars count]>=2)	{
					VVRELEASE(fragCoordVarNameString);
					//fragCoordVarNameString = [[mainImageVars objectAtIndex:1] copy];
					NSArray		*tmpArray = [[mainImageVars objectAtIndex:1] componentsSeparatedByRegex:@"[^\\w_]"];
					if (tmpArray!=nil)
						fragCoordVarNameString = [[tmpArray lastObject] copy];
				}
				//NSLog(@"\t\tfragColorVarNameString is %@, fragCoordVarNameString is %@",fragColorVarNameString,fragCoordVarNameString);
				//	i still need to know where the first bracket of the mainImage() function is (it may be on another line, so i have to find it now)
				NSRange			tmpRange = NSMakeRange(mainImageFunctionRange.location+mainImageFunctionRange.length, 1);
				while (firstBracketOfMainImageFunction.length<1)	{
					if ([[rawFragString substringWithRange:tmpRange] isEqualToString:@"{"])	{
						firstBracketOfMainImageFunction = tmpRange;
					}
					++tmpRange.location;
				}
				
				
				//	if this line contains the bracket after the mainImage function...
				if ((firstBracketOfMainImageFunction.length>0)	&&
				((firstBracketOfMainImageFunction.location+firstBracketOfMainImageFunction.length)<=(thisLineRange.location+thisLineRange.length)))	{
					//	update the bracket count (only update the count if this line contains the first bracket after the mainImage function!)
					mainImageFunctionBracketCount += [[line componentsSeparatedByString:@"{"] count];
					mainImageFunctionBracketCount -= [[line componentsSeparatedByString:@"}"] count];
					//	we're not longer before the mainImage function...
					beforeMainImage = NO;
				}
			}
			//	else this line isn't the mainImage function
			else	{
				//NSRange			tmpRange;
				//	create a mutable string, populate it initially with the line i'm enumerating
				__block NSMutableString		*newLine = [NSMutableString stringWithCapacity:0];
				[newLine appendString:line];
				
				//	if i'm before the mainImage function, empty it- we already handled this content in the previous pass
				if (beforeMainImage && !afterMainImage)	{
					//	if this line contains the bracket after the mainImage function...
					if ((firstBracketOfMainImageFunction.length>0)	&&
					((firstBracketOfMainImageFunction.location+firstBracketOfMainImageFunction.length)<=(thisLineRange.location+thisLineRange.length)))	{
						//	update the bracket count (only update the count if this line contains the first bracket after the mainImage function!)
						mainImageFunctionBracketCount += [[line componentsSeparatedByString:@"{"] count];
						mainImageFunctionBracketCount -= [[line componentsSeparatedByString:@"}"] count];
						//	we're not longer before the mainImage function...
						beforeMainImage = NO;
						//	empty the line, then copy everything after the first bracket of the main function (which is in this line!) to it
						[newLine setString:@""];
						NSRange			tmpRange;
						tmpRange.location = firstBracketOfMainImageFunction.location + 1;
						tmpRange.length = thisLineRange.location + thisLineRange.length - tmpRange.location;
						if (tmpRange.length>0)
							[newLine appendString:[rawFragString substringWithRange:tmpRange]];
					}
					//	else this line doesn't contain the bracket after the mainImage function
					else	{
						//	empty the string- we're "before the main image", but also before the first bracket of the mainImage function- we are most likely somewhere before or within the mainImage function declaration
						[newLine setString:@""];
					}
				}
				//	if i'm still within the mainImage function, replace occurrences of fragCoord and fragColor with their GLSL 1.2 equivalents
				else if (!beforeMainImage && !afterMainImage)	{
					NSString		*regexString = nil;
					regexString = VVFMTSTRING(@"([^\\w])(%@)([^\\w])",fragColorVarNameString);
					while ([newLine isMatchedByRegex:regexString])	{
						[newLine replaceOccurrencesOfRegex:regexString withString:@"$1gl_FragColor$3"];
					}
					//	now i want to replace "fragCoord" with "gl_FragCoord", but "fragCoord" is vec2, and "gl_FragCoord" is vec4.
					//	first try to replace "fragCoord." (fragCoord-period) with "gl_FragColor."
					regexString = VVFMTSTRING(@"([^\\w])(%@\\.)([a-z])",fragCoordVarNameString);
					while ([newLine isMatchedByRegex:regexString])	{
						[newLine replaceOccurrencesOfRegex:regexString withString:@"$1gl_FragCoord.$3"];
					}
					//	now try to just replace "fragCoord" with "gl_FragColor.xy"
					regexString = VVFMTSTRING(@"([^\\w])(%@)([^\\w])",fragCoordVarNameString);
					while ([newLine isMatchedByRegex:regexString])	{
						[newLine replaceOccurrencesOfRegex:regexString withString:@"$1gl_FragCoord.xy$3"];
					}
				
				
					//	this does the replacing on lines that start with the values i'm replacing...
					regexString = VVFMTSTRING(@"(^%@)([^\\w])",fragColorVarNameString);
					while ([newLine isMatchedByRegex:regexString])	{
						[newLine replaceOccurrencesOfRegex:regexString withString:@"gl_FragColor$2"];
					}
					//	now i want to replace "fragCoord" with "gl_FragCoord", but "fragCoord" is vec2, and "gl_FragCoord" is vec4.
					//	first try to replace "fragCoord." (fragCoord-period) with "gl_FragColor."
					regexString = VVFMTSTRING(@"(^%@\\.)([^\\w])",fragCoordVarNameString);
					while ([newLine isMatchedByRegex:regexString])	{
						[newLine replaceOccurrencesOfRegex:regexString withString:@"gl_FragCoord$2"];
					}
					//	now try to just replace "fragCoord" with "gl_FragColor.xy"
					regexString = VVFMTSTRING(@"(^%@)([^\\w])",fragCoordVarNameString);
					while ([newLine isMatchedByRegex:regexString])	{
						[newLine replaceOccurrencesOfRegex:regexString withString:@"gl_FragCoord$2"];
					}
					
					
					//	now do all the find-and-replacing
					LineFindAndReplaceBlock(newLine,varSwapNameDict,rawFragString,NSMakeRange(thisLineRange.location,[newLine length]));
					
					
					
					//	update the count of mainImage function brackets in both directions
					mainImageFunctionBracketCount += [[newLine componentsSeparatedByString:@"{"] count];
					mainImageFunctionBracketCount -= [[newLine componentsSeparatedByString:@"}"] count];
					//	if the mainImage bracket count hits 0, then i'm no longer within the mainImage function!
					if (mainImageFunctionBracketCount<=0)	{
						afterMainImage = YES;
						*stop = YES;
					}
					
					//	if there are multiple passes, everything is indented- add a tab
					if (multiplePasses)
						[newLine insertString:@"\t" atIndex:0];
				}
				
				
				
				if ([newLine length]>0)	{
					[tmpMutString appendString:@"\n"];
					[tmpMutString appendString:newLine];
				}
			}
		}];
		
		
		//	if there are multiple passes, don't forget to close the PASSINDEX bracket!
		if (multiplePasses)	{
			//[tmpMutString appendString:@"}\n"];
			[tmpMutString appendString:@"\n"];
		}
		
		
		//	we have to release these (we explicitly retained them earlier)
		VVAUTORELEASE(fragColorVarNameString);
		VVAUTORELEASE(fragCoordVarNameString);
		
		//	increment the pass index!
		++passIndex;
	}
	
	//	close our main function
	if (multiplePasses)
		[tmpMutString appendString:@"}"];
	[tmpMutString appendString:@"\n"];
	
	
	
	
	//	run through the array of frag shader sources again- this time we're going to copy everything after "mainImage"...
	passIndex = 0;
	for (NSString *rawFragString in rawFragStrings)	{
		//	get the variable swap dict, i'll need it for find-and-replacing...
		__block NSMutableDictionary		*varSwapNameDict = [varSwapNameDicts objectAtIndex:passIndex];
		//	set up a bunch of other vars used to track where i am within the main image
		__block BOOL		beforeMainImage = YES;
		__block BOOL		afterMainImage = NO;
		__block int			mainImageFunctionBracketCount = 0;	//	...in order to determine when i'm parsing text within the mainImage() function i need to keep a count of the brackets- when it hits 0, i've left the function!
		__block NSRange		thisLineRange = NSMakeRange(0,0);
		__block NSRange		mainImageFunctionRange = NSMakeRange(0,0);	//	the range of the full "mainImage" function (and all its vars and stuff) in the raw frag string
		__block NSRange		firstBracketOfMainImageFunction = NSMakeRange(0,0);
		[rawFragString enumerateLinesUsingBlock:^(NSString *line, BOOL *stop)	{
			//	update the range of this line within the raw frag string (we need to know the range because we're going to need to lex function calls that may span multiple lines)
			thisLineRange.location = thisLineRange.location + thisLineRange.length;
			thisLineRange.length = [line length]+1;
			//	make sure that the range is within the bounds of the raw frag string!
			if (thisLineRange.location+thisLineRange.length>=[rawFragString length])
				thisLineRange.length = [rawFragString length]-thisLineRange.location;
			
			NSString			*mainImageRegex = @"[\\r\\n\\s]*void[\\s]+(mainImage)";
			if ([line isMatchedByRegex:mainImageRegex])	{
				//	first of all, reset the mainImage function bracket count stuff, then increment it (if appropriate)
				mainImageFunctionBracketCount = 0;
				//	the default variable names passed to mainImage (fragColor and fragCoord) may be different in this shader- we have to capture them to find out
				NSRange				mainImageStringRange = [line rangeOfRegex:mainImageRegex capture:1];
				mainImageStringRange.location += thisLineRange.location;
				NSMutableArray		*mainImageVars = MUTARRAY;
				mainImageFunctionRange = [rawFragString lexFunctionCallInRange:mainImageStringRange addVariablesToArray:mainImageVars];
				//	i still need to know where the first bracket of the mainImage() function is (it may be on another line, so i have to find it now)
				NSRange			tmpRange = NSMakeRange(mainImageFunctionRange.location+mainImageFunctionRange.length, 1);
				while (firstBracketOfMainImageFunction.length<1)	{
					if ([[rawFragString substringWithRange:tmpRange] isEqualToString:@"{"])	{
						firstBracketOfMainImageFunction = tmpRange;
					}
					++tmpRange.location;
				}
				
				
				//	if this line contains the bracket after the mainImage function...
				if ((firstBracketOfMainImageFunction.length>0)	&&
				((firstBracketOfMainImageFunction.location+firstBracketOfMainImageFunction.length)<=(thisLineRange.location+thisLineRange.length)))	{
					//	update the bracket count (only update the count if this line contains the first bracket after the mainImage function!)
					mainImageFunctionBracketCount += [[line componentsSeparatedByString:@"{"] count];
					mainImageFunctionBracketCount -= [[line componentsSeparatedByString:@"}"] count];
					//	we're not longer before the mainImage function...
					beforeMainImage = NO;
				}
			}
			//	else this line isn't the mainImage function
			else	{
				//NSRange			tmpRange;
				
				//	if i'm before the mainImage function, do nothing
				if (beforeMainImage && !afterMainImage)	{
					//	if this line contains the bracket after the mainImage function...
					if ((firstBracketOfMainImageFunction.length>0)	&&
					((firstBracketOfMainImageFunction.location+firstBracketOfMainImageFunction.length)<=(thisLineRange.location+thisLineRange.length)))	{
						//	update the bracket count (only update the count if this line contains the first bracket after the mainImage function!)
						mainImageFunctionBracketCount += [[line componentsSeparatedByString:@"{"] count];
						mainImageFunctionBracketCount -= [[line componentsSeparatedByString:@"}"] count];
						//	we're not longer before the mainImage function...
						beforeMainImage = NO;
					}
					//	else this line doesn't contain the bracket after the mainImage function
					else	{
						//	do nothing- we're "before the main image", but also before the first bracket of the mainImage function- we are most likely somewhere before or within the mainImage function declaration
					}
				}
				//	if i'm still within the mainImage function, replace occurrences of fragCoord and fragColor with their GLSL 1.2 equivalents
				else if (!beforeMainImage && !afterMainImage)	{
					//	update the count of mainImage function brackets in both directions
					mainImageFunctionBracketCount += [[line componentsSeparatedByString:@"{"] count];
					mainImageFunctionBracketCount -= [[line componentsSeparatedByString:@"}"] count];
					//	if the mainImage bracket count hits 0, then i'm no longer within the mainImage function!
					if (mainImageFunctionBracketCount<=0)
						afterMainImage = YES;
				}
				//	if i'm after the mainImage function...
				else if (!beforeMainImage && afterMainImage)	{
					__block NSMutableString		*newLine = [[NSMutableString stringWithCapacity:0] retain];
					[newLine appendString:line];
					//NSLog(@"\t\tbefore, newLine is %@",newLine);
					LineFindAndReplaceBlock(newLine,varSwapNameDict,rawFragString,NSMakeRange(thisLineRange.location,[newLine length]));
					//NSLog(@"\t\tafter, newLine is %@",newLine);
					
					
					
					[tmpMutString appendString:[newLine copy]];
					[tmpMutString appendString:@"\n"];
					
					[newLine autorelease];
				}
			}
			
			
			/*
			if (beforeMainImage)	{
				if ([line isMatchedByRegex:@"[\\r\\n\\s]*void[\\s]+mainImage"])	{
					beforeMainImage = NO;
					mainImageFunctionBracketCount += [[line componentsSeparatedByString:@"{"] count];
					mainImageFunctionBracketCount -= [[line componentsSeparatedByString:@"}"] count];
				}
			}
			else if (!beforeMainImage && !afterMainImage)	{
				mainImageFunctionBracketCount += [[line componentsSeparatedByString:@"{"] count];
				mainImageFunctionBracketCount -= [[line componentsSeparatedByString:@"}"] count];
				if (mainImageFunctionBracketCount <= 0)
					afterMainImage = YES;
			}
			else if (!beforeMainImage && afterMainImage)	{
				[tmpMutString appendString:line];
				[tmpMutString appendString:@"\n"];
			}
			*/
		}];
		
		//	increment the pass index
		++passIndex;
	}
	
	
	
	//	figure out if the source code uses the mouse var
	BOOL		usesMouseVar = [tmpMutString isMatchedByRegex:@"([^\\w_])(iMouse)([^\\w_])"];
	//	if i'm using the mouse var, make 2d input for it
	if (usesMouseVar)	{
		NSMutableArray		*tmpInputs = [suppEntries objectForKey:@"INPUTS"];
		if (tmpInputs == nil)	{
			tmpInputs = MUTARRAY;
			[suppEntries setObject:tmpInputs forKey:@"INPUTS"];
		}
		
		NSMutableDictionary	*tmpInput = MUTDICT;
		[tmpInputs addObject:tmpInput];
		[tmpInput setObject:@"iMouse" forKey:@"NAME"];
		[tmpInput setObject:@"point2D" forKey:@"TYPE"];
		//	...no min/max array, we want to pass in raw pixel coords
	}
	
	
	
	//	we're pretty much done, we just have to turn the supplemental entries dict into a JSON string and return it along with the modified source code
	return VVFMTSTRING(@"/*\n%@\n*/\n\n%@",[suppEntries prettyJSONString],tmpMutString);
}


@end

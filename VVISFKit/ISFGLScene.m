#import "ISFGLScene.h"
#import <DDMathParser/DDMathParser.h>
#import "ISFAttrib.h"
#import "ISFStringAdditions.h"




MutLockDict		*_ISFImportedImages = nil;
NSString			*_ISFVertPassthru = nil;
NSString			*_ISFVertVarDec = nil;
NSString 			*_ISFVertInitFunc = nil;
NSString			*_ISFMacro2DString = nil;
NSString			*_ISFMacro2DBiasString = nil;
NSString			*_ISFMacro2DRectString = nil;
NSString			*_ISFMacro2DRectBiasString = nil;




@implementation ISFGLScene


+ (void) initialize	{
	if (_ISFImportedImages==nil)	{
		_ISFImportedImages = [[MutLockDict alloc] init];
		
		//	load the various supporting txt files which contain data which will be used to assemble frag and vertex shaders from ISF files 
		NSBundle		*mb = [NSBundle bundleForClass:[ISFGLScene class]];
		_ISFVertPassthru = [[NSString stringWithContentsOfFile:[mb pathForResource:@"ISFGLScenePassthru" ofType:@"vs"] encoding:NSUTF8StringEncoding error:nil] retain];
		_ISFVertVarDec = [[NSString stringWithContentsOfFile:[mb pathForResource:@"ISFGLSceneVertShaderIncludeVarDec" ofType:@"txt"] encoding:NSUTF8StringEncoding error:nil] retain];
		_ISFVertInitFunc = [[NSString stringWithContentsOfFile:[mb pathForResource:@"ISFGLSceneVertShaderIncludeInitFunc" ofType:@"txt"] encoding:NSUTF8StringEncoding error:nil] retain];
		_ISFMacro2DString = [[NSString stringWithContentsOfFile:[mb pathForResource:@"ISFGLMacro2D" ofType:@"txt"] encoding:NSUTF8StringEncoding error:nil] retain];
		_ISFMacro2DBiasString = [[NSString stringWithContentsOfFile:[mb pathForResource:@"ISFGLMacro2DBias" ofType:@"txt"] encoding:NSUTF8StringEncoding error:nil] retain];
		_ISFMacro2DRectString = [[NSString stringWithContentsOfFile:[mb pathForResource:@"ISFGLMacro2DRect" ofType:@"txt"] encoding:NSUTF8StringEncoding error:nil] retain];
		_ISFMacro2DRectBiasString = [[NSString stringWithContentsOfFile:[mb pathForResource:@"ISFGLMacro2DRectBias" ofType:@"txt"] encoding:NSUTF8StringEncoding error:nil] retain];
		if (_ISFVertPassthru==nil ||
		_ISFVertVarDec==nil ||
		_ISFVertInitFunc==nil ||
		_ISFMacro2DString==nil ||
		_ISFMacro2DBiasString==nil ||
		_ISFMacro2DRectString==nil ||
		_ISFMacro2DRectBiasString==nil)	{
			NSLog(@"ERR: missing resources that should be located with ISF's parent framework, %s",__func__);
		}
	}
}
- (id) initWithSharedContext:(NSOpenGLContext *)c	{
	return [self initWithSharedContext:c pixelFormat:[GLScene defaultPixelFormat] sized:NSMakeSize(80,60)];
}
- (id) initWithSharedContext:(NSOpenGLContext *)c sized:(NSSize)s	{
	return [self initWithSharedContext:c pixelFormat:[GLScene defaultPixelFormat] sized:s];
}
- (id) initWithSharedContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p	{
	return [self initWithSharedContext:c pixelFormat:p sized:NSMakeSize(80,60)];
}
- (id) initWithSharedContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p sized:(NSSize)s	{
	self = [super initWithSharedContext:c pixelFormat:p sized:s];
	if (self!=nil)	{
	}
	return self;
}
- (id) initWithContext:(NSOpenGLContext *)c	{
	return [self initWithContext:c sized:NSMakeSize(80,60)];
}
- (id) initWithContext:(NSOpenGLContext *)c sharedContext:(NSOpenGLContext *)sc	{
	return [self initWithContext:c sharedContext:sc sized:NSMakeSize(80,60)];
}
- (id) initWithContext:(NSOpenGLContext *)c sized:(NSSize)s	{
	return [self initWithContext:c sharedContext:nil sized:s];
}
- (id) initWithContext:(NSOpenGLContext *)c sharedContext:(NSOpenGLContext *)sc sized:(NSSize)s	{
	self = [super initWithContext:c sharedContext:sc sized:s];
	if (self!=nil)	{
	}
	return self;
}
- (void) generalInit	{
	[super generalInit];
	propertyLock = OS_SPINLOCK_INIT;
	//performClear = NO;
	throwExceptions = NO;
	filePath = nil;
	fileName = nil;
	fileDescription = nil;
	fileCredits = nil;
	categoryNames = [MUTARRAY retain];
	inputs = [[MutLockArray alloc] init];
	imageInputs = [[MutLockArray alloc] init];
	imageImports = [[MutLockArray alloc] init];
	renderSize = NSMakeSize(1,1);
	swatch = [[VVStopwatch alloc] init];
	bufferRequiresEval = NO;
	persistentBufferArray = [[MutLockArray alloc] init];
	tempBufferArray = [[MutLockArray alloc] init];
	passes = [[MutLockArray alloc] init];
	passIndex = 1;
	jsonString = nil;
	vertShaderSource = nil;
	fragShaderSource = nil;
	compiledInputTypeString = nil;
	renderSizeUniformLoc = -1;
	passIndexUniformLoc = -1;
	timeUniformLoc = -1;
	[self setRenderTarget:self];
	[self setRenderSelector:@selector(renderCallback:)];
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	OSSpinLockLock(&propertyLock);
	VVRELEASE(filePath);
	VVRELEASE(fileName);
	VVRELEASE(fileDescription);
	VVRELEASE(fileCredits);
	OSSpinLockUnlock(&propertyLock);
	VVRELEASE(categoryNames);
	VVRELEASE(inputs);
	VVRELEASE(imageInputs);
	[self _clearImageImports];
	VVRELEASE(imageImports);
	VVRELEASE(swatch);
	VVRELEASE(persistentBufferArray);
	VVRELEASE(tempBufferArray);
	VVRELEASE(passes);
	OSSpinLockLock(&srcLock);
	VVRELEASE(jsonString);
	VVRELEASE(vertShaderSource);
	VVRELEASE(fragShaderSource);
	VVRELEASE(compiledInputTypeString);
	OSSpinLockUnlock(&srcLock);
	[super dealloc];
}


- (void) useFile:(NSString *)p	{
	[self useFile:p resetTimer:YES];
}
- (void) useFile:(NSString *)p resetTimer:(BOOL)r	{
	//NSLog(@"%s ... %@",__func__,p);
	OSSpinLockLock(&propertyLock);
	VVRELEASE(filePath);
	VVRELEASE(fileName);
	VVRELEASE(fileDescription);
	VVRELEASE(fileCredits);
	VVRELEASE(categoryNames);
	OSSpinLockUnlock(&propertyLock);
	[inputs lockRemoveAllObjects];
	[imageInputs lockRemoveAllObjects];
	[self _clearImageImports];
	bufferRequiresEval = NO;
	[persistentBufferArray lockRemoveAllObjects];
	[tempBufferArray lockRemoveAllObjects];
	[passes lockRemoveAllObjects];
	
	OSSpinLockLock(&srcLock);
	VVRELEASE(jsonString);
	VVRELEASE(vertShaderSource);
	VVRELEASE(fragShaderSource);
	VVRELEASE(compiledInputTypeString);
	OSSpinLockUnlock(&srcLock);
	
	pthread_mutex_lock(&renderLock);
	VVRELEASE(vertexShaderString);
	VVRELEASE(fragmentShaderString);
	pthread_mutex_unlock(&renderLock);
	
	if (_ISFVertPassthru==nil ||
	_ISFVertVarDec==nil ||
	_ISFVertInitFunc==nil ||
	_ISFMacro2DString==nil ||
	_ISFMacro2DBiasString==nil ||
	_ISFMacro2DRectString==nil ||
	_ISFMacro2DRectBiasString==nil)	{
		NSLog(@"ERR: missing resources that should be located with ISF's parent framework, %s",__func__);
		if (throwExceptions)
			[NSException raise:@"Missing Resources" format:@"Unable to load file, missing text resources that should be with ISF's framework."];
		return;
	}
	
	NSString		*rawFile = (p==nil) ? nil : [NSString stringWithContentsOfFile:p encoding:NSUTF8StringEncoding error:nil];
	if (rawFile == nil)	{
		if (throwExceptions && p!=nil)
			[NSException raise:@"Invalid File" format:@"file %@ couldn't be loaded, encoding unrecognized",p];
		return;
	}
	
	OSSpinLockLock(&propertyLock);
	NSString		*localFilePath = p;
	NSString		*localFileName = [p lastPathComponent];
	filePath = [p retain];
	fileName = [localFileName retain];
	OSSpinLockUnlock(&propertyLock);
	
	//	there should be a JSON blob at the very beginning of the file describing the script's attributes and parameters- this is inside comments...
	NSRange			openCommentRange;
	NSRange			closeCommentRange;
	Class			stringClass = [NSString class];
	Class			dictClass = [NSDictionary class];
	Class			arrayClass = [NSArray class];
	Class			numClass = [NSNumber class];
	Class			colorClass = [NSColor class];
	openCommentRange = [rawFile rangeOfString:@"/*"];
	closeCommentRange = [rawFile rangeOfString:@"*/"];
	if (openCommentRange.length<=0 || closeCommentRange.length<=0)	{
		if (throwExceptions)
			[NSException raise:@"Missing JSON Blob" format:@"file %@ was missing the initial JSON blob describing it",p];
		return;
	}
	else	{
		//	remove the JSON blob, save it as one string- save everything else as the raw shader source string
		OSSpinLockLock(&srcLock);
		VVRELEASE(fragShaderSource);
		VVRELEASE(jsonString);
		fragShaderSource = [[rawFile substringWithRange:NSMakeRange(closeCommentRange.location+closeCommentRange.length, [rawFile length]-(closeCommentRange.location+closeCommentRange.length))] retain];
		jsonString = [[rawFile substringWithRange:NSMakeRange(openCommentRange.location+openCommentRange.length, closeCommentRange.location-(openCommentRange.location+openCommentRange.length))] retain];
		//	parse the JSON dict, turning it into a dictionary and values
		id				jsonObject = (jsonString==nil) ? nil : [jsonString objectFromJSONString];
		if (jsonObject==nil)	{
			NSLog(@"\t\terror parsing json object in %s, string was \"%@\"",__func__,jsonString);
		}
		OSSpinLockUnlock(&srcLock);
		
		//	run through the dictionaries and values parsed from JSON, creating the appropriate attributes
		if (![jsonObject isKindOfClass:dictClass])	{
			NSLog(@"\t\terr: jsonObject was wrong class, %@",localFilePath);
			if (throwExceptions)
				[NSException raise:@"Malformed JSON Blob" format:@"JSON blob in file %@ was malformed in some way",p];
			return;
		}
		else	{
			NSString		*localFileDescription = [jsonObject objectForKey:@"DESCRIPTION"];
			NSString		*localFileCredits = [jsonObject objectForKey:@"CREDIT"];
			NSArray			*catsArray = [jsonObject objectForKey:@"CATEGORIES"];
			
			OSSpinLockLock(&propertyLock);
			if (localFileDescription!=nil && [localFileDescription isKindOfClass:stringClass])	{
				VVRELEASE(fileDescription);
				fileDescription = [localFileDescription retain];
			}
			if (localFileCredits!=nil && [localFileCredits isKindOfClass:stringClass])	{
				VVRELEASE(fileCredits);
				fileCredits = [localFileCredits retain];
			}
			if (catsArray!=nil && [catsArray isKindOfClass:arrayClass])	{
				VVRELEASE(categoryNames);
				categoryNames = [catsArray mutableCopy];
			}
			OSSpinLockUnlock(&propertyLock);
			
			
			//	parse the persistent buffers from the JSON dict
			id				anObj = [jsonObject objectForKey:@"PERSISTENT_BUFFERS"];
			if (anObj != nil)	{
				//	if the persistent buffers object is an array, check that they're strings and add accordingly
				if ([anObj isKindOfClass:arrayClass])	{
					for (NSString *bufferName in anObj)	{
						if ([bufferName isKindOfClass:stringClass])	{
							ISFTargetBuffer		*newBuffer = [ISFTargetBuffer create];
							[newBuffer setName:bufferName];
							[persistentBufferArray lockAddObject:newBuffer];
						}
					}
				}
				//	else if the persistent buffers object is a dict, add and populate the dict accordingly
				else if ([anObj isKindOfClass:dictClass])	{
					for (NSString *bufferName in [anObj allKeys])	{
						NSDictionary		*bufferDescription = [anObj objectForKey:bufferName];
						if (bufferDescription!=nil && [bufferDescription isKindOfClass:dictClass])	{
							ISFTargetBuffer		*newBuffer = [ISFTargetBuffer create];
							[newBuffer setName:bufferName];
							NSString				*tmpString = nil;
							tmpString = [bufferDescription objectForKey:@"WIDTH"];
							if (tmpString != nil)	{
								[newBuffer setTargetWidthString:tmpString];
								bufferRequiresEval = YES;
							}
							tmpString = [bufferDescription objectForKey:@"HEIGHT"];
							if (tmpString != nil)	{
								[newBuffer setTargetHeightString:tmpString];
								bufferRequiresEval = YES;
							}
							NSNumber			*tmpNum = [bufferDescription objectForKey:@"FLOAT"];
							if (tmpNum!=nil && [tmpNum isKindOfClass:[NSNumber class]] && [tmpNum boolValue])
								[newBuffer setFloatFlag:YES];
							else
								[newBuffer setFloatFlag:NO];
							[persistentBufferArray lockAddObject:newBuffer];
						}
					}
				}
			}
			//	parse the array of imported images
			anObj = [jsonObject objectForKey:@"IMPORTED"];
			if (anObj != nil)	{
				//	if i'm going to be importing files, get the path to the directory that contains the file i'm loading
				NSString		*parentDirectory = [p stringByDeletingLastPathComponent];
				NSFileManager	*fm = [NSFileManager defaultManager];
				
				
				//	this is the block that we're going to use to parse an import dict and import its contents.
				void		(^parseImportedImageDict)(NSDictionary *importDict) = ^(NSDictionary *importDict){
					//	figure out the full path to the image i want to import
					NSString		*samplerName = [importDict objectForKey:@"NAME"];
					if (samplerName != nil)	{
						NSString		*cubeFlag = [importDict objectForKey:@"TYPE"];
						if (cubeFlag!=nil && ![cubeFlag isEqualToString:@"cube"])
							cubeFlag = nil;
						
						VVBuffer		*importedBuffer = nil;
						//	are we a cube map?
						if (cubeFlag!=nil)	{
							//	the PATH var has an array of strings with the paths to the six files...
							NSArray			*partialPaths = [importDict objectForKey:@"PATH"];
							if (![partialPaths isKindOfClass:[NSArray class]] || [partialPaths count]!=6)	{
								if (throwExceptions)
									[NSException raise:@"Conflicting filter definition" format:@"supplied PATH for an imported cube map wasn't an array or wasn't sized appropriately, %@",partialPaths];
							}
							
							//	assemble an array with the full paths for all the files
							NSMutableArray		*fullPaths = MUTARRAY;
							NSMutableArray		*images = MUTARRAY;
							for (NSString *partialPath in partialPaths)	{
								NSString		*tmpFullPath = [VVFMTSTRING(@"%@/%@",parentDirectory,partialPath) stringByStandardizingPath];
								[fullPaths addObject:tmpFullPath];
								
							}
							
							//	check to see if the cube map has already been loaded- if not, do so now
							[_ISFImportedImages wrlock];
							importedBuffer = [_ISFImportedImages objectForKey:[fullPaths objectAtIndex:0]];
							if (importedBuffer!=nil)	{
								//	the num at the userInfo stores how many inputs are using the buffer
								NSNumber		*tmpNum = [importedBuffer userInfo];
								if (tmpNum != nil)
									[importedBuffer setUserInfo:[NSNumber numberWithInt:[tmpNum intValue]+1]];
							}
							[_ISFImportedImages unlock];
							
							//	if the cube map hasn't been loaded yet, do so now
							if (importedBuffer==nil)	{
								//	make sure all the files exist, create NSImages from them
								for (NSString *fullPath in fullPaths)	{
									//	if any of the files from the array of paths don't exist, throw an error
									if (![fm fileExistsAtPath:fullPath])	{
										if (throwExceptions)
											[NSException raise:@"Missing filter resource" format:@"can't load cube map, file %@ is missing",fullPath];
										return;
									}
									//	if i can't make an image from any of the paths, throw an error
									NSImage		*tmpImage = [[NSImage alloc] initWithContentsOfFile:fullPath];
									if (tmpImage==nil)	{
										if (throwExceptions)
											[NSException raise:@"Can't load image" format:@"can't load image for file %@",fullPath];
										return;
									}
									[images addObject:tmpImage];
									[tmpImage release];
								}
								//	load the images i assembled into a GL texture, store the cube texture in the array of imported buffers
								importedBuffer = [_globalVVBufferPool allocCubeMapTextureForImages:images];
								if (importedBuffer==nil)	{
									if (throwExceptions)
										[NSException raise:@"filter resource can't be loaded" format:@"can't make a cubemap from files %@",fullPaths];
									return;
								}
								//	the num at the userInfo stores how many inputs are using the buffer
								[importedBuffer setUserInfo:[NSNumber numberWithInt:1]];
								[_ISFImportedImages lockSetObject:importedBuffer forKey:[fullPaths objectAtIndex:0]];
								[importedBuffer release];
								
								
							}
							
							//	assuming i've imported or located the appropriate file, make an attrib for it and store it
							if (importedBuffer!=nil)	{
								ISFAttrib			*newAttrib = nil;
								ISFAttribVal		minVal;
								ISFAttribVal		maxVal;
								ISFAttribVal		defVal;
								ISFAttribVal		idenVal;
								minVal.imageVal = 0;
								maxVal.imageVal = 0;
								defVal.imageVal = 0;
								idenVal.imageVal = 0;
								newAttrib = [ISFAttrib
									createWithName:samplerName
									description:[fullPaths objectAtIndex:0]
									label:nil
									type:ISFAT_Cube
									values:minVal:maxVal:defVal:idenVal:nil:nil];
								[newAttrib setUserInfo:importedBuffer];
								[imageImports lockAddObject:newAttrib];
							}
						}
						//	else it's just a normal image...
						else	{
							//	if the PATH object isn't a string, throw an error
							NSString		*partialPath = [importDict objectForKey:@"PATH"];
							if (![partialPath isKindOfClass:[NSString class]])	{
								if (throwExceptions)
									[NSException raise:@"Conflicting filter definition" format:@"supplied PATH for an imported image wasn't a string, %@",partialPath];
								return;
							}
							NSString		*fullPath = [VVFMTSTRING(@"%@/%@",parentDirectory,partialPath) stringByStandardizingPath];
							
							//	check to see if the cube map has already been loaded- if not, do so now
							[_ISFImportedImages wrlock];
							importedBuffer = [_ISFImportedImages objectForKey:fullPath];
							if (importedBuffer!=nil)	{
								//	the num at the userInfo stores how many inputs are using the buffer
								NSNumber		*tmpNum = [importedBuffer userInfo];
								if (tmpNum != nil)
									[importedBuffer setUserInfo:[NSNumber numberWithInt:[tmpNum intValue]+1]];
							}
							[_ISFImportedImages unlock];
							
							//	if the image hasn't been loaded yet, do so now
							if (importedBuffer==nil)	{
								//	if the path doesn't describe a valid file, throw an error
								if (![fm fileExistsAtPath:fullPath])	{
									if (throwExceptions)
										[NSException raise:@"Missing filter resource" format:@"can't load, file %@ is missing",partialPath];
									return;
								}
								//	load the image at the path, store it in the array of imported buffers
								NSImage		*tmpImg = [[NSImage alloc] initWithContentsOfFile:fullPath];
								NSSize		tmpImgSize = [tmpImg size];
								//	upload the image to a GL texture
								importedBuffer = (tmpImg==nil) ? nil : [_globalVVBufferPool allocBufferForNSImage:tmpImg prefer2DTexture:(tmpImgSize.width==tmpImgSize.height)?YES:NO];
								VVRELEASE(tmpImg);
								//	throw an error if i can't load the image
								if (importedBuffer==nil)	{
									if (throwExceptions)
										[NSException raise:@"filter resource can't be loaded" format:@"file %@ was found, but can't be loaded",partialPath];
									return;
								}
								//	the num at the userInfo stores how many inputs are using the buffer
								[importedBuffer setUserInfo:[NSNumber numberWithInt:1]];
								[_ISFImportedImages lockSetObject:importedBuffer forKey:fullPath];
								[importedBuffer release];
							}
							
							//	assuming i've imported or located the appropriate file, make an attrib for it and store it
							if (importedBuffer!=nil)	{
								ISFAttrib			*newAttrib = nil;
								ISFAttribVal		minVal;
								ISFAttribVal		maxVal;
								ISFAttribVal		defVal;
								ISFAttribVal		idenVal;
								minVal.imageVal = 0;
								maxVal.imageVal = 0;
								defVal.imageVal = 0;
								idenVal.imageVal = 0;
								newAttrib = [ISFAttrib
									createWithName:samplerName
									description:fullPath
									label:nil
									type:ISFAT_Image
									values:minVal:maxVal:defVal:idenVal:nil:nil];
								[newAttrib setUserInfo:importedBuffer];
								[imageImports lockAddObject:newAttrib];
								//NSLog(@"\t\tnewAttrib is %@",newAttrib);
							}
						}
						
					}
				};
				
				
				//	if i'm importing files from a dictionary, execute the block on all the elements in the dict (each element is another dict describing the thing to import)
				if ([anObj isKindOfClass:dictClass])	{
					//	each key is the name by which the imported image will be available, and the object is the dict describing the image to import
					[anObj enumerateKeysAndObjectsUsingBlock:^(id importDictKey, id importDict, BOOL *stop)	{
						if ([importDict isKindOfClass:[NSDictionary class]])	{
							//	if the import dict doesn't have a "NAME" key, make a new mut dict and add it
							if ([importDict objectForKey:@"NAME"]==nil)	{
								NSMutableDictionary		*tmpMutDict = [importDict mutableCopy];
								[tmpMutDict setObject:importDictKey forKey:@"NAME"];
								parseImportedImageDict(tmpMutDict);
								[tmpMutDict autorelease];
							}
							//	else the import dict already had a name key, just add it straightaway
							else	{
								parseImportedImageDict(importDict);
							}
						}
					}];
				}
				//	else it's an array- an array full of dictionaries, each of which describes a file to import
				else if ([anObj isKindOfClass:arrayClass])	{
					//	run through all the dictionaries in 'IMPORTED' (each dict describes a file to be imported)
					for (id subObj in (NSArray *)anObj)	{
						if ([subObj isKindOfClass:dictClass])	{
							parseImportedImageDict(subObj);
						}
					}
				}
				
			}
			//	parse the PASSES array of dictionaries describing the various passes (which may need temp buffers)
			anObj = [jsonObject objectForKey:@"PASSES"];
			if (anObj!=nil && [anObj isKindOfClass:arrayClass])	{
				for (NSDictionary *rawPassDict in (NSArray *)anObj)	{
					//NSLog(@"\t\trawPassDict is %@",rawPassDict);
					if ([rawPassDict isKindOfClass:dictClass])	{
						//	make a new render pass and populate it from the raw pass dict
						ISFRenderPass		*newPass = [ISFRenderPass create];
						NSString				*tmpBufferName = [rawPassDict objectForKey:@"TARGET"];
						if (tmpBufferName != nil && [tmpBufferName isKindOfClass:stringClass])	{
							[newPass setTargetName:tmpBufferName];
							//	find the target buffer for this pass- first check the persistent buffers
							ISFTargetBuffer			*targetBuffer = [self findPersistentBufferNamed:tmpBufferName];
							//	if i couldn't find a persistent buffer, create one, add it as a temp buffer
							if (targetBuffer == nil)	{
								targetBuffer = [ISFTargetBuffer create];
								[targetBuffer setName:tmpBufferName];
								[tempBufferArray lockAddObject:targetBuffer];
							}
							//	update the width/height stuff for the target buffer
							NSString			*tmpString = nil;
							tmpString = [rawPassDict objectForKey:@"WIDTH"];
							if (tmpString != nil && [tmpString isKindOfClass:stringClass])	{
								[targetBuffer setTargetWidthString:tmpString];
								bufferRequiresEval = YES;
							}
							tmpString = [rawPassDict objectForKey:@"HEIGHT"];
							if (tmpString != nil && [tmpString isKindOfClass:stringClass])	{
								[targetBuffer setTargetHeightString:tmpString];
								bufferRequiresEval = YES;
							}
							NSNumber			*tmpNum = [rawPassDict objectForKey:@"FLOAT"];
							if (tmpNum!=nil && [tmpNum isKindOfClass:[NSNumber class]] && [tmpNum boolValue])
								[targetBuffer setFloatFlag:YES];
							else
								[targetBuffer setFloatFlag:NO];
						}
						//	add the new render pass to the array of render passes
						[passes lockAddObject:newPass];
					}
				}
			}
			//	if at this point there aren't any passes, add an empty pass
			if ([passes count]<1)
				[passes lockAddObject:[ISFRenderPass create]];
			//	parse the INPUTS from the JSON dict (these form the basis of user interaction)
			NSArray			*inputsArray = [jsonObject objectForKey:@"INPUTS"];
			if (inputsArray!=nil && [inputsArray isKindOfClass:arrayClass])	{
				
				ISFAttrib		*newAttrib = nil;
				ISFAttribValType	newAttribType = ISFAT_Event;
				NSString			*typeString = nil;
				NSString			*descString = nil;
				NSString			*labelString = nil;
				ISFAttribVal	minVal;
				ISFAttribVal	maxVal;
				ISFAttribVal	defVal;
				ISFAttribVal	idenVal;
				NSArray				*labelArray = nil;
				NSArray				*valArray = nil;
				BOOL				isImageInput = NO;
				BOOL				isFilterImageInput = NO;
				
				for (NSDictionary *inputDict in inputsArray)	{
					if ([inputDict isKindOfClass:dictClass])	{
						NSString			*inputKey = [inputDict objectForKey:@"NAME"];
						if (inputKey != nil)	{
							newAttrib = nil;
							labelArray = nil;
							valArray = nil;
							typeString = [inputDict objectForKey:@"TYPE"];
							if (![typeString isKindOfClass:stringClass])
								typeString = nil;
							descString = [inputDict objectForKey:@"DESCRIPTION"];
							if (![descString isKindOfClass:stringClass])
								descString = nil;
							labelString = [inputDict objectForKey:@"LABEL"];
							if (![labelString isKindOfClass:stringClass])
								labelString = nil;
							//NSLog(@"\t\tattrib key is %@, typeString is %@",inputKey,typeString);
							isImageInput = NO;
							isFilterImageInput = NO;
							
							//	if the typeString is nil (or was set to nil because it wasn't a string), the attrib simply shouldn't exist
							if (typeString == nil)	{
								inputKey = nil;
							}
							else if ([typeString isEqualToString:@"image"])	{
								newAttribType = ISFAT_Image;
								minVal.imageVal = 0;
								maxVal.imageVal = 0;
								defVal.imageVal = 0;
								idenVal.imageVal = 0;
								isImageInput = YES;
								if ([inputKey isEqualToString:@"inputImage"])
									isFilterImageInput = YES;
							}
							else if ([typeString isEqualToString:@"cube"])	{
								newAttribType = ISFAT_Cube;
								minVal.imageVal = 0;
								maxVal.imageVal = 0;
								defVal.imageVal = 0;
								idenVal.imageVal = 0;
							}
							else if ([typeString isEqualToString:@"float"])	{
								newAttribType = ISFAT_Float;
								NSNumber			*tmpNum = nil;
								tmpNum = [inputDict objectForKey:@"MIN"];
								minVal.floatVal = (tmpNum==nil || ![tmpNum isKindOfClass:numClass]) ? 0.0 : [tmpNum floatValue];
								tmpNum = [inputDict objectForKey:@"MAX"];
								maxVal.floatVal = (tmpNum==nil || ![tmpNum isKindOfClass:numClass]) ? 1.0 : [tmpNum floatValue];
								tmpNum = [inputDict objectForKey:@"DEFAULT"];
								defVal.floatVal = (tmpNum==nil || ![tmpNum isKindOfClass:numClass]) ? 0.5 : [tmpNum floatValue];
								tmpNum = [inputDict objectForKey:@"IDENTITY"];
								idenVal.floatVal = (tmpNum==nil || ![tmpNum isKindOfClass:numClass]) ? 0.5 : [tmpNum floatValue];
							}
							else if ([typeString isEqualToString:@"bool"])	{
								newAttribType = ISFAT_Bool;
								NSNumber			*tmpNum = nil;
								minVal.floatVal = (tmpNum==nil) ? NO : [tmpNum floatValue];
								maxVal.floatVal = (tmpNum==nil) ? YES : [tmpNum floatValue];
								tmpNum = [inputDict objectForKey:@"DEFAULT"];
								defVal.boolVal = (tmpNum==nil || ![tmpNum isKindOfClass:numClass]) ? YES : [tmpNum boolValue];
								tmpNum = [inputDict objectForKey:@"IDENTITY"];
								idenVal.boolVal = (tmpNum==nil || ![tmpNum isKindOfClass:numClass]) ? YES : [tmpNum boolValue];
							}
							else if ([typeString isEqualToString:@"long"])	{
								newAttribType = ISFAT_Long;
								NSNumber			*tmpNum = nil;
								//	look for "VALUES" and "LABELS" arrays
								valArray = [inputDict objectForKey:@"VALUES"];
								labelArray = [inputDict objectForKey:@"LABELS"];
								if (valArray!=nil && [valArray isKindOfClass:arrayClass] && labelArray!=nil && [labelArray isKindOfClass:arrayClass] && [valArray count]==[labelArray count])	{
									minVal.longVal = 0.0;
									maxVal.longVal = 10.0;
								}
								else	{
									valArray = nil;
									labelArray = nil;
									//	if i couldn't find the arrays, look for min/max
									tmpNum = [inputDict objectForKey:@"MIN"];
									minVal.longVal = (tmpNum==nil || ![tmpNum isKindOfClass:numClass]) ? 0.0 : [tmpNum longValue];
									tmpNum = [inputDict objectForKey:@"MAX"];
									maxVal.longVal = (tmpNum==nil || ![tmpNum isKindOfClass:numClass]) ? 10.0 : [tmpNum longValue];
								}
								tmpNum = [inputDict objectForKey:@"DEFAULT"];
								defVal.longVal = (tmpNum==nil || ![tmpNum isKindOfClass:numClass]) ? 5.0 : [tmpNum longValue];
								tmpNum = [inputDict objectForKey:@"IDENTITY"];
								idenVal.longVal = (tmpNum==nil || ![tmpNum isKindOfClass:numClass]) ? 5.0 : [tmpNum longValue];
							}
							else if ([typeString isEqualToString:@"event"])	{
								//NSLog(@"********* ERR: %s",__func__);
								newAttribType = ISFAT_Event;
								minVal.eventVal = NO;
								maxVal.eventVal = YES;
								defVal.eventVal = NO;
								idenVal.eventVal = NO;
							}
							else if ([typeString isEqualToString:@"color"])	{
								newAttribType = ISFAT_Color;
								NSColor				*tmpColor = nil;
								for (int i=0;i<4;++i)	{
									minVal.colorVal[i] = 0.0;
									maxVal.colorVal[i] = 1.0;
								}
								tmpColor = [inputDict objectForKey:@"DEFAULT"];
								if (tmpColor==nil)
									bzero(defVal.colorVal, sizeof(GLfloat)*4);
								else if ([tmpColor isKindOfClass:arrayClass])	{
									NSArray		*tmpArray = (NSArray *)tmpColor;
									int			tmpInt = 0;
									for (NSNumber *tmpNum in (NSArray *)tmpArray)	{
										defVal.colorVal[tmpInt] = [tmpNum floatValue];
										++tmpInt;
									}
								}
								else if ([tmpColor isKindOfClass:colorClass])	{
									CGFloat			tmpVals[4];
									[tmpColor getComponents:tmpVals];
									for (int i=0; i<4; ++i)
										defVal.colorVal[i] = tmpVals[i];
								}
								
								tmpColor = [inputDict objectForKey:@"IDENTITY"];
								if (tmpColor==nil)
									bzero(idenVal.colorVal, sizeof(GLfloat)*4);
								else if ([tmpColor isKindOfClass:arrayClass])	{
									NSArray		*tmpArray = (NSArray *)tmpColor;
									int			tmpInt = 0;
									for (NSNumber *tmpNum in (NSArray *)tmpArray)	{
										idenVal.colorVal[tmpInt] = [tmpNum floatValue];
										++tmpInt;
									}
								}
								else if ([tmpColor isKindOfClass:colorClass])	{
									CGFloat			tmpVals[4];
									[tmpColor getComponents:tmpVals];
									for (int i=0; i<4; ++i)
										idenVal.colorVal[i] = tmpVals[i];
								}
							}
							else if ([typeString isEqualToString:@"point2D"])	{
								//NSLog(@"********* ERR: %s",__func__);
								newAttribType = ISFAT_Point2D;
								for (int i=0; i<2; ++i)	{
									minVal.point2DVal[i] = 0.0;
									maxVal.point2DVal[i] = 0.0;
								}
								
								NSArray		*tmpArray = nil;
								tmpArray = [inputDict objectForKey:@"DEFAULT"];
								if (tmpArray!=nil && [tmpArray isKindOfClass:arrayClass])	{
									NSNumber		*tmpNum = [tmpArray objectAtIndex:0];
									if (tmpNum!=nil && [tmpNum isKindOfClass:numClass])
										defVal.point2DVal[0] = [tmpNum floatValue];
									tmpNum = [tmpArray objectAtIndex:1];
									if (tmpNum!=nil && [tmpNum isKindOfClass:numClass])
										defVal.point2DVal[1] = [tmpNum floatValue];
								}
								tmpArray = [inputDict objectForKey:@"IDENTITY"];
								if (tmpArray!=nil && [tmpArray isKindOfClass:arrayClass])	{
									NSNumber		*tmpNum = [tmpArray objectAtIndex:0];
									if (tmpNum!=nil && [tmpNum isKindOfClass:numClass])
										defVal.point2DVal[0] = [tmpNum floatValue];
									tmpNum = [tmpArray objectAtIndex:1];
									if (tmpNum!=nil && [tmpNum isKindOfClass:numClass])
										defVal.point2DVal[1] = [tmpNum floatValue];
								}
								tmpArray = [inputDict objectForKey:@"MIN"];
								if (tmpArray!=nil && [tmpArray isKindOfClass:arrayClass] && [tmpArray count]==2)	{
									NSNumber		*tmpNum = [tmpArray objectAtIndex:0];
									if (tmpNum!=nil && [tmpNum isKindOfClass:numClass])
										minVal.point2DVal[0] = [tmpNum floatValue];
									tmpNum = [tmpArray objectAtIndex:1];
									if (tmpNum!=nil && [tmpNum isKindOfClass:numClass])
										minVal.point2DVal[1] = [tmpNum floatValue];
								}
								tmpArray = [inputDict objectForKey:@"MAX"];
								if (tmpArray!=nil && [tmpArray isKindOfClass:arrayClass] && [tmpArray count]==2)	{
									NSNumber		*tmpNum = [tmpArray objectAtIndex:0];
									if (tmpNum!=nil && [tmpNum isKindOfClass:numClass])
										maxVal.point2DVal[0] = [tmpNum floatValue];
									tmpNum = [tmpArray objectAtIndex:1];
									if (tmpNum!=nil && [tmpNum isKindOfClass:numClass])
										maxVal.point2DVal[1] = [tmpNum floatValue];
								}
							}
							//	else the attribute type wasn't recognized- it simply shouldn't exist!
							else	{
								inputKey = nil;
							}
							
							
							//if (!isFilterImageInput)	{
								if (inputKey != nil)	{
									newAttrib = [ISFAttrib
										createWithName:inputKey
										description:descString
										label:labelString
										type:newAttribType
										values:minVal:maxVal:defVal:idenVal:labelArray:valArray];
									[newAttrib setIsFilterInputImage:isFilterImageInput];
									[inputs lockAddObject:newAttrib];
									if (isImageInput)
										[imageInputs lockAddObject:newAttrib];
								}
							//}
							
						}
					}
				}
			}
			
			
		}
	}
	
	//	look for a vert shader that matches the name of the frag shader
	NSString		*noExtPath = [p stringByDeletingPathExtension];
	NSString		*tmpPath = nil;
	NSFileManager	*fm = [NSFileManager defaultManager];
	tmpPath = VVFMTSTRING(@"%@.vs",noExtPath);
	if ([fm fileExistsAtPath:tmpPath])	{
		OSSpinLockLock(&srcLock);
		vertShaderSource = [[NSString stringWithContentsOfFile:tmpPath encoding:NSUTF8StringEncoding error:nil] retain];
		OSSpinLockUnlock(&srcLock);
	}
	else	{
		tmpPath = VVFMTSTRING(@"%@.vert",noExtPath);
		if ([fm fileExistsAtPath:tmpPath])	{
			OSSpinLockLock(&srcLock);
			vertShaderSource = [[NSString stringWithContentsOfFile:tmpPath encoding:NSUTF8StringEncoding error:nil] retain];
			OSSpinLockUnlock(&srcLock);
		}
		else	{
			OSSpinLockLock(&srcLock);
			//tmpPath = [[NSBundle mainBundle] pathForResource:@"ISFGLScenePassthru" ofType:@"vs"];
			//if (tmpPath != nil)
				vertShaderSource = [_ISFVertPassthru retain];
			OSSpinLockUnlock(&srcLock);
		}
	}
	
	[swatch start];
}
- (VVBuffer *) allocAndRenderABuffer	{
	return [self allocAndRenderToBufferSized:size prefer2DTex:NO renderTime:[swatch timeSinceStart] passDict:nil];
}
- (VVBuffer *) allocAndRenderToBufferSized:(NSSize)s	{
	return [self allocAndRenderToBufferSized:s prefer2DTex:NO renderTime:[swatch timeSinceStart] passDict:nil];
}
- (VVBuffer *) allocAndRenderToBufferSized:(NSSize)s prefer2DTex:(BOOL)wants2D	{
	return [self allocAndRenderToBufferSized:s prefer2DTex:wants2D renderTime:[swatch timeSinceStart] passDict:nil];
}
- (VVBuffer *) allocAndRenderToBufferSized:(NSSize)s prefer2DTex:(BOOL)wants2D passDict:(NSMutableDictionary *)d	{
	return [self allocAndRenderToBufferSized:s prefer2DTex:wants2D renderTime:[swatch timeSinceStart] passDict:d];
}
- (VVBuffer *) allocAndRenderToBufferSized:(NSSize)s prefer2DTex:(BOOL)wants2D renderTime:(double)t	{
	return [self allocAndRenderToBufferSized:s prefer2DTex:wants2D renderTime:t passDict:nil];
}
- (VVBuffer *) allocAndRenderToBufferSized:(NSSize)s prefer2DTex:(BOOL)wants2D renderTime:(double)t passDict:(NSMutableDictionary *)d	{
	//NSLog(@"%s ... %0.2f x %0.2f",__func__,s.width,s.height);
	[passes rdlock];
	ISFRenderPass	*lastPass = (passes==nil || [passes count]<1) ? nil  : [passes lastObject];
	NSString		*lastPassTargetName = (lastPass==nil) ? nil : [lastPass targetName];
	[passes unlock];
	ISFTargetBuffer	*lastPassTargetBuffer = [self findPersistentBufferNamed:lastPassTargetName];
	if (lastPassTargetBuffer==nil)
		lastPassTargetBuffer = [self findTempBufferNamed:lastPassTargetName];
	
	VVBuffer		*returnMe = nil;
	if (wants2D)	{
		returnMe = (lastPassTargetBuffer!=nil && [lastPassTargetBuffer floatFlag])
			? [_globalVVBufferPool allocBGRFloat2DPOTTexSized:s]
			: [_globalVVBufferPool allocBGR2DPOTTexSized:s];
	}
	else	{
		returnMe = (lastPassTargetBuffer!=nil && [lastPassTargetBuffer floatFlag])
			? [_globalVVBufferPool allocBGRFloatTexSized:s]
			: [_globalVVBufferPool allocBGRTexSized:s];
	}
	
	[self renderToBuffer:returnMe sized:s renderTime:t passDict:d];
	return returnMe;
}
- (void) renderToBuffer:(VVBuffer *)b sized:(NSSize)s	{
	[self renderToBuffer:b sized:s renderTime:[swatch timeSinceStart] passDict:nil];
}
- (void) renderToBuffer:(VVBuffer *)b sized:(NSSize)s renderTime:(double)t passDict:(NSMutableDictionary *)d	{
	//NSLog(@"%s ... %@",__func__,b);
	pthread_mutex_lock(&renderLock);
	renderSize = s;
	renderTime = t;
	
	NSMutableDictionary		*subDict = (bufferRequiresEval) ? [self _assembleSubstitutionDict] : nil;
	//NSMutableDictionary		*subDict = MUTDICT;
	if (subDict != nil)	{
		[subDict retain];
		[subDict setObject:NUMINT(s.width) forKey:@"WIDTH"];
		[subDict setObject:NUMINT(s.height) forKey:@"HEIGHT"];
	}
	
	//	make sure that all the persistent buffers are sized appropriately
	[persistentBufferArray rdlock];
	for (ISFTargetBuffer *tmpBuffer in [persistentBufferArray array])	{
		if ([tmpBuffer targetSizeNeedsEval])
			[tmpBuffer evalTargetSizeWithSubstitutionsDict:subDict resizeExistingBuffer:YES createNewBuffer:YES];
		else
			[tmpBuffer setTargetSize:s resizeExistingBuffer:YES createNewBuffer:YES];
	}
	[persistentBufferArray unlock];
	//	make sure all the temp buffers are also sized appropriately
	[tempBufferArray rdlock];
	for (ISFTargetBuffer *tmpBuffer in [tempBufferArray array])	{
		if ([tmpBuffer targetSizeNeedsEval])
			[tmpBuffer evalTargetSizeWithSubstitutionsDict:subDict resizeExistingBuffer:NO createNewBuffer:YES];
		else
			[tmpBuffer setTargetSize:s resizeExistingBuffer:NO createNewBuffer:YES];
	}
	[tempBufferArray unlock];
	
	//	run through the array of pass dicts, rendering each of the passes
	if (d != nil)
		[d removeAllObjects];
	[passes rdlock];
	passIndex = 1;
	for (ISFRenderPass *pass in [passes array])	{
		//NSLog(@"\t\trendering pass %d",passIndex);
		//	get the name of the target buffer for this pass (if there is a name)
		NSString				*targetBufferName = [pass targetName];
		//NSMutableDictionary		*targetBufferDict = nil;
		ISFTargetBuffer		*targetBuffer = nil;
		BOOL					isPersistentBuffer = NO;
		BOOL					isTempBuffer = NO;
		VVBuffer				*targetFBO = nil;
		VVBuffer				*targetColorTex = nil;
		VVBuffer				*targetDepth = nil;
		
		//	if there's a target buffer name, i need to find the dict describing the target buffer so i can create a new buffer to match
		if (targetBufferName != nil)	{
			//	try to find a persistent buffer matching the target name
			targetBuffer = [self findPersistentBufferNamed:targetBufferName];
			//	if i couldn't find a persistent buffer matching the target name
			if (targetBuffer != nil)
				isPersistentBuffer = YES;
			else	{
				//	try to find a temp buffer matching the target name
				targetBuffer = [self findTempBufferNamed:targetBufferName];
				if (targetBuffer != nil)	{
					isTempBuffer = YES;
				}
				else	{
					NSLog(@"\t\tERR: failed to locate buffer named %@",targetBufferName);
					NSLog(@"\t\tERR: persistent: %@",persistentBufferArray);
					NSLog(@"\t\tERR: temp: %@",tempBufferArray);
				}
			}
			
		}
		NSSize					targetBufferSize = (targetBuffer==nil) ? s : [targetBuffer targetSize];
		//NSSizeLog(@"\t\ttargetBufferSize is",targetBufferSize);
		//NSLog(@"\t\ttargetBuffer is %@, size is %0.2f x %0.2f",targetBuffer,targetBufferSize.width,targetBufferSize.height);
		
		//	create a buffer of the appropriate size (if this is the last pass, observe the 2D texture preference from the method)
		if (passIndex >= [passes count])	{
			targetColorTex = (b==nil) ? nil : [b retain];
			//NSLog(@"\t\tlast pass, rendering into %@",targetColorTex);
		}
		else	{
			targetColorTex = ([targetBuffer floatFlag])
				? [_globalVVBufferPool allocBGRFloatTexSized:targetBufferSize]
				: [_globalVVBufferPool allocBGRTexSized:targetBufferSize];
			//NSLog(@"\t\tgenerated targetColorTex %@",targetColorTex);
		}
		//	if i've got a targetColorTex to render into, make a depth buffer and FBO
		if (targetColorTex!=nil)	{
			//	create an FBO and depth buffer
			targetFBO = [_globalVVBufferPool allocFBO];
			targetDepth = [_globalVVBufferPool allocDepthSized:targetBufferSize];
		}
		
		//	render this pass!
		[self setSize:targetBufferSize];
		[self
			renderInMSAAFBO:0
			colorRB:0
			depthRB:0
			fbo:((targetFBO==nil) ? 0 : [targetFBO name])
			colorTex:((targetColorTex==nil) ? 0 : [targetColorTex name])
			depthTex:((targetDepth==nil) ? 0 : [targetDepth name])
			target:((targetColorTex==nil) ? GL_TEXTURE_RECTANGLE_EXT : [targetColorTex target])];
		
		//	if there's an image dict, add the frame i just rendered into to it at the appropriate index/key
		if (d!=nil && targetColorTex!=nil)	{
			[d setObject:targetColorTex forKey:NUMINT(passIndex-1)];
		}
		
		//	increment the pass index for next time!
		++passIndex;
		
		//	if this was a persistent or temp buffer, put it back in its buffer dict
		if ((isPersistentBuffer || isTempBuffer) && targetBuffer!=nil)	{
			//NSLog(@"\t\trendered into %@, applying to %@",targetColorTex,targetBuffer);
			[targetBuffer setBuffer:targetColorTex];
		}
		
		//	release all the resources
		VVRELEASE(targetFBO);
		VVRELEASE(targetColorTex);
		VVRELEASE(targetDepth);
	}
	[passes unlock];
	
	
	//	if there's a pass dict...
	if (d != nil)	{
		//	add the buffer i rendered into (this is the "output" buffer, and is stored at key "-1")
		if (b!=nil)
			[d setObject:b forKey:NUMINT(-1)];
		//	add the buffers for the various image inputs at keys going from 100-199
		[imageInputs rdlock];
		for (int i=0; i<[imageInputs count]; ++i)	{
			ISFAttrib		*attrib = [imageInputs objectAtIndex:i];
			VVBuffer		*imgInputBuffer = [attrib userInfo];
			if (imgInputBuffer!=nil)
				[d setObject:imgInputBuffer forKey:NUMINT(100+i)];
		}
		[imageInputs unlock];
	}
	
	
	pthread_mutex_unlock(&renderLock);
	
	
	if (throwExceptions)	{
		NSDictionary		*errDictCopy = nil;
		OSSpinLockLock(&errDictLock);
		errDictCopy = errDict;
		errDict = nil;
		OSSpinLockUnlock(&errDictLock);
		if (errDictCopy != nil)	{
			NSException		*ex = [NSException
				exceptionWithName:@"Shader Problem"
				reason:@"check userInfo dict for description"
				userInfo:errDictCopy];
			[errDictCopy autorelease];
			[ex raise];
		}
	}
	
	
	
	//	run through and release all the buffers in the temp buffer array
	[tempBufferArray rdlock];
	for (ISFTargetBuffer *targetBuffer in [tempBufferArray array])	{
		[targetBuffer clearBuffer];
	}
	[tempBufferArray unlock];
	
	
	
	VVRELEASE(subDict);
}
- (void) render	{
	[self renderToBuffer:nil sized:size renderTime:[swatch timeSinceStart] passDict:nil];
}


//	this is called from within "_renderPrep"
- (void) _assembleShaderSource	{
	
	
	/*	stores names of the images/buffers that are accessed via IMG_THIS_PIXEL (which is replaced 
	in the frag shader, but the names are then needed to declare vars in the vert shader)		*/
	NSMutableArray		*imgThisPixelSamplerNames = nil;
	NSMutableArray		*imgThisNormPixelSamplerNames = nil;
	//	i need variable declarations for both the vertex and fragment shaders
	NSMutableString		*varDeclarations = [[[self _assembleShaderSource_VarDeclarations] copy] autorelease];
	
	//	check the source string to see if it requires any of the macro functions, add them if necessary
	//BOOL			requiresMacroFunctions = NO;
	BOOL			requires2DMacro = NO;
	BOOL			requires2DBiasMacro = NO;
	BOOL			requires2DRectMacro = NO;
	BOOL			requires2DRectBiasMacro = NO;
	NSRange			tmpRange;
	NSString		*searchString = nil;
	VVBuffer		*imgBuffer = nil;
	NSMutableString		*modSrcString = nil;
	
	//NSLog(@"\t\tbeginning to assemble frag shader");
	//	put together a new frag shader string from the raw shader source
	NSMutableString		*newFragShaderSrc = [NSMutableString stringWithCapacity:0];
	{
		//	copy the variable declarations to the frag shader src
		[newFragShaderSrc appendString:varDeclarations];
		
		//	now i have to find-and-replace the shader source for various things- make a copy of the raw source and work from that.
		modSrcString = [NSMutableString stringWithCapacity:0];
		OSSpinLockLock(&srcLock);
		[modSrcString appendString:fragShaderSource];
		OSSpinLockUnlock(&srcLock);
		
		//	now find-and-replace IMGPIXEL
		//NSLog(@"**************************************");
		//NSLog(@"\t\tmodSrcString is %@",modSrcString);
		//NSLog(@"**************************************");
		searchString = @"IMG_PIXEL";
		imgBuffer = nil;
		tmpRange = NSMakeRange(0,[modSrcString length]);
		do	{
			tmpRange = [modSrcString rangeOfString:searchString options:NSLiteralSearch range:tmpRange];
			if (tmpRange.length!=0)	{
				//requiresMacroFunctions = YES;
				NSMutableArray		*varArray = MUTARRAY;
				NSRange				fullFuncRangeToReplace = [(NSString *)modSrcString lexFunctionCallInRange:tmpRange addVariablesToArray:varArray];
				NSUInteger			varArrayCount = [varArray count];
				if (varArrayCount!=2 && varArrayCount!=3)	{
					NSLog(@"\t\tERR: variable count wrong searching for %@: %@",searchString,varArray);
					break;
				}
				else	{
					NSString		*newFuncString = nil;
					NSString		*samplerName = [varArray objectAtIndex:0];
					NSString		*samplerCoord = [varArray objectAtIndex:1];
					imgBuffer = [self bufferForInputImageKey:samplerName];
					if (imgBuffer==nil || [imgBuffer target]==GL_TEXTURE_RECTANGLE_EXT)	{
						//newFuncString = VVFMTSTRING(@"VVSAMPLER_2DRECTBYPIXEL(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
						if (varArrayCount==3)	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DRECTBYPIXEL(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord,[varArray objectAtIndex:2]);
							requires2DRectBiasMacro = YES;
						}
						else	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DRECTBYPIXEL(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
							requires2DRectMacro = YES;
						}
					}
					else	{
						//newFuncString = VVFMTSTRING(@"VVSAMPLER_2DBYPIXEL(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
						if (varArrayCount==3)	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DBYPIXEL(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord,[varArray objectAtIndex:2]);
							requires2DBiasMacro = YES;
						}
						else	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DBYPIXEL(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
							requires2DMacro = YES;
						}
					}
					[modSrcString replaceCharactersInRange:fullFuncRangeToReplace withString:newFuncString];
					tmpRange.location = fullFuncRangeToReplace.location + [newFuncString length];
					tmpRange.length = [modSrcString length] - tmpRange.location;
				}
			}
		} while (tmpRange.length!=0);
		
		searchString = @"IMG_NORM_PIXEL";
		tmpRange = NSMakeRange(0,[modSrcString length]);
		imgBuffer = nil;
		do	{
			tmpRange = [modSrcString rangeOfString:searchString options:NSLiteralSearch range:tmpRange];
			if (tmpRange.length!=0)	{
				//requiresMacroFunctions = YES;
				NSMutableArray		*varArray = MUTARRAY;
				NSRange				fullFuncRangeToReplace = [(NSString *)modSrcString lexFunctionCallInRange:tmpRange addVariablesToArray:varArray];
				NSUInteger			varArrayCount = [varArray count];
				if (varArrayCount!=2 && varArrayCount!=3)	{
					NSLog(@"\t\tERR: variable count wrong searching for %@: %@",searchString,varArray);
					break;
				}
				else	{
					NSString		*newFuncString = nil;
					NSString		*samplerName = [varArray objectAtIndex:0];
					NSString		*samplerCoord = [varArray objectAtIndex:1];
					imgBuffer = [self bufferForInputImageKey:samplerName];
					if (imgBuffer==nil || [imgBuffer target]==GL_TEXTURE_RECTANGLE_EXT)	{
						//newFuncString = VVFMTSTRING(@"VVSAMPLER_2DRECTBYNORM(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
						if (varArrayCount==3)	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DRECTBYNORM(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord,[varArray objectAtIndex:2]);
							requires2DRectBiasMacro = YES;
						}
						else	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DRECTBYNORM(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
							requires2DRectMacro = YES;
						}
					}
					else	{
						//newFuncString = VVFMTSTRING(@"VVSAMPLER_2DBYNORM(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
						if (varArrayCount==3)	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DBYNORM(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord,[varArray objectAtIndex:2]);
							requires2DBiasMacro = YES;
						}
						else	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DBYNORM(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
							requires2DMacro = YES;
						}
					}
					[modSrcString replaceCharactersInRange:fullFuncRangeToReplace withString:newFuncString];
					tmpRange.location = fullFuncRangeToReplace.location + [newFuncString length];
					tmpRange.length = [modSrcString length] - tmpRange.location;
				}
			}
		} while (tmpRange.length!=0);
		
		searchString = @"IMG_THIS_PIXEL";
		tmpRange = NSMakeRange(0,[modSrcString length]);
		imgBuffer = nil;
		do	{
			tmpRange = [modSrcString rangeOfString:searchString options:NSLiteralSearch range:tmpRange];
			if (tmpRange.length!=0)	{
				NSMutableArray		*varArray = MUTARRAY;
				NSRange				fullFuncRangeToReplace = [(NSString *)modSrcString lexFunctionCallInRange:tmpRange addVariablesToArray:varArray];
				NSUInteger			varArrayCount = [varArray count];
				if (varArrayCount!=1)	{
					NSLog(@"\t\tERR: variable count wrong searching for %@: %@",searchString,varArray);
					break;
				}
				else	{
					NSString		*newFuncString = nil;
					NSString		*samplerName = [varArray objectAtIndex:0];
					if (imgThisPixelSamplerNames==nil)
						imgThisPixelSamplerNames = MUTARRAY;
					if (![imgThisPixelSamplerNames containsObject:samplerName])
						[imgThisPixelSamplerNames addObject:samplerName];
					
					imgBuffer = [self bufferForInputImageKey:samplerName];
					if (imgBuffer==nil || [imgBuffer target]==GL_TEXTURE_RECTANGLE_EXT)	{
						newFuncString = VVFMTSTRING(@"texture2DRect(%@, _%@_texCoord)",samplerName,samplerName);
					}
					else	{
						newFuncString = VVFMTSTRING(@"texture2D(%@, _%@_texCoord)",samplerName,samplerName);
					}
					[modSrcString replaceCharactersInRange:fullFuncRangeToReplace withString:newFuncString];
					tmpRange.location = fullFuncRangeToReplace.location + [newFuncString length];
					tmpRange.length = [modSrcString length] - tmpRange.location;
				}
			}
		} while (tmpRange.length!=0);
		//	add the IMG_THIS_PIXEL variable names to the frag shader
		if (imgThisPixelSamplerNames != nil)	{
			for (NSString *tmpString in imgThisPixelSamplerNames)
				[newFragShaderSrc appendString:VVFMTSTRING(@"varying vec2\t\t_%@_texCoord;\n",tmpString)];
		}
		
		searchString = @"IMG_THIS_NORM_PIXEL";
		tmpRange = NSMakeRange(0,[modSrcString length]);
		imgBuffer = nil;
		do	{
			tmpRange = [modSrcString rangeOfString:searchString options:NSLiteralSearch range:tmpRange];
			if (tmpRange.length!=0)	{
				NSMutableArray		*varArray = MUTARRAY;
				NSRange				fullFuncRangeToReplace = [(NSString *)modSrcString lexFunctionCallInRange:tmpRange addVariablesToArray:varArray];
				NSUInteger			varArrayCount = [varArray count];
				if (varArrayCount!=1)	{
					NSLog(@"\t\tERR: variable count wrong searching for %@: %@",searchString,varArray);
					break;
				}
				else	{
					NSString		*newFuncString = nil;
					NSString		*samplerName = [varArray objectAtIndex:0];
					if (imgThisNormPixelSamplerNames==nil)
						imgThisNormPixelSamplerNames = MUTARRAY;
					if (![imgThisNormPixelSamplerNames containsObject:samplerName])
						[imgThisNormPixelSamplerNames addObject:samplerName];
					
					imgBuffer = [self bufferForInputImageKey:samplerName];
					if (imgBuffer==nil || [imgBuffer target]==GL_TEXTURE_RECTANGLE_EXT)	{
						newFuncString = VVFMTSTRING(@"texture2DRect(%@, _%@_normTexCoord)",samplerName,samplerName);
					}
					else	{
						newFuncString = VVFMTSTRING(@"texture2D(%@, _%@_normTexCoord)",samplerName,samplerName);
					}
					[modSrcString replaceCharactersInRange:fullFuncRangeToReplace withString:newFuncString];
					tmpRange.location = fullFuncRangeToReplace.location + [newFuncString length];
					tmpRange.length = [modSrcString length] - tmpRange.location;
				}
			}
		} while (tmpRange.length!=0);
		//	add the IMG_THIS_NORM_PIXEL variable names to the frag shader
		if (imgThisNormPixelSamplerNames != nil)	{
			for (NSString *tmpString in imgThisNormPixelSamplerNames)
				[newFragShaderSrc appendString:VVFMTSTRING(@"varying vec2\t\t_%@_normTexCoord;\n",tmpString)];
		}
		
		searchString = @"IMG_SIZE";
		imgBuffer = nil;
		tmpRange = NSMakeRange(0,[modSrcString length]);
		do	{
			tmpRange = [modSrcString rangeOfString:searchString options:NSLiteralSearch range:tmpRange];
			if (tmpRange.length!=0)	{
				//requiresMacroFunctions = YES;
				NSMutableArray		*varArray = MUTARRAY;
				NSRange				fullFuncRangeToReplace = [(NSString *)modSrcString lexFunctionCallInRange:tmpRange addVariablesToArray:varArray];
				NSUInteger			varArrayCount = [varArray count];
				if (varArrayCount!=1)	{
					NSLog(@"\t\tERR: variable count wrong searching for %@: %@",searchString,varArray);
					break;
				}
				else	{
					NSString		*newFuncString = nil;
					NSString		*samplerName = [varArray objectAtIndex:0];
					newFuncString = VVFMTSTRING(@"(_%@_imgRect.zw)",samplerName);
					[modSrcString replaceCharactersInRange:fullFuncRangeToReplace withString:newFuncString];
					tmpRange.location = fullFuncRangeToReplace.location + [newFuncString length];
					tmpRange.length = [modSrcString length] - tmpRange.location;
				}
			}
		} while (tmpRange.length!=0);
		
		//	if the frag shader requires macro functions, add them now that i'm done declaring the variables
		if (requires2DMacro)
			[newFragShaderSrc appendString:_ISFMacro2DString];
		if (requires2DBiasMacro)
			[newFragShaderSrc appendString:_ISFMacro2DBiasString];
		if (requires2DRectMacro)
			[newFragShaderSrc appendString:_ISFMacro2DRectString];
		if (requires2DRectBiasMacro)
			[newFragShaderSrc appendString:_ISFMacro2DRectBiasString];
		
		//	add the shader source that has been find-and-replaced
		[newFragShaderSrc appendString:modSrcString];
	}
	
	
	//NSLog(@"\t\tbeginning to assemble vert shader");
	//	now that i've taken care of the frag shader, put together the vert shader (the vert shader's content depends on the content of the frag shader)
	NSMutableString		*newVertShaderSrc = [NSMutableString stringWithCapacity:0];
	{
		//	load any specific vars or function declarations for the vertex shader from an included file
		[newVertShaderSrc appendString:_ISFVertVarDec];
		//	append the variable declarations i assembled earlier with the frag shader
		[newVertShaderSrc appendString:varDeclarations];
		
		//	add the variables for values corresponding to buffers from IMG_THIS_PIXEL and IMG_THIS_NORM_PIXEL in the frag shader
		if (imgThisPixelSamplerNames!=nil || imgThisNormPixelSamplerNames!=nil)	{
			if (imgThisPixelSamplerNames != nil)	{
				for (NSString *tmpString in imgThisPixelSamplerNames)	{
					//NSLog(@"\t\tprocessing imgThisPixelSamplerNames named %@",tmpString);
					[newVertShaderSrc appendString:VVFMTSTRING(@"varying vec2\t\t_%@_texCoord;\n",tmpString)];
				}
			}
			if (imgThisNormPixelSamplerNames != nil)	{
				for (NSString *tmpString in imgThisNormPixelSamplerNames)	{
					//NSLog(@"\t\tprocessing imgThisNormPixelSamplerNames named %@",tmpString);
					[newVertShaderSrc appendString:VVFMTSTRING(@"varying vec2\t\t_%@_normTexCoord;\n",tmpString)];
				}
			}
		}
		
		//	check the source string to see if it requires any of the macro functions, add them if necessary
		requires2DMacro = NO;
		requires2DBiasMacro = NO;
		requires2DRectMacro = NO;
		requires2DRectBiasMacro = NO;
		
		//	now i have to find-and-replace the shader source for various things- make a copy of the raw source and work from that.
		modSrcString = [NSMutableString stringWithCapacity:0];
		OSSpinLockLock(&srcLock);
		[modSrcString appendString:vertShaderSource];
		OSSpinLockUnlock(&srcLock);
		
		//	now find-and-replace IMGPIXEL
		//NSLog(@"**************************************");
		//NSLog(@"\t\tmodSrcString is %@",modSrcString);
		//NSLog(@"**************************************");
		searchString = @"IMG_PIXEL";
		imgBuffer = nil;
		tmpRange = NSMakeRange(0,[modSrcString length]);
		do	{
			tmpRange = [modSrcString rangeOfString:searchString options:NSLiteralSearch range:tmpRange];
			if (tmpRange.length!=0)	{
				//requiresMacroFunctions = YES;
				NSMutableArray		*varArray = MUTARRAY;
				NSRange				fullFuncRangeToReplace = [(NSString *)modSrcString lexFunctionCallInRange:tmpRange addVariablesToArray:varArray];
				NSUInteger			varArrayCount = [varArray count];
				if (varArrayCount!=2 && varArrayCount!=3)	{
					NSLog(@"\t\tERR: variable count wrong searching for %@: %@",searchString,varArray);
					break;
				}
				else	{
					NSString		*newFuncString = nil;
					NSString		*samplerName = [varArray objectAtIndex:0];
					NSString		*samplerCoord = [varArray objectAtIndex:1];
					imgBuffer = [self bufferForInputImageKey:samplerName];
					if (imgBuffer==nil || [imgBuffer target]==GL_TEXTURE_RECTANGLE_EXT)	{
						//newFuncString = VVFMTSTRING(@"VVSAMPLER_2DRECTBYPIXEL(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
						if (varArrayCount==3)	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DRECTBYPIXEL(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord,[varArray objectAtIndex:2]);
							requires2DRectBiasMacro = YES;
						}
						else	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DRECTBYPIXEL(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
							requires2DRectMacro = YES;
						}
					}
					else	{
						//newFuncString = VVFMTSTRING(@"VVSAMPLER_2DBYPIXEL(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
						if (varArrayCount==3)	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DBYPIXEL(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord,[varArray objectAtIndex:2]);
							requires2DBiasMacro = YES;
						}
						else	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DBYPIXEL(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
							requires2DMacro = YES;
						}
					}
					[modSrcString replaceCharactersInRange:fullFuncRangeToReplace withString:newFuncString];
					tmpRange.location = fullFuncRangeToReplace.location + [newFuncString length];
					tmpRange.length = [modSrcString length] - tmpRange.location;
				}
			}
		} while (tmpRange.length!=0);
		
		searchString = @"IMG_NORM_PIXEL";
		tmpRange = NSMakeRange(0,[modSrcString length]);
		imgBuffer = nil;
		do	{
			tmpRange = [modSrcString rangeOfString:searchString options:NSLiteralSearch range:tmpRange];
			if (tmpRange.length!=0)	{
				//requiresMacroFunctions = YES;
				NSMutableArray		*varArray = MUTARRAY;
				NSRange				fullFuncRangeToReplace = [(NSString *)modSrcString lexFunctionCallInRange:tmpRange addVariablesToArray:varArray];
				NSUInteger			varArrayCount = [varArray count];
				if (varArrayCount!=2 && varArrayCount!=3)	{
					NSLog(@"\t\tERR: variable count wrong searching for %@: %@",searchString,varArray);
					break;
				}
				else	{
					NSString		*newFuncString = nil;
					NSString		*samplerName = [varArray objectAtIndex:0];
					NSString		*samplerCoord = [varArray objectAtIndex:1];
					imgBuffer = [self bufferForInputImageKey:samplerName];
					if (imgBuffer==nil || [imgBuffer target]==GL_TEXTURE_RECTANGLE_EXT)	{
						//newFuncString = VVFMTSTRING(@"VVSAMPLER_2DRECTBYNORM(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
						if (varArrayCount==3)	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DRECTBYNORM(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord,[varArray objectAtIndex:2]);
							requires2DRectBiasMacro = YES;
						}
						else	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DRECTBYNORM(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
							requires2DRectMacro = YES;
						}
					}
					else	{
						//newFuncString = VVFMTSTRING(@"VVSAMPLER_2DBYNORM(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
						if (varArrayCount==3)	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DBYNORM(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord,[varArray objectAtIndex:2]);
							requires2DBiasMacro = YES;
						}
						else	{
							newFuncString = VVFMTSTRING(@"VVSAMPLER_2DBYNORM(%@, _%@_imgRect, _%@_imgSize, _%@_flip, %@)",samplerName,samplerName,samplerName,samplerName,samplerCoord);
							requires2DMacro = YES;
						}
					}
					[modSrcString replaceCharactersInRange:fullFuncRangeToReplace withString:newFuncString];
					tmpRange.location = fullFuncRangeToReplace.location + [newFuncString length];
					tmpRange.length = [modSrcString length] - tmpRange.location;
				}
			}
		} while (tmpRange.length!=0);
		
		//	if the frag shader requires macro functions, add them now that i'm done declaring the variables
		if (requires2DMacro)
			[newVertShaderSrc appendString:_ISFMacro2DString];
		if (requires2DBiasMacro)
			[newVertShaderSrc appendString:_ISFMacro2DBiasString];
		if (requires2DRectMacro)
			[newVertShaderSrc appendString:_ISFMacro2DRectString];
		if (requires2DRectBiasMacro)
			[newVertShaderSrc appendString:_ISFMacro2DRectBiasString];
		
		//	add the shader source that has been find-and-replaced
		[newVertShaderSrc appendString:modSrcString];
		
		//	add the vv_vertShaderInit() method to the vertex shader
		[newVertShaderSrc appendString:@"\nvoid vv_vertShaderInit(void)\t{"];
		[newVertShaderSrc appendString:_ISFVertInitFunc];
		//	run through the IMG_THIS_PIXEL sampler names, populating the varying vec2 variables i declared
		if (imgThisPixelSamplerNames != nil)	{
			for (NSString *samplerName in imgThisPixelSamplerNames)	{
				[newVertShaderSrc appendString:VVFMTSTRING(@"\t_%@_texCoord = (_%@_flip) ? vec2(((vv_fragCoord.x/_%@_imgSize.x*_%@_imgRect.z)+_%@_imgRect.x), (_%@_imgRect.w-(vv_fragCoord.y/_%@_imgSize.y*_%@_imgRect.w)+_%@_imgRect.y)) : vec2(((vv_fragCoord.x/_%@_imgSize.x*_%@_imgRect.z)+_%@_imgRect.x), (vv_fragCoord.y/_%@_imgSize.y*_%@_imgRect.w)+_%@_imgRect.y);\n",samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName)];
			}
		}
		//	run through the IMG_THIS_NORM_PIXEL sampler names, populating the varying vec2 variables i declared
		if (imgThisNormPixelSamplerNames != nil)	{
			for (NSString *samplerName in imgThisNormPixelSamplerNames)	{
				imgBuffer = [self bufferForInputImageKey:samplerName];
				if (imgBuffer==nil || [imgBuffer target]==GL_TEXTURE_RECTANGLE_EXT)	{
					[newVertShaderSrc appendString:VVFMTSTRING(@"\t_%@_normTexCoord = (_%@_flip) ? vec2((((vv_FragNormCoord.x*_%@_imgRect.z)/_%@_imgSize.x*_%@_imgRect.z)+_%@_imgRect.x), (_%@_imgRect.w-((vv_FragNormCoord.y*_%@_imgRect.w)/_%@_imgSize.y*_%@_imgRect.w)+_%@_imgRect.y)) : vec2((((vv_FragNormCoord.x*_%@_imgRect.z)/_%@_imgSize.x*_%@_imgRect.z)+_%@_imgRect.x), ((vv_FragNormCoord.y*_%@_imgRect.w)/_%@_imgSize.y*_%@_imgRect.w)+_%@_imgRect.y);\n",samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName)];
				}
				else	{
					[newVertShaderSrc appendString:VVFMTSTRING(@"\t_%@_normTexCoord = (_%@_flip) ? vec2((((vv_FragNormCoord.x*_%@_imgSize.x)/_%@_imgSize.x*_%@_imgRect.z)+_%@_imgRect.x), (_%@_imgRect.w-((vv_FragNormCoord.y*_%@_imgSize.y)/_%@_imgSize.y*_%@_imgRect.w)+_%@_imgRect.y)) : vec2((((vv_FragNormCoord.x*_%@_imgSize.x)/_%@_imgSize.x*_%@_imgRect.z)+_%@_imgRect.x), ((vv_FragNormCoord.y*_%@_imgSize.y)/_%@_imgSize.y*_%@_imgRect.w)+_%@_imgRect.y);\n",samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName,samplerName)];
				}
			}
		}
		//	...this finishes adding the vv_vertShaderInit() method!
		[newVertShaderSrc appendString:@"}\n"];
		
		//	if there are any "#version" tags in the shaders, see that they are preserved and moved to the beginning!
		NSCharacterSet		*newLineCharSet = [NSCharacterSet newlineCharacterSet];
		NSString			*fragVersionString = nil;
		NSString			*vertVersionString = nil;
		searchString = @"#version ";
		tmpRange = NSMakeRange(0,[newFragShaderSrc length]);
		tmpRange = [newFragShaderSrc rangeOfString:searchString options:NSLiteralSearch range:tmpRange];
		if (tmpRange.length != 0)	{
			//	expand the range until it includes everything up to the newline char
			while (![newLineCharSet characterIsMember:[newFragShaderSrc characterAtIndex:(tmpRange.location+tmpRange.length)]])
				++tmpRange.length;
			++tmpRange.length;
			fragVersionString = [newFragShaderSrc substringWithRange:tmpRange];
			[newFragShaderSrc replaceCharactersInRange:tmpRange withString:@""];
			[newFragShaderSrc insertString:fragVersionString atIndex:0];
		}
		
		tmpRange = NSMakeRange(0,[newVertShaderSrc length]);
		tmpRange = [newVertShaderSrc rangeOfString:searchString options:NSLiteralSearch range:tmpRange];
		if (tmpRange.length != 0)	{
			//	expand the range until it includes everything up to the newline char
			while (![newLineCharSet characterIsMember:[newVertShaderSrc characterAtIndex:(tmpRange.location+tmpRange.length)]])
				++tmpRange.length;
			++tmpRange.length;
			vertVersionString = [newVertShaderSrc substringWithRange:tmpRange];
			[newVertShaderSrc replaceCharactersInRange:tmpRange withString:@""];
			[newVertShaderSrc insertString:vertVersionString atIndex:0];
		}
		else if (fragVersionString != nil)
			[newVertShaderSrc insertString:fragVersionString atIndex:0];
	}
	
	
	
	/*
	//NSLog(@"********************************");
	//NSLog(@"\t\tnew vert shader src is:\n%@",newVertShaderSrc);
	//NSLog(@"********************************");
	//NSLog(@"\t\tnew frag shader src is:\n%@",newFragShaderSrc);
	//NSLog(@"********************************");
	*/
	
	[self setVertexShaderString:newVertShaderSrc];
	[self setFragmentShaderString:newFragShaderSrc];
}
- (NSMutableString *) _assembleShaderSource_VarDeclarations	{
	NSMutableString		*varDeclarations = [NSMutableString stringWithCapacity:0];
	
	//	first declare the variables for the various attributes
	[inputs rdlock];
	for (ISFAttrib *attrib in [inputs array])	{
		ISFAttribValType	attribType = [attrib attribType];
		NSString				*attribName = [attrib attribName];
		VVBuffer				*attribBuffer = nil;
		switch (attribType)	{
			case ISFAT_Event:
				[varDeclarations appendString:VVFMTSTRING(@"uniform bool\t\t%@;\n",attribName)];
				break;
			case ISFAT_Bool:
				[varDeclarations appendString:VVFMTSTRING(@"uniform bool\t\t%@;\n",attribName)];
				break;
			case ISFAT_Long:
				[varDeclarations appendString:VVFMTSTRING(@"uniform int\t\t%@;\n",attribName)];
				break;
			case ISFAT_Float:
				[varDeclarations appendString:VVFMTSTRING(@"uniform float\t\t%@;\n",attribName)];
				break;
			case ISFAT_Point2D:
				[varDeclarations appendString:VVFMTSTRING(@"uniform vec2\t\t%@;\n",attribName)];
				break;
			case ISFAT_Color:
				[varDeclarations appendString:VVFMTSTRING(@"uniform vec4\t\t%@;\n",attribName)];
				break;
			case ISFAT_Image:	//	most of the voodoo happens here
				//	make a sampler of the appropriate type for this input
				attribBuffer = [attrib userInfo];
				if (attribBuffer==nil || [attribBuffer target]==GL_TEXTURE_RECTANGLE_EXT)
					[varDeclarations appendString:VVFMTSTRING(@"uniform sampler2DRect\t\t%@;\n",attribName)];
				else
					[varDeclarations appendString:VVFMTSTRING(@"uniform sampler2D\t\t%@;\n",attribName)];
				//	a vec4 describing the image rect IN NATIVE GL TEXTURE COORDS (2D is normalized, RECT is not)
				[varDeclarations appendString:VVFMTSTRING(@"uniform vec4\t\t_%@_imgRect;\n",attribName)];
				//	a vec2 describing the size in pixels of the image
				[varDeclarations appendString:VVFMTSTRING(@"uniform vec2\t\t_%@_imgSize;\n",attribName)];
				//	a bool describing whether the image in the texture should be flipped vertically
				[varDeclarations appendString:VVFMTSTRING(@"uniform bool\t\t_%@_flip;\n",attribName)];
				break;
			case ISFAT_Cube:
				//	make a sampler for the cubemap texture
				[varDeclarations appendString:VVFMTSTRING(@"uniform samplerCube\t\t%@;\n",attribName)];
				//	just pass in the imgSize
				[varDeclarations appendString:VVFMTSTRING(@"uniform vec2\t\t_%@_imgSize;\n",attribName)];
				break;
		}
	}
	[inputs unlock];
	//	add the variables for the imported buffers
	[imageImports rdlock];
	for (ISFAttrib *attrib in [imageImports array])	{
		//NSLog(@"\t\tassembling source for attrib %@",attrib);
		ISFAttribValType	attribType = [attrib attribType];
		if (attribType==ISFAT_Image || attribType==ISFAT_Cube)	{
			NSString		*attribName = [attrib attribName];
			VVBuffer		*attribBuffer = [attrib userInfo];
			GLuint			attribBufferTarget = (attribBuffer==nil) ? GL_TEXTURE_RECTANGLE_EXT : [attribBuffer target];
			if (attribBufferTarget==GL_TEXTURE_RECTANGLE_EXT)
				[varDeclarations appendString:VVFMTSTRING(@"uniform sampler2DRect\t\t%@;\n",attribName)];
			else if (attribBufferTarget==GL_TEXTURE_CUBE_MAP)
				[varDeclarations appendString:VVFMTSTRING(@"uniform samplerCube\t\t%@;\n",attribName)];
			else
				[varDeclarations appendString:VVFMTSTRING(@"uniform sampler2D\t\t%@;\n",attribName)];
			
			//	both cubes and normal images need the imgSize
			[varDeclarations appendString:VVFMTSTRING(@"uniform vec2\t\t_%@_imgSize;\n",attribName)];
			//	only normal images need the imgRect and flip
			if (attribBufferTarget!=GL_TEXTURE_CUBE_MAP)	{
				//	a vec4 describing the image rect IN NATIVE GL TEXTURE COORDS (2D is normalized, RECT is not)
				[varDeclarations appendString:VVFMTSTRING(@"uniform vec4\t\t_%@_imgRect;\n",attribName)];
				//	a bool describing whether the image in the texture should be flipped vertically
				[varDeclarations appendString:VVFMTSTRING(@"uniform bool\t\t_%@_flip;\n",attribName)];
			}
		}
	}
	[imageImports unlock];
	//	add the variables for the persistent buffers
	[persistentBufferArray rdlock];
	for (ISFTargetBuffer *targetBuffer in [persistentBufferArray array])	{
		NSString		*bufferName = [targetBuffer name];
		VVBuffer		*tmpBuffer = [targetBuffer buffer];
		if (tmpBuffer!=nil && [tmpBuffer target]==GL_TEXTURE_2D)
			[varDeclarations appendString:VVFMTSTRING(@"uniform sampler2D\t\t%@;\n",bufferName)];
		else
			[varDeclarations appendString:VVFMTSTRING(@"uniform sampler2DRect\t\t%@;\n",bufferName)];
		[varDeclarations appendString:VVFMTSTRING(@"uniform vec4\t\t_%@_imgRect;\n",bufferName)];
		[varDeclarations appendString:VVFMTSTRING(@"uniform vec2\t\t_%@_imgSize;\n",bufferName)];
		[varDeclarations appendString:VVFMTSTRING(@"uniform bool\t\t_%@_flip;\n",bufferName)];
	}
	[persistentBufferArray unlock];
	//	add the variables for the temp buffers
	[tempBufferArray rdlock];
	for (ISFTargetBuffer *targetBuffer in [tempBufferArray array])	{
		NSString			*bufferName = [targetBuffer name];
		VVBuffer			*tmpBuffer = [targetBuffer buffer];
		if (tmpBuffer!=nil && [tmpBuffer target]==GL_TEXTURE_2D)
			[varDeclarations appendString:VVFMTSTRING(@"uniform sampler2D\t\t%@;\n",bufferName)];
		else
			[varDeclarations appendString:VVFMTSTRING(@"uniform sampler2DRect\t\t%@;\n",bufferName)];
		[varDeclarations appendString:VVFMTSTRING(@"uniform vec4\t\t_%@_imgRect;\n",bufferName)];
		[varDeclarations appendString:VVFMTSTRING(@"uniform vec2\t\t_%@_imgSize;\n",bufferName)];
		[varDeclarations appendString:VVFMTSTRING(@"uniform bool\t\t_%@_flip;\n",bufferName)];
	}
	[tempBufferArray unlock];
	
	//	add the "PASSINDEX" variable
	[varDeclarations appendString:@"uniform int\t\tPASSINDEX;\n"];
	//	add the "RENDERSIZE" variable
	[varDeclarations appendString:@"uniform vec2\t\tRENDERSIZE;\n"];
	//	add the coord vars
	//[varDeclarations appendString:@"varying vec2\t\tvv_fragCoord;\n"];
	[varDeclarations appendString:@"varying vec2\t\tvv_FragNormCoord;\n"];
	[varDeclarations appendString:@"varying vec3\t\tvv_VertNorm;\n"];
	[varDeclarations appendString:@"varying vec3\t\tvv_VertPos;\n"];
	//	add the time var
	[varDeclarations appendString:@"uniform float\t\tTIME;\n"];
	
	return varDeclarations;
}
- (NSMutableDictionary *) _assembleSubstitutionDict	{
	if (!bufferRequiresEval)
		return nil;
	NSMutableDictionary		*returnMe = MUTDICT;
	[inputs rdlock];
	for (ISFAttrib *attrib in [inputs array])	{
		ISFAttribValType	attribType = [attrib attribType];
		ISFAttribVal		attribVal = [attrib currentVal];
		
		switch (attribType)	{
			case ISFAT_Event:
				[returnMe setObject:((attribVal.eventVal) ? NUMFLOAT(1.0) : NUMFLOAT(0.0)) forKey:[attrib attribName]];
				break;
			case ISFAT_Bool:
				[returnMe setObject:((attribVal.boolVal) ? NUMFLOAT(1.0) : NUMFLOAT(0.0)) forKey:[attrib attribName]];
				break;
			case ISFAT_Long:
				[returnMe setObject:NUMFLOAT(attribVal.longVal) forKey:[attrib attribName]];
				break;
			case ISFAT_Float:
				[returnMe setObject:NUMFLOAT(attribVal.floatVal) forKey:[attrib attribName]];
				break;
			case ISFAT_Point2D:
				break;
			case ISFAT_Color:
				break;
			case ISFAT_Image:
				break;
			case ISFAT_Cube:
				break;
		}
	}
	[inputs unlock];
	return returnMe;
}
- (void) _clearImageImports	{
	if (deleted || imageImports==nil)
		return;
	[imageImports wrlock];
	for (ISFAttrib *attrib in [imageImports array])	{
		NSString		*importPath = [attrib attribDescription];
		[_ISFImportedImages wrlock];
		VVBuffer		*importBuffer = [_ISFImportedImages objectForKey:importPath];
		if (importBuffer != nil)	{
			//	the num at the userInfo stores how many inputs are using the buffer
			NSNumber		*tmpNum = [importBuffer userInfo];
			tmpNum = [NSNumber numberWithInt:[tmpNum intValue]-1];
			[importBuffer setUserInfo:tmpNum];
			if ([tmpNum intValue]<1)
				[_ISFImportedImages removeObjectForKey:importPath];
		}
		[_ISFImportedImages unlock];
	}
	[imageImports removeAllObjects];
	[imageImports unlock];
}
- (void) _renderPrep	{
	//NSLog(@"%s",__func__);
	//	assemble a string that describes whether the images to be passed to the shader are 2d or rect textures
	NSMutableString		*tmpMutString = [NSMutableString stringWithCapacity:0];
	[imageInputs rdlock];
	for (ISFAttrib *attrib in [imageInputs array])	{
		ISFAttribValType		attribType = [attrib attribType];
		if (attribType==ISFAT_Image)	{
			VVBuffer		*tmpBuffer = [attrib userInfo];
			GLenum			tmpTarget = (tmpBuffer==nil) ? GL_TEXTURE_RECTANGLE_EXT : [tmpBuffer target];
			if (tmpTarget==GL_TEXTURE_RECTANGLE_EXT)
				[tmpMutString appendString:@"R"];
			else
				[tmpMutString appendString:@"2"];
		}
		else if (attribType==ISFAT_Cube)	{
			[tmpMutString appendString:@"C"];
		}
	}
	[imageInputs unlock];
	
	[imageImports rdlock];
	for (ISFAttrib *attrib in [imageImports array])	{
		ISFAttribValType		attribType = [attrib attribType];
		if (attribType==ISFAT_Image)	{
			VVBuffer		*tmpBuffer = [attrib userInfo];
			GLenum			tmpTarget = (tmpBuffer==nil) ? GL_TEXTURE_RECTANGLE_EXT : [tmpBuffer target];
			if (tmpTarget==GL_TEXTURE_RECTANGLE_EXT)
				[tmpMutString appendString:@"R"];
			else
				[tmpMutString appendString:@"2"];
		}
		else if (attribType==ISFAT_Cube)	{
			[tmpMutString appendString:@"C"];
		}
	}
	[imageImports unlock];
	
	[persistentBufferArray rdlock];
	for (ISFTargetBuffer *targetBuffer in [persistentBufferArray array])	{
		VVBuffer		*tmpBuffer = [targetBuffer buffer];
		GLenum			tmpTarget = (tmpBuffer==nil) ? GL_TEXTURE_RECTANGLE_EXT : [tmpBuffer target];
		if (tmpTarget==GL_TEXTURE_RECTANGLE_EXT)
			[tmpMutString appendString:@"R"];
		else
			[tmpMutString appendString:@"2"];
	}
	[persistentBufferArray unlock];
	
	[tempBufferArray rdlock];
	for (ISFTargetBuffer *targetBuffer in [tempBufferArray array])	{
		VVBuffer		*tmpBuffer = [targetBuffer buffer];
		GLenum			tmpTarget = (tmpBuffer==nil) ? GL_TEXTURE_RECTANGLE_EXT : [tmpBuffer target];
		if (tmpTarget==GL_TEXTURE_RECTANGLE_EXT)
			[tmpMutString appendString:@"R"];
		else
			[tmpMutString appendString:@"2"];
	}
	[tempBufferArray unlock];
	
	
	OSSpinLockLock(&srcLock);
	//	if the string i just assembled doesn't match the current compiledInputTypeString
	if (compiledInputTypeString==nil || ![compiledInputTypeString isEqualToString:tmpMutString])	{
		//NSLog(@"\t\tlast input type string doesn't match current, re-assembling shader src");
		VVRELEASE(compiledInputTypeString);
		compiledInputTypeString = [tmpMutString copy];
		OSSpinLockUnlock(&srcLock);
		
		[self _assembleShaderSource];
	}
	else
		OSSpinLockUnlock(&srcLock);
	
	
	//	store these values, then check them after the super's "_renderPrep"...
	BOOL		vShaderUpdatedFlag = vertexShaderUpdated;
	BOOL		fShaderUpdatedFlag = fragmentShaderUpdated;
	
	//	tell the super to do its _renderPrep, which will compile the shader and get it all set up if necessary
	[super _renderPrep];
	
	//	...if either of these values have changed, the program has been recompiled and i need to find new uniform locations for all the attributes (the uniforms in the GLSL programs)
	BOOL		findNewUniforms = NO;
	if (vShaderUpdatedFlag!=vertexShaderUpdated || fShaderUpdatedFlag!=fragmentShaderUpdated)
		findNewUniforms = YES;
	
	
	//	run through the inputs, applying the current values to the shader
	[inputs rdlock];
	CGLContextObj	cgl_ctx = [context CGLContextObj];
	__block GLint		samplerLoc = 0;
	int			textureCount = 0;
	VVBuffer	*tmpBuffer = nil;
	NSRect		tmpRect;
	char		*tmpCString = malloc(sizeof(char)*64);
	for (ISFAttrib *attrib in [inputs array])	{
		ISFAttribValType	attribType = [attrib attribType];
		ISFAttribVal		attribVal = [attrib currentVal];
		__block const char		*attribNameC = nil;
		
		void		(^findNewUniformsBlock)(void) = ^(void)	{
			if (findNewUniforms)	{
				attribNameC = [[attrib attribName] UTF8String];
				samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,attribNameC);
				if (samplerLoc >= 0)
					[attrib setUniformLocation:samplerLoc forIndex:0];
			}
			else
				samplerLoc = [attrib uniformLocationForIndex:0];
		};
		
		switch (attribType)	{
			case ISFAT_Event:
				findNewUniformsBlock();
				if (samplerLoc>=0)
					glUniform1i(samplerLoc, ((attribVal.eventVal)?1:0));
				attribVal.eventVal = NO;
				[attrib setCurrentVal:attribVal];
				break;
			case ISFAT_Bool:
				findNewUniformsBlock();
				if (samplerLoc>=0)
					glUniform1i(samplerLoc, ((attribVal.boolVal)?1:0));
				break;
			case ISFAT_Long:
				findNewUniformsBlock();
				if (samplerLoc>=0)
					glUniform1i(samplerLoc, attribVal.longVal);
				break;
			case ISFAT_Float:
				findNewUniformsBlock();
				if (samplerLoc>=0)
					glUniform1f(samplerLoc, attribVal.floatVal);
				break;
			case ISFAT_Point2D:
				findNewUniformsBlock();
				if (samplerLoc>=0)
					glUniform2f(samplerLoc, attribVal.point2DVal[0], attribVal.point2DVal[1]);
				break;
			case ISFAT_Color:
				findNewUniformsBlock();
				if (samplerLoc>=0)
					glUniform4f(samplerLoc, attribVal.colorVal[0], attribVal.colorVal[1], attribVal.colorVal[2], attribVal.colorVal[3]);
				break;
			case ISFAT_Image:
				if (findNewUniforms)	{
					attribNameC = [[attrib attribName] UTF8String];
					samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,attribNameC);
					if (samplerLoc >= 0)
						[attrib setUniformLocation:samplerLoc forIndex:0];
					
					sprintf(tmpCString,"_%s_imgRect",attribNameC);
					samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
					if (samplerLoc >= 0)
						[attrib setUniformLocation:samplerLoc forIndex:1];
					
					sprintf(tmpCString,"_%s_imgSize",attribNameC);
					samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
					if (samplerLoc >= 0)
						[attrib setUniformLocation:samplerLoc forIndex:2];
					
					sprintf(tmpCString,"_%s_flip",attribNameC);
					samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
					if (samplerLoc >= 0)
						[attrib setUniformLocation:samplerLoc forIndex:3];
				}
				tmpBuffer = [attrib userInfo];
				if (tmpBuffer != nil)	{
					//	pass the actual texture to the program
					glActiveTexture(GL_TEXTURE0 + textureCount);
					glBindTexture([tmpBuffer target],[tmpBuffer name]);
					
					samplerLoc = [attrib uniformLocationForIndex:0];
					if (samplerLoc >= 0)
						glUniform1i(samplerLoc,textureCount);
					++textureCount;
					//	pass the img rect to the program
					tmpRect = [tmpBuffer glReadySrcRect];
					samplerLoc = [attrib uniformLocationForIndex:1];
					if (samplerLoc >= 0)
						glUniform4f(samplerLoc,tmpRect.origin.x,tmpRect.origin.y,tmpRect.size.width,tmpRect.size.height);
					//	pass the size to the program
					tmpRect = [tmpBuffer srcRect];
					samplerLoc = [attrib uniformLocationForIndex:2];
					if (samplerLoc >= 0)
						glUniform2f(samplerLoc,tmpRect.size.width,tmpRect.size.height);
					//	pass the flippedness to the program
					samplerLoc = [attrib uniformLocationForIndex:3];
					if (samplerLoc >= 0)
						glUniform1i(samplerLoc,(([tmpBuffer flipped])?1:0));
				}
				break;
			case ISFAT_Cube:
				if (findNewUniforms)	{
					attribNameC = [[attrib attribName] UTF8String];
					samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,attribNameC);
					if (samplerLoc >= 0)
						[attrib setUniformLocation:samplerLoc forIndex:0];
					
					sprintf(tmpCString,"_%s_imgSize",attribNameC);
					samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
					if (samplerLoc >= 0)
						[attrib setUniformLocation:samplerLoc forIndex:2];
				}
				tmpBuffer = [attrib userInfo];
				if (tmpBuffer != nil)	{
					//	pass the actual texture to the program
					glActiveTexture(GL_TEXTURE0 + textureCount);
					glBindTexture([tmpBuffer target],[tmpBuffer name]);
					
					samplerLoc = [attrib uniformLocationForIndex:0];
					if (samplerLoc >= 0)
						glUniform1i(samplerLoc,textureCount);
					++textureCount;
					//	pass the size to the program
					tmpRect = [tmpBuffer srcRect];
					samplerLoc = [attrib uniformLocationForIndex:2];
					if (samplerLoc >= 0)
						glUniform2f(samplerLoc,tmpRect.size.width,tmpRect.size.height);
				}
				break;
		}
	}
	[inputs unlock];
	
	
	//	apply the imported images to the shader
	[imageImports rdlock];
	for (ISFAttrib *attrib in [imageImports array])	{
		ISFAttribValType	attribType = [attrib attribType];
		if (attribType == ISFAT_Image)	{
			const char				*attribNameC = nil;
			if (findNewUniforms)	{
				attribNameC = [[attrib attribName] UTF8String];
				samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,attribNameC);
				if (samplerLoc >= 0)
					[attrib setUniformLocation:samplerLoc forIndex:0];
				
				sprintf(tmpCString,"_%s_imgRect",attribNameC);
				samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
				if (samplerLoc >= 0)
					[attrib setUniformLocation:samplerLoc forIndex:1];
				
				sprintf(tmpCString,"_%s_imgSize",attribNameC);
				samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
				if (samplerLoc >= 0)
					[attrib setUniformLocation:samplerLoc forIndex:2];
				
				sprintf(tmpCString,"_%s_flip",attribNameC);
				samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
				if (samplerLoc >= 0)
					[attrib setUniformLocation:samplerLoc forIndex:3];
			}
			tmpBuffer = [attrib userInfo];
			if (tmpBuffer != nil)	{
				//	pass the actual texture to the program
				glActiveTexture(GL_TEXTURE0 + textureCount);
				glBindTexture([tmpBuffer target],[tmpBuffer name]);
				
				samplerLoc = [attrib uniformLocationForIndex:0];
				if (samplerLoc >= 0)
					glUniform1i(samplerLoc,textureCount);
				++textureCount;
				//	pass the img rect to the program
				tmpRect = [tmpBuffer glReadySrcRect];
				samplerLoc = [attrib uniformLocationForIndex:1];
				if (samplerLoc >= 0)
					glUniform4f(samplerLoc,tmpRect.origin.x,tmpRect.origin.y,tmpRect.size.width,tmpRect.size.height);
				//	pass the size to the program
				tmpRect = [tmpBuffer srcRect];
				samplerLoc = [attrib uniformLocationForIndex:2];
				if (samplerLoc >= 0)
					glUniform2f(samplerLoc,tmpRect.size.width,tmpRect.size.height);
				//	pass the flippedness to the program
				samplerLoc = [attrib uniformLocationForIndex:3];
				if (samplerLoc >= 0)
					glUniform1i(samplerLoc,(([tmpBuffer flipped])?1:0));
			}
		}
		else if (attribType == ISFAT_Cube)	{
			const char				*attribNameC = nil;
			if (findNewUniforms)	{
				attribNameC = [[attrib attribName] UTF8String];
				samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,attribNameC);
				if (samplerLoc >= 0)
					[attrib setUniformLocation:samplerLoc forIndex:0];
				
				sprintf(tmpCString,"_%s_imgSize",attribNameC);
				samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
				if (samplerLoc >= 0)
					[attrib setUniformLocation:samplerLoc forIndex:2];
			}
			tmpBuffer = [attrib userInfo];
			if (tmpBuffer != nil)	{
				//	pass the actual texture to the program
				glActiveTexture(GL_TEXTURE0 + textureCount);
				glBindTexture([tmpBuffer target],[tmpBuffer name]);
				
				samplerLoc = [attrib uniformLocationForIndex:0];
				if (samplerLoc >= 0)
					glUniform1i(samplerLoc,textureCount);
				++textureCount;
				//	pass the size to the program
				tmpRect = [tmpBuffer srcRect];
				samplerLoc = [attrib uniformLocationForIndex:2];
				if (samplerLoc >= 0)
					glUniform2f(samplerLoc,tmpRect.size.width,tmpRect.size.height);
			}
		}
	}
	[imageImports unlock];
	
	
	//	apply the persistent buffers to the shader
	[persistentBufferArray rdlock];
	for (ISFTargetBuffer *targetBuffer in [persistentBufferArray array])	{
		if (findNewUniforms)	{
			const char		*attribNameC = nil;
			attribNameC = [[targetBuffer name] UTF8String];
			samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,attribNameC);
			if (samplerLoc >= 0)
				[targetBuffer setUniformLocation:samplerLoc forIndex:0];
			
			sprintf(tmpCString,"_%s_imgRect",attribNameC);
			samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
			if (samplerLoc >= 0)
				[targetBuffer setUniformLocation:samplerLoc forIndex:1];
			
			sprintf(tmpCString,"_%s_imgSize",attribNameC);
			samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
			if (samplerLoc >= 0)
				[targetBuffer setUniformLocation:samplerLoc forIndex:2];
			
			sprintf(tmpCString,"_%s_flip",attribNameC);
			samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
			if (samplerLoc >= 0)
				[targetBuffer setUniformLocation:samplerLoc forIndex:3];
		}
		VVBuffer		*tmpBuffer = [targetBuffer buffer];
		if (tmpBuffer != nil)	{
			//	pass the actual texture to the program
			glActiveTexture(GL_TEXTURE0 + textureCount);
			glBindTexture([tmpBuffer target],[tmpBuffer name]);
			
			samplerLoc = [targetBuffer uniformLocationForIndex:0];
			if (samplerLoc >= 0)
				glUniform1i(samplerLoc,textureCount);
			++textureCount;
			//	pass the img rect to the program
			tmpRect = [tmpBuffer glReadySrcRect];
			samplerLoc = [targetBuffer uniformLocationForIndex:1];
			if (samplerLoc >= 0)
				glUniform4f(samplerLoc,tmpRect.origin.x,tmpRect.origin.y,tmpRect.size.width,tmpRect.size.height);
			//	pass the size to the program
			tmpRect = [tmpBuffer srcRect];
			samplerLoc = [targetBuffer uniformLocationForIndex:2];
			if (samplerLoc >= 0)
				glUniform2f(samplerLoc,tmpRect.size.width,tmpRect.size.height);
			//	pass the flippedness to the program
			samplerLoc = [targetBuffer uniformLocationForIndex:3];
			if (samplerLoc >= 0)
				glUniform1i(samplerLoc,(([tmpBuffer flipped])?1:0));
		}
	}
	[persistentBufferArray unlock];
	
	
	//	apply the temp buffers to the shader
	[tempBufferArray rdlock];
	for (ISFTargetBuffer *targetBuffer in [tempBufferArray array])	{
		if (findNewUniforms)	{
			const char		*attribNameC = nil;
			attribNameC = [[targetBuffer name] UTF8String];
			samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,attribNameC);
			if (samplerLoc >= 0)
				[targetBuffer setUniformLocation:samplerLoc forIndex:0];
			
			sprintf(tmpCString,"_%s_imgRect",attribNameC);
			samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
			if (samplerLoc >= 0)
				[targetBuffer setUniformLocation:samplerLoc forIndex:1];
			
			sprintf(tmpCString,"_%s_imgSize",attribNameC);
			samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
			if (samplerLoc >= 0)
				[targetBuffer setUniformLocation:samplerLoc forIndex:2];
			
			sprintf(tmpCString,"_%s_flip",attribNameC);
			samplerLoc = (program<=0) ? -1 : glGetUniformLocation(program,tmpCString);
			if (samplerLoc >= 0)
				[targetBuffer setUniformLocation:samplerLoc forIndex:3];
		}
		VVBuffer		*tmpBuffer = [targetBuffer buffer];
		if (tmpBuffer != nil)	{
			//	pass the actual texture to the program
			glActiveTexture(GL_TEXTURE0 + textureCount);
			glBindTexture([tmpBuffer target],[tmpBuffer name]);
			
			samplerLoc = [targetBuffer uniformLocationForIndex:0];
			if (samplerLoc >= 0)
				glUniform1i(samplerLoc,textureCount);
			++textureCount;
			//	pass the img rect to the program
			tmpRect = [tmpBuffer glReadySrcRect];
			samplerLoc = [targetBuffer uniformLocationForIndex:1];
			if (samplerLoc >= 0)
				glUniform4f(samplerLoc,tmpRect.origin.x,tmpRect.origin.y,tmpRect.size.width,tmpRect.size.height);
			//	pass the size to the program
			tmpRect = [tmpBuffer srcRect];
			samplerLoc = [targetBuffer uniformLocationForIndex:2];
			if (samplerLoc >= 0)
				glUniform2f(samplerLoc,tmpRect.size.width,tmpRect.size.height);
			//	pass the flippedness to the program
			samplerLoc = [targetBuffer uniformLocationForIndex:3];
			if (samplerLoc >= 0)
				glUniform1i(samplerLoc,(([tmpBuffer flipped])?1:0));
		}
	}
	[tempBufferArray unlock];
	
	free(tmpCString);
	
	
	OSSpinLockLock(&srcLock);
	if (findNewUniforms)	{
		renderSizeUniformLoc = (program<=0) ? -1 : glGetUniformLocation(program, "RENDERSIZE");
		passIndexUniformLoc = (program<=0) ? -1 : glGetUniformLocation(program, "PASSINDEX");
		timeUniformLoc = (program<=0) ? -1 : glGetUniformLocation(program, "TIME");
	}
	if (renderSizeUniformLoc >= 0)
		glUniform2f(renderSizeUniformLoc, size.width, size.height);
	if (passIndexUniformLoc >= 0)
		glUniform1i(passIndexUniformLoc, passIndex-1);
	if (timeUniformLoc >= 0)
		glUniform1f(timeUniformLoc, renderTime);
	OSSpinLockUnlock(&srcLock);
}
- (void) renderCallback:(GLScene *)s	{
	//NSLog(@"%s",__func__);
	NSRect		tmpRect = NSMakeRect(0,0,0,0);
	tmpRect.size = [s size];
	CGLContextObj		cgl_ctx = [s CGLContextObj];
	glColor4f(1.0, 1.0, 1.0, 1.0);
	glEnableClientState(GL_VERTEX_ARRAY);
	GLDRAWRECT(tmpRect);
}


- (void) setVertexShaderString:(NSString *)n	{
	[super setVertexShaderString:n];
	if (n != nil)	{
		[inputs rdlock];
		for (ISFAttrib *attrib in [inputs array])	{
			[attrib clearUniformLocations];
		}
		[inputs unlock];
		
		[imageImports rdlock];
		for (ISFAttrib *attrib in [imageImports array])	{
			[attrib clearUniformLocations];
		}
		[imageImports unlock];
	}
}
- (void) setFragmentShaderString:(NSString *)n	{
	[super setFragmentShaderString:n];
	if (n != nil)	{
		[inputs rdlock];
		for (ISFAttrib *attrib in [inputs array])	{
			[attrib clearUniformLocations];
		}
		[inputs unlock];
		
		[imageImports rdlock];
		for (ISFAttrib *attrib in [imageImports array])	{
			[attrib clearUniformLocations];
		}
		[imageImports unlock];
	}
}


- (void) setBuffer:(VVBuffer *)b forInputImageKey:(NSString *)k	{
	//NSLog(@"%s ... %@, %@",__func__,b,k);
	if (deleted || b==nil || k==nil)
		return;
	[imageInputs rdlock];
	for (ISFAttrib *attrib in [imageInputs array])	{
		if ([[attrib attribName] isEqualToString:k])	{
			[attrib setUserInfo:b];
			break;
		}
	}
	[imageInputs unlock];
}
- (void) setFilterInputImageBuffer:(VVBuffer *)b	{
	if (deleted || b==nil)
		return;
	[imageInputs rdlock];
	for (ISFAttrib *attrib in [imageInputs array])	{
		if ([attrib isFilterInputImage])	{
			[attrib setUserInfo:b];
			break;
		}
	}
	[imageInputs unlock];
}
- (VVBuffer *) bufferForInputImageKey:(NSString *)k	{
	if (deleted || k==nil)
		return nil;
	VVBuffer		*returnMe = nil;
	NSString		*attribName = nil;
	//	try to find the buffer in the image inputs
	[imageInputs rdlock];
	for (ISFAttrib *attrib in [imageInputs array])	{
		attribName = [attrib attribName];
		if (attribName!=nil && [attribName isEqualToString:k])	{
			returnMe = [attrib userInfo];
			break;
		}
	}
	[imageInputs unlock];
	
	//	if i still haven't found it, try to find the buffer in the image imports
	if (returnMe == nil)	{
		[imageImports rdlock];
		for (ISFAttrib *attrib in [imageImports array])	{
			attribName = [attrib attribName];
			if (attribName!=nil && [attribName isEqualToString:k])	{
				returnMe = [attrib userInfo];
				break;
			}
		}
		[imageImports unlock];
		
		//	if i still haven't found it, try to find the buffer in the persistent buffers
		if (returnMe == nil)	{
			[persistentBufferArray rdlock];
			for (ISFTargetBuffer *targetBuffer in [persistentBufferArray array])	{
				attribName = [targetBuffer name];
				if (attribName!=nil && [attribName isEqualToString:k])	{
					returnMe = [targetBuffer buffer];
					break;
				}
			}
			[persistentBufferArray unlock];
			
			//	if i still haven't found it, try to find the buffer in the temporary buffers
			if (returnMe == nil)	{
				[tempBufferArray rdlock];
				for (ISFTargetBuffer *targetBuffer in [tempBufferArray array])	{
					attribName = [targetBuffer name];
					if (attribName!=nil && [attribName isEqualToString:k])	{
						returnMe = [targetBuffer buffer];
						break;
					}
				}
				[tempBufferArray unlock];
			}
		}
	}
	return returnMe;
}
- (void) purgeInputGLTextures	{
	if (deleted)
		return;
	//	try to find the buffer in the image inputs
	[imageInputs rdlock];
	for (ISFAttrib *attrib in [imageInputs array])	{
		ISFAttribValType	type = [attrib attribType];
		if (type==ISFAT_Image || type==ISFAT_Cube)
			[attrib setUserInfo:nil];
	}
	[imageInputs unlock];
}
- (void) setValue:(ISFAttribVal)n forInputKey:(NSString *)k	{
	if (deleted || k==nil)
		return;
	[inputs rdlock];
	for (ISFAttrib *attrib in [inputs array])	{
		if ([[attrib attribName] isEqualToString:k])	{
			[attrib setCurrentVal:n];
			break;
		}
	}
	[inputs unlock];
}
- (void) setNSObjectVal:(id)n forInputKey:(NSString *)k	{
	//NSLog(@"%s ... %@ - %@",__func__,k,n);
	if (deleted || n==nil || k==nil)
		return;
	[inputs rdlock];
	for (ISFAttrib *attrib in [inputs array])	{
		if ([[attrib attribName] isEqualToString:k])	{
			ISFAttribValType	type = [attrib attribType];
			ISFAttribVal		newVal;
			switch (type)	{
				case ISFAT_Event:
					newVal.eventVal = [n boolValue];
					[attrib setCurrentVal:newVal];
					break;
				case ISFAT_Bool:
					newVal.boolVal = [n boolValue];
					[attrib setCurrentVal:newVal];
					break;
				case ISFAT_Long:
					newVal.longVal = [n longValue];
					[attrib setCurrentVal:newVal];
					break;
				case ISFAT_Float:
					newVal.floatVal = [n floatValue];
					[attrib setCurrentVal:newVal];
					break;
				case ISFAT_Point2D:	{
						NSPoint		tmpPoint = [n pointValue];
						newVal.point2DVal[0] = tmpPoint.x;
						newVal.point2DVal[1] = tmpPoint.y;
						[attrib setCurrentVal:newVal];
					}
					break;
				case ISFAT_Color:	{
					CGFloat		tmpVals[4];
					[n getComponents:tmpVals];
					for (int i=0; i<4; ++i)
						newVal.colorVal[i] = tmpVals[i];
					[attrib setCurrentVal:newVal];
					break;
				}
				case ISFAT_Image:
					[attrib setUserInfo:n];
					break;
				case ISFAT_Cube:
					[attrib setUserInfo:n];
					break;
			}
			break;
		}
	}
	[inputs unlock];
}
- (NSMutableArray *) inputsOfType:(ISFAttribValType)t	{
	NSMutableArray		*returnMe = MUTARRAY;
	[inputs rdlock];
	for (ISFAttrib *attrib in [inputs array])	{
		if ([attrib attribType]==t)
			[returnMe addObject:attrib];
	}
	[inputs unlock];
	return returnMe;
}
- (ISFAttrib *) attribForInputWithKey:(NSString *)k	{
	if (k==nil || deleted)
		return nil;
	ISFAttrib		*returnMe = nil;
	[inputs rdlock];
	for (ISFAttrib *attrib in [inputs array])	{
		if ([[attrib attribName] isEqualToString:k])	{
			returnMe = attrib;
			break;
		}
	}
	[inputs unlock];
	if (returnMe != nil)
		[returnMe retain];
	return [returnMe autorelease];
}


- (ISFTargetBuffer *) findPersistentBufferNamed:(NSString *)n	{
	if (n==nil || persistentBufferArray==nil)
		return nil;
	ISFTargetBuffer	*returnMe = nil;
	[persistentBufferArray rdlock];
	for (ISFTargetBuffer *targetBuffer in [persistentBufferArray array])	{
		NSString		*bufferName = [targetBuffer name];
		if (bufferName!=nil && [bufferName isEqualToString:n])	{
			returnMe = targetBuffer;
			break;
		}
	}
	[persistentBufferArray unlock];
	return returnMe;
}
- (ISFTargetBuffer *) findTempBufferNamed:(NSString *)n	{
	if (n==nil || tempBufferArray==nil)
		return nil;
	ISFTargetBuffer	*returnMe = nil;
	[tempBufferArray rdlock];
	for (ISFTargetBuffer *targetBuffer in [tempBufferArray array])	{
		NSString		*bufferName = [targetBuffer name];
		if (bufferName!=nil && [bufferName isEqualToString:n])	{
			returnMe = targetBuffer;
			break;
		}
	}
	[tempBufferArray unlock];
	return returnMe;
}


@synthesize throwExceptions;
- (NSString *) filePath	{
	NSString		*returnMe = nil;
	OSSpinLockLock(&propertyLock);
	returnMe = (filePath==nil) ? nil : [[filePath retain] autorelease];
	OSSpinLockUnlock(&propertyLock);
	return returnMe;
}
- (NSString *) fileName	{
	NSString		*returnMe = nil;
	OSSpinLockLock(&propertyLock);
	returnMe = (fileName==nil) ? nil : [[fileName retain] autorelease];
	OSSpinLockUnlock(&propertyLock);
	return returnMe;
}
- (NSString *) fileDescription	{
	NSString		*returnMe = nil;
	OSSpinLockLock(&propertyLock);
	returnMe = (fileDescription==nil) ? nil : [[fileDescription retain] autorelease];
	OSSpinLockUnlock(&propertyLock);
	return returnMe;
}
- (NSString *) fileCredits	{
	NSString		*returnMe = nil;
	OSSpinLockLock(&propertyLock);
	returnMe = (fileCredits==nil) ? nil : [[fileCredits retain] autorelease];
	OSSpinLockUnlock(&propertyLock);
	return returnMe;
}
- (NSArray *) categoryNames	{
	NSArray		*returnMe = nil;
	OSSpinLockLock(&propertyLock);
	returnMe = (categoryNames==nil) ? nil : [[categoryNames retain] autorelease];
	OSSpinLockUnlock(&propertyLock);
	return returnMe;
}
@synthesize inputs;
@synthesize imageInputs;
@synthesize renderSize;
- (int) passCount	{
	if (deleted || passes==nil)
		return 0;
	return (int)[passes count];
}
- (int) imageInputsCount	{
	if (deleted || imageInputs==nil)
		return 0;
	return (int)[imageInputs lockCount];
}
- (NSString *) jsonString	{
	if (deleted)
		return nil;
	NSString		*returnMe = nil;
	OSSpinLockLock(&srcLock);
	returnMe = (jsonString==nil) ? nil : [[jsonString retain] autorelease];
	OSSpinLockUnlock(&srcLock);
	return returnMe;
}
- (NSString *) vertShaderSource	{
	if (deleted)
		return nil;
	NSString		*returnMe = nil;
	OSSpinLockLock(&srcLock);
	returnMe = (vertShaderSource==nil) ? nil : [[vertShaderSource retain] autorelease];
	OSSpinLockUnlock(&srcLock);
	return returnMe;
}
- (NSString *) fragShaderSource	{
	if (deleted)
		return nil;
	NSString		*returnMe = nil;
	OSSpinLockLock(&srcLock);
	returnMe = (fragShaderSource==nil) ? nil : [[fragShaderSource retain] autorelease];
	OSSpinLockUnlock(&srcLock);
	return returnMe;
}


- (void) _renderLock	{
	if (deleted)
		return;
	pthread_mutex_lock(&renderLock);
}
- (void) _renderUnlock	{
	if (deleted)
		return;
	pthread_mutex_unlock(&renderLock);
}


@end

#import "VVMetadataItem.h"
#import <VVBasics/VVBasics.h>
//#import "NSFileManagerAdditions.h"

static NSMutableDictionary *_UTITable = NULL; 

@implementation VVMetadataItem

+ (void) initialize	{
	//NSLog(@"%s",__func__);
	if (_UTITable != nil)
		return;
	_UTITable = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
}

+ (id) createWithPath:(NSString *)p	{
	//return [[[VVMetadataItem alloc] initWithPath:p] autorelease];
	if (p==nil)
		return nil;
	
	VVMetadataItem		*returnMe = [[VVMetadataItem alloc] initWithPath:p];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}

- (id) initWithPath:(NSString *)p	{
	//NSLog(@"%s",__func__);
	if (p == nil)	
		goto BAIL;
	
	NSFileManager *fm = [[NSFileManager alloc] init];
	if (![fm fileExistsAtPath:p])	{
		[fm release];
		goto BAIL;
	}

	[fm release];
	
	if (self = [super init])	{
		//NSLog(@"\t\tloading path : %@", p);
		//	If it is disk based..
		_item = MDItemCreate(NULL, (CFStringRef)p);
		//_item = NULL;

		//	If the meta data object doesn't work, make a fake attributes dict with whatever information I do have
		if (_item==NULL)	{
			NSLog(@"err: meta data item was null for path %@",p);
			[self loadAttributesFromFilePath:p];
		}
		//	If the meta data item fails to return for content type or path, use the fallback
		else if (([self valueForKey:@"kMDItemContentType"]==nil)||
					([[self valueForKey:@"kMDItemContentType"] isEqualToString:@""])||
					([self valueForKey:@"kMDItemPath"]==nil)||
					([[self valueForKey:@"kMDItemPath"] isEqualToString:@""]))	{
			NSLog(@"err: MDItem created but no content type detected at path - %@",p);
			CFRelease(_item);
			_item = NULL;
			//[self performSelectorOnMainThread:@selector(loadAttributesFromFilePath:) withObject:p waitUntilDone:YES];
			[self loadAttributesFromFilePath:p];
			//NSLog(@"\t\tattribs: %@", [self valuesForAttributes:[self attributes]]);
		}
		
		
		return self;
	}
BAIL:
	if (self != nil)
		[self release];
	return nil;
}

+ (id) createWithMDItemRef:(MDItemRef)md	{
	VVMetadataItem		*returnMe = [[VVMetadataItem alloc] initWithMDItemRef:md];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}

- (id) initWithMDItemRef:(MDItemRef)md	{
	if (md == NULL)
		goto BAIL;
		
	if (self = [super init])	{
		//NSLog(@"\t\tloading path : %@", p);
		//	If it is disk based..
		_item = md;
		CFRetain(_item);
		
		return self;
	}
BAIL:
	[self release];
	return nil;
}

- (void) loadAttributesFromFilePath:(NSString *)p	{
	if (p==nil)
		return;
	//NSLog(@"%s - %@",__func__, p);
	NSFileManager *fm = [[NSFileManager alloc] init];
	NSMutableDictionary	*tmpDict = [NSMutableDictionary dictionaryWithCapacity:0];
	
	//	MDItem can only work if the drive the file is on was indexed with spotlight
	//	This is the fallback method- uses a combination of NSWorkspace / NSFileManager / FSRef's
	//	to get / track the basic information needed and makes it available using the same keys as MDItem would use
	
	Boolean		isDirectory = false;
	NSString	*contentType = nil;
	NSWorkspace *ws = [[[NSWorkspace alloc] init] autorelease];
	
	//	Try to create a url from this and if it works see if it has a fileReferenceURL
	CFURLRef filePathURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)p, kCFURLPOSIXPathStyle, NO);
	
	//	If that fails, this might not be a disk based file
	//	Use this fallback for the path / name / content type / etc.
	if ((filePathURL == NULL) || ([(NSURL *)filePathURL fileReferenceURL] == nil))	{
		[tmpDict setObject:p forKey:@"kMDItemPath"];
		[tmpDict setObject:[p lastPathComponent] forKey:@"kMDItemFSName"];
		[tmpDict setObject:[p lastPathComponent] forKey:@"kMDItemDisplayName"];
		contentType = [(NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)[p pathExtension], kUTTypeContent) autorelease];
	}
	else	{
		//	Add the file name and display name.. use the actual file name
		NSString	*displayName = nil;
		
		displayName = [fm displayNameAtPath:p];
		
		if ((displayName == nil)||([displayName	isEqualToString:@""]))
			displayName = [p lastPathComponent];
		
		[tmpDict setObject:p forKey:@"kMDItemPath"];
		[tmpDict setObject:displayName forKey:@"kMDItemDisplayName"];
		[tmpDict setObject:displayName forKey:@"kMDItemFSName"];
		
		contentType = [ws typeOfFile:p error:nil];
	
		//	If NSWorkspace fails, try using the UTI services directly
		if (contentType == nil)	{
			if (isDirectory)	{
				contentType = [(NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)[p pathExtension], kUTTypeDirectory) autorelease];
			}
			else	{
				contentType = [(NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)[p pathExtension], kUTTypeContent) autorelease];
			}
		}
	}
	
	//	NSWorkspace / Launch servies gives me the most accurate UTI string
	//	However, it will not give me the whole UTI tree..
	if (contentType != nil)	{
		[tmpDict setObject:contentType forKey:@"kMDItemContentType"];
		//NSLog(@"\t\tUTI: %@ for extension: %@",contentType, [p pathExtension]);
		
		NSArray	*contentKindTree = [_UTITable objectForKey:contentType];
		
		if (contentKindTree==nil)	{
			//[self addTypeTreeForUIT:contentType];
			//	If this is the main thread generate the 
			if ([NSThread isMainThread])	{
				[self addTypeTreeForUTI:contentType];
				contentKindTree = [_UTITable objectForKey:contentType];
			}
			else	{
				[self performSelectorOnMainThread:@selector(addTypeTreeForUTI:) withObject:contentType waitUntilDone:NO];
				contentKindTree = [_UTITable objectForKey:contentType];
			}
			
		}
		if (contentKindTree != nil)	{
			//NSLog(@"\t\tcontentKindTree: %@",contentKindTree);	
			[tmpDict setObject:contentKindTree forKey:@"kMDItemContentTypeTree"];
		}
		else	{
			[tmpDict setObject:[NSArray arrayWithObject:contentType] forKey:@"kMDItemContentTypeTree"];
		}
		//	If I successfully got a content type, use localizedDescriptionForType: to get the Kind
		/*
		NSString	*contentKind = [ws localizedDescriptionForType:contentType];
		if (contentKind != nil)	{
			//NSLog(@"\t\tkind: %@",contentKind);
			[tmpDict setObject:contentKind forKey:@"kMDItemKind"];
		}
		*/
	}
	//NSLog(@"\t\t%@",tmpDict);
	_attributes = [[NSDictionary dictionaryWithDictionary:tmpDict] retain];
	[fm release];
	
	if (filePathURL!=NULL)	{
		CFRelease(filePathURL);
		filePathURL = NULL;
	}
}

- (void) dealloc	{
	//NSLog(@"%s",__func__);
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	if (_item!=NULL)	{
		CFRelease(_item);
		_item = NULL;
	}
	VVRELEASE(_attributes);
	[super dealloc];
}

//	required for using this with predicates
- (id) valueForKey:(NSString *)k	{
	return [self valueForAttribute:k];
}

//	calls MDItemCopyAttribute + autorelease
- (id) valueForAttribute:(id)attribute	{
	if (attribute == nil)	{
		return nil;
	}
	id	returnMe = nil;
	
	if (_item!=NULL)	{
		returnMe = [(id)MDItemCopyAttribute(_item, (CFStringRef)attribute) autorelease];
	}
	//	if the MDItem is NULL, use the fallback attributes / fsref
	//	use the fsref to get the item path & file system name - this technique auto-updates along with the changes
	else	{
		/*
		if ([attribute isEqualToString:@"kMDItemPath"])	{
			CFURLRef url = CFURLCreateFromFSRef(kCFAllocatorDefault, &_fsRef);
			if (url != NULL)	{
				returnMe = [(NSString*)CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle) autorelease];
				CFRelease(url);
			}
		}
		else if ([attribute isEqualToString:@"kMDItemFSName"])	{
			CFURLRef url = CFURLCreateFromFSRef(kCFAllocatorDefault, &_fsRef);
			if (url != NULL)	{
				returnMe = [(NSString*)CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle) autorelease];
				returnMe = [returnMe lastPathComponent];
				CFRelease(url);
			}
		}
		*/
	}
	
	if ((returnMe == nil)&&(_attributes != nil))	{
		//NSLog(@"\t\trequested %@",attribute);
		returnMe = [_attributes objectForKey:attribute];
	}

	return returnMe;
}

//	calls MDItemCopyAttributes + autorelease
- (NSDictionary *) valuesForAttributes:(NSArray *)attributes	{
	if (attributes == nil)	{
		return nil;
	}
	NSDictionary *returnMe = nil;

	if (_item!=NULL)	{
		returnMe = (NSDictionary *)MDItemCopyAttributes(_item, (CFArrayRef)attributes);
		if (returnMe)
			[returnMe autorelease];
	}
	else if (_attributes!=nil)	{
		NSArray	*objs = [_attributes objectsForKeys:attributes notFoundMarker:[NSNull null]];
		if ([objs count] == [attributes count])	{
			returnMe = [NSDictionary dictionaryWithObjects:objs forKeys:attributes];
		}
		else	{
			returnMe = [NSDictionary dictionary];
			NSLog(@"err: VVMetadataItem: valuesForAttributes: %lu count did not match %@",(unsigned long)[objs count], attributes);
		}
	}
	
	return returnMe;
}

//	calls MDItemCopyAttributeNames
//	note that this does not always return all the available attributes! eg. kMDItemPath, kMDItemFSName
- (NSArray *) attributes	{
	NSArray *returnMe = nil;
	
	if (_item!=NULL)
		returnMe = [(NSArray *)MDItemCopyAttributeNames(_item) autorelease];
	else if (_attributes!=nil)
		returnMe = [_attributes allKeys];
	
	return returnMe;
}

//	A method for quickly getting the path (the most common file information)
- (NSString *) path	{
	return [self valueForAttribute:@"kMDItemPath"];
}
//	A method for getting the display name
- (NSString *) displayName	{
	return [self valueForAttribute:@"kMDItemDisplayName"];
}

- (void) addTypeTreeForUTI:(NSString *)p	{
	if (p == nil)	{
		return;
	}
	
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	id					type = nil;
	NSString			*lastType = nil;
	
	//	Add the main type to the array
	type = [[p copy] autorelease];
	[returnMe addObject: type];
	//[type release];
	
	//	Now walk up the tree
	//	If we hit public.executable or public.item or the type becomes nil we've reached the end
	while ((type != nil)&&([type isEqualToString:@"public.executable"]==NO)&&([type isEqualToString:@"public.item"]==NO))	{
		//	Use UTTypeCopyDeclaration to get the next batch of UTI's in the tree
		if ([type isKindOfClass:[NSString class]]==NO)	{
			NSLog(@"err: TYPE WAS NOT A STRING : %@", type);
		}
		
		if (lastType==nil)	{
		
		}
		else if ([lastType isEqualToString:type])	{
			NSLog(@"err: last type was the same - breaking");
			break;
		}
		else	{
			//NSLog(@"\t\t\tlast type was %@",lastType);
		}
		
		VVRELEASE(lastType);
		lastType = [type copy];
		
		//NSLog(@"\t\tnow checking %@",type);
		
		NSDictionary *contentDeclaration = (NSDictionary *)UTTypeCopyDeclaration((CFStringRef) type);
		
		if (contentDeclaration)	{
			type = [(NSDictionary *)contentDeclaration objectForKey:@"UTTypeConformsTo"];
			
			//	The value returned for "UTTypeConformsTo" can be a string or an array
			//	If it is an array, copy all of the values in the array
			//	If it is a string, just copy the string
			if (type != nil)	{
				//NSLog(@"\t\tfound UTIs: %@",type);
				if ([type isKindOfClass:[NSArray class]])	{
					for (NSString *typeString in (NSArray *)type)	{
						NSString *tmpString = [typeString copy];
						[returnMe addObject:tmpString];
						[tmpString release];						
					}
					type = [returnMe lastObject];
				}
				else if ([type isKindOfClass:[NSString class]])	{
					//NSLog(@"\t\tfound UTI: %@",type);
					NSString *tmpString = [type copy];
					[returnMe addObject:tmpString];
					[tmpString release];
					type = tmpString;
				}
				else	{
					type = nil;
				}
			}
			CFRelease(contentDeclaration);
			//[(NSDictionary *)contentDeclaration autorelease];
		}
		else	{
			//NSLog(@"\t\tcontentDeclaration was nil");
			type = nil;
		}
	}
	//NSLog(@"\t\t%@",returnMe);
	[_UTITable setObject:returnMe forKey:p];
	VVRELEASE(lastType);
	//return returnMe;
}
@end

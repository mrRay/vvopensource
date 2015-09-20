#import "ISFFileManager.h"
#import "ISFStringAdditions.h"




@implementation ISFFileManager


+ (NSMutableArray *) allFilesForPath:(NSString *)path recursive:(BOOL)r	{
	return [self _filtersInDirectory:path recursive:r matchingFunctionality:ISFF_All];
}
+ (NSMutableArray *) imageFiltersForPath:(NSString *)path recursive:(BOOL)r	{
	return [self _filtersInDirectory:path recursive:r matchingFunctionality:ISFF_Filter];
}
+ (NSMutableArray *) generativeSourcesForPath:(NSString *)path recursive:(BOOL)r	{
	return [self _filtersInDirectory:path recursive:r matchingFunctionality:ISFF_Source];
}
+ (NSMutableArray *) defaultImageFilters	{
	NSMutableArray		*sys = [self imageFiltersForPath:@"/Library/Graphics/ISF" recursive:YES];
	[sys retain];
	NSMutableArray		*user = [self imageFiltersForPath:[@"~/Library/Graphics/ISF" stringByExpandingTildeInPath] recursive:YES];
	[sys addObjectsFromArray:user];
	return [sys autorelease];
}
+ (NSMutableArray *) defaultGenerativeSources	{
	NSMutableArray		*sys = [self generativeSourcesForPath:@"/Library/Graphics/ISF" recursive:YES];
	[sys retain];
	NSMutableArray		*user = [self generativeSourcesForPath:[@"~/Library/Graphics/ISF" stringByExpandingTildeInPath] recursive:YES];
	[sys addObjectsFromArray:user];
	return [sys autorelease];
}
+ (NSMutableArray *) _filtersInDirectory:(NSString *)folder recursive:(BOOL)r matchingFunctionality:(ISFFunctionality)func	{
	if (folder==nil)
		return nil;
	NSString			*trimmedPath = [folder stringByDeletingLastAndAddingFirstSlash];
	NSFileManager		*fm = [NSFileManager defaultManager];
	BOOL				isDirectory = NO;
	if (![fm fileExistsAtPath:trimmedPath isDirectory:&isDirectory])
		return nil;
	if (!isDirectory)
		return nil;
	NSMutableArray			*returnMe = [[NSMutableArray alloc] initWithCapacity:0];
	if (r)	{
		NSDirectoryEnumerator	*it = [fm enumeratorAtPath:trimmedPath];
		NSString				*file = nil;
		while (file = [it nextObject])	{
			NSString		*ext = [file pathExtension];
			if (ext!=nil && ([ext isEqualToString:@"fs"] || [ext isEqualToString:@"frag"]))	{
				NSString		*fullPath = [NSString stringWithFormat:@"%@/%@",trimmedPath,file];
				if (func == ISFF_All)
					[returnMe addObject:fullPath];
				else	{
					if ([self _isAFilter:fullPath])	{
						if (func == ISFF_Filter)
							[returnMe addObject:fullPath];
					}
					else	{
						if (func == ISFF_Source)
							[returnMe addObject:fullPath];
					}
				}
			}
		}
	}
	//	else non-recursive (shallow) listing
	else	{
		NSArray		*tmpArray = [fm contentsOfDirectoryAtPath:trimmedPath error:nil];
		for (NSString *file in tmpArray)	{
			NSString		*ext = [file pathExtension];
			if (ext!=nil && ([ext isEqualToString:@"fs"] || [ext isEqualToString:@"frag"]))	{
				NSString		*fullPath = [NSString stringWithFormat:@"%@/%@",trimmedPath,file];
				if (func == ISFF_All)
					[returnMe addObject:fullPath];
				else	{
					if ([self _isAFilter:fullPath])	{
						if (func == ISFF_Filter)
							[returnMe addObject:fullPath];
					}
					else	{
						if (func == ISFF_Source)
							[returnMe addObject:fullPath];
					}
				}
			}
		}
	}
	return [returnMe autorelease];
}
+ (BOOL) _isAFilter:(NSString *)pathToFile	{
	if (pathToFile==nil)
		return NO;
	NSString		*rawFile = [NSString stringWithContentsOfFile:pathToFile encoding:NSUTF8StringEncoding error:nil];
	if (rawFile == nil)	{
		NSLog(@"\t\terr: couldn't load file %@ in %s",pathToFile,__func__);
		return NO;
	}
	//	there should be a JSON blob at the very beginning of the file describing the script's attributes and parameters- this is inside comments...
	NSRange			openCommentRange;
	NSRange			closeCommentRange;
	openCommentRange = [rawFile rangeOfString:@"/*"];
	closeCommentRange = [rawFile rangeOfString:@"*/"];
	if (openCommentRange.length!=0 && closeCommentRange.length!=0)	{
		//	parse the JSON string, turning it into a dictionary and values
		NSString		*jsonString = [rawFile substringWithRange:NSMakeRange(openCommentRange.location+openCommentRange.length, closeCommentRange.location-(openCommentRange.location+openCommentRange.length))];
		id				jsonObject = [jsonString objectFromJSONString];
		if (jsonObject==nil)	{
			NSLog(@"\t\terr: couldn't make jsonObject in %s, string was %@",__func__,jsonString);
			return NO;
		}
		else	{
			if ([jsonObject isKindOfClass:[NSDictionary class]])	{
				//	check the "INPUTS" section of the JSON dict
				NSArray		*inputs = [jsonObject objectForKey:@"INPUTS"];
				if (inputs==nil || ![inputs isKindOfClass:[NSArray class]])	{
					NSLog(@"\t\terr: inputs was nil, or was the wrong type, %s",__func__);
					return NO;
				}
				for (NSDictionary *inputDict in inputs)	{
					if ([inputDict isKindOfClass:[NSDictionary class]])	{
						NSString		*tmpString = nil;
						tmpString = [inputDict objectForKey:@"NAME"];
						if (tmpString!=nil && [tmpString isEqualToString:@"inputImage"])	{
							tmpString = [inputDict objectForKey:@"TYPE"];
							if (tmpString!=nil && [tmpString isEqualToString:@"image"])
								return YES;
						}
					}
				}
			}
			else	{
				NSLog(@"\t\terr: jsonObject was wrong class, %s",__func__);
				NSLog(@"\t\tfile was %@",pathToFile);
				return NO;
			}
		}
	}
	return NO;
}


@end



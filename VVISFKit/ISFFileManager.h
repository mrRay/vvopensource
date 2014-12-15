/**
\file
*/
#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>




///	so far, there are only two different types of ISF filters- "source" or "filter"
typedef NS_ENUM(NSInteger, ISFFunctionality)	{
	ISFF_All = 0,	//!< all image filters
	ISFF_Source = 1,	//!< generative sources
	ISFF_Filter = 2	//!< image filters
};




///	class interface to aid in discovering ISF files installed in the default location on the host system (/Library/Graphics/ISF and ~/Library/Graphics/ISF)
/**
\ingroup VVISFKit
*/
@interface ISFFileManager : NSObject	{
}

///	searches the passed path, returns an array with all the ISF filters
/**
only returns paths corresponding to valid ISF files
@param path the directory whose contents you want to search
@param r whether or not you want the search to be recursive
@return a mutable array with all the ISF filters in 'path'
*/
+ (NSMutableArray *) allFilesForPath:(NSString *)path recursive:(BOOL)r;
///	returns an array of all the ISF filters that are image filters in the passed path
/**
@param path the directory whose contents you want to search
@param r whether or not you want the search to be recursive
@return a mutable array with all the ISF filters in 'path' that are image filters
*/
+ (NSMutableArray *) imageFiltersForPath:(NSString *)path recursive:(BOOL)r;
///	returns an array of all the ISF filters that are generative sources in the passed path
/**
@param path the directory whose contents you want to search
@param r whether or not you want the search to be recursive
@return a mutable array with all the ISF filters in 'path' that are generative sources
*/
+ (NSMutableArray *) generativeSourcesForPath:(NSString *)path recursive:(BOOL)r;
///	returns an array with all the image filters installed in the default locations for ISF files on your system
+ (NSMutableArray *) defaultImageFilters;
///	returns an array with all the generative sources installed in the default locations for ISF files on your system
+ (NSMutableArray *) defaultGenerativeSources;

+ (NSMutableArray *) _filtersInDirectory:(NSString *)folder recursive:(BOOL)r matchingFunctionality:(ISFFunctionality)func;
+ (BOOL) _isAFilter:(NSString *)pathToFile;

@end

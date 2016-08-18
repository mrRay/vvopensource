/*
	
	To Do:
	• Add support for aliases
	• Additonal fallback for non-disk based files
	
*/

#import <Cocoa/Cocoa.h>


@interface VVMetadataItem : NSObject {
	BOOL	isFileURL;

	//	if possible, use MDItemRef- it uses spotlight services to get info from a disk-based file
	
	MDItemRef		_item;
	
	//	-or-
	
	//	if an MDItemRef is not available for the path (say the file is on a disk that has not been indexed)
	//	then I can fall-back on using a combintion of FSRef / NSWorkspace / NSFileManager / Launch Services to get *some* of the same file data
	
	NSDictionary	*_attributes;		//	file attributes to store

}
+ (id) createWithPath:(NSString *)p;
- (id) initWithPath:(NSString *)p;

+ (id) createWithMDItemRef:(MDItemRef)md;
- (id) initWithMDItemRef:(MDItemRef)md;

//	This method is the fallback in case the drive is not spotlight indexed
//	Instead of using an MDItemRef to retrieve meta data / track a file it uses a combination of workspace & filemanager 
//	methods to determine the most common file attributes
- (void) loadAttributesFromFilePath:(NSString *)p;
- (void) addTypeTreeForUTI:(NSString *)p;

//	calls MDItemCopyAttribute + autorelease
- (id) valueForAttribute:(id)attribute;

//	calls MDItemCopyAttributes + autorelease
- (NSDictionary *) valuesForAttributes:(NSArray *)attributes;

//	calls MDItemCopyAttributeNames
- (NSArray *) attributes;

//	For easy access to the most common file attributes-
//	returns the [self valueForAttribute:kMDItemPath]
- (NSString *) path;
//	returns the [self valueForAttribute:kMDItemDisplayName]
- (NSString *) displayName;
@end

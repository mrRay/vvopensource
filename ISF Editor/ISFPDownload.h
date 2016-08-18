#import <Foundation/Foundation.h>




@interface ISFPDownload : NSObject	{
	NSString		*fragPath;
	NSString		*thumbURL;
	NSImage			*thumb;
	NSDate			*updateDate;
	NSNumber		*uniqueID;
}

+ (id) create;

@property (retain,readwrite) NSString *fragPath;
@property (retain,readwrite) NSString *thumbURL;
@property (retain,readwrite) NSImage *thumb;
@property (retain,readwrite) NSDate *updateDate;
@property (retain,readwrite) NSNumber *uniqueID;

- (NSString *) updateDateString;

@end

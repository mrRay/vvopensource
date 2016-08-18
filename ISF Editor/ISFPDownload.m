#import "ISFPDownload.h"
#import <VVBasics/VVBasics.h>




@implementation ISFPDownload


+ (id) create	{
	return [[[ISFPDownload alloc] init] autorelease];
}
- (id) init	{
	self = [super init];
	if (self != nil)	{
		fragPath = nil;
		thumbURL = nil;
		thumb = nil;
		updateDate = nil;
		uniqueID = nil;
	}
	return self;
}
- (void) dealloc	{
	[self setFragPath:nil];
	[self setThumbURL:nil];
	[self setThumb:nil];
	[self setUpdateDate:nil];
	[self setUniqueID:nil];
	[super dealloc];
}
- (NSString *) description	{
	return [fragPath lastPathComponent];
}


@synthesize fragPath;
@synthesize thumbURL;
@synthesize thumb;
@synthesize updateDate;
@synthesize uniqueID;


- (NSString *) updateDateString	{
	NSString			*returnMe = nil;
	NSDate				*localDate = [self updateDate];
	if (localDate!=nil)	{
		NSDateFormatter		*fmt = [[NSDateFormatter alloc] init];
		//[fmt setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS"];
		[fmt setDateFormat:@"dd/MM, HH:mm"];
		returnMe = [fmt stringFromDate:localDate];
		[fmt release];
		fmt = nil;
	}
	if (returnMe==nil)
		returnMe = @"<no date>";
	return returnMe;
}


@end

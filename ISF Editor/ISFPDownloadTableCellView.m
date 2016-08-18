#import "ISFPDownloadTableCellView.h"
#import <VVBasics/VVBasics.h>




@implementation ISFPDownloadTableCellView


- (id) initWithFrame:(NSRect)n	{
	self = [super initWithFrame:n];
	if (self != nil)	{
		download = nil;
	}
	return self;
}
- (id) initWithCoder:(NSCoder *)c	{
	self = [super initWithCoder:c];
	if (self != nil)	{
		download = nil;
	}
	return self;
}
- (void) dealloc	{
	[self setDownload:nil];
	[super dealloc];
}
- (void) refreshWithDownload:(ISFPDownload *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if (n==nil)
		return;
	[self setDownload:n];
	
	[openInBrowserButton setImage:[NSImage imageNamed:NSImageNameShareTemplate]];
	
	NSImage		*thumbImg = [n thumb];
	NSString	*title = [[[n fragPath] lastPathComponent] stringByDeletingPathExtension];
	NSString		*updateString = [n updateDateString];
	
	[thumbView setImage:thumbImg];
	[titleField setStringValue:title];
	[updateDateField setStringValue:updateString];
}


@synthesize download;


- (IBAction) openInBrowserButtonUsed:(id)sender	{
	ISFPDownload		*_download = [self download];
	if (_download==nil)
		return;
	NSString			*urlString = [NSString stringWithFormat:@"http://www.interactiveshaderformat.com/sketches/%d",[[_download uniqueID] intValue]];
	NSURL				*url = [NSURL URLWithString:urlString];
	[[NSWorkspace sharedWorkspace] openURL:url];
}


@end

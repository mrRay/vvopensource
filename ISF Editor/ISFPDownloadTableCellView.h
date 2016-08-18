#import <Cocoa/Cocoa.h>
#import "ISFPDownload.h"




@interface ISFPDownloadTableCellView : NSTableCellView	{
	IBOutlet NSImageView		*thumbView;
	IBOutlet NSTextField		*titleField;
	IBOutlet NSTextField		*updateDateField;
	
	IBOutlet NSButton			*openInBrowserButton;
	
	ISFPDownload				*download;
}

- (void) refreshWithDownload:(ISFPDownload *)n;

@property (retain,readwrite) ISFPDownload *download;

- (IBAction) openInBrowserButtonUsed:(id)sender;

@end

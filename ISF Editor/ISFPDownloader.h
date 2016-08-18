#import <Foundation/Foundation.h>
#import <VVISFKit/VVISFKit.h>
#import <VVBasics/VVBasics.h>
#import "ISFController.h"
#import "DocController.h"
#import "ISFPDownload.h"




typedef enum {
    ISFPDownloaderBrowseType_MostStars = 1,
    ISFPDownloaderBrowseType_Latest = 2
} ISFPDownloaderBrowseType;




@interface ISFPDownloader : NSObject	{
	BOOL						alreadyAwake;	//	when we make table cell views, awakeFromNib gets called repeatedly
	
	IBOutlet NSWindow		*appWindow;	//	the main app window- we appear as a modal view over this
	IBOutlet NSWindow		*myWindow;
	
	IBOutlet id				appController;
	IBOutlet ISFController	*isfController;
	IBOutlet DocController	*docController;
	
	IBOutlet NSSearchField		*searchField;
	IBOutlet NSPopUpButton		*browseTypePUB;
	
	IBOutlet NSTableView		*tableView;
	
	ISFGLScene					*isfScene;
	
	NSInteger					pageStartIndex;	//	we view X results at a time- this is the index (on the server) of the first result in 'completedDownloads'
	NSInteger					maxPageStartIndex;	//	NSNotFound by default, set to a value if the # of results downloaded doesn't match the # of results we tried to download.  check this when calling "next page".
	//NSString					*pageBaseURL;
	NSArray						*pageQueryTerms;
	ISFPDownloaderBrowseType	browseType;
	
	MutLockArray				*completedDownloads;	//	array of ISFPDownload instances
	MutLockArray				*imagesToDownload;
	dispatch_queue_t			downloadQueue;
	
	NSTimer						*reloadTableTimer;	//	used to throttle table view reloading (throttle necessary because of completedDownloads)
}

- (IBAction) searchFieldUsed:(id)sender;
- (IBAction) browseTypePUBUsed:(id)sender;

- (IBAction) nextPageClicked:(id)sender;
- (IBAction) prevPageClicked:(id)sender;

- (IBAction) importClicked:(id)sender;
- (IBAction) importAllClicked:(id)sender;
- (void) _importDownload:(ISFPDownload *)dl;
- (IBAction) closeClicked:(id)sender;

//- (NSString *) createBrowseQueryURL;
//- (NSString *) createSearchQueryURL;
- (NSString *) createQueryURL;
- (void) downloadResultsForURLString:(NSString *)address;
- (void) clearResults;
- (void) openModalWindow;
- (void) closeModalWindow;

@property (assign, readwrite) NSInteger pageStartIndex;
@property (assign, readwrite) NSInteger maxPageStartIndex;
//@property (retain, readwrite) NSString *pageBaseURL;
@property (retain,readwrite) NSArray *pageQueryTerms;
@property (assign,readwrite) ISFPDownloaderBrowseType browseType;
- (void) parsedNewDownloads:(NSMutableArray *)n;
- (void) startDownloadingImage;
- (void) downloadedImage:(NSImage *)img fromURL:(NSString *)urlString;

- (void) reloadTableButThrottleThisMethod;
//- (void) _resetReloadTableTimer;
- (void) timerThrottledTableReloader:(NSTimer *)t;

@end

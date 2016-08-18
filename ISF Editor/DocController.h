#import <Foundation/Foundation.h>
#import <VVBasics/VVBasics.h>
#import <MGSFragaria/MGSFragaria.h>




/*		this controller manages opening, displaying, and editing an ISF file.  it also manages the 
		error, fragment shader, vertex shader, and JSON text views, as well as the split view that 
		contains both the file text view and the error/frag/vert/JSON text views.
*/
@interface DocController : NSObject <NSSplitViewDelegate>	{
	IBOutlet id				isfController;
	IBOutlet NSWindow		*window;
	
	NSString				*fragFilePath;
	NSString				*fragFilePathContentsOnOpen;	//	we retain the contents of the file as it was opened for comparison purposes
	BOOL					fragEditsPerformed;
	NSString				*vertFilePath;
	NSString				*vertFilePathContentsOnOpen;
	BOOL					vertEditsPerformed;
	NSTimer					*tmpFileSaveTimer;	//	when we make a new file, before it's been properly saved to disk, it's just a tmp file- which is saved frequently...
	
	IBOutlet NSSplitView		*splitView;
	IBOutlet NSView				*splitViewFileSubview;
	IBOutlet NSView				*splitViewNonFileSubview;
	
	IBOutlet NSSplitView		*fileSplitView;
	IBOutlet NSView				*fileSplitViewFragSubview;
	IBOutlet NSView				*fileSplitviewVertSubview;
	IBOutlet NSView				*fileSplitViewJSONSubview;
	
	MGSFragaria					*fragFileFragaria;
	MGSFragaria					*vertFileFragaria;
	MGSFragaria					*jsonFragaria;
	MGSFragaria					*errorFragaria;
	MGSFragaria					*vertTextFragaria;
	MGSFragaria					*fragTextFragaria;
	
	IBOutlet NSView				*fragFileTextView;
	IBOutlet NSView				*vertFileTextView;
	IBOutlet NSTabView			*nonFileTabView;
	IBOutlet NSView				*jsonTextView;
	IBOutlet NSView				*errorTextView;
	IBOutlet NSView				*vertTextView;
	IBOutlet NSView				*fragTextView;
	
	IBOutlet id					jsonController;
}

- (void) createNewFile;
- (void) loadFile:(NSString *)p;
- (void) saveOpenFile;
- (void) reloadFileFromTableView;

- (void) loadNonFileContentDict:(NSDictionary *)n;

- (BOOL) contentsNeedToBeSaved;

- (void) fragEditPerformed;
- (void) vertEditPerformed;

- (NSString *) fragFilePath;

@end

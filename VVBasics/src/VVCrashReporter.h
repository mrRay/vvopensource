
#import <Cocoa/Cocoa.h>
#import <SystemConfiguration/SCNetwork.h>
#import <asl.h>
#import "VVCURLDL.h"
#import "MutLockArray.h"




///	The crash reporter's delegate must adhere to this protocol
/*!
	This protocol exists largely because it's conceivable that objects will want to know when the crash reporter- which uploads asynchronously- has finished sending its data to the remote server.
*/
@protocol VVCrashReporterDelegate
- (void) crashReporterCheckDone;
@end



///	Simple class which automatically uploads crash logs and other relevant diagnostic information automatically made available by os x to a remote server.
/*!
it's been my experience that most apps crash much more frequently on end-users than the app's developers would guess.  the simplest and easiest way to improve the end-user's experience is to have the application check their machine for crash logs- which are generated automatically by os x whenever an application crashes- and send them to the developer.

this class exists so i have a really easy way to make my apps send their crash logs to me; the goal here is to make it as easy as possible to get all the information i need to troubleshoot a problem with as little work on the user's part as possible.  it also sends a basic system profile, anything the app- and ONLY the app, not other apps- recently printed to the console log, and optional description/email fields to facilitate communication directly with the user.  this data is then uploaded to a given URL using an HTTP POST.

on the server side, i use a PHP page which sanitizes the POST data (i can't stress how important this step is) and works with it.  i've included a sample PHP page that simply dumps the received data to a file on disk (and optionally emails someone) with this project.

HOW TO USE THIS CLASS:

	1)- create an instance of this class
	
	2)- set the instance's delegate, uploadURL, and developerEmail.  these are necessary!
	
	3)- call "check" on the instance.  when it's done, it calls "crashReporterCheckDone" on the 
		delegate.  that's it- you're done.
*/

@interface VVCrashReporter : NSObject <VVCURLDLDelegate> {
	NSString						*uploadURL;	//	does NOT includes http://
	NSString						*developerEmail;
	id								delegate;	//	must respond to VVCrashReporterDelegate protocol
	MutLockArray					*crashLogArray;
	NSMutableDictionary				*systemProfilerDict;
	NSString						*consoleLog;
	int								jobSize;			//	used to update progress indicator/label
	int								jobCurrentIndex;	//	used to update progress indicator/label
	int								currentCrashLogTimeout;	//	countdown for timeout of sending/receiving data for a specific crash log
	NSTimer							*currentCrashLogTimer;
	
	IBOutlet NSWindow				*window;
	IBOutlet NSButton				*replyButton;
	IBOutlet NSView					*emailFieldHolder;
	IBOutlet NSTextField			*emailField;
	IBOutlet NSTextView				*descriptionField;
	IBOutlet NSTextField			*submittingLabel;	//	non-editable. 'submitting', 'getting machine profile', etc.
	IBOutlet NSProgressIndicator	*progressIndicator;	//	indicates progress through all crash logs to be submitted
	IBOutlet NSTextField			*countdownLabel;	//	non-editable; countdown so user knows app hasn't hung
	
	NSNib							*theNib;
	NSArray							*nibTopLevelObjects;
}

///	This is the main method- when you call 'check', the crash reporter looks for crash logs, gets a basic system profile, and collects anything your applications has dumped to the console log.
- (void) check;
- (void) openCrashReporter;
- (IBAction) replyButtonClicked:(id)sender;
- (IBAction) doneClicked:(id)sender;
- (void) sendACrashLog;
- (void) closeCrashReporter;

- (NSString *) _nibName;
- (NSString *) _consoleLogString;
- (NSMutableDictionary *) _systemProfilerDict;
- (NSString *) _stringForSystemProfilerDataType:(NSString *)t;

- (void) updateCrashLogTimeout:(NSTimer *)t;

//	VVCURLDLDelegate method- this class will be the delegate of multiple VVCURLDL instances
- (void) dlFinished:(id)h;

///	Sets the developer email address; this is displayed if the user has a problem connecting to the internet/the server the crash reporter is supposed to be connecting to
- (void) setDeveloperEmail:(NSString *)n;
- (NSString *) developerEmail;
///	This is the URL of the php/cgi/etc. page which the crash data will be POSTed to
- (void) setUploadURL:(NSString *)n;
- (NSString *) uploadURL;

///	The crash reporter's delegate is notified when the check has completed
@property (assign,readwrite) id delegate;

@end

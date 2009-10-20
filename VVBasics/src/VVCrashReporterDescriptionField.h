#import <Cocoa/Cocoa.h>


/*
	this class exists solely to prevent users from pasting or dragging huge amounts of text (like 
	crash/console logs!) into the description field of the crash reporter.  sounds weird, but trust 
	me- it's necessary.
*/


@interface VVCrashReporterDescriptionField : NSTextView {

}

@end

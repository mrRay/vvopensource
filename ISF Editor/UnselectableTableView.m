#import "UnselectableTableView.h"

@implementation UnselectableTableView

/*		source:	http://www.corbinstreehouse.com/blog/2014/04/nstableview-tips-not-delaying-the-first-responder/
	
	Now normally when you try to directly click on one of the NSTextFields the table will first select 
	the row. Then a second click will allow you to start editing. For most tables, this is the behavior 
	you want. For something like what I have, I want to avoid this, and allow the first responder to 
	go through. This can easily be done by subclassing NSTableView and overriding:

	- (BOOL)validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event {
	   return YES; // no delay
	}
	NSTableView’s default logic is a bit complex that allows things to go through or not based on several 
	properties. This method is declared in NSResponder.h, and it is sent up the responder chain when 
	the text field itself attempts to become first responder. When NSTableView gets it, it does some 
	determination to determine if it should go through or not. If it wasn’t an already selected row, 
	it returns NO; this causes the table to get the mouseDown: and do the selection logic.  I don’t 
	care what control was clicked; I want it to go through without selecting, and always return YES.		*/
- (BOOL)validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event {
	return YES; // no delay
}

@end

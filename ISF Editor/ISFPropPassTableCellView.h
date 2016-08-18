#import <Foundation/Foundation.h>
#import "JSONGUIPass.h"
#import "JSONGUITop.h"
#import "JSONGUIDragBarView.h"




@interface ISFPropPassTableCellView : NSTableCellView	{
	IBOutlet NSTextField		*passNameField;
	
	IBOutlet NSTextField		*targetField;
	IBOutlet NSButton			*persistentToggle;
	IBOutlet NSButton			*floatToggle;
	IBOutlet NSTextField		*widthField;
	IBOutlet NSTextField		*heightField;
	
	ObjectHolder				*pass;	//	really a JSONGUIPass
	
	IBOutlet JSONGUIDragBarView		*dragBar;
}

- (IBAction) uiItemUsed:(id)sender;
- (IBAction) deleteClicked:(id)sender;

- (void) refreshWithTop:(JSONGUITop *)t pass:(JSONGUIPass *)p;

- (JSONGUIPass *) pass;

@end

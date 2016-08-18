#import <Foundation/Foundation.h>
#import "JSONGUITop.h"




@interface ISFPropTopTableCellView : NSTableCellView	{
	IBOutlet NSTextField		*descriptionField;
	IBOutlet NSTextField		*creditField;
	
	IBOutlet NSTextField		*categoriesField;
	IBOutlet NSTextField		*filterVsnField;
	
	ObjectHolder				*top;
}

- (IBAction) uiItemUsed:(id)sender;

- (void) refreshWithTop:(JSONGUITop *)t;

- (JSONGUITop *) top;

@end

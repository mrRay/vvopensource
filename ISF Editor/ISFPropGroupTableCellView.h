#import <Foundation/Foundation.h>
#import "JSONGUIController.h"




@interface ISFPropGroupTableCellView : NSTableCellView	{
	IBOutlet NSTextField		*groupNameField;
	
	ObjectHolder			*group;	//	JSONGUIArrayGroup
}

- (IBAction) addButtonUsed:(id)sender;

- (void) refreshWithGroup:(JSONGUIArrayGroup *)n;

- (JSONGUIArrayGroup *) group;

@end

#import <Foundation/Foundation.h>
#import "ISFPropInputTableCellView.h"




@interface ISFPropColorTableCellView : ISFPropInputTableCellView	{
	IBOutlet NSColorWell		*defaultCWell;
	IBOutlet NSColorWell		*minCWell;
	IBOutlet NSColorWell		*maxCWell;
	IBOutlet NSColorWell		*identityCWell;
	
	IBOutlet NSButton			*defaultCWellButton;
	IBOutlet NSButton			*minCWellButton;
	IBOutlet NSButton			*maxCWellButton;
	IBOutlet NSButton			*identityCWellButton;
}

- (IBAction) uiItemUsed:(id)sender;

@end

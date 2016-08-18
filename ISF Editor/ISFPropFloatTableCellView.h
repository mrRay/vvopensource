#import <Foundation/Foundation.h>
#import "ISFPropInputTableCellView.h"




@interface ISFPropFloatTableCellView : ISFPropInputTableCellView	{
	IBOutlet NSTextField		*defaultField;
	IBOutlet NSTextField		*minField;
	IBOutlet NSTextField		*maxField;
	IBOutlet NSTextField		*identityField;
}

- (IBAction) uiItemUsed:(id)sender;

@end

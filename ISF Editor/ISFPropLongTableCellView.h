#import <Foundation/Foundation.h>
#import "ISFPropInputTableCellView.h"




@interface ISFPropLongTableCellView : ISFPropInputTableCellView	{
	IBOutlet NSTextField		*defaultField;
	IBOutlet NSTextField		*identityField;
	
	IBOutlet NSTextField		*valuesField;
	IBOutlet NSTextField		*labelsField;
}

- (IBAction) uiItemUsed:(id)sender;

@end

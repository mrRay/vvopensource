#import <Foundation/Foundation.h>
#import "ISFPropInputTableCellView.h"




@interface ISFPropBoolTableCellView : ISFPropInputTableCellView	{
	IBOutlet NSTextField		*defaultField;
	IBOutlet NSTextField		*identityField;
}

- (IBAction) uiItemUsed:(id)sender;

@end

#import <Foundation/Foundation.h>
#import "ISFPropInputTableCellView.h"




@interface ISFPropAudioFFTTableCellView : ISFPropInputTableCellView	{
	IBOutlet NSTextField		*maxField;
	//IBOutlet NSButton			*floatToggle;
}

- (IBAction) uiItemUsed:(id)sender;

@end

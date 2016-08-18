#import <Foundation/Foundation.h>
#import "JSONGUIInput.h"
#import "JSONGUIDragBarView.h"




@interface ISFPropInputTableCellView : NSTableCellView	{
	IBOutlet NSTextField		*inputNameField;
	
	IBOutlet NSTextField		*labelField;
	IBOutlet NSPopUpButton		*typePUB;
	
	ObjectHolder			*input;	//	retained
	
	IBOutlet JSONGUIDragBarView		*dragBar;
}

- (IBAction) baseUIItemUsed:(id)sender;
- (IBAction) deleteClicked:(id)sender;

- (void) refreshWithInput:(JSONGUIInput *)n;

- (JSONGUIInput *) input;

- (NSNumber *) parseBooleanFromString:(NSString *)n;
- (NSNumber *) parseNumberFromString:(NSString *)n;
- (NSArray *) parseValArrayFromString:(NSString *)n;
- (NSArray *) parseStringArrayFromString:(NSString *)n;

@end

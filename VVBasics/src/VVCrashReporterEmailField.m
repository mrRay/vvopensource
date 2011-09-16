#import "VVCrashReporterEmailField.h"


@implementation VVCrashReporterEmailField


- (void) awakeFromNib	{
	[self setDelegate:(id)self];
	//[self setDelegate:(id <NSTextFieldDelegate>)self];
}

- (void)textDidChange:(NSNotification *)notification	{
	if ([[self stringValue] length] > 550)	{
		NSRunAlertPanel(@"Hang on a second....",@"I don't think your email address is that long- this field is for your email address, and ONLY your email address...",@"",nil,nil);
		[self setStringValue:@""];
	}
}


@end

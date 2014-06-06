#import "VVCrashReporterEmailField.h"
#import "VVBasicMacros.h"


@implementation VVCrashReporterEmailField


- (void) awakeFromNib	{
	[self setDelegate:(id)self];
	//[self setDelegate:(id <NSTextFieldDelegate>)self];
}

- (void)textDidChange:(NSNotification *)notification	{
	if ([[self stringValue] length] > 550)	{
		VVRunAlertPanel(@"Hang on a second....",
			@"I don't think your email address is that long- this field is for your email address, and ONLY your email address...",
			@"OK",nil,nil);
		[self setStringValue:@""];
	}
}


@end

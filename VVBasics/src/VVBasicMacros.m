#import "VVBasicMacros.h"




NSInteger VVRunAlertPanel(NSString *title, NSString *msg, NSString *btnA, NSString *btnB, NSString *btnC)	{
	NSInteger		returnMe;
	NSAlert			*macroLocalAlert = [NSAlert alertWithError:[NSError
		errorWithDomain:@""
		code:0
		userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
			title, NSLocalizedDescriptionKey,
			msg, NSLocalizedRecoverySuggestionErrorKey,
			nil]]];
	[macroLocalAlert setAlertStyle:NSWarningAlertStyle];
	if (btnA!=nil && [btnA length]>0)
		[macroLocalAlert addButtonWithTitle:btnA];
	if (btnB!=nil && [btnB length]>0)
		[macroLocalAlert addButtonWithTitle:btnB];
	if (btnC!=nil && [btnC length]>0)
		[macroLocalAlert addButtonWithTitle:btnC];
	returnMe = [macroLocalAlert runModal];
	//NSLog(@"\t\treturning %ld",returnMe);
	return returnMe;
}

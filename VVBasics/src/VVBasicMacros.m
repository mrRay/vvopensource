#import "VVBasicMacros.h"



#if !TARGET_OS_IPHONE
NSInteger VVRunAlertPanel(NSString *title, NSString *msg, NSString *btnA, NSString *btnB, NSString *btnC)	{
	return VVRunAlertPanelSuppressString(title, msg, btnA, btnB, btnC, nil, NULL);
}

NSInteger VVRunAlertPanelSuppressString(NSString *title, NSString *msg, NSString *btnA, NSString *btnB, NSString *btnC, NSString *suppressString, BOOL *returnSuppressValue)	{
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
	
	BOOL		showsSuppressionButton = (suppressString!=nil && [suppressString length]>0) ? YES : NO;
	if (showsSuppressionButton)	{
		[macroLocalAlert setShowsSuppressionButton:YES];
		NSButton		*tmpButton = [macroLocalAlert suppressionButton];
		if (tmpButton != nil)	{
			[tmpButton setTitle:suppressString];
			[tmpButton setIntValue:NSOffState];
		}
	}
	else	{
		[macroLocalAlert setShowsSuppressionButton:NO];
	}
	
	returnMe = [macroLocalAlert runModal];
	//NSLog(@"\t\treturning %ld",returnMe);
	
	if (showsSuppressionButton && returnSuppressValue!=NULL)	{
		*returnSuppressValue = ([[macroLocalAlert suppressionButton] intValue]==NSOnState) ? YES : NO;
	}
	
	return returnMe;
}
#endif


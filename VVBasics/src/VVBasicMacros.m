#import "VVBasicMacros.h"



#if !TARGET_OS_IPHONE
@interface NSAlert (NSAlertAdditions)
- (NSInteger) runModalForWindow:(NSWindow *)aWindow;
@end
@implementation NSAlert (NSAlertAdditions)
- (NSInteger) runModalForWindow:(NSWindow *)aWindow {
	__block NSInteger		returnMe = 0;
	__block id				bss = self;
	//	this code is in a block because it must be executed on the main thread (AppKit isn't threadsafe)
	void		(^tmpBlock)(void) = ^(void)	{
		//	configure the buttons to trigger a method we're adding to NSAlert in this category
		for (NSButton *button in [bss buttons]) {
			[button setTarget:bss];
			[button setAction:@selector(closeAlertsAppModalSession:)];
		}
		//	open the sheet as modal for the passed window
		[bss beginSheetModalForWindow:aWindow completionHandler:nil];
		//	start a modal session for the window- this will ensure that any events outside the window are ignored
		returnMe = [NSApp runModalForWindow:[bss window]];
	
		//	...execution won't pass this point until the NSApp modal session above is ended (happens when a button is clicked)...
	
		//	end the sheet we began with 'beginSheetModalForWindow'
		[NSApp endSheet:[bss window]];
	};
	//	execute the block, ensuring that it happens synchronously and on the main thread
	if (![NSThread isMainThread])
		dispatch_sync(dispatch_get_main_queue(), tmpBlock);
	else
		tmpBlock();
	return returnMe;
}
- (IBAction) closeAlertsAppModalSession:(id)sender {
	NSUInteger		senderButtonIndex = [[self buttons] indexOfObject:sender];
	NSInteger		returnMe = 0;
	if (senderButtonIndex == NSAlertFirstButtonReturn)
		returnMe = NSAlertFirstButtonReturn;
	else if (senderButtonIndex == NSAlertSecondButtonReturn)
		returnMe = NSAlertSecondButtonReturn;
	else if (senderButtonIndex == NSAlertThirdButtonReturn)
		returnMe = NSAlertThirdButtonReturn;
	else
		returnMe = NSAlertThirdButtonReturn + (senderButtonIndex - 2);
	
	[NSApp stopModalWithCode:returnMe];
}
@end
NSInteger VVRunAlertPanel(NSString *title, NSString *msg, NSString *btnA, NSString *btnB, NSString *btnC)	{
	return VVRunAlertPanelSuppressString(title, msg, btnA, btnB, btnC, nil, NULL);
}
NSInteger VVRunAlertPanelSuppressString(NSString *title, NSString *msg, NSString *btnA, NSString *btnB, NSString *btnC, NSString *suppressString, BOOL *returnSuppressValue)	{
	__block NSInteger		returnMe;
	NSAlert			*macroLocalAlert = [NSAlert alertWithError:[NSError
		errorWithDomain:@""
		code:0
		userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
			title, NSLocalizedDescriptionKey,
			msg, NSLocalizedRecoverySuggestionErrorKey,
			nil]]];
	[macroLocalAlert setAlertStyle:NSAlertStyleWarning];
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
	
	//	so, -[NSAlert runModal] should be handling all this- but we can't do that, because sometimes NSAlert will display the modal dialog on the non-main screen.  to work around this, we have to create an invisible window on the main screen, and attach the alert to it as a sheet that uses a modal session to restrict user interaction.
	NSRect			mainScreenRect = [[[NSScreen screens] objectAtIndex:0] frame];
	NSRect			clearWinRect = NSMakeRect(0, 0, 100, 100);
	clearWinRect.origin = NSMakePoint(VVMIDX(mainScreenRect) - clearWinRect.size.width/2., (mainScreenRect.size.height*0.66) + mainScreenRect.origin.y - clearWinRect.size.height/2.);
	NSWindow		*clearWin = [[NSWindow alloc] initWithContentRect:clearWinRect styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
	[clearWin setHasShadow:NO];
	[clearWin setOpaque:NO];
	[clearWin setBackgroundColor:[NSColor clearColor]];
		//[clearWin useOptimizedDrawing:YES];
	[clearWin setHidesOnDeactivate:YES];
	[clearWin setLevel:NSModalPanelWindowLevel];
	[clearWin setIgnoresMouseEvents:YES];
	
	//NSLog(@"\t\ttelling the app to run a modal session for the clear window...");
	returnMe = [macroLocalAlert runModalForWindow:clearWin];
	
	//	get rid of the clear window...
	[clearWin orderOut:nil];
	//[clearWin release];
	clearWin = nil;
	
	if (showsSuppressionButton && returnSuppressValue!=NULL)	{
		*returnSuppressValue = ([[macroLocalAlert suppressionButton] intValue]==NSOnState) ? YES : NO;
	}
	
	return returnMe;
}
#endif




#if !TARGET_OS_IPHONE
NSRect NSPositiveDimensionsRect(NSRect inRect)	{
	if (inRect.size.width >= 0. && inRect.size.height >= 0.)
		return inRect;
	
	NSRect			returnMe = inRect;
	if (returnMe.size.width < 0.)	{
		returnMe.origin.x += returnMe.size.width;
		returnMe.size.width = fabs(returnMe.size.width);
	}
	if (returnMe.size.height < 0.)	{
		returnMe.origin.y += returnMe.size.height;
		returnMe.size.height = fabs(returnMe.size.height);
	}
	
	return returnMe;
}
NSRect NSIntegralPositiveDimensionsRect(NSRect inRect)	{
	NSRect		returnMe = NSMakeRect(round(inRect.origin.x), round(inRect.origin.y), round(inRect.size.width), round(inRect.size.height));
	if (returnMe.size.width >= 0. && returnMe.size.height >= 0.)
		return returnMe;
	
	if (returnMe.size.width < 0.)	{
		returnMe.origin.x = round(returnMe.origin.x + returnMe.size.width);
		returnMe.size.width = round(fabs(returnMe.size.width));
	}
	if (returnMe.size.height < 0.)	{
		returnMe.origin.y = round(returnMe.origin.y + returnMe.size.height);
		returnMe.size.height = round(fabs(returnMe.size.height));
	}
	
	return returnMe;
}
#endif


#import "VVCrashReporterDescriptionField.h"
#import "VVBasicMacros.h"


@implementation VVCrashReporterDescriptionField


- (void) paste:(id)sender	{
	NSPasteboard		*gpb = [NSPasteboard generalPasteboard];
	NSString			*type = nil;
	NSString			*value = nil;
	//long				temp;
	
	if (gpb == nil)	{	//	return if there's no pasteboard
		return;
	}
	type = [gpb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]];
	if (type == nil)	{	//	if there aren't any strings in the pb
		return;
	}
	value = [gpb stringForType:NSStringPboardType];
	if (value == nil)	{	//	if the string's nil (don't know why this would happen, but whatever
		return;
	}
	if ([value length] > 550)	{
		VVRunAlertPanel(@"Hang on a second....",
			@"You can't paste that much text in here.  Please enter a SHORT description of your setup and/or what you were doing when the crash occurred.  Please do NOT paste things like crash or console logs in here.",
			@"OK",nil,nil);
	}
	else	{
		[super paste:sender];
	}
}

- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender	{
	return NO;
}


@end

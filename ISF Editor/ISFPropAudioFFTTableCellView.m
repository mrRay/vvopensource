#import "ISFPropAudioFFTTableCellView.h"
#import "JSONGUIController.h"




@implementation ISFPropAudioFFTTableCellView


- (void) dealloc	{
	[maxField setTarget:nil];
	//[floatToggle setTarget:nil];
	[super dealloc];
}
- (void) refreshWithInput:(JSONGUIInput *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	[super refreshWithInput:n];
	
	if (n==nil)
		return;
	
	NSString		*tmpString = nil;
	NSNumber		*tmpNum = nil;
	
	tmpString = [n objectForKey:@"MAX"];
	tmpNum = [self parseNumberFromString:tmpString];
	tmpString = (tmpNum==nil) ? @"" : VVFMTSTRING(@"%d",[tmpNum intValue]);
	[maxField setStringValue:tmpString];
	
	/*
	tmpString = [n objectForKey:@"FLOAT"];
	tmpNum = [self parseBooleanFromString:tmpString];
	if (tmpNum == nil)
		tmpNum = [self parseNumberFromString:tmpString];
	if (tmpNum == nil)
		tmpNum = NUMINT(0);
	[floatToggle setIntValue:([tmpNum intValue]>0) ? NSOnState : NSOffState];
	*/
	
	/*
	tmpString = [n objectForKey:@"MAX"];
	if (tmpString==nil)
		tmpString = @"";
	else if ([tmpString isKindOfClass:[NSNumber class]])
		tmpString = VVFMTSTRING(@"%d",[(NSNumber *)tmpString intValue]);
	else if (![tmpString isKindOfClass:[NSString class]])
		tmpString = @"";
	[maxField setStringValue:tmpString];
	*/
	
}


- (IBAction) uiItemUsed:(id)sender	{
	NSLog(@"%s",__func__);
	JSONGUIInput	*myInput = [self input];
	if (myInput == nil)
		return;
	NSNumber		*tmpNum = nil;
	NSString		*tmpString = nil;
	//	parse the string into a number value
	if (sender == maxField)	{
		tmpString = [sender stringValue];
		if (tmpString!=nil)
			tmpNum = [self parseNumberFromString:tmpString];
		[myInput setObject:tmpNum forKey:@"MAX"];
	}
	/*
	else if (sender == floatToggle)	{
		if ([floatToggle intValue]==NSOnState)
			[myInput setObject:NUMBOOL(YES) forKey:@"FLOAT"];
		else
			[myInput setObject:nil forKey:@"FLOAT"];
	}
	*/
	
	[_globalJSONGUIController recreateJSONAndExport];
}


@end

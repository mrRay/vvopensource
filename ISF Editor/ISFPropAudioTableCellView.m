#import "ISFPropAudioTableCellView.h"
#import "JSONGUIController.h"




@implementation ISFPropAudioTableCellView


- (void) dealloc	{
	[maxField setTarget:nil];
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
	NSString		*tmpString = nil;
	
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
	//NSLog(@"%s",__func__);
	JSONGUIInput	*myInput = [self input];
	if (myInput == nil)
		return;
	
	NSString		*tmpString = [sender stringValue];
	
	//	'default' and 'identity' need to each contain a single long from a string
	if (sender == maxField)	{
		NSNumber		*tmpNum = [self parseNumberFromString:tmpString];
		[myInput setObject:tmpNum forKey:@"MAX"];
	}
	
	[_globalJSONGUIController recreateJSONAndExport];
}


@end

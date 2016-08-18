#import "ISFPropFloatTableCellView.h"
#import "JSONGUIController.h"




@implementation ISFPropFloatTableCellView


- (void) dealloc	{
	[defaultField setTarget:nil];
	[minField setTarget:nil];
	[maxField setTarget:nil];
	[identityField setTarget:nil];
	[super dealloc];
}
- (void) refreshWithInput:(JSONGUIInput *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	[super refreshWithInput:n];
	
	if (n==nil)
		return;
	
	NSString		*tmpString = nil;
	NSNumber		*tmpNum = nil;
	
	tmpString = [n objectForKey:@"DEFAULT"];
	tmpNum = [self parseNumberFromString:tmpString];
	[defaultField setStringValue:(tmpNum==nil) ? @"" : VVFMTSTRING(@"%f",[tmpNum doubleValue])];
	
	tmpString = [n objectForKey:@"MIN"];
	tmpNum = [self parseNumberFromString:tmpString];
	[minField setStringValue:(tmpNum==nil) ? @"" : VVFMTSTRING(@"%f",[tmpNum doubleValue])];
	
	tmpString = [n objectForKey:@"MAX"];
	tmpNum = [self parseNumberFromString:tmpString];
	[maxField setStringValue:(tmpNum==nil) ? @"" : VVFMTSTRING(@"%f",[tmpNum doubleValue])];
	
	tmpString = [n objectForKey:@"IDENTITY"];
	tmpNum = [self parseNumberFromString:tmpString];
	[identityField setStringValue:(tmpNum==nil) ? @"" : VVFMTSTRING(@"%f",[tmpNum doubleValue])];
}


- (IBAction) uiItemUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	JSONGUIInput	*myInput = [self input];
	if (myInput == nil)
		return;
	//	parse the string into a number value
	NSNumber		*newNum = [self parseNumberFromString:[sender stringValue]];
	
	
	if (sender == defaultField)	{
		[myInput setObject:newNum forKey:@"DEFAULT"];
	}
	else if (sender == minField)	{
		[myInput setObject:newNum forKey:@"MIN"];
	}
	else if (sender == maxField)	{
		[myInput setObject:newNum forKey:@"MAX"];
	}
	else if (sender == identityField)	{
		[myInput setObject:newNum forKey:@"IDENTITY"];
	}
	
	[_globalJSONGUIController recreateJSONAndExport];
}


@end

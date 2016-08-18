#import "ISFPropLongTableCellView.h"
#import "JSONGUIController.h"




@implementation ISFPropLongTableCellView


- (void) dealloc	{
	[defaultField setTarget:nil];
	[identityField setTarget:nil];
	[valuesField setTarget:nil];
	[labelsField setTarget:nil];
	[super dealloc];
}
- (void) refreshWithInput:(JSONGUIInput *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	[super refreshWithInput:n];
	
	if (n==nil)
		return;
	
	NSArray			*tmpArray = nil;
	NSMutableString	*mutString = nil;
	NSInteger		tmpIndex = 0;
	
	tmpArray = [n objectForKey:@"VALUES"];
	mutString = [NSMutableString stringWithCapacity:0];
	tmpIndex = 0;
	for (NSString *tmpString in tmpArray)	{
		if ([tmpString isKindOfClass:[NSString class]])	{
			if (tmpIndex > 0)
				[mutString appendFormat:@", %@",tmpString];
			else
				[mutString appendString:tmpString];
		}
		else if ([tmpString isKindOfClass:[NSNumber class]])	{
			if (tmpIndex > 0)
				[mutString appendFormat:@", %d",[(NSNumber *)tmpString intValue]];
			else
				[mutString appendFormat:@"%d",[(NSNumber *)tmpString intValue]];
		}
		++tmpIndex;
	}
	[valuesField setStringValue:mutString];
	
	tmpArray = [n objectForKey:@"LABELS"];
	mutString = [NSMutableString stringWithCapacity:0];
	tmpIndex = 0;
	for (NSString *tmpString in tmpArray)	{
		if (tmpIndex > 0)
			[mutString appendFormat:@", %@",tmpString];
		else
			[mutString appendString:tmpString];
		++tmpIndex;
	}
	[labelsField setStringValue:mutString];
	
	
	NSString		*tmpString = nil;
	NSNumber		*tmpNum = nil;
	
	tmpString = [n objectForKey:@"DEFAULT"];
	tmpNum = [self parseNumberFromString:tmpString];
	[defaultField setStringValue:(tmpNum==nil) ? @"" : VVFMTSTRING(@"%d",[tmpNum intValue])];
	
	tmpString = [n objectForKey:@"IDENTITY"];
	tmpNum = [self parseNumberFromString:tmpString];
	[identityField setStringValue:(tmpNum==nil) ? @"" : VVFMTSTRING(@"%d",[tmpNum intValue])];
}


- (IBAction) uiItemUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	JSONGUIInput	*myInput = [self input];
	if (myInput == nil)
		return;
	
	NSString		*tmpString = [sender stringValue];
	
	//	'default' and 'identity' need to each contain a single long from a string
	if (sender == defaultField)	{
		NSNumber		*tmpNum = [self parseNumberFromString:tmpString];
		[myInput setObject:tmpNum forKey:@"DEFAULT"];
	}
	else if (sender == identityField)	{
		NSNumber		*tmpNum = [self parseNumberFromString:tmpString];
		[myInput setObject:tmpNum forKey:@"IDENTITY"];
	}
	//	'values' needs to be an array of values from strings
	else if (sender == valuesField)	{
		NSArray			*tmpNums = [self parseValArrayFromString:tmpString];
		[myInput setObject:tmpNums forKey:@"VALUES"];
	}
	//	'labels' needs to be an array of strings
	else if (sender == labelsField)	{
		NSArray			*tmpStrings = [self parseStringArrayFromString:tmpString];
		[myInput setObject:tmpStrings forKey:@"LABELS"];
	}
	
	[_globalJSONGUIController recreateJSONAndExport];
}


@end

#import "ISFPropBoolTableCellView.h"
#import "JSONGUIController.h"




@implementation ISFPropBoolTableCellView


- (void) dealloc	{
	[defaultField setTarget:nil];
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
	tmpNum = [self parseBooleanFromString:tmpString];
	if (tmpNum == nil)
		tmpNum = [self parseNumberFromString:tmpString];
	if (tmpNum == nil)
		tmpNum = NUMINT(0);
	[defaultField setStringValue:VVFMTSTRING(@"%d",[tmpNum intValue])];
	
	tmpString = [n objectForKey:@"IDENTITY"];
	tmpNum = [self parseBooleanFromString:tmpString];
	if (tmpNum == nil)
		tmpNum = [self parseNumberFromString:tmpString];
	if (tmpNum == nil)
		tmpNum = NUMINT(0);
	[identityField setStringValue:VVFMTSTRING(@"%d",[tmpNum intValue])];
}


- (IBAction) uiItemUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	JSONGUIInput	*myInput = [self input];
	if (myInput == nil)
		return;
	//	parse the string into a number value
	NSNumber		*newNum = nil;
	NSString		*tmpString = [sender stringValue];
	if (tmpString!=nil)	{
		newNum = [self parseBooleanFromString:tmpString];
		if (newNum == nil)
			newNum = [self parseNumberFromString:tmpString];
		/*
		if ([tmpString localizedCaseInsensitiveCompare:@"YES"]==NSOrderedSame	||
		[tmpString localizedCaseInsensitiveCompare:@"TRUE"]==NSOrderedSame)	{
			newNum = NUMBOOL(YES);
		}
		else if ([tmpString localizedCaseInsensitiveCompare:@"NO"]==NSOrderedSame	||
		[tmpString localizedCaseInsensitiveCompare:@"FALSE"]==NSOrderedSame)	{
			newNum = NUMBOOL(NO);
		}
		else	{
			newNum = [self parseNumberFromString:[sender stringValue]];
		}
		*/
	}
	//NSLog(@"\t\tnewNum is %@",newNum);
	
	if (sender == defaultField)	{
		[myInput setObject:newNum forKey:@"DEFAULT"];
	}
	else if (sender == identityField)	{
		[myInput setObject:newNum forKey:@"IDENTITY"];
	}
	
	[_globalJSONGUIController recreateJSONAndExport];
}


@end

#import "ISFPropPoint2DTableCellView.h"
#import <VVBufferPool/VVBufferPool.h>
#import "JSONGUIController.h"
#import "NSValueAdditions.h"




@implementation ISFPropPoint2DTableCellView


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
	
	NSValue			*tmpVal = nil;
	NSString		*tmpString = nil;
	
	tmpVal = [NSValue pointValueFromValArray:[n objectForKey:@"DEFAULT"]];
	if (tmpVal==nil)
		tmpString = @"";
	tmpString = (tmpVal==nil) ? @"" : [NSString stringWithFormat:@"%f, %f",[tmpVal pointValue].x, [tmpVal pointValue].y];
	[defaultField setStringValue:tmpString];
	
	tmpVal = [NSValue pointValueFromValArray:[n objectForKey:@"MIN"]];
	if (tmpVal==nil)
		tmpString = @"";
	tmpString = (tmpVal==nil) ? @"" : [NSString stringWithFormat:@"%f, %f",[tmpVal pointValue].x, [tmpVal pointValue].y];
	[minField setStringValue:tmpString];
	
	tmpVal = [NSValue pointValueFromValArray:[n objectForKey:@"MAX"]];
	if (tmpVal==nil)
		tmpString = @"";
	tmpString = (tmpVal==nil) ? @"" : [NSString stringWithFormat:@"%f, %f",[tmpVal pointValue].x, [tmpVal pointValue].y];
	[maxField setStringValue:tmpString];
	
	tmpVal = [NSValue pointValueFromValArray:[n objectForKey:@"IDENTITY"]];
	if (tmpVal==nil)
		tmpString = @"";
	tmpString = (tmpVal==nil) ? @"" : [NSString stringWithFormat:@"%f, %f",[tmpVal pointValue].x, [tmpVal pointValue].y];
	[identityField setStringValue:tmpString];
}


- (IBAction) uiItemUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	JSONGUIInput	*myInput = [self input];
	if (myInput == nil)
		return;
	
	//	get the string from the UI item
	NSString		*tmpString = [sender stringValue];
	//	parse the string into an array of values
	NSArray			*valArray = [self parseValArrayFromString:tmpString];
	if ([valArray count] != 2)
		valArray = nil;
	
	if (sender == defaultField)	{
		[myInput setObject:valArray forKey:@"DEFAULT"];
	}
	else if (sender == minField)	{
		[myInput setObject:valArray forKey:@"MIN"];
	}
	else if (sender == maxField)	{
		[myInput setObject:valArray forKey:@"MAX"];
	}
	else if (sender == identityField)	{
		[myInput setObject:valArray forKey:@"IDENTITY"];
	}
	
	[_globalJSONGUIController recreateJSONAndExport];
}


@end

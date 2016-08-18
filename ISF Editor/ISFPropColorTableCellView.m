#import "ISFPropColorTableCellView.h"
#import <VVBufferPool/VVBufferPool.h>
#import "JSONGUIController.h"
#import "NSColorAdditions.h"




@implementation ISFPropColorTableCellView


- (void) dealloc	{
	//NSLog(@"%s",__func__);
	//	we have to set the targets to nil here or the color wells may be deactivated after self has been freed (which crashes)
	[defaultCWell setTarget:nil];
	[minCWell setTarget:nil];
	[maxCWell setTarget:nil];
	[identityCWell setTarget:nil];
	[defaultCWellButton setTarget:nil];
	[minCWellButton setTarget:nil];
	[maxCWellButton setTarget:nil];
	[identityCWellButton setTarget:nil];
	[super dealloc];
}
- (void) refreshWithInput:(JSONGUIInput *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	[super refreshWithInput:n];
	
	if (n==nil)
		return;
	
	NSColor			*tmpColor = nil;
	
	tmpColor = [NSColor devColorFromValArray:[n objectForKey:@"DEFAULT"]];
	[defaultCWellButton setIntValue:(tmpColor==nil) ? NSOffState : NSOnState];
	if (tmpColor != nil)
		[defaultCWell setColor:tmpColor];
	
	tmpColor = [NSColor devColorFromValArray:[n objectForKey:@"MIN"]];
	[minCWellButton setIntValue:(tmpColor==nil) ? NSOffState : NSOnState];
	if (tmpColor != nil)
		[minCWell setColor:tmpColor];
	
	tmpColor = [NSColor devColorFromValArray:[n objectForKey:@"MAX"]];
	[maxCWellButton setIntValue:(tmpColor==nil) ? NSOffState : NSOnState];
	if (tmpColor != nil)
		[maxCWell setColor:tmpColor];
	
	tmpColor = [NSColor devColorFromValArray:[n objectForKey:@"IDENTITY"]];
	[identityCWellButton setIntValue:(tmpColor==nil) ? NSOffState : NSOnState];
	if (tmpColor != nil)
		[identityCWell setColor:tmpColor];
}


- (IBAction) uiItemUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	JSONGUIInput	*myInput = [self input];
	if (myInput == nil)
		return;
	
	
	
	if (sender == defaultCWell)	{
		//	if the corresponding button is disabled, bail immediately b/c we aren't saving the value
		if ([defaultCWellButton intValue]==NSOffState)
			return;
		//	get the color, convert it to an array of values, store them in my dict
		NSMutableArray	*newColorArray = MUTARRAY;
		NSColor		*newColor = [(NSColorWell *)sender color];
		CGFloat		colorComps[4];
		[newColor getComponents:colorComps];
		for (int i=0; i<4; ++i)
			[newColorArray addObject:NUMDOUBLE(colorComps[i])];
		[myInput setObject:newColorArray forKey:@"DEFAULT"];
	}
	else if (sender == minCWell)	{
		//	if the corresponding button is disabled, bail immediately b/c we aren't saving the value
		if ([minCWellButton intValue]==NSOffState)
			return;
		//	get the color, convert it to an array of values, store them in my dict
		NSMutableArray	*newColorArray = MUTARRAY;
		NSColor		*newColor = [(NSColorWell *)sender color];
		CGFloat		colorComps[4];
		[newColor getComponents:colorComps];
		for (int i=0; i<4; ++i)
			[newColorArray addObject:NUMDOUBLE(colorComps[i])];
		[myInput setObject:newColorArray forKey:@"MIN"];
	}
	else if (sender == maxCWell)	{
		//	if the corresponding button is disabled, bail immediately b/c we aren't saving the value
		if ([maxCWellButton intValue]==NSOffState)
			return;
		//	get the color, convert it to an array of values, store them in my dict
		NSMutableArray	*newColorArray = MUTARRAY;
		NSColor		*newColor = [(NSColorWell *)sender color];
		CGFloat		colorComps[4];
		[newColor getComponents:colorComps];
		for (int i=0; i<4; ++i)
			[newColorArray addObject:NUMDOUBLE(colorComps[i])];
		[myInput setObject:newColorArray forKey:@"MAX"];
	}
	else if (sender == identityCWell)	{
		//	if the corresponding button is disabled, bail immediately b/c we aren't saving the value
		if ([identityCWellButton intValue]==NSOffState)
			return;
		//	get the color, convert it to an array of values, store them in my dict
		NSMutableArray	*newColorArray = MUTARRAY;
		NSColor		*newColor = [(NSColorWell *)sender color];
		CGFloat		colorComps[4];
		[newColor getComponents:colorComps];
		for (int i=0; i<4; ++i)
			[newColorArray addObject:NUMDOUBLE(colorComps[i])];
		[myInput setObject:newColorArray forKey:@"IDENTITY"];
	}
	else if (sender == defaultCWellButton)	{
		if ([sender intValue] == NSOffState)
			[myInput setObject:nil forKey:@"DEFAULT"];
		else	{
			//	get the color, convert it to an array of values, store them in my dict
			NSMutableArray	*newColorArray = MUTARRAY;
			NSColor		*newColor = [defaultCWell color];
			CGFloat		colorComps[4];
			[newColor getComponents:colorComps];
			for (int i=0; i<4; ++i)
				[newColorArray addObject:NUMDOUBLE(colorComps[i])];
			[myInput setObject:newColorArray forKey:@"DEFAULT"];
		}
	}
	else if (sender == minCWellButton)	{
		if ([sender intValue] == NSOffState)
			[myInput setObject:nil forKey:@"MIN"];
		else	{
			//	get the color, convert it to an array of values, store them in my dict
			NSMutableArray	*newColorArray = MUTARRAY;
			NSColor		*newColor = [minCWell color];
			CGFloat		colorComps[4];
			[newColor getComponents:colorComps];
			for (int i=0; i<4; ++i)
				[newColorArray addObject:NUMDOUBLE(colorComps[i])];
			[myInput setObject:newColorArray forKey:@"MIN"];
		}
	}
	else if (sender == maxCWellButton)	{
		if ([sender intValue] == NSOffState)
			[myInput setObject:nil forKey:@"MAX"];
		else	{
			//	get the color, convert it to an array of values, store them in my dict
			NSMutableArray	*newColorArray = MUTARRAY;
			NSColor		*newColor = [maxCWell color];
			CGFloat		colorComps[4];
			[newColor getComponents:colorComps];
			for (int i=0; i<4; ++i)
				[newColorArray addObject:NUMDOUBLE(colorComps[i])];
			[myInput setObject:newColorArray forKey:@"MAX"];
		}
	}
	else if (sender == identityCWellButton)	{
		if ([sender intValue] == NSOffState)
			[myInput setObject:nil forKey:@"IDENTITY"];
		else	{
			//	get the color, convert it to an array of values, store them in my dict
			NSMutableArray	*newColorArray = MUTARRAY;
			NSColor		*newColor = [identityCWell color];
			CGFloat		colorComps[4];
			[newColor getComponents:colorComps];
			for (int i=0; i<4; ++i)
				[newColorArray addObject:NUMDOUBLE(colorComps[i])];
			[myInput setObject:newColorArray forKey:@"IDENTITY"];
		}
	}
	
	[_globalJSONGUIController recreateJSONAndExport];
}


@end

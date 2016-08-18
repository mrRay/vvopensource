#import "ISFPropInputTableCellView.h"
#import <VVBufferPool/VVBufferPool.h>
#import <VVISFKit/VVISFKit.h>
#import "JSONGUIController.h"
#import <DDMathParser/DDMathParser.h>
#import "RegexKitLite.h"




@implementation ISFPropInputTableCellView


- (id) initWithFrame:(NSRect)f	{
	self = [super initWithFrame:f];
	@synchronized (self)	{
		input = nil;
	}
	return self;
}
- (id) initWithCoder:(NSCoder *)c	{
	self = [super initWithCoder:c];
	@synchronized (self)	{
		input = nil;
	}
	return self;
}
- (void) dealloc	{
	[inputNameField setTarget:nil];
	[labelField setTarget:nil];
	[typePUB setTarget:nil];
	@synchronized (self)	{
		VVRELEASE(input);
	}
	[super dealloc];
}
- (IBAction) baseUIItemUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	BOOL			needsSaveAndReload = NO;
	if (sender == inputNameField)	{
		//	first of all, get my input- only proceed if we can find the input...
		JSONGUIInput	*myInput = [self input];
		if (myInput != nil)	{
			//	get the new val
			NSString		*newVal = [[inputNameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			//	get the old val
			NSString		*oldVal = [myInput objectForKey:@"NAME"];
			//	if the old val and new val are identical, don't do anything
			if ((newVal==nil && oldVal==nil)	||
			(newVal!=nil && oldVal!=nil && [newVal isEqualToString:oldVal]))	{
				//	...do nothing here
			}
			//	else the new and old vals are different- we're trying to change the name
			else	{
				//	get the top, ask it for any inputs using the new val- only proceed if there's no collision...
				JSONGUITop		*myTop = [myInput top];
				JSONGUIInput	*nameCollisionInput = [myTop getInputNamed:newVal];
				if (nameCollisionInput == nil)	{
					//	update my name in my dict to the new name!
					[myInput setObject:newVal forKey:@"NAME"];
					
					//	i've made changes- save to disk & reload!
					needsSaveAndReload = YES;
				}
				//	something was FUBAR, reload anyway
				else
					needsSaveAndReload = YES;
			}
		}
		//	something was FUBAR, reload anyway
		else
			needsSaveAndReload = YES;
	}
	else if (sender == labelField)	{
		JSONGUIInput	*myInput = [self input];
		if (myInput != nil)	{
			//	get the new & old vals
			NSString		*newVal = [[labelField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			NSString		*oldVal = [myInput objectForKey:@"LABEL"];
			//	if there's no change, don't do anything
			if ((newVal==nil && oldVal==nil)	||
			(newVal!=nil && oldVal!=nil && [newVal isEqualToString:oldVal]))	{
				//	...do nothing here
			}
			//	else the val changed, and must be applied
			else	{
				if ([newVal length]<1)
					newVal = nil;
				[myInput setObject:newVal forKey:@"LABEL"];
				
				//	i've made changes- save to disk & reload!
				needsSaveAndReload = YES;
			}
		}
		//	something was FUBAR, reload anyway
		else
			needsSaveAndReload = YES;
	}
	else if (sender == typePUB)	{
		//	first of all, get my input- only proceed if we can find the input...
		JSONGUIInput	*myInput = [self input];
		if (myInput != nil)	{
			//	get the new val
			NSString		*newVal = [typePUB titleOfSelectedItem];
			//	get the old val
			NSString		*oldVal = [myInput objectForKey:@"TYPE"];
			//	if the old val & new val are the same, we don't have to do anything
			if (newVal!=nil && oldVal!=nil && [newVal isEqualToString:oldVal])	{
				//	...do nothing here
			}
			//	else the new and old vals are different- we're trying to change the type
			else	{
				//	delete any properties that might have been relevant to the old type
				[myInput setObject:nil forKey:@"MIN"];
				[myInput setObject:nil forKey:@"MAX"];
				[myInput setObject:nil forKey:@"DEFAULT"];
				[myInput setObject:nil forKey:@"IDENTITY"];
				[myInput setObject:nil forKey:@"VALUES"];
				[myInput setObject:nil forKey:@"LABELS"];
				//	set the new type
				[myInput setObject:newVal forKey:@"TYPE"];
				
				//	i've made changes- save to disk & reload!
				needsSaveAndReload = YES;
			}
		}
		//	something was FUBAR, reload anyway
		else
			needsSaveAndReload = YES;
	}
	
	//	if i've made changes and need to save/reload stuff, do so now!
	if (needsSaveAndReload)	{
		[_globalJSONGUIController recreateJSONAndExport];
	}
}
- (IBAction) deleteClicked:(id)sender	{
	JSONGUIInput		*myInput = [self input];
	if (myInput == nil)
		return;
	JSONGUITop			*top = [myInput top];
	[[[top inputsGroup] contents] lockRemoveObject:myInput];
	
	[_globalJSONGUIController recreateJSONAndExport];
}
- (void) refreshWithInput:(JSONGUIInput *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if (n==nil)
		return;
	
	@synchronized (self)	{
		VVRELEASE(input);
		input = [[ObjectHolder alloc] initWithZWRObject:n];
	}
	
	NSString			*tmpString = nil;
	
	tmpString = [n objectForKey:@"NAME"];
	if (tmpString == nil)
		tmpString = @"???";
	[inputNameField setStringValue:tmpString];
	
	tmpString = [n objectForKey:@"LABEL"];
	if (tmpString == nil)
		tmpString = @"";
	[labelField setStringValue:tmpString];
	
	tmpString = [n objectForKey:@"TYPE"];
	[typePUB selectItem:nil];
	if (tmpString != nil)
		[typePUB selectItemWithTitle:tmpString];
}
- (JSONGUIInput *) input	{
	JSONGUIInput		*returnMe = nil;
	@synchronized (self)	{
		returnMe = (input==nil) ? nil : [input object];
	}
	return returnMe;
}
- (NSNumber *) parseBooleanFromString:(NSString *)n	{
	if (n==nil)
		return nil;
	if ([n isKindOfClass:[NSNumber class]])
		return [[(NSNumber *)n retain] autorelease];
	return [n parseAsBoolean];
}
- (NSNumber *) parseNumberFromString:(NSString *)n	{
	if (n==nil)
		return nil;
	if ([n isKindOfClass:[NSNumber class]])
		return [[(NSNumber *)n retain] autorelease];
	if (![n isKindOfClass:[NSString class]])
		return nil;
	if ([n length]<1)
		return nil;
	return [n numberByEvaluatingString];
}
- (NSArray *) parseValArrayFromString:(NSString *)n	{
	//NSLog(@"%s",__func__);
	if (n==nil || [n length]<1)
		return nil;
	NSMutableArray		*returnMe = nil;
	//NSArray				*components = [n componentsSeparatedByRegex:@"[^\\w]"];
	NSArray				*components = [n componentsSeparatedByRegex:@"[^0-9\\.]"];
	for (NSString *tmpString in components)	{
		if ([tmpString length]>0)	{
			NSNumber		*tmpNum = [tmpString numberByEvaluatingString];
			if (tmpNum != nil)	{
				if (returnMe == nil)
					returnMe = MUTARRAY;
				[returnMe addObject:tmpNum];
			}
		}
	}
	return returnMe;
}
- (NSArray *) parseStringArrayFromString:(NSString *)n	{
	if (n==nil)
		return nil;
	NSMutableArray		*returnMe = nil;
	NSArray				*components = [n componentsSeparatedByRegex:@"[^\\w]"];
	for (NSString *tmpString in components)	{
		if ([tmpString length]>0)	{
			if (returnMe == nil)
				returnMe = MUTARRAY;
			[returnMe addObject:tmpString];
		}
	}
	return returnMe;
}


@end

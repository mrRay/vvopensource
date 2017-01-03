#import "ISFPropTopTableCellView.h"
#import "RegexKitLite.h"
#import "JSONGUIController.h"




@implementation ISFPropTopTableCellView


- (id) initWithFrame:(NSRect)f	{
	self = [super initWithFrame:f];
	@synchronized (self)	{
		top = nil;
	}
	return self;
}
- (id) initWithCoder:(NSCoder *)c	{
	self = [super initWithCoder:c];
	@synchronized (self)	{
		top = nil;
	}
	return self;
}
- (void) dealloc	{
	[descriptionField setTarget:nil];
	[creditField setTarget:nil];
	[categoriesField setTarget:nil];
	@synchronized (self)	{
		VVRELEASE(top);
	}
	[super dealloc];
}
- (void) drawRect:(NSRect)r	{
	NSColor		*bgColor = [[self window] backgroundColor];
	if (bgColor == nil)
		return;
	[bgColor set];
	NSRectFill([self bounds]);
	[super drawRect:r];
}


- (IBAction) uiItemUsed:(id)sender	{
	MutLockDict		*isfDict = [[self top] isfDict];
	if (isfDict==nil)
		return;
	
	NSString		*tmpString = nil;
	
	if (sender == descriptionField)	{
		tmpString = [[sender stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if (tmpString==nil || [tmpString length]<1)
			[isfDict lockRemoveObjectForKey:@"DESCRIPTION"];
		else
			[isfDict lockSetObject:tmpString forKey:@"DESCRIPTION"];
	}
	else if (sender == creditField)	{
		tmpString = [[sender stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if (tmpString==nil || [tmpString length]<1)
			[isfDict lockRemoveObjectForKey:@"CREDIT"];
		else
			[isfDict lockSetObject:tmpString forKey:@"CREDIT"];
	}
	else if (sender == categoriesField)	{
		
		//	we're going to parse the string, and either have a nil array, or an array populated by one or more categories
		NSMutableArray	*newCats = nil;
		//	use regex, break on non-word stuff!
		tmpString = [categoriesField stringValue];
		if (tmpString!=nil && [tmpString length]<1)
			tmpString = nil;
		if (tmpString == nil)	{
			[isfDict lockRemoveObjectForKey:@"CATEGORIES"];
		}
		else	{
			NSArray			*terms = nil;
			terms = [tmpString componentsSeparatedByRegex:@"[,]+"];
			//NSLog(@"\t\tcats are %@",terms);
			for (NSString *term in terms)	{
				if ([term length]>0)	{
					if (newCats==nil)
						newCats = MUTARRAY;
					[newCats addObject:[term stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
				}
			}
		}
		//	now apply 'newCats' to isfDict
		if (newCats == nil)
			[isfDict lockRemoveObjectForKey:@"CATEGORIES"];
		else
			[isfDict lockSetObject:newCats forKey:@"CATEGORIES"];
	}
	else if (sender == filterVsnField)	{
		tmpString = [filterVsnField stringValue];
		//	parse the string, breaking on periods- filter the results, ensuring that all the terms are numbers
		NSArray			*terms = [tmpString componentsSeparatedByRegex:@"\\."];
		NSMutableArray	*filteredTerms = nil;
		for (NSString *term in terms)	{
			NSString		*filteredTerm = [term stringByReplacingOccurrencesOfRegex:@"[^0-9]" withString:@""];
			if (filteredTerm != nil)	{
				if (filteredTerms == nil)
					filteredTerms = MUTARRAY;
				[filteredTerms addObject:filteredTerm];
			}
		}
		//	if there are zero terms, remove the object from the key
		if (filteredTerms==nil || [filteredTerms count]<1)	{
			[isfDict lockRemoveObjectForKey:@"VSN"];
		}
		//	else there are one or more terms- make a new vsn string, store it
		else	{
			NSMutableString		*mutString = [NSMutableString stringWithCapacity:0];
			int			i = 0;
			for (NSString *filteredTerm in filteredTerms)	{
				if (i==0)
					[mutString appendString:filteredTerm];
				else
					[mutString appendFormat:@".%@",filteredTerm];
				++i;
			}
			if (mutString != nil)
				[isfDict lockSetObject:[[mutString copy] autorelease] forKey:@"VSN"];
		}
	}
	
	[_globalJSONGUIController recreateJSONAndExport];
}


- (void) refreshWithTop:(JSONGUITop *)t	{
	@synchronized (self)	{
		VVRELEASE(top);
		top = [[ObjectHolder alloc] initWithZWRObject:t];
	}
	
	NSString		*tmpString = nil;
	MutLockDict		*isfDict = [t isfDict];
	NSArray			*tmpArray = nil;
	
	tmpString = [isfDict objectForKey:@"DESCRIPTION"];
	if (tmpString==nil)
		tmpString = @"";
	else if (![tmpString isKindOfClass:[NSString class]])
		tmpString = @"";
	[descriptionField setStringValue:tmpString];
	
	tmpString = [isfDict objectForKey:@"CREDIT"];
	if (tmpString==nil)
		tmpString = @"";
	else if (![tmpString isKindOfClass:[NSString class]])
		tmpString = @"";
	[creditField setStringValue:tmpString];
	
	tmpArray = [isfDict objectForKey:@"CATEGORIES"];
	if (![tmpArray isKindOfClass:[NSArray class]])
		tmpString = @"";
	else	{
		NSMutableString		*tmpMutString = [NSMutableString stringWithCapacity:0];
		int					i = 0;
		for (NSString *catString in tmpArray)	{
			if (i==0)
				[tmpMutString appendString:catString];
			else
				[tmpMutString appendFormat:@", %@",catString];
			++i;
		}
		tmpString = [[tmpMutString copy] autorelease];
	}
	[categoriesField setStringValue:tmpString];
	
	tmpString = [isfDict objectForKey:@"VSN"];
	if (tmpString==nil)
		tmpString = @"";
	else if (![tmpString isKindOfClass:[NSString class]])
		tmpString = @"";
	[filterVsnField setStringValue:tmpString];
}


- (JSONGUITop *) top	{
	JSONGUITop		*returnMe = nil;
	@synchronized (self)	{
		returnMe = (top==nil) ? nil : [top object];
	}
	return returnMe;
}


@end

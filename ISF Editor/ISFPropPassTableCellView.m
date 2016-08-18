#import "ISFPropPassTableCellView.h"
#import "JSONGUIPersistentBuffer.h"
#import <VVISFKit/VVISFKit.h>
#import <DDMathParser/DDMathParser.h>
#import "JSONGUIController.h"




@implementation ISFPropPassTableCellView


- (id) initWithFrame:(NSRect)f	{
	self = [super initWithFrame:f];
	@synchronized (self)	{
		pass = nil;
	}
	return self;
}
- (id) initWithCoder:(NSCoder *)c	{
	self = [super initWithCoder:c];
	@synchronized (self)	{
		pass = nil;
	}
	return self;
}
- (void) dealloc	{
	[passNameField setTarget:nil];
	[targetField setTarget:nil];
	[persistentToggle setTarget:nil];
	[floatToggle setTarget:nil];
	[widthField setTarget:nil];
	[heightField setTarget:nil];
	@synchronized (self)	{
		VVRELEASE(pass);
	}
	[super dealloc];
}


- (IBAction) uiItemUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	//	get the pass & top, we're probably going to need it
	JSONGUIPass		*myPass = [self pass];
	//NSLog(@"\t\tmyPass is %@",myPass);
	JSONGUITop		*top = [myPass top];
	BOOL			needsSaveAndReload = NO;
	
	if (sender == targetField)	{
		NSString		*oldName = [myPass objectForKey:@"TARGET"];
		//	get the target name- if it's empty, set it to nil
		NSString		*targetName = [[targetField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if (targetName!=nil && [targetName length]<1)
			targetName = nil;
		//	if the target name matches the current name, do nothing
		if ((oldName==nil && targetName==nil)	||
		(oldName!=nil && targetName!=nil && [oldName isEqualToString:targetName]))	{
			//	do nothing!
		}
		//	else we're changing the target name
		else	{
			//	if another pass is already using the target name
			if ([top getPassesRenderingToBufferNamed:targetName]!=nil)	{
				//	we can't use the target name- for program flow, reset it to the "old" name
				targetName = oldName;
			}
			//	else no passes are using the target name- we're clear to use it
			else	{
				//	i've made changes- save to disk & reload!
				needsSaveAndReload = YES;
				[myPass setObject:targetName forKey:@"TARGET"];
			}
		}
		
	}
	else if (sender == persistentToggle)	{
		//NSLog(@"\t\tpersistent toggle used");
		//	get the target name- if there isn't a target name, bail immediately
		NSString		*targetName = [myPass objectForKey:@"TARGET"];
		if (targetName!=nil)	{
			//	if we're enabling the persistent toggle
			if ([persistentToggle intValue]==NSOnState)	{
				//	make a new persistent buffer object with the appropriate name
				JSONGUIPersistentBuffer		*pbuffer = [[[JSONGUIPersistentBuffer alloc] initWithName:targetName top:top] autorelease];
				//	add the new persistent buffer to the dict of persistent buffers
				[[[top buffersGroup] contents] lockSetObject:pbuffer forKey:targetName];
			}
			//	else we're disabling the persistent toggle
			else	{
				//NSLog(@"\t\tshould be disabling persistent toggle");
				//	locate the existing persistent buffer object
				JSONGUIPersistentBuffer		*pbuffer = [top getPersistentBufferNamed:targetName];
				//NSLog(@"\t\tpbuffer is %@",pbuffer);
				//	add the objects from the persistent buffer object's dict to my pass dict so i don't lose any sizing data
				NSDictionary		*oldBufferDict = [pbuffer createExportDict];
				for (NSString *tmpKey in [oldBufferDict allKeys])	{
					if (![tmpKey isEqualToString:@"PERSISTENT"])
						[myPass setObject:[oldBufferDict objectForKey:tmpKey] forKey:tmpKey];
				}
				//	delete the persistent buffer object
				//NSLog(@"\t\tbefore, buffersGroup is %@",[[top buffersGroup] contents]);
				[[[top buffersGroup] contents] lockRemoveObjectForKey:targetName];
				//NSLog(@"\t\tafter, buffersGroup is %@",[[top buffersGroup] contents]);
				//	make sure all the passes know that anything targeting this isn't rendering to a peristent buffer
				for (JSONGUIPass *tmpPass in [top getPassesRenderingToBufferNamed:targetName])	{
					if ([tmpPass objectForKey:@"PERSISTENT"]!=nil)
						[tmpPass setObject:nil forKey:@"PERSISTENT"];
				}
			}
		}
		//	i've made changes- save to disk & reload!
		needsSaveAndReload = YES;
	}
	else if (sender == floatToggle)	{
		//NSLog(@"\t\tfloat toggle used");
		BOOL			newFloatVal = ([floatToggle intValue]==NSOnState) ? YES : NO;
		//	get the target name
		NSString		*targetName = [myPass objectForKey:@"TARGET"];
		//	try to get a persistent buffer for the name
		JSONGUIPersistentBuffer	*pbuffer = [top getPersistentBufferNamed:targetName];
		//NSLog(@"\t\ttargetName is %@, pbuffer is %@",targetName,pbuffer);
		//	if i got a persistent buffer, add the float property there
		if (pbuffer != nil)	{
			[pbuffer setObject:((newFloatVal) ? NUMBOOL(YES) : nil) forKey:@"FLOAT"];
		}
		//	else i didn't get a persistent buffer- add the float property to the pass dict
		else	{
			[myPass setObject:((newFloatVal) ? NUMBOOL(YES) : nil) forKey:@"FLOAT"];
		}
		//	i've made changes- save to disk & reload!
		needsSaveAndReload = YES;
	}
	else if (sender == widthField)	{
		NSString		*newStringVal = [[sender stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if (newStringVal!=nil && [newStringVal length]<1)
			newStringVal = nil;
		//	get the target name
		NSString		*targetName = [myPass objectForKey:@"TARGET"];
		//	try to get a persistent buffer for the name
		JSONGUIPersistentBuffer	*pbuffer = [top getPersistentBufferNamed:targetName];
		//	if i got a persistent buffer, add the float property there
		if (pbuffer != nil)
			[pbuffer setObject:newStringVal forKey:@"WIDTH"];
		//	else i didn't get a persistent buffer- add the float property to the pass dict
		else
			[myPass setObject:newStringVal forKey:@"WIDTH"];
		//	i've made changes- save to disk & reload!
		needsSaveAndReload = YES;
	}
	else if (sender == heightField)	{
		NSString		*newStringVal = [[sender stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		if (newStringVal!=nil && [newStringVal length]<1)
			newStringVal = nil;
		//	get the target name
		NSString		*targetName = [myPass objectForKey:@"TARGET"];
		//	try to get a persistent buffer for the name
		JSONGUIPersistentBuffer	*pbuffer = [top getPersistentBufferNamed:targetName];
		//	if i got a persistent buffer, add the float property there
		if (pbuffer != nil)
			[pbuffer setObject:newStringVal forKey:@"HEIGHT"];
		//	else i didn't get a persistent buffer- add the float property to the pass dict
		else
			[myPass setObject:newStringVal forKey:@"HEIGHT"];
		//	i've made changes- save to disk & reload!
		needsSaveAndReload = YES;
	}
	
	//	if i've made changes and need to save/reload stuff, do so now!
	if (needsSaveAndReload)	{
		[_globalJSONGUIController recreateJSONAndExport];
	}
}
- (IBAction) deleteClicked:(id)sender	{
	JSONGUIPass			*myPass = [self pass];
	if (myPass == nil)
		return;
	JSONGUITop			*top = [myPass top];
	[[[top passesGroup] contents] lockRemoveObject:myPass];
	
	[_globalJSONGUIController recreateJSONAndExport];
}
- (void) refreshWithTop:(JSONGUITop *)t pass:(JSONGUIPass *)p	{
	//NSLog(@"%s ... %@",__func__,p);
	@synchronized (self)	{
		VVRELEASE(pass);
		pass = [[ObjectHolder alloc] initWithZWRObject:p];
	}
	
	NSString		*tmpString = nil;
	NSNumber		*tmpNum = nil;
	//NSArray			*tmpArray = nil;
	
	//	get the index of the passed pass
	NSInteger		passIndex = [t indexOfPass:p];
	if (passIndex == NSNotFound)
		NSLog(@"\t\tERR: passIndex for %@ is NSNotFound",p);
	else	{
		//	update the pass name field
		[passNameField setStringValue:[NSString stringWithFormat:@"PASSINDEX %d",(int)passIndex]];
		
		//	update the target buffer name field
		tmpString = [p objectForKey:@"TARGET"];
		if (tmpString == nil)
			tmpString = @"";
		else if (![tmpString isKindOfClass:[NSString class]])
			tmpString = @"";
		[targetField setStringValue:tmpString];
		
		//	is there a persistent buffer for the target buffer?
		JSONGUIPersistentBuffer		*pbuffer = [t getPersistentBufferNamed:[targetField stringValue]];
		//	get an array of passes that render to the target buffer
		JSONGUIPass			*myPass = [self pass];
		//NSArray			*passes = [t getPassesRenderingToBufferNamed:[targetField stringValue]];
		//JSONGUIPass		*pass = (passes==nil || [passes count]<1) ? nil : [passes objectAtIndex:0];
		//	...okay, so now we have all the source of information about this buffer- populate more UI items...
		
		//	persistent toggle
		[persistentToggle setIntValue:(pbuffer==nil) ? NSOffState : NSOnState];
		
		//	float toggle
		tmpString = [myPass objectForKey:@"FLOAT"];
		if (tmpString!=nil && [tmpString isKindOfClass:[NSNumber class]])
			tmpNum = [[(NSNumber *)tmpString retain] autorelease];
		else if ([tmpString isKindOfClass:[NSString class]])	{
			tmpNum = [tmpString parseAsBoolean];
			if (tmpNum == nil)
				tmpNum = [tmpString numberByEvaluatingString];
		}
		else
			tmpNum = nil;
		if (tmpNum == nil)
			tmpNum = NUMINT(0);
		[floatToggle setIntValue:([tmpNum intValue]>0) ? NSOnState : NSOffState];
		/*
		tmpString = [myPass objectForKey:@"FLOAT"];
		if (tmpString == nil)
			tmpString = [pbuffer objectForKey:@"FLOAT"];
		
		tmpNum = [self parseBooleanFromString:tmpString];
		if (tmpNum == nil)
			tmpNum = [self parseNumberFromString];
		if (tmpNum == nil)
			tmpNum = NUMINT(0);
		[floatToggle setIntValue:([tmpNum intValue]>0) ? NSOnState : NSOffState];
		*/
		
		//	width field
		tmpString = [myPass objectForKey:@"WIDTH"];
		if (tmpString == nil)
			tmpString = [pbuffer objectForKey:@"WIDTH"];
		if ([tmpString isKindOfClass:[NSNumber class]])
			tmpString = [NSString stringWithFormat:@"%d",[(NSNumber *)tmpString intValue]];
		else if (![tmpString isKindOfClass:[NSString class]])
			tmpString = @"";
		[widthField setStringValue:tmpString];
		
		//	height field
		tmpString = [myPass objectForKey:@"HEIGHT"];
		if (tmpString == nil)
			tmpString = [pbuffer objectForKey:@"HEIGHT"];
		if ([tmpString isKindOfClass:[NSNumber class]])
			tmpString = [NSString stringWithFormat:@"%d",[(NSNumber *)tmpString intValue]];
		else if (![tmpString isKindOfClass:[NSString class]])
			tmpString = @"";
		[heightField setStringValue:tmpString];
	}
}


- (JSONGUIPass *) pass	{
	JSONGUIPass		*returnMe = nil;
	@synchronized (self)	{
		returnMe = (pass==nil) ? nil : [pass object];
	}
	return returnMe;
}


@end

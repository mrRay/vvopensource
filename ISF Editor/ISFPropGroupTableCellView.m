#import "ISFPropGroupTableCellView.h"
#import "JSONGUIInput.h"




@implementation ISFPropGroupTableCellView


- (id) initWithFrame:(NSRect)f	{
	self = [super initWithFrame:f];
	@synchronized (self)	{
		group = nil;
	}
	return self;
}
- (id) initWithCoder:(NSCoder *)c	{
	self = [super initWithCoder:c];
	@synchronized (self)	{
		group = nil;
	}
	return self;
}
- (void) dealloc	{
	[groupNameField setTarget:nil];
	[super dealloc];
	@synchronized (self)	{
		VVRELEASE(group);
	}
}
- (void) drawRect:(NSRect)r	{
	NSColor		*bgColor = [[self window] backgroundColor];
	if (bgColor == nil)
		return;
	[bgColor set];
	NSRectFill([self bounds]);
	[super drawRect:r];
}


- (IBAction) addButtonUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	//	get my group
	JSONGUIArrayGroup	*myGroup = [self group];
	if (myGroup==nil)
		return;
	JSONGUITop	*top = [myGroup top];
	if (top==nil)
		return;
	//	depending on what kind of group, i need to make a new...thing
	switch ([myGroup groupType])	{
		case ISFArrayClassType_Input:
		{
			//	tell the top to create a new input name
			NSString			*newInputName = [top createNewInputName];
			//	make a dict that describes the new input (we'll go with a simple float for the default)
			NSMutableDictionary	*newInputDict = MUTDICT;
			[newInputDict setObject:newInputName forKey:@"NAME"];
			[newInputDict setObject:@"float" forKey:@"TYPE"];
			//	make a new input from the dict
			JSONGUIInput		*newInput = [[[JSONGUIInput alloc] initWithDict:newInputDict top:top] autorelease];
			if (newInput == nil)
				NSLog(@"\t\terr: couldn't make new input, %s.  dict was %@",__func__,newInputDict);
			else	{
				//	add the input to the array!
				[[myGroup contents] lockAddObject:newInput];
			}
			break;
		}
		case ISFArrayClassType_Pass:
		{
			//	make a new pass
			JSONGUIPass		*newPass = [[[JSONGUIPass alloc] initWithDict:nil top:top] autorelease];
			if (newPass==nil)
				NSLog(@"\t\terr: couldn't make new pass, %s",__func__);
			else	{
				//	add the new pass to the array of passes
				[[myGroup contents] lockAddObject:newPass];
			}
			break;
		}
	}
	
	//	recreate the JSON blob, export the file, and have everybody reload it!
	[_globalJSONGUIController recreateJSONAndExport];
}
- (void) refreshWithGroup:(JSONGUIArrayGroup *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	@synchronized (self)	{
		VVRELEASE(group);
		group = (n==nil) ? nil : [[ObjectHolder alloc] initWithZWRObject:n];
	}
	
	switch ([n groupType])	{
	case ISFArrayClassType_Input:
		[groupNameField setStringValue:[NSString stringWithFormat:@"INPUTS (%ld)",[[n contents] lockCount]]];
		break;
	case ISFArrayClassType_Pass:
		[groupNameField setStringValue:[NSString stringWithFormat:@"PASSES (%ld)",[[n contents] lockCount]]];
		break;
	}
}


- (JSONGUIArrayGroup *) group	{
	JSONGUIArrayGroup		*returnMe = nil;
	@synchronized (self)	{
		returnMe = (group==nil) ? nil : [group object];
	}
	return returnMe;
}


@end

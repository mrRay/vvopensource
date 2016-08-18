#import "JSONGUIArrayGroup.h"
#import "JSONGUIInput.h"
#import "JSONGUIPass.h"




@implementation JSONGUIArrayGroup


- (id) initWithType:(ISFArrayClassType)targetType top:(JSONGUITop *)theTop	{
	self = [super init];
	if (self != nil)	{
		//	initialize the basic vars
		groupType = targetType;
		contents = [[MutLockArray alloc] init];
		top = [[ObjectHolder alloc] initWithZWRObject:theTop];
		//	get the raw ISF dict from the top-level object- this is what we're going to parse to populate our contents
		MutLockDict		*isfDict = [theTop isfDict];
		
		switch (groupType)	{
		//	if this is meant to parse an array of inputs
		case ISFArrayClassType_Input:
			for (NSDictionary *itemDict in [isfDict objectForKey:@"INPUTS"])	{
				//	create a JSONGUIInput from the dict
				[contents lockAddObject:[[[JSONGUIInput alloc] initWithDict:itemDict top:theTop] autorelease]];
			}
			break;
		//	if this is meant to parse an array of rendering passes
		case ISFArrayClassType_Pass:
			for (NSDictionary *itemDict in [isfDict objectForKey:@"PASSES"])	{
				//	create a JSONGUIPass from the dict- this instance will use the top to query the full ISF dict and populate itself
				[contents lockAddObject:[[[JSONGUIPass alloc] initWithDict:itemDict top:theTop] autorelease]];
			}
			break;
		}
	}
	return self;
}
- (void) dealloc	{
	VVRELEASE(contents);
	VVRELEASE(top);
	[super dealloc];
}
@synthesize groupType;
@synthesize contents;
- (JSONGUITop *) top	{
	return [top object];
}
- (NSString *) description	{
	switch (groupType)	{
	case ISFArrayClassType_Input:
		return @"<JSONGUIArrayGroup- inputs>";
	case ISFArrayClassType_Pass:
		return @"<JSONGUIArrayGroup- passes>";
	}
	return @"<JSONGUIArrayGroup- ?>";
}


@end

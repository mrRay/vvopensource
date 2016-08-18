#import "JSONGUIInput.h"




@implementation JSONGUIInput


- (id) initWithDict:(NSDictionary *)n top:(JSONGUITop *)t	{
	self = [super init];
	if (self != nil)	{
		dict = nil;
		top = nil;
		if (n==nil || t==nil)	{
			[self release];
			return nil;
		}
		dict = [[MutLockDict alloc] init];
		//	we can just copy the contents of INPUT dicts
		[dict lockAddEntriesFromDictionary:n];
		top = [[ObjectHolder alloc] initWithZWRObject:t];
	}
	return self;
}
- (void) dealloc	{
	VVRELEASE(dict);
	VVRELEASE(top);
	[super dealloc];
}
- (id) objectForKey:(NSString *)k	{
	return [[[dict lockObjectForKey:k] retain] autorelease];
}
- (void) setObject:(id)n forKey:(NSString *)k	{
	if (n==nil)
		[dict lockRemoveObjectForKey:k];
	else
		[dict lockSetObject:n forKey:k];
}
- (NSString *) description	{
	return [NSString stringWithFormat:@"<JSONGUIInput- %@>",[dict lockObjectForKey:@"NAME"]];
}
- (JSONGUITop *) top	{
	return [top object];
}


- (NSMutableDictionary *) createExportDict	{
	if (dict==nil)
		return nil;
	return [dict lockCreateDictCopy];
}


@end

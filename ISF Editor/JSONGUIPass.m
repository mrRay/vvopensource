#import "JSONGUIPass.h"
#import "JSONGUIPersistentBuffer.h"
#import "JSONGUITop.h"




@implementation JSONGUIPass


- (id) initWithDict:(NSDictionary *)n top:(JSONGUITop *)t	{
	self = [super init];
	if (self != nil)	{
		dict = nil;
		top = nil;
		if (t==nil)	{
			[self release];
			return nil;
		}
		dict = [[MutLockDict alloc] init];
		[dict wrlock];
		//	add all the entries from the dict we were passed (which should be a dict from the PASSES array of an ISF dict)
		[dict addEntriesFromDictionary:n];
		[dict unlock];
		
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
	//NSLog(@"%s ... %@, %@",__func__,n,k);
	if (n==nil)
		[dict lockRemoveObjectForKey:k];
	else
		[dict lockSetObject:n forKey:k];
	//NSLog(@"\t\tafter, dict is %@",dict);
}
- (NSString *) description	{
	return [NSString stringWithFormat:@"<JSONGUIPass %p>",self];
}
- (JSONGUITop *) top	{
	return [top object];
}


- (NSMutableDictionary *) createExportDict	{
	//NSLog(@"%s ... %@",__func__,self);
	if (dict==nil)
		return nil;
	//	copy the entries from my dict into the dict i'll be returning
	NSMutableDictionary		*returnMe = MUTDICT;
	[dict rdlock];
	[returnMe addEntriesFromDictionary:[dict dict]];
	[dict unlock];
	//	if i'm rendering into a persistent buffer, i shouldn't put any info about it in this dict (i'll let the persistent buffer do this)
	NSString			*targetName = [dict lockObjectForKey:@"TARGET"];
	JSONGUIPersistentBuffer	*pbuffer = (targetName==nil) ? nil : [[top object] getPersistentBufferNamed:targetName];
	if (pbuffer != nil)	{
		[returnMe removeObjectForKey:@"WIDTH"];
		[returnMe removeObjectForKey:@"HEIGHT"];
		[returnMe removeObjectForKey:@"FLOAT"];
		[returnMe setObject:NUMBOOL(YES) forKey:@"PERSISTENT"];
		[returnMe addEntriesFromDictionary:[pbuffer createExportDict]];
	}
	//NSLog(@"\t\treturning %@",returnMe);
	return returnMe;
}


@end

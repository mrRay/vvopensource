#import "JSONGUIPersistentBuffer.h"
#import "JSONGUITop.h"




@implementation JSONGUIPersistentBuffer


- (id) initWithName:(NSString *)n top:(JSONGUITop *)t	{
	self = [super init];
	if (self != nil)	{
		dict = nil;
		name = nil;
		top = nil;
		if (n==nil || [n length]<1 || t==nil)	{
			[self release];
			return nil;
		}
		
		//	make an empty dict, retain the passed name and make a weak ref to the top
		dict = [[MutLockDict alloc] init];
		name = (n==nil) ? nil : [n retain];
		top = [[ObjectHolder alloc] initWithZWRObject:t];
		
		//	get the top-level ISF dict- we're going to parse its contents to populate 'dict'
		MutLockDict		*isfDict = [t isfDict];
		
		//	the "PERSISTENT_BUFFERS" dict (or maybe array?) has to be parsed for information relevant to the buffer i'm looking for
		NSDictionary		*pbuffersDict = [isfDict objectForKey:@"PERSISTENT_BUFFERS"];
		if (pbuffersDict != nil)	{
			//	if the "PERSISTENT_BUFFERS" dict is really an array
			if ([pbuffersDict isKindOfClass:[NSArray class]])	{
				//	do nothing- the array only contains strings/buffer names, and we already have the name
			}
			//	if the "PERSISTENT_BUFFERS" dict is really a dictionary
			else if ([pbuffersDict isKindOfClass:[NSDictionary class]])	{
				//	use the passed name to look up the sub-dict which describes the persistent buffer
				NSDictionary		*pbufferDict = [pbuffersDict objectForKey:n];
				//	if i found a dict describing myself, add its entries to my dict
				if (pbufferDict != nil)
					[dict lockAddEntriesFromDictionary:pbufferDict];
			}
		}
		
		//	the "PASSES" might also contain information about persistent buffers!
		NSArray				*passes = [isfDict objectForKey:@"PASSES"];
		//	run through all the pass dicts
		for (NSDictionary *passDict in passes)	{
			//	if this pass has a target, and that target matches my target
			NSString			*passTargetName = [passDict objectForKey:@"TARGET"];
			if (passTargetName!=nil && [passTargetName isEqualToString:n])	{
				//	get the WIDTH, HEIGHT, and FLOAT keys from the pass dict!
				NSArray				*tmpKeys = @[@"WIDTH", @"HEIGHT", @"FLOAT"];
				for (NSString *tmpKey in tmpKeys)	{
					id			anObj = [passDict objectForKey:tmpKey];;
					if (anObj != nil)
						[dict lockSetObject:anObj forKey:tmpKey];
				}
			}
		}
		
		//	...okay, at this point 'dict' should be fully populated with all the values necessary to describe this buffer
	}
	return self;
}
- (void) dealloc	{
	VVRELEASE(dict);
	VVRELEASE(name);
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
- (NSString *) name	{
	return [[name retain] autorelease];
}
- (NSString *) description	{
	return [NSString stringWithFormat:@"<JSONGUIPersistentBuffer %@>",name];
}
- (JSONGUITop *) top	{
	return [top object];
}


- (NSDictionary *) createExportDict	{
	return [dict lockCreateDictCopy];
}


@end

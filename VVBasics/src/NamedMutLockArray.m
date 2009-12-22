
#import "NamedMutLockArray.h"




@implementation NamedMutLockArray


- (NSString *) description	{
	return [NSString stringWithFormat:@"<NamedMutLockArray: %@, %@>",name,array];
}
- (id) initWithCapacity:(NSUInteger)c	{
	if (self = [super initWithCapacity:c])	{
		name = nil;
		return self;
	}
	[self release];
	return nil;
}
- (id) init	{
	return [self initWithCapacity:0];
}
- (void) dealloc	{
	VVRELEASE(name);
	[super dealloc];
}


- (NSComparisonResult) nameCompare:(NamedMutLockArray *)comp	{
	if (name==nil)
		return NSOrderedDescending;
	NSString		*compName = [comp name];
	if (compName==nil)
		return NSOrderedAscending;
	return [name caseInsensitiveCompare:compName];
}


- (void) setName:(NSString *)n	{
	VVRELEASE(name);
	if (n != nil)
		name = [n retain];
}
- (NSString *)name	{
	return name;
}


@end

#import "ISFRenderPass.h"




@implementation ISFRenderPass


+ (id) create	{
	id		returnMe = [[ISFRenderPass alloc] init];
	if (returnMe == nil)
		return returnMe;
	return [returnMe autorelease];
}

- (id) init	{
	if (self = [super init])	{
		targetName = nil;
		return self;
	}
	[self release];
	return nil;
}
- (void) dealloc	{
	VVRELEASE(targetName);
	[super dealloc];
}


@synthesize targetName;


@end

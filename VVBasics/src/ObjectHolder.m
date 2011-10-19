
#import "ObjectHolder.h"




@implementation ObjectHolder


+ (id) createWithObject:(id)o	{
	ObjectHolder		*returnMe = [[ObjectHolder alloc] initWithObject:o];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithObject:(id)o	{
	//NSLog(@"%s",__func__);
	if (o == nil)
		goto BAIL;
	if (self = [super init])	{
		deleted = NO;
		object = o;
		return self;
	}
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	NSException		*exc = nil;
	exc = [NSException
		exceptionWithName:@"TestName"
		reason:@"Test Reason"
		userInfo:nil];
	if (exc == nil)
		NSLog(@"\t\terr: couldn't make the exception!");
	else
		[exc raise];
	[self release];
	return nil;
}
- (void) dealloc	{
	deleted = YES;
	object = nil;
	[super dealloc];
}

- (void) setObject:(id)n	{
	object = n;
}
- (id) object	{
	return object;
}


- (id) valueForKey:(NSString *)k	{
	id		returnMe = nil;
	if (object != nil)
		returnMe = [object valueForKey:k];
	if (returnMe == nil)
		returnMe = [self valueForKey:k];
	return returnMe;
}
- (BOOL) isEqual:(id)o	{
	return [object isEqual:[o object]];
}
- (BOOL) isEqualTo:(id)o	{
	return [object isEqualTo:[o object]];
}


- (NSMethodSignature *) methodSignatureForSelector:(SEL)s	{
	//NSLog(@"%s ... %s",__func__,s);
	//	if i've been deleted, return nil
	if ((deleted) || (object==nil))
		return nil;
	//	try to find the actual method signature for me
	NSMethodSignature	*returnMe = [super methodSignatureForSelector:s];
	if (returnMe != nil)	{
		//NSLog(@"\tactually found the selector!");
		return returnMe;
	}
	//	if i don't have an object, return nil
	if (object == nil)
		return nil;
	returnMe = [object methodSignatureForSelector:s];
	return returnMe;
}

- (void) forwardInvocation:(NSInvocation *)anInvocation	{
	//NSLog(@"%s ... %@",__func__,anInvocation);
	if ((!deleted) && (object!=nil))	{
		[anInvocation invokeWithTarget:object];
	}
}
- (NSString *)description	{	
	if (object != nil)
		return [NSString stringWithFormat:@"ObjectHolder: %ld : %@",self,object];
	else 
		return [NSString stringWithFormat:@"ObjectHolder: %ld",self];
	

}

@end


#import "ObjectHolder.h"
#import "VVBasicMacros.h"




@implementation ObjectHolder


+ (id) createWithObject:(id)o	{
	ObjectHolder		*returnMe = [[ObjectHolder alloc] initWithObject:o];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithZWRObject:(id)o	{
	ObjectHolder		*returnMe = [[ObjectHolder alloc] initWithZWRObject:o];
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
		zwr = nil;
		return self;
	}
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	/*
	NSException		*exc = nil;
	exc = [NSException
		exceptionWithName:@"TestName"
		reason:@"Test Reason"
		userInfo:nil];
	if (exc == nil)
		NSLog(@"\t\terr: couldn't make the exception!");
	else
		[exc raise];
	*/
	[self release];
	return nil;
}
- (id) initWithZWRObject:(id)o	{
	//NSLog(@"%s",__func__);
	if (o == nil)
		goto BAIL;
	if (self = [super init])	{
		deleted = NO;
		object = nil;
		zwr = (o==nil) ? nil : [[VV_MAZeroingWeakRef alloc] initWithTarget:o];
		return self;
	}
	BAIL:
	//NSLog(@"\t\terr: %s - BAIL",__func__);
	
	/*
	NSException		*exc = nil;
	exc = [NSException
		exceptionWithName:@"TestName"
		reason:@"Test Reason"
		userInfo:nil];
	if (exc == nil)
		NSLog(@"\t\terr: couldn't make the exception!");
	else
		[exc raise];
	*/
	[self release];
	return nil;
}
- (id) init	{
	if (self = [super init])	{
		deleted = NO;
		object = nil;
		zwr = nil;
		return self;
	}
	NSLog(@"\t\terr: %s - BAIL",__func__);
	[self release];
	return nil;
}
- (void) dealloc	{
	deleted = YES;
	object = nil;
	VVRELEASE(zwr);
	[super dealloc];
}

- (void) setObject:(id)n	{
	VVRELEASE(zwr);
	object = n;
}
- (void) setZWRObject:(id)n	{
	object = nil;
	if (n == nil)	{
		VVRELEASE(zwr);
	}
	else	{
		VVRELEASE(zwr);
		zwr = [[VV_MAZeroingWeakRef alloc] initWithTarget:n];
	}
}
- (id) object	{
	if (object != nil)
		return object;
	else if (zwr != nil)
		return [zwr target];
	return nil;
}


- (id) valueForKey:(NSString *)k	{
	id		myObj = [self object];
	id		returnMe = nil;
	if (myObj != nil)
		returnMe = [myObj valueForKey:k];
	if (returnMe == nil)
		returnMe = [self valueForKey:k];
	return returnMe;
}
- (BOOL) isEqual:(id)o	{
	id		myObj = [self object];
	return [myObj isEqual:[o object]];
}
- (BOOL) isEqualTo:(id)o	{
	id		myObj = [self object];
	return [myObj isEqualTo:[o object]];
}


- (NSMethodSignature *) methodSignatureForSelector:(SEL)s	{
	//NSLog(@"%s ... %s",__func__,s);
	//	if i've been deleted, return nil
	if ((deleted) || ((object==nil) && (zwr==nil)))
		return nil;
	//	try to find the actual method signature for me
	NSMethodSignature	*returnMe = [super methodSignatureForSelector:s];
	if (returnMe != nil)	{
		//NSLog(@"\tactually found the selector!");
		return returnMe;
	}
	//	if i don't have an object, return nil
	id		myObj = [self object];
	if (myObj == nil)
		return nil;
	returnMe = [myObj methodSignatureForSelector:s];
	return returnMe;
}

- (void) forwardInvocation:(NSInvocation *)anInvocation	{
	//NSLog(@"%s ... %@",__func__,anInvocation);
	if (deleted)
		return;
	id		myObj = [self object];
	if (myObj != nil)	{
		[anInvocation invokeWithTarget:myObj];
	}
}
- (NSString *)description	{	
	id		myObj = [self object];
	if (myObj != nil)
		return [NSString stringWithFormat:@"ObjectHolder: %p : %@",self,myObj];
	else
		return [NSString stringWithFormat:@"ObjectHolder: %p",self];
	

}

@end

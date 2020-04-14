
#import "ObjectHolder.h"
#import "VVBasicMacros.h"




@implementation ObjectHolder


+ (id) createWithObject:(id)o	{
	ObjectHolder		*returnMe = [[ObjectHolder alloc] initWithObject:o];
	return returnMe;
}
+ (id) createWithZWRObject:(id)o	{
	ObjectHolder		*returnMe = [[ObjectHolder alloc] initWithZWRObject:o];
	return returnMe;
}
- (id) initWithObject:(id)o	{
	//NSLog(@"%s",__func__);
	if (o == nil)
		goto BAIL;
	if (self = [super init])	{
		deleted = NO;
		self.object = o;
		return self;
	}
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	VVRELEASE(self);
	return self;
}
- (id) initWithZWRObject:(id)o	{
	//NSLog(@"%s",__func__);
	if (o == nil)
		goto BAIL;
	if (self = [super init])	{
		deleted = NO;
		self.object = o;
		return self;
	}
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	VVRELEASE(self);
	return self;
}
- (id) init	{
	if (self = [super init])	{
		deleted = NO;
		self.object = nil;
		return self;
	}
	NSLog(@"\t\terr: %s - BAIL",__func__);
	VVRELEASE(self);
	return self;
}
- (void) dealloc	{
	deleted = YES;
	self.object = nil;
}

- (void) setZWRObject:(id)n	{
	self.object = n;
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
	id		myObj = self.object;
	return [myObj isEqual:[o object]];
}
- (BOOL) isEqualTo:(id)o	{
	id		myObj = self.object;
	return [myObj isEqualTo:[o object]];
}


- (NSMethodSignature *) methodSignatureForSelector:(SEL)s	{
	//NSLog(@"%s ... %s",__func__,s);
	//	if i've been deleted, return nil
	if ((deleted) || (self.object==nil))
		return nil;
	//	try to find the actual method signature for me
	NSMethodSignature	*returnMe = [super methodSignatureForSelector:s];
	if (returnMe != nil)	{
		//NSLog(@"\tactually found the selector!");
		return returnMe;
	}
	//	if i don't have an object, return nil
	id		myObj = self.object;
	if (myObj == nil)
		return nil;
	returnMe = [myObj methodSignatureForSelector:s];
	return returnMe;
}

- (void) forwardInvocation:(NSInvocation *)anInvocation	{
	//NSLog(@"%s ... %@",__func__,anInvocation);
	if (deleted)
		return;
	id		myObj = self.object;
	if (myObj != nil)	{
		[anInvocation invokeWithTarget:myObj];
	}
}
- (NSString *)description	{	
	id		myObj = self.object;
	if (myObj != nil)
		return [NSString stringWithFormat:@"ObjectHolder: %p : %@",self,myObj];
	else
		return [NSString stringWithFormat:@"ObjectHolder: %p",self];
	

}

@end

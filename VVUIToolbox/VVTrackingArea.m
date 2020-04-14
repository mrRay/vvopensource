#import "VVTrackingArea.h"




#define LOCK os_unfair_lock_lock
#define UNLOCK os_unfair_lock_unlock




@implementation VVTrackingArea


- (instancetype) initWithRect:(VVRECT)r options:(NSTrackingAreaOptions)opt owner:(id)own userInfo:(NSDictionary *)ui	{
	if (self = [super init])	{
		attribLock = OS_UNFAIR_LOCK_INIT;
		rect = r;
		options = opt;
		owner = own;
		userInfo = ui;
		appleTrackingArea = nil;
		return self;
	}
	VVRELEASE(self);
	return self;
}
- (void) dealloc	{
	LOCK(&attribLock);
	owner = nil;
	VVRELEASE(userInfo);
	VVRELEASE(appleTrackingArea);
	UNLOCK(&attribLock);
}


- (void) setRect:(VVRECT)n	{
	LOCK(&attribLock);
	rect = n;
	UNLOCK(&attribLock);
}
- (VVRECT) rect	{
	VVRECT			returnMe = VVZERORECT;
	LOCK(&attribLock);
	returnMe = rect;
	UNLOCK(&attribLock);
	return returnMe;
}
- (NSTrackingAreaOptions) options	{
	NSTrackingAreaOptions		returnMe = 0;
	LOCK(&attribLock);
	returnMe = options;
	UNLOCK(&attribLock);
	return returnMe;
}
- (id) owner	{
	id				returnMe = nil;
	LOCK(&attribLock);
	returnMe = owner;
	UNLOCK(&attribLock);
	return returnMe;
}
- (NSDictionary *) userInfo	{
	NSDictionary		*returnMe = nil;
	LOCK(&attribLock);
	returnMe = (userInfo==nil) ? nil : userInfo;
	UNLOCK(&attribLock);
	return returnMe;
}


- (void) updateAppleTrackingAreaWithContainerView:(NSView *)v containerViewRect:(VVRECT)r	{
	//NSLog(@"%s ... %@",__func__,v);
	//VVRectLog(@"\t\tcontainerViewRect is",r);
	if (v==nil)
		return;
	
	LOCK(&attribLock);
	NSTrackingArea		*old = appleTrackingArea;
	appleTrackingArea = [[NSTrackingArea alloc]
		initWithRect:r
		options:options
		owner:owner
		userInfo:userInfo];
	if (old != nil)	{
		[v removeTrackingArea:old];
		VVRELEASE(old);
	}
	[v addTrackingArea:appleTrackingArea];
	UNLOCK(&attribLock);
}
- (void) removeAppleTrackingAreaFromContainerView:(NSView *)v	{
	//NSLog(@"%s ... %@",__func__,v);
	if (v==nil)
		return;
	LOCK(&attribLock);
	if (appleTrackingArea != nil)	{
		[v removeTrackingArea:appleTrackingArea];
		VVRELEASE(appleTrackingArea);
	}
	UNLOCK(&attribLock);
}

/*
- (void) setAppleTrackingArea:(NSTrackingArea *)n	{
	LOCK(&attribLock);
	VVRELEASE(appleTrackingArea);
	appleTrackingArea = (n==nil) ? nil : [n retain];
	UNLOCK(&attribLock);
}
- (NSTrackingArea *) appleTrackingArea	{
	NSTrackingArea		*returnMe = nil;
	LOCK(&attribLock);
	returnMe = (appleTrackingArea==nil) ? nil : [appleTrackingArea retain];
	UNLOCK(&attribLock);
	return (returnMe==nil) ? nil : [returnMe autorelease];
}
*/

@end

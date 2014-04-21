#import "VVTrackingArea.h"




@implementation VVTrackingArea


- (id) initWithRect:(VVRECT)r options:(NSTrackingAreaOptions)opt owner:(id)own userInfo:(NSDictionary *)ui	{
	if (self = [super init])	{
		attribLock = OS_SPINLOCK_INIT;
		rect = r;
		options = opt;
		owner = own;
		userInfo = (ui==nil) ? nil : [ui retain];
		appleTrackingArea = nil;
		return self;
	}
	[self release];
	return nil;
}
- (void) dealloc	{
	OSSpinLockLock(&attribLock);
	owner = nil;
	VVRELEASE(userInfo);
	VVRELEASE(appleTrackingArea);
	OSSpinLockUnlock(&attribLock);
	[super dealloc];
}


- (void) setRect:(VVRECT)n	{
	OSSpinLockLock(&attribLock);
	rect = n;
	OSSpinLockUnlock(&attribLock);
}
- (VVRECT) rect	{
	VVRECT			returnMe = VVZERORECT;
	OSSpinLockLock(&attribLock);
	returnMe = rect;
	OSSpinLockUnlock(&attribLock);
	return returnMe;
}
- (NSTrackingAreaOptions) options	{
	NSTrackingAreaOptions		returnMe = 0;
	OSSpinLockLock(&attribLock);
	returnMe = options;
	OSSpinLockUnlock(&attribLock);
	return returnMe;
}
- (id) owner	{
	id				returnMe = nil;
	OSSpinLockLock(&attribLock);
	returnMe = owner;
	OSSpinLockUnlock(&attribLock);
	return returnMe;
}
- (NSDictionary *) userInfo	{
	NSDictionary		*returnMe = nil;
	OSSpinLockLock(&attribLock);
	returnMe = (userInfo==nil) ? nil : [userInfo retain];
	OSSpinLockUnlock(&attribLock);
	return (returnMe==nil) ? nil : [returnMe autorelease];
}


- (void) updateAppleTrackingAreaWithContainerView:(NSView *)v containerViewRect:(VVRECT)r	{
	//NSLog(@"%s ... %@",__func__,v);
	//VVRectLog(@"\t\tcontainerViewRect is",r);
	if (v==nil)
		return;
	
	OSSpinLockLock(&attribLock);
	NSTrackingArea		*old = appleTrackingArea;
	appleTrackingArea = [[NSTrackingArea alloc]
		initWithRect:r
		options:options
		owner:owner
		userInfo:userInfo];
	if (old != nil)	{
		[v removeTrackingArea:old];
		[old release];
		old = nil;
	}
	[v addTrackingArea:appleTrackingArea];
	OSSpinLockUnlock(&attribLock);
}
- (void) removeAppleTrackingAreaFromContainerView:(NSView *)v	{
	//NSLog(@"%s ... %@",__func__,v);
	if (v==nil)
		return;
	OSSpinLockLock(&attribLock);
	if (appleTrackingArea != nil)	{
		[v removeTrackingArea:appleTrackingArea];
		[appleTrackingArea release];
		appleTrackingArea = nil;
	}
	OSSpinLockUnlock(&attribLock);
}

/*
- (void) setAppleTrackingArea:(NSTrackingArea *)n	{
	OSSpinLockLock(&attribLock);
	VVRELEASE(appleTrackingArea);
	appleTrackingArea = (n==nil) ? nil : [n retain];
	OSSpinLockUnlock(&attribLock);
}
- (NSTrackingArea *) appleTrackingArea	{
	NSTrackingArea		*returnMe = nil;
	OSSpinLockLock(&attribLock);
	returnMe = (appleTrackingArea==nil) ? nil : [appleTrackingArea retain];
	OSSpinLockUnlock(&attribLock);
	return (returnMe==nil) ? nil : [returnMe autorelease];
}
*/

@end

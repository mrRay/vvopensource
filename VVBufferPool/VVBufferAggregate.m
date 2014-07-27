#import "VVBufferAggregate.h"




@implementation VVBufferAggregate


/*
- (NSString *) description	{
	OSSpinLockLock(&planeLock);
	NSString		*returnMe = [NSString stringWithFormat:@"<VVBufferAggregate %p: %@, %@, %@, %@>",self,planes[0],planes[1],planes[2],planes[3]];
	//NSString		*returnMe = [NSString stringWithFormat:@"<VVBufferAggregate %@, %@, %@, %@>",nil,nil,nil,nil];
	OSSpinLockUnlock(&planeLock);
	return returnMe;
}
*/
- (id) init	{
	return [self initWithBuffers:nil:nil:nil:nil];
}
- (id) initWithBuffer:(VVBuffer *)r	{
	return [self initWithBuffers:r:nil:nil:nil];
}
- (id) initWithBuffers:(VVBuffer *)r :(VVBuffer *)g	{
	return [self initWithBuffers:r:g:nil:nil];
}
- (id) initWithBuffers:(VVBuffer *)r :(VVBuffer *)g :(VVBuffer *)b	{
	return [self initWithBuffers:r:g:b:nil];
}
- (id) initWithBuffers:(VVBuffer *)r :(VVBuffer *)g :(VVBuffer *)b :(VVBuffer *)a	{
	if (self = [super init])	{
		[self generalInit];
		if (r != nil)
			planes[0] = [r retain];
		if (g != nil)
			planes[1] = [g retain];
		if (b != nil)
			planes[2] = [b retain];
		if (a != nil)
			planes[3] = [a retain];
		return self;
	}
	[self release];
	return nil;
}
- (void) generalInit	{
	planeLock = OS_SPINLOCK_INIT;
	for (int i=0; i<4; ++i)
		planes[i] = nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	OSSpinLockLock(&planeLock);
	if (planes[0] != nil)	{
		[planes[0] release];
		planes[0] = nil;
	}
	if (planes[1] != nil)	{
		[planes[1] release];
		planes[1] = nil;
	}
	if (planes[2] != nil)	{
		[planes[2] release];
		planes[2] = nil;
	}
	if (planes[3] != nil)	{
		[planes[3] release];
		planes[3] = nil;
	}
	OSSpinLockUnlock(&planeLock);
	[super dealloc];
}


- (VVBuffer *) copyR	{
	return [self copyBufferAtIndex:0];
}
- (VVBuffer *) copyG	{
	return [self copyBufferAtIndex:1];
}
- (VVBuffer *) copyB	{
	return [self copyBufferAtIndex:2];
}
- (VVBuffer *) copyA	{
	return [self copyBufferAtIndex:3];
}
- (VVBuffer *) copyBufferAtIndex:(int)i	{
	//NSLog(@"%s ... %@, %d",__func__,[self description],i);
	if (i<0 || i>=4)	{
		NSLog(@"\t\tERR: out of bounds, %s",__func__);
		return nil;
	}
	VVBuffer		*returnMe = nil;
	OSSpinLockLock(&planeLock);
	returnMe = planes[i];
	if (returnMe != nil)
		[returnMe retain];
	OSSpinLockUnlock(&planeLock);
	return returnMe;
}
- (void) insertBuffer:(VVBuffer *)n atIndex:(int)i	{
	//NSLog(@"%s ... %@, %d",__func__,n,i);
	//NSLog(@"\t\tbefore, was %@",[self description]);
	if (i<0 || i>=4)	{
		NSLog(@"\t\tERR: bailing, passed buffer was nil, %s",__func__);
		return;
	}
	if (n != nil)
		[n retain];
	OSSpinLockLock(&planeLock);
	if (planes[i]!=nil)
		[planes[i] release];
	planes[i] = n;
	OSSpinLockUnlock(&planeLock);
	//NSLog(@"\t\tafter, was %@",[self description]);
}


@end

#import "VVBufferAggregate.h"




@implementation VVBufferAggregate


/*
- (NSString *) description	{
	VVLockLock(&planeLock);
	NSString		*returnMe = [NSString stringWithFormat:@"<VVBufferAggregate %p: %@, %@, %@, %@>",self,planes[0],planes[1],planes[2],planes[3]];
	//NSString		*returnMe = [NSString stringWithFormat:@"<VVBufferAggregate %@, %@, %@, %@>",nil,nil,nil,nil];
	VVLockUnlock(&planeLock);
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
			planes[0] = r;
		if (g != nil)
			planes[1] = g;
		if (b != nil)
			planes[2] = b;
		if (a != nil)
			planes[3] = a;
		return self;
	}
	VVRELEASE(self);
	return self;
}
- (void) generalInit	{
	planeLock = VV_LOCK_INIT;
	for (int i=0; i<4; ++i)
		planes[i] = nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	VVLockLock(&planeLock);
	if (planes[0] != nil)	{
		planes[0] = nil;
	}
	if (planes[1] != nil)	{
		planes[1] = nil;
	}
	if (planes[2] != nil)	{
		planes[2] = nil;
	}
	if (planes[3] != nil)	{
		planes[3] = nil;
	}
	VVLockUnlock(&planeLock);
	
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
	VVLockLock(&planeLock);
	returnMe = planes[i];
	VVLockUnlock(&planeLock);
	return returnMe;
}
- (void) insertBuffer:(VVBuffer *)n atIndex:(int)i	{
	//NSLog(@"%s ... %@, %d",__func__,n,i);
	//NSLog(@"\t\tbefore, was %@",[self description]);
	if (i<0 || i>=4)	{
		NSLog(@"\t\tERR: bailing, passed buffer was nil, %s",__func__);
		return;
	}
	VVLockLock(&planeLock);
	if (planes[i]!=nil)
		planes[i] = nil;
	planes[i] = n;
	VVLockUnlock(&planeLock);
	//NSLog(@"\t\tafter, was %@",[self description]);
}


@end

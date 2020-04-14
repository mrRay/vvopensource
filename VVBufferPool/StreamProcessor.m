#import "StreamProcessor.h"




@implementation StreamProcessor


- (id) init	{
	if (self = [super init])	{
		deleted = NO;
		objNext = nil;
		objLock = OS_UNFAIR_LOCK_INIT;
		objArray = [[MutLockArray alloc] init];
		objMaxCount = 2;
		return self;
	}
	VVRELEASE(self);
	return self;
}
- (void) prepareToBeDeleted	{
	
	deleted = YES;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	os_unfair_lock_lock(&objLock);
	VVRELEASE(objNext);
	os_unfair_lock_unlock(&objLock);
	VVRELEASE(objArray);
	
}


- (void) setNextObjForStream:(id)n	{
	if (deleted || n==nil)
		return;
	NSMutableDictionary		*tmpDict = MUTDICT;
	[tmpDict setObject:n forKey:@"passed"];
	os_unfair_lock_lock(&objLock);
		VVRELEASE(objNext);
		objNext = tmpDict;
	os_unfair_lock_unlock(&objLock);
}
- (id) copyAndPullObjThroughStream	{
	if (deleted)
		return nil;
	NSMutableDictionary		*returnDict = nil;
	id						returnMe = nil;
	
	//	if there's an 'objNext', i'm going to be adding it to the array no matter what, so get that out of the spinlock now
	NSMutableDictionary		*theNextDict = nil;
	os_unfair_lock_lock(&objLock);
		theNextDict = objNext;
		objNext = nil;
	os_unfair_lock_unlock(&objLock);
	
	
	[objArray wrlock];
	NSUInteger			prePullCount = [objArray count];
	//	if there's a new dict, add it to the array (don't forget to release it so it doesn't leak!) and start processing it
	if (theNextDict != nil)	{
		[objArray addObject:theNextDict];
		//	this is the method where you start doing whatever it is you want to the object we're adding to the stream
		[self startProcessingThisDict:theNextDict];
	}
	//	if there are too many items in the array, pull one out of the top & finish processing it!
	if ([objArray count]>=objMaxCount || prePullCount>0)	{
		returnDict = [objArray objectAtIndex:0];
		if (returnDict != nil)	{
			//	this is the method where you finish doing whatever it is you want to the object we're pulling out of the end of the stream
			returnMe = [self copyAndFinishProcessingThisDict:returnDict];
			[returnDict removeAllObjects];
			[objArray removeObjectAtIndex:0];
		}
	}
	[objArray unlock];
	
	return returnMe;
}


- (void) clearStream	{
	if (deleted)
		return;
	os_unfair_lock_lock(&objLock);
	VVRELEASE(objNext);
	os_unfair_lock_unlock(&objLock);
	[objArray lockRemoveAllObjects];
}
- (NSUInteger) streamCount	{
	NSUInteger		returnMe = 0;
	os_unfair_lock_lock(&objLock);
	returnMe = [objArray count];
	if (returnMe==0 && objNext!=nil)
		++returnMe;
	os_unfair_lock_unlock(&objLock);
	return returnMe;
}


- (int) objMaxCount	{
	return objMaxCount;
}
- (void) setObjMaxCount:(int)n	{
	[objArray wrlock];
	objMaxCount = n;
	[objArray unlock];
}


//	this is the method where you start doing whatever it is you want to the object we're adding to the stream
- (void) startProcessingThisDict:(NSMutableDictionary *)d	{
	NSLog(@"ERR: %s - subclass should override this!",__func__);
}
//	this is the method where you finish doing whatever it is you want to the object we're pulling out of the end of the stream
- (id) copyAndFinishProcessingThisDict:(NSMutableDictionary *)d	{
	NSLog(@"ERR: %s - subclass should override this!",__func__);
	return nil;
}


@end

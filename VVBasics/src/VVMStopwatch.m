#import "VVMStopwatch.h"
#import "VVBasicMacros.h"




#define LOCK os_unfair_lock_lock
#define UNLOCK os_unfair_lock_unlock




@implementation VVMStopwatch


+ (id) create	{
	VVMStopwatch		*returnMe = [[VVMStopwatch alloc] init];
	return returnMe;
}
- (id) init	{
	self = [super init];
	if (self != nil)	{
		timeLock = OS_UNFAIR_LOCK_INIT;
		paused = NO;
		prePauseTimeSinceStart = 0.;
		[self start];
	}
	return self;
}

- (void) start	{
	LOCK(&timeLock);
	startTime = mach_absolute_time();
	paused = NO;
	prePauseTimeSinceStart = 0.;
	UNLOCK(&timeLock);
}
- (void) pause	{
	LOCK(&timeLock);
	if (!paused)	{
		prePauseTimeSinceStart = SWatchTimeSinceAbsTimeUnit(startTime);
		paused = YES;
	}
	UNLOCK(&timeLock);
}
- (BOOL) paused	{
	BOOL		returnMe = NO;
	LOCK(&timeLock);
	returnMe = paused;
	UNLOCK(&timeLock);
	return returnMe;
}
- (void) resume	{
	LOCK(&timeLock);
	uint64_t			nowTime = mach_absolute_time();
	startTime = nowTime - SWatchAbsTimeUnitForTime(prePauseTimeSinceStart);
	paused = NO;
	UNLOCK(&timeLock);
}
- (BOOL) running	{
	BOOL		returnMe = NO;
	LOCK(&timeLock);
	returnMe = !paused;
	UNLOCK(&timeLock);
	return returnMe;
}
- (uint64_t) startTime	{
	LOCK(&timeLock);
	uint64_t		returnMe = startTime;
	UNLOCK(&timeLock);
	return returnMe;
}


- (double) timeSinceStart	{
	double				returnMe = 0.;
	LOCK(&timeLock);
	if (paused)	{
		returnMe = prePauseTimeSinceStart;
	}
	else	{
		returnMe = SWatchTimeSinceAbsTimeUnit(startTime);
	}
	UNLOCK(&timeLock);
	return returnMe;
}
- (void) getFullTimeSinceStart:(uint64_t *)dst	{
	if (dst == NULL)
		return;
	uint64_t		stopTime = mach_absolute_time();
	LOCK(&timeLock);
	*dst = (stopTime - startTime);
	UNLOCK(&timeLock);
}
- (void) startInTimeInterval:(NSTimeInterval)t	{
	uint64_t		nowTime = mach_absolute_time();
	LOCK(&timeLock);
	uint64_t		tVal = SWatchAbsTimeUnitForTime(t);
	startTime = nowTime + tVal;
	paused = NO;
	UNLOCK(&timeLock);
}
- (void) copyStartTimeToTimeval:(uint64_t *)dst	{
	if (dst == NULL)
		return;
	LOCK(&timeLock);
	*dst = startTime;
	UNLOCK(&timeLock);
}
- (void) setStartTimeval:(uint64_t *)src	{
	if (src == NULL)
		return;
	LOCK(&timeLock);
	startTime = *src;
	UNLOCK(&timeLock);
}



@end





uint64_t SWatchAbsTimeUnitForTime(double inTime)	{
	mach_timebase_info_data_t		info;
	mach_timebase_info(&info);
	
	uint64_t			nanos = (uint64_t)(inTime * NSEC_PER_SEC);
	uint64_t			elapsed = nanos * info.denom / info.numer;
	return elapsed;
}
double SWatchTimeSinceAbsTimeUnit(uint64_t inStartTime)	{
	uint64_t		stopTime = mach_absolute_time();
	mach_timebase_info_data_t		info;
	mach_timebase_info(&info);
	uint64_t		elapsed = stopTime - inStartTime;
	uint64_t		nanos = elapsed * info.numer / info.denom;
	return (double)nanos/NSEC_PER_SEC;
}
double SWatchTimeForAbsTimeUnit(uint64_t inTime)	{
	mach_timebase_info_data_t		info;
	mach_timebase_info(&info);
	uint64_t		nanos = inTime * info.numer / info.denom;
	return (double)nanos/NSEC_PER_SEC;
}


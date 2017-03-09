#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <mach/mach_time.h>
#import <libkern/OSAtomic.h>


///	This class is used to measure how long it takes to do things; much easier to work with than NSDate.  Monotonic, uses mach_absolute_time().
/**
\ingroup VVBasics
*/
@interface VVMStopwatch : NSObject	{
	uint64_t			startTime;
	OSSpinLock			timeLock;
	BOOL				paused;
	double				prePauseTimeSinceStart;
}

///	Returns an auto-released instance of VVStopwatch; the stopwatch is started on creation.
+ (id) create;

///	Starts the stopwatch over again
- (void) start;
///	Returns a float representing the time (in seconds) since the stopwatch was started
- (double) timeSinceStart;
///	Populates the passed pointer with the full time vals since start (mach absolute time units)
- (void) getFullTimeSinceStart:(uint64_t *)dst;
///	Sets the stopwatch's starting time as an offset to the current time
- (void) startInTimeInterval:(NSTimeInterval)t;
///	Populates the value behind the passed pointer with the start time (mach absolute time units)
- (void) copyStartTimeToTimeval:(uint64_t *)dst;
///	Populates the starting time with the value behind the passed ptr (mach absolute time units)
- (void) setStartTimeval:(uint64_t *)src;

- (void) pause;
- (BOOL) paused;
- (void) resume;
- (BOOL) running;
- (uint64_t) startTime;

@end


#if defined __cplusplus
extern "C" {
#endif

uint64_t SWatchAbsTimeUnitForTime(double inTime);
double SWatchTimeSinceAbsTimeUnit(uint64_t inStartTime);
double SWatchTimeForAbsTimeUnit(uint64_t inTime);

#if defined __cplusplus
};
#endif



#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#include <sys/time.h>
#import <libkern/OSAtomic.h>



///	This class is used to measure how long it takes to do things; much easier to work with than NSDate.
/**
\ingroup VVBasics
*/
@interface VVStopwatch : NSObject {
	struct timeval		startTime;
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
///	Populates the passed timeval struct with the full time vals since start (usec-level accuracy, no rounding)
- (void) getFullTimeSinceStart:(struct timeval *)dst;
///	Sets the stopwatch's starting time as an offset to the current time
- (void) startInTimeInterval:(NSTimeInterval)t;
///	Populates the passed timeval struct with the current timeval
- (void) copyStartTimeToTimevalStruct:(struct timeval *)dst;
///	Populates the starting time with the passed timeval struct
- (void) setStartTimeStruct:(struct timeval *)src;

- (void) pause;
- (BOOL) paused;
- (void) resume;
- (BOOL) running;

@end

void populateTimevalWithFloat(struct timeval *tval, double secVal);

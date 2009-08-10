
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#include <sys/time.h>



///	This class is used to measure how long it takes to do things; much easier to work with than NSDate.

@interface VVStopwatch : NSObject {
	struct timeval		startTime;
}

///	Returns an auto-released instance of VVStopwatch; the stopwatch is started on creation.
+ (id) create;

///	Starts the stopwatch over again
- (void) start;
///	Returns a float representing the time (in seconds) since the stopwatch was started
- (float) timeSinceStart;

@end

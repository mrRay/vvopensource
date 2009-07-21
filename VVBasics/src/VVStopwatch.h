
#import <Cocoa/Cocoa.h>
#include <sys/time.h>




/*
	times stuff.  really simple.  dead useful.
*/




@interface VVStopwatch : NSObject {
	struct timeval		startTime;
}

+ (id) create;

- (void) start;
- (float) timeSinceStart;

@end

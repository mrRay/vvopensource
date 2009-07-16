
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#include <sys/time.h>




@interface VVStopwatch : NSObject {
	struct timeval		startTime;
}

+ (id) create;

- (void) start;
- (float) timeSinceStart;

@end

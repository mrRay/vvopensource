
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#include <sys/time.h>




@interface VVThreadLoop : NSObject {
	float				interval;
	BOOL				running;
	BOOL				bail;
	
	id					targetObj;	//	NOT retained!
	SEL					targetSel;
}

- (id) initWithTimeInterval:(float)i target:(id)t selector:(SEL)s;
- (id) initWithTimeInterval:(float)i;
- (void) generalInit;
- (void) start;
- (void) threadCallback;
- (void) threadProc;
- (void) stop;
- (void) stopAndWaitUntilDone;
- (void) setInterval:(float)i;
- (BOOL) running;

@end

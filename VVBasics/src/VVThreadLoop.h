
#import <Cocoa/Cocoa.h>
#include <sys/time.h>




/*
	when started, an instance of this class will spawn a thread and repeatedly 
	execute a method on that thread.  if i was passed a target and selector on 
	creation, the selector will be called on the target every time the thread 
	executes.  if it's more convenient to subclass VVThreadLoop and work with 
	your custom subclass, leave the target/selector nil and VVThreadLoop will 
	call "threadProc" on itself- just override this method (it's empty anyway) 
	in your subclass and do whatever you want in there.
	
	you can change the execution interval, and VVThreadLoop also examines how 
	long it takes to execute your code and adjusts in an attempt to ensure that 
	the interval is accurate.
*/



//	this macro sets the max time interval; default is 1 second (can't go slower than 1 proc/sec)
#define MAXTIME 1.0



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

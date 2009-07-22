
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#include <sys/time.h>




//	this macro sets the max time interval; default is 1 second (can't go slower than 1 proc/sec)
#define MAXTIME 1.0



///	Simple class for spawning a thread which executes at a specified interval- simpler and easier to work with than NSThread/NSTimer in multi-threaded programming environments.
/*!
When started, an instance of this class will spawn a thread and repeatedly execute a method on that thread.  If it was passed a target and selector on creation, the selector will be called on the target every time the thread executes.  If it's more convenient to subclass VVThreadLoop and work with your custom subclass, leave the target/selector nil and VVThreadLoop will call "threadProc" on itself- just override this method (it's empty anyway) in your subclass and do whatever you want in there.

You can change the execution interval, and VVThreadLoop also examines how long it takes to execute your code and adjusts in an attempt to ensure that the interval is accurate (sleep-time is interval-duration minus proc-execution-duration)
*/



@interface VVThreadLoop : NSObject {
	float				interval;
	BOOL				running;
	BOOL				bail;
	
	id					targetObj;	//!<NOT retained!  If there's no valid target obj/sel pair, the instance sill simply call "threadProc" on itself, so you can just override that method
	SEL					targetSel;
}

///	Returns an initialized VVThreadLoop which will call method "s" on target "t" every time it executes.  Returns nil if passed a nil target or selector, or if the target doesn't respond to the selector.
- (id) initWithTimeInterval:(float)i target:(id)t selector:(SEL)s;
///	Returns an initialized VVThreadLoop which will call "threadProc" on itself every time it executes, so you should override "threadProc" in your subclass.
- (id) initWithTimeInterval:(float)i;
- (void) generalInit;
///	Spawns a thread and starts executing.  If the thread has already been spawned and is executing, doesn't do anything.
- (void) start;
- (void) threadCallback;
- (void) threadProc;
///	Stops execution by setting a "bail" flag, and returns immediately.  IMPORTANT: may return while the thread loop is still executing!
- (void) stop;
///	Stops execution and doesn't return until the thread's done executing and has been closed.
- (void) stopAndWaitUntilDone;
///	The interval between executions, in seconds.
- (float) interval;
///	Set the interval between executions, in seconds.
- (void) setInterval:(float)i;
///	Whether or not the thread loop is running.
- (BOOL) running;

@end

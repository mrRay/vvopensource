
#import "VVThreadLoop.h"
#import "VVAssertionHandler.h"
#import "VVBasicMacros.h"




@implementation VVThreadLoop


- (id) initWithTimeInterval:(double)i target:(id)t selector:(SEL)s	{
	self = [super init];
	if (self != nil)	{
		[self generalInit];
		[self setInterval:i];
		targetObj = t;
		targetSel = s;
		if ((t==nil) || (s==nil) || (![t respondsToSelector:s]))	{
			VVRELEASE(self);
		}
	}
	return self;
}
- (id) initWithTimeInterval:(double)i	{
	self = [super init];
	if (self != nil)	{
		[self generalInit];
		[self setInterval:i];
	}
	return self;
}
- (void) generalInit	{
	interval = 0.1;
	maxInterval = 1.0;
	running = NO;
	bail = NO;
	paused = NO;
	executingCallback = NO;
	thread = nil;
	rlTimer = nil;
	runLoop = nil;
	
	valLock = VV_LOCK_INIT;
	
	targetObj = nil;
	targetSel = nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	[self stopAndWaitUntilDone];
	targetObj = nil;
	targetSel = nil;
}
- (void) start	{
	//NSLog(@"%s",__func__);
	VVLockLock(&valLock);
	if (running)	{
		VVLockUnlock(&valLock);
		return;
	}
	paused = NO;
	VVLockUnlock(&valLock);
	
	[NSThread
		detachNewThreadSelector:@selector(threadCallback)
		toTarget:self
		withObject:nil];
}
- (void) threadCallback	{
	//NSLog(@"%s",__func__);
	//NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	
	@autoreleasepool	{
	
	USE_CUSTOM_ASSERTION_HANDLER

	if (![NSThread setThreadPriority:1.0])
		NSLog(@"\terror setting thread priority to 1.0");

	BOOL					tmpRunning = YES;
	BOOL					tmpBail = NO;
	VVLockLock(&valLock);
	running = YES;
	bail = NO;
	thread = [NSThread currentThread];
	runLoop = [NSRunLoop currentRunLoop];
	//	add a one-year timer to the run loop, so it will run & pause when i tell the run loop to run
	rlTimer = [NSTimer
		scheduledTimerWithTimeInterval:60.0*60.0*24.0*7.0*52.0
		target:self
		selector:@selector(timerCallback:)
		userInfo:nil
		repeats:NO];
	VVLockUnlock(&valLock);
	
		STARTLOOP:
		@try	{
			while ((tmpRunning) && (!tmpBail))	{
				//NSLog(@"\t\tproc start");
				
				@autoreleasepool	{
				
					struct timeval		startTime;
					struct timeval		stopTime;
					double				executionTime;
					double				sleepDuration;	//	in microseconds!
			
					gettimeofday(&startTime,NULL);
					VVLockLock(&valLock);
					if (!paused)	{
						executingCallback = YES;
						VVLockUnlock(&valLock);
						//@try	{
							//	if there's a target object, ping it (delegate-style)
							if (targetObj != nil)	{
								#pragma clang diagnostic push
								#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
								[targetObj performSelector:targetSel];
								#pragma clang diagnostic pop
							}
							//	else just call threadProc (subclass-style)
							else
								[self threadProc];
						//}
						//@catch (NSException *err)	{
						//	NSLog(@"%s caught exception, %@",__func__,err);
						//}
				
						VVLockLock(&valLock);
						executingCallback = NO;
						VVLockUnlock(&valLock);
					}
					else
						VVLockUnlock(&valLock);
			
					//++runLoopCount;
					//if (runLoopCount > 4)	{
					//{
					//	NSAutoreleasePool		*oldPool = pool;
					//	pool = nil;
					//	[oldPool release];
					//	pool = [[NSAutoreleasePool alloc] init];
					//}
			
					//	figure out how long it took to run the callback
					gettimeofday(&stopTime,NULL);
					while (stopTime.tv_sec > startTime.tv_sec)	{
						--stopTime.tv_sec;
						stopTime.tv_usec = stopTime.tv_usec + 1000000;
					}
					executionTime = ((double)(stopTime.tv_usec-startTime.tv_usec))/1000000.0;
					sleepDuration = fmin(maxInterval,fmax(0.0,interval - executionTime));
			
					//	only sleep if duration's > 0, sleep for a max of 1 sec
					if (sleepDuration > 0.0)	{
						if (sleepDuration > maxInterval)
							sleepDuration = maxInterval;
						CFRunLoopRunInMode(kCFRunLoopDefaultMode, sleepDuration, false);
					}
					else	{
						//NSLog(@"\t\tsleepDuration was 0, about to CFRunLoopRun()...");
						if (interval==0.0)
							CFRunLoopRunInMode(kCFRunLoopDefaultMode, maxInterval, false);
						else
							CFRunLoopRunInMode(kCFRunLoopDefaultMode, interval, false);
					}
			
					VVLockLock(&valLock);
					tmpRunning = running;
					tmpBail = bail;
					VVLockUnlock(&valLock);
				
				}	//	autoreleasepool
				
				//NSLog(@"\t\tproc looping");
				
			}	//	while loop
		}
		@catch (NSException *err)	{
			//NSAutoreleasePool		*oldPool = pool;
			//pool = nil;
			if (targetObj == nil)
				NSLog(@"\t\t%s caught exception %@ on %@",__func__,err,self);
			else
				NSLog(@"\t\t%s caught exception %@ on %@, target is %@",__func__,err,self,[targetObj class]);
			@try {
				//[oldPool release];
			}
			@catch (NSException *subErr)	{
				if (targetObj == nil)
					NSLog(@"\t\t%s caught sub-exception %@ on %@",__func__,subErr,self);
				else
					NSLog(@"\t\t%s caught sub-exception %@ on %@, target is %@",__func__,subErr,self,[targetObj class]);
			}
			//pool = [[NSAutoreleasePool alloc] init];
			goto STARTLOOP;
		}
	
	}
	
	//[pool release];
	VVLockLock(&valLock);
	if (rlTimer != nil)	{
		[rlTimer invalidate];
		rlTimer = nil;
	}
	thread = nil;
	runLoop = nil;
	running = NO;
	VVLockUnlock(&valLock);
	//NSLog(@"\t\t%s - FINSHED",__func__);
}
- (void) threadProc	{
	
}
- (void) timerCallback:(NSTimer *)n	{
	
}
- (void) pause	{
	VVLockLock(&valLock);
	paused = YES;
	VVLockUnlock(&valLock);
}
- (void) resume	{
	VVLockLock(&valLock);
	paused = NO;
	VVLockUnlock(&valLock);
}
- (void) stop	{
	VVLockLock(&valLock);
	if (!running)	{
		VVLockUnlock(&valLock);
		return;
	}
	bail = YES;
	VVLockUnlock(&valLock);
}
- (void) stopAndWaitUntilDone	{
	//NSLog(@"%s",__func__);
	[self stop];
	BOOL			tmpRunning = NO;
	
	VVLockLock(&valLock);
	tmpRunning = running;
	VVLockUnlock(&valLock);
	
	while (tmpRunning)	{
		//NSLog(@"\twaiting");
		//pthread_yield_np();
		usleep(100);
		
		VVLockLock(&valLock);
		tmpRunning = running;
		VVLockUnlock(&valLock);
	}
	
}
- (double) interval	{
	return interval;
}
- (void) setInterval:(double)i	{
	double		absVal = fabs(i);
	interval = (absVal > maxInterval) ? maxInterval : absVal;
}
- (BOOL) running	{
	BOOL		returnMe = NO;
	VVLockLock(&valLock);
	returnMe = running;
	VVLockUnlock(&valLock);
	return returnMe;
}
- (NSThread *) thread	{
	VVLockLock(&valLock);
	NSThread		*returnMe = thread;
	VVLockUnlock(&valLock);
	return returnMe;
}
- (NSRunLoop *) runLoop	{
	VVLockLock(&valLock);
	NSRunLoop		*returnMe = runLoop;
	VVLockUnlock(&valLock);
	return returnMe;
}


@synthesize maxInterval;


@end

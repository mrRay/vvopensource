
#import "VVThreadLoop.h"
#import "VVAssertionHandler.h"




@implementation VVThreadLoop


- (id) initWithTimeInterval:(double)i target:(id)t selector:(SEL)s	{
	if ((t==nil) || (s==nil) || (![t respondsToSelector:s]))
		return nil;
	if (self = [super init])	{
		[self generalInit];
		[self setInterval:i];
		targetObj = t;
		targetSel = s;
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithTimeInterval:(double)i	{
	if (self = [super init])	{
		[self generalInit];
		[self setInterval:i];
		return self;
	}
	[self release];
	return nil;
}
- (void) generalInit	{
	interval = 0.1;
	maxInterval = 1.0;
	running = NO;
	bail = NO;
	paused = NO;
	executingCallback = NO;
	thread = nil;
	runLoop = nil;
	
	valLock = OS_SPINLOCK_INIT;
	
	targetObj = nil;
	targetSel = nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	[self stopAndWaitUntilDone];
	targetObj = nil;
	targetSel = nil;
	[super dealloc];
}
- (void) start	{
	//NSLog(@"%s",__func__);
	OSSpinLockLock(&valLock);
	if (running)	{
		OSSpinLockUnlock(&valLock);
		return;
	}
	paused = NO;
	OSSpinLockUnlock(&valLock);
	
	[NSThread
		detachNewThreadSelector:@selector(threadCallback)
		toTarget:self
		withObject:nil];
}
- (void) threadCallback	{
	//NSLog(@"%s",__func__);
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	
	USE_CUSTOM_ASSERTION_HANDLER
	
	if (![NSThread setThreadPriority:1.0])
		NSLog(@"\terror setting thread priority to 1.0");
	
	BOOL					tmpRunning = YES;
	BOOL					tmpBail = NO;
	OSSpinLockLock(&valLock);
	running = YES;
	bail = NO;
	thread = [NSThread currentThread];
	runLoop = [NSRunLoop currentRunLoop];
	//	add a one-year timer to the run loop, so it will run & pause when i tell the run loop to run
	[NSTimer
		scheduledTimerWithTimeInterval:60.0*60.0*24.0*7.0*52.0
		target:nil
		selector:nil
		userInfo:nil
		repeats:NO];
	OSSpinLockUnlock(&valLock);
	
	STARTLOOP:
	@try	{
		while ((tmpRunning) && (!tmpBail))	{
			//NSLog(@"\t\tproc start");
			struct timeval		startTime;
			struct timeval		stopTime;
			double				executionTime;
			double				sleepDuration;	//	in microseconds!
			
			gettimeofday(&startTime,NULL);
			OSSpinLockLock(&valLock);
			if (!paused)	{
				executingCallback = YES;
				OSSpinLockUnlock(&valLock);
				//@try	{
					//	if there's a target object, ping it (delegate-style)
					if (targetObj != nil)
						[targetObj performSelector:targetSel];
					//	else just call threadProc (subclass-style)
					else
						[self threadProc];
				//}
				//@catch (NSException *err)	{
				//	NSLog(@"%s caught exception, %@",__func__,err);
				//}
				
				OSSpinLockLock(&valLock);
				executingCallback = NO;
				OSSpinLockUnlock(&valLock);
			}
			else
				OSSpinLockUnlock(&valLock);
			
			//++runLoopCount;
			//if (runLoopCount > 4)	{
			{
				NSAutoreleasePool		*oldPool = pool;
				pool = nil;
				[oldPool release];
				pool = [[NSAutoreleasePool alloc] init];
			//	runLoopCount = 0;
			}
			
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
			
			OSSpinLockLock(&valLock);
			tmpRunning = running;
			tmpBail = bail;
			OSSpinLockUnlock(&valLock);
			//NSLog(@"\t\tproc looping");
		}
	}
	@catch (NSException *err)	{
		NSAutoreleasePool		*oldPool = pool;
		pool = nil;
		if (targetObj == nil)
			NSLog(@"\t\t%s caught exception %@ on %@",__func__,err,self);
		else
			NSLog(@"\t\t%s caught exception %@ on %@, target is %@",__func__,err,self,[targetObj class]);
		@try {
			[oldPool release];
		}
		@catch (NSException *subErr)	{
			if (targetObj == nil)
				NSLog(@"\t\t%s caught sub-exception %@ on %@",__func__,subErr,self);
			else
				NSLog(@"\t\t%s caught sub-exception %@ on %@, target is %@",__func__,subErr,self,[targetObj class]);
		}
		pool = [[NSAutoreleasePool alloc] init];
		goto STARTLOOP;
	}
	
	[pool release];
	OSSpinLockLock(&valLock);
	thread = nil;
	runLoop = nil;
	running = NO;
	OSSpinLockUnlock(&valLock);
	//NSLog(@"\t\t%s - FINSHED",__func__);
}
- (void) threadProc	{
	
}
- (void) pause	{
	OSSpinLockLock(&valLock);
	paused = YES;
	OSSpinLockUnlock(&valLock);
}
- (void) resume	{
	OSSpinLockLock(&valLock);
	paused = NO;
	OSSpinLockUnlock(&valLock);
}
- (void) stop	{
	OSSpinLockLock(&valLock);
	if (!running)	{
		OSSpinLockUnlock(&valLock);
		return;
	}
	bail = YES;
	OSSpinLockUnlock(&valLock);
}
- (void) stopAndWaitUntilDone	{
	//NSLog(@"%s",__func__);
	[self stop];
	BOOL			tmpRunning = NO;
	
	OSSpinLockLock(&valLock);
	tmpRunning = running;
	OSSpinLockUnlock(&valLock);
	
	while (tmpRunning)	{
		//NSLog(@"\twaiting");
		//pthread_yield_np();
		usleep(100);
		
		OSSpinLockLock(&valLock);
		tmpRunning = running;
		OSSpinLockUnlock(&valLock);
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
	OSSpinLockLock(&valLock);
	returnMe = running;
	OSSpinLockUnlock(&valLock);
	return returnMe;
}
- (NSThread *) thread	{
	OSSpinLockLock(&valLock);
	NSThread		*returnMe = thread;
	OSSpinLockUnlock(&valLock);
	return returnMe;
}
- (NSRunLoop *) runLoop	{
	OSSpinLockLock(&valLock);
	NSRunLoop		*returnMe = runLoop;
	OSSpinLockUnlock(&valLock);
	return returnMe;
}


@synthesize maxInterval;


@end

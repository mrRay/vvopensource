
#import "VVThreadLoop.h"




@implementation VVThreadLoop


- (id) initWithTimeInterval:(float)i target:(id)t selector:(SEL)s	{
	if ((t==nil) || (s==nil) || (![t respondsToSelector:s]))
		return nil;
	if (self = [super init])	{
		[self generalInit];
		interval = i;
		targetObj = t;
		targetSel = s;
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithTimeInterval:(float)i	{
	if (self = [super init])	{
		[self generalInit];
		interval = i;
		return self;
	}
	[self release];
	return nil;
}
- (void) generalInit	{
	interval = 0.1;
	running = NO;
	bail = NO;
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
	if (running)
		return;
	[NSThread
		detachNewThreadSelector:@selector(threadCallback)
		toTarget:self
		withObject:nil];
}
- (void) threadCallback	{
	//NSLog(@"%s",__func__);
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	int						runLoopCount = 0;
	
	running = YES;
	bail = NO;
	if (![NSThread setThreadPriority:1.0])
		NSLog(@"\terror setting thread priority to 1.0");
	
	while ((running) && (!bail))	{
		//NSLog(@"\t\tproc start");
		struct timeval		startTime;
		struct timeval		stopTime;
		float				executionTime;
		float				sleepDuration;	//	in microseconds!
		
		gettimeofday(&startTime,NULL);
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
		
		++runLoopCount;
		if (runLoopCount > 4)	{
			[pool release];
			pool = [[NSAutoreleasePool alloc] init];
			runLoopCount = 0;
		}
		
		//	figure out how long it took to run the callback
		gettimeofday(&stopTime,NULL);
		while (stopTime.tv_sec > startTime.tv_sec)	{
			--stopTime.tv_sec;
			stopTime.tv_usec = stopTime.tv_usec + 1000000;
		}
		executionTime = ((float)(stopTime.tv_usec-startTime.tv_usec))/1000000.0;
		sleepDuration = interval - executionTime;
		
		//	only sleep if duration's > 0, sleep for a max of 1 sec
		if (sleepDuration > 0)	{
			if (sleepDuration > MAXTIME)
				sleepDuration = MAXTIME;
			[NSThread sleepForTimeInterval:sleepDuration];
		}
		//NSLog(@"\t\tproc looping");
	}
	
	[pool release];
	running = NO;
	//NSLog(@"\t\t%s - FINSHED",__func__);
}
- (void) threadProc	{
	
}
- (void) stop	{
	if (!running)
		return;
	bail = YES;
}
- (void) stopAndWaitUntilDone	{
	//NSLog(@"%s",__func__);
	[self stop];
	while (running)	{
		NSLog(@"\twaiting");
		//pthread_yield_np();
	}
}
- (float) interval	{
	return interval;
}
- (void) setInterval:(float)i	{
	interval = (i > MAXTIME) ? MAXTIME : i;
}
- (BOOL) running	{
	return running;
}


@end

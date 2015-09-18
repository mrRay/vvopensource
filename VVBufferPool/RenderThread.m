#import "RenderThread.h"




@implementation RenderThread


- (void) generalInit	{
	[super generalInit];
	deleteArray = [[MutLockArray alloc] init];
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	[[NSNotificationCenter defaultCenter] postNotificationName:RTDeleteArrayDestroyNotification object:deleteArray];
	VVRELEASE(deleteArray);
	[super dealloc];
}
- (void) threadCallback	{
	//NSLog(@"%s",__func__);
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	
	USE_CUSTOM_ASSERTION_HANDLER
	
	if (![NSThread setThreadPriority:1.0])
		NSLog(@"\terror setting thread priority to 1.0");
	
	//	add the deleteArray to the current thread's thread dictionary so other stuff can find it!
	[[[NSThread currentThread] threadDictionary] setObject:deleteArray forKey:@"deleteArray"];
	//	add a ptr to an object holder pointing to me
	ObjectHolder			*anObj = [ObjectHolder createWithZWRObject:self];
	[[[NSThread currentThread] threadDictionary] setObject:anObj forKey:@"renderThread"];
	
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
				
				//	purge the delete array
				//[deleteArray lockRemoveAllObjects];
				[deleteArray wrlock];
				while ([deleteArray count]>0)
					[deleteArray removeObjectAtIndex:0];
				[deleteArray unlock];
				
				OSSpinLockLock(&valLock);
				executingCallback = NO;
				OSSpinLockUnlock(&valLock);
			}
			else
				OSSpinLockUnlock(&valLock);
			
			//++runLoopCount;
			//if (runLoopCount > 128)	{
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
			//	this makes sure everything's properly freed as long as you stop this thread LAST!
			//[deleteArray lockRemoveAllObjects];
			[deleteArray wrlock];
			while ([deleteArray count]>0)
				[deleteArray removeObjectAtIndex:0];
			[deleteArray unlock];
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
	
	//[QTMovie exitQTKitOnThread];
	
	//	purge the delete array one last time!
	//	this makes sure everything's properly freed as long as you stop this thread LAST!
	//[deleteArray lockRemoveAllObjects];
	[deleteArray wrlock];
	while ([deleteArray count]>0)
		[deleteArray removeObjectAtIndex:0];
	[deleteArray unlock];
	
	[pool release];
	OSSpinLockLock(&valLock);
	thread = nil;
	runLoop = nil;
	running = NO;
	OSSpinLockUnlock(&valLock);
	
	
	//NSLog(@"\t\t%s - %@ - FINSHED",__func__,self);
}


@end


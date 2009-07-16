
#import "VVStopwatch.h"




@implementation VVStopwatch


+ (id) create	{
	VVStopwatch		*returnMe = [[VVStopwatch alloc] init];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) init	{
	//NSLog(@"%s",__func__);
	if (self = [super init])	{
		[self start];
		return self;
	}
	[self release];
	return nil;
}
- (void) start	{
	gettimeofday(&startTime,NULL);
}
- (float) timeSinceStart	{
	float				returnMe = 0.0;
	struct timeval		stopTime;
	//	get the current time of day
	gettimeofday(&stopTime,NULL);
	/*	make sure that the start time's microseconds component is less than
		the stop time's microseconds component so we can subtract evenly		*/
	while (stopTime.tv_usec < startTime.tv_usec)	{
		--stopTime.tv_sec;
		stopTime.tv_usec += 1000000;
	}
	//	get the time difference in seconds
	returnMe = stopTime.tv_sec - startTime.tv_sec;
	//	add the time difference in microseconds
	returnMe += (((float)(stopTime.tv_usec - startTime.tv_usec)) / 1000000.0);
	return returnMe;
}


@end

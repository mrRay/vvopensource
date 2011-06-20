
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
- (void) startInTimeInterval:(NSTimeInterval)t	{
	//NSLog(@"%s ... %f",__func__,t);
	struct timeval		tmpStartTime;
	gettimeofday(&tmpStartTime,NULL);
	struct timeval		intervalStruct;
	populateTimevalWithFloat(&intervalStruct,t);
	if (t < 0.0)	{
		intervalStruct.tv_sec = intervalStruct.tv_sec * -1;
		intervalStruct.tv_usec = intervalStruct.tv_usec * -1;
		timersub(&tmpStartTime,&intervalStruct,&startTime);
	}
	else
		timeradd(&tmpStartTime,&intervalStruct,&startTime);
}


@end

void populateTimevalWithFloat(struct timeval *tval, float secVal)	{
	//NSLog(@"%s ... %f",__func__,secVal);
	if (tval == nil)
		return;
	if (secVal == 0.0)	{
		(*(tval)).tv_sec = 0;
		(*(tval)).tv_usec = 0;
		return;
	}
	(*(tval)).tv_sec = (secVal>0.0) ? ((int)floorf(secVal)) : ((int)ceilf(secVal));
	(*(tval)).tv_usec = ((int)(((float)(secVal - ((float)(*(tval)).tv_sec)))*1000000.0));
	//NSLog(@"\t\ttv_sec = %ld",(*(tval)).tv_sec);
	//NSLog(@"\t\ttv_usec = %ld",(*(tval)).tv_usec);
}

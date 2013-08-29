#import "OSCQueryReply.h"
#import <VVBasics/VVBasics.h>




@implementation OSCQueryReply


- (id) initWithQuery:(OSCMessage *)m timeout:(double)t replyBlock:(void (^)(OSCMessage *replyMsg))b	{
	//NSLog(@"%s",__func__);
	if (m==nil || b==nil)	{
		[self release];
		return nil;
	}
	if (self = [super init])	{
		initialQuery = [m retain];
		replyBlock = Block_copy(b);
		replyDelegateZWR = nil;
		timeoutDate = [[NSDate dateWithTimeIntervalSinceNow:t] retain];
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithQuery:(OSCMessage *)m timeout:(double)t replyDelegate:(id <OSCQueryReplyDelegate>)d	{
	//NSLog(@"%s",__func__);
	if (m==nil || d==nil)	{
		[self release];
		return nil;
	}
	if (self = [super init])	{
		initialQuery = [m retain];
		replyBlock = nil;
		replyDelegateZWR = [[VV_MAZeroingWeakRef alloc] initWithTarget:d];
		timeoutDate = [[NSDate dateWithTimeIntervalSinceNow:t] retain];
		return self;
	}
	[self release];
	return nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	VVRELEASE(initialQuery);
	if (replyBlock != nil)	{
		Block_release(replyBlock);
		replyBlock = nil;
	}
	VVRELEASE(replyDelegateZWR);
	VVRELEASE(timeoutDate);
	[super dealloc];
}


- (void) dispatchReply:(OSCMessage *)r	{
	//NSLog(@"%s ... %@",__func__,r);
	if (r==nil)
		return;
	if (replyBlock != nil)	{
		replyBlock(r);
	}
	else if (replyDelegateZWR != nil)	{
		id <OSCQueryReplyDelegate>		delegateObj = [replyDelegateZWR target];
		if (delegateObj != nil)
			[delegateObj oscQueryReplyReceived:r];
	}
}
//	returns a YES if the timeout was dispatched (and i should be freed/removed from the queue)
- (BOOL) _timeoutCheckAgainstDate:(NSDate *)d	{
	if (d==nil || initialQuery==nil || timeoutDate==nil)
		return YES;
	
	BOOL			returnMe = NO;
	if (timeoutDate == [d earlierDate:timeoutDate])	{
		returnMe = YES;
		//OSCMessage		*timeoutMsg = [OSCMessage createErrorForMessage:initialQuery];
		//[self dispatchReply:timeoutMsg];
	}
	return returnMe;
}


- (OSCMessage *) initialQuery	{
	return initialQuery;
}


@end

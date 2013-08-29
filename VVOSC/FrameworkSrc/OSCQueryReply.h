#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "OSCMessage.h"
#import <VVBasics/MAZeroingWeakRef.h>




@protocol OSCQueryReplyDelegate
//	this method is called either when a reply was received for the query, or after the timeout duration (in which case an error will be passed)
- (void) oscQueryReplyReceived:(OSCMessage *)replyMsg;
@end




@interface OSCQueryReply : NSObject	{
	OSCMessage				*initialQuery;
	void					(^replyBlock)(OSCMessage *replyMsg);
	VV_MAZeroingWeakRef		*replyDelegateZWR;
	NSDate					*timeoutDate;
}

- (id) initWithQuery:(OSCMessage *)m timeout:(double)d replyBlock:(void (^)(OSCMessage *replyMsg))b;
- (id) initWithQuery:(OSCMessage *)m timeout:(double)t replyDelegate:(id <OSCQueryReplyDelegate>)d;

- (void) dispatchReply:(OSCMessage *)r;

//	returns a YES if the timeout was dispatched (and i should be freed/removed from the queue)
- (BOOL) _timeoutCheckAgainstDate:(NSDate *)d;

@property (readonly) OSCMessage *initialQuery;

@end

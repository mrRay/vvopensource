#import <VVBasics/VVBasics.h>
#import "VVBuffer.h"




///	Convenience class i've been using lately to pass around groups of VVBuffers.  this is a relatively new class, we'll see how it goes...
/**
\ingroup VVBufferPool
*/
@interface VVBufferAggregate : NSObject	{
	OSSpinLock		planeLock;
	VVBuffer		*planes[4];
}

///	inits a VVBufferAggregate, retaining the passed buffer in the first plane
- (id) initWithBuffer:(VVBuffer *)r;
///	inits a VVBufferAggregate, retaining the passed buffers in the first two planes
- (id) initWithBuffers:(VVBuffer *)r :(VVBuffer *)g;
///	inits a VVBufferAggregate, retaining the passed buffers in the first three planes
- (id) initWithBuffers:(VVBuffer *)r :(VVBuffer *)g :(VVBuffer *)b;
///	inits a VVBufferAggregate, retaining the passed buffers in each of the four planes
- (id) initWithBuffers:(VVBuffer *)r :(VVBuffer *)g :(VVBuffer *)b :(VVBuffer *)a;
- (void) generalInit;

///	safely returns a retained instance of the buffer in the first plane
- (VVBuffer *) copyR;
///	safely returns a retained instance of the buffer in the second plane
- (VVBuffer *) copyG;
///	safely returns a retained instance of the buffer in the third plane
- (VVBuffer *) copyB;
///	safely returns a retained instance of the buffer in the last plane
- (VVBuffer *) copyA;
///	safely returns a retained instance of the buffer in the plane at the supplied index
- (VVBuffer *) copyBufferAtIndex:(int)i;
///	safely inserts the supplied buffer into the plane at the given index
- (void) insertBuffer:(VVBuffer *)n atIndex:(int)i;

@end

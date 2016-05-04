#import <Cocoa/Cocoa.h>
#import "StreamProcessor.h"
#import <OpenGL/CGLMacro.h>
#import <pthread.h>
#import <VVBasics/VVBasics.h>
@class VVBuffer;




@interface PBOGLCPUStreamer : StreamProcessor	{
	MutLockArray			*ctxArray;
}

//	call this method if you want an immediate response (less efficient overall)
- (VVBuffer *) allocCPUBufferForTexBuffer:(VVBuffer *)b;

//	use these methods if you want to work with a stream of images (faster/more efficient, double-buffered)
- (void) setNextTexBufferForStream:(VVBuffer *)n;
//	pulls the raw PBO out of the stream- you'll probably want to copy the data from this to wherever you want the CPU data
- (VVBuffer *) copyAndGetPBOBufferForStream;
//	creates a new CPU-based buffer, pulls a raw PBO out of the stream, and copies the data from the PBO to the newly-created buffer
- (VVBuffer *) copyAndGetCPUBufferForStream;

//	if you already have a CPU-based buffer, this is the fastest way to pull a PBO out of the stream and copy its data to your cpu-based buffer.  internally, other methods in this class use this method.  returns a YES if successfully copied from the PBO (returns a NO if there wasn't anything available in the stream or there was a problem)
- (BOOL) copyPBOFromStreamToRawDataBuffer:(void *)b sized:(NSSize)dataBufferSize;
- (void) _copyBytesPerRow:(NSUInteger)bpr ofPBOBuffer:(VVBuffer *)pbo toRawDataBuffer:(void *)w usingContext:(CGLContextObj)cgl_ctx;
- (void) _copyPBOBuffer:(VVBuffer *)pbo toRawDataBuffer:(void *)w usingContext:(CGLContextObj)cgl_ctx;


- (MutLockArray *) ctxArray;

@end

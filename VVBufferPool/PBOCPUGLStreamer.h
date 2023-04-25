#import <Cocoa/Cocoa.h>
#import <VVBufferPool/StreamProcessor.h>
#import <OpenGL/CGLMacro.h>
#import <pthread.h>
#import <VVBasics/VVBasics.h>
@class VVBuffer;




@interface PBOCPUGLStreamer : StreamProcessor	{
	MutLockArray				*ctxArray;
}

- (void) setNextPBOForStream:(VVBuffer *)n;
- (VVBuffer *) copyAndGetTexBufferForStream;

@end

#import <Cocoa/Cocoa.h>
#import "StreamProcessor.h"
@class VVBufferCopier;
@class VVBuffer;




@interface TexRangeGLCPUStreamer : StreamProcessor	{
	VVBufferCopier			*copyObj;	//	used to copy non-tex range textures to tex range textures
	MutLockArray			*ctxArray;	//	sort of a buffer pool for GL contexts.
	BOOL					copyAndResize;
	NSSize					copySize;
}

- (void) setNextTexBufferForStream:(VVBuffer *)n;
- (VVBuffer *) copyAndGetCPUBackedBufferForStream;

@property (assign,readwrite) BOOL copyAndResize;
@property (assign,readwrite) NSSize copySize;

@end

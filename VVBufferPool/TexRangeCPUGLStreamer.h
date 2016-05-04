#import <Cocoa/Cocoa.h>
@class VVBuffer;




/*
	this is basically a legacy class- at one point there was a discrete node for pushing CPU-based 
	images to GL texture ranges (the class was optimized specifically for texture ranges/writing 
	directly to VRAM).  this has since been moved into a class method of VVBufferPool which can use 
	any GL context.
	
	the swizzle node is a convenience- frequently, swizzling color models is performed after 
	uploading the texture, so a swizzle node is included in instances of this class to save code in 
	implementations of this class (the swizzle node will be nil until it's needed)
*/




@interface TexRangeCPUGLStreamer : NSObject	{
	BOOL				deleted;
	NSOpenGLContext		*ctx;
	pthread_mutex_t		contextLock;
}

- (void) prepareToBeDeleted;

- (void) pushTexRangeBufferRAMtoVRAM:(VVBuffer *)b;

- (void) _createGLResources;

@end

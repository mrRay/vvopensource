#import <Cocoa/Cocoa.h>
#import <VVBufferPool/VVBufferPool.h>
#import <pthread.h>




extern id			_globalVVBufferCopier;




///	subclass of GLScene, used to copy the contents of VVBuffer instances by rendering them into a texture.
/**
\ingroup VVBufferPool
*/
@interface VVBufferCopier : GLScene {
	pthread_mutex_t		renderLock;
	BOOL				copyToIOSurface;	//	NO by default; if NO, the copied buffer won't have an associated IOSurfaceRef
	VVBufferPixFormat	copyPixFormat;	//	VVBufferPF_BGRA by default
	BOOL				copyAndResize;	//	NO by default. if NO, copies preserve the size of the passed buffer- if NO, resizes the buffer while copying it
	NSSize				copySize;	//	only used if "copyAndResize" is YES;
	VVSizingMode		copySizingMode;
}

///	there's a global (singleton) instance of VVBufferCopier- by default this is created when you set up the global VVBufferPool, but if you want to override it and create it to work with a different context, this is how.
+ (void) createGlobalVVBufferCopierWithSharedContext:(NSOpenGLContext *)c;
///	returns the instance of the global (singleton) VVBufferCopier which is automatically created when you make the global VVBufferPool.  if this is nil, something's wrong- check to see if your global buffer pool is nil or not!
+ (VVBufferCopier *) globalBufferCopier;

///	returns a retained instance of VVBuffer which was made by rendering the passed buffer into a new texture of matching dimensions.
- (VVBuffer *) copyToNewBuffer:(VVBuffer *)n;

///	copies the first passed buffer into the second, returns YES if successful- if sizes don't match or either buffer is nil, bails and returns NO!  ignores "copyToIOSurface" and "copyPixFormat"!
- (BOOL) copyThisBuffer:(VVBuffer *)a toThisBuffer:(VVBuffer *)b;
///	copies the first buffer into the second buffer.  will stretch/squash 'a' to fit into 'b'.
- (void) sizeVariantCopyThisBuffer:(VVBuffer *)a toThisBuffer:(VVBuffer *)b;
///	copies the first buffer into the second buffer, completely ignoring sizes- it just draws 'a' in the bottom-left corner of 'b'.  the resulting image may depict 'a' as being "too small" or "cropped".
- (void) ignoreSizeCopyThisBuffer:(VVBuffer *)a toThisBuffer:(VVBuffer *)b;

///	fills the passed buffer with transparent black
- (void) copyBlackFrameToThisBuffer:(VVBuffer *)b;
///	fills the passed buffer with opaque black
- (void) copyOpaqueBlackFrameToThisBuffer:(VVBuffer *)b;
///	fills the passed buffer with opaque red
- (void) copyRedFrameToThisBuffer:(VVBuffer *)b;

///	NO by default.  if YES, will create a GL texture used to back an IOSurface (for inter-process texture sharing) when "copyToNewBuffer" is called.
@property (assign,readwrite) BOOL copyToIOSurface;
@property (assign,readwrite) VVBufferPixFormat copyPixFormat;
///	NO by default.  if YES, the buffer copier will resize anything passed to "copyToNewBuffer" or throw an error if the buffer sizes don't match and you call "copyThisBuffer:toThisBuffer:".
@property (assign,readwrite) BOOL copyAndResize;
///	the "copySize" is only used if "copyAndResize" is YES
@property (assign,readwrite) NSSize copySize;
@property (assign,readwrite) VVSizingMode copySizingMode;

@end

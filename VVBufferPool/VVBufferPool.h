#import <Cocoa/Cocoa.h>
#import <OpenGL/CGLMacro.h>
#import <pthread.h>
#import <VVBasics/VVBasics.h>

#import "VVBufferPoolStringAdditions.h"
#import "VVBuffer.h"
#import "VVBufferAggregate.h"
#import "VVBufferGLView.h"
#import "RenderThread.h"
#import "VVSizingTool.h"
#import "GLScene.h"
#import "GLShaderScene.h"
#import "CIGLScene.h"
#import "VVQCComposition.h"
#import "QCGLScene.h"
#import "VVBufferCopier.h"
#import "HapSupport.h"
/**
\defgroup VVBufferPool VVBufferPool framework
*/





extern id				_globalVVBufferPool;	//	retained, nil on launch- this is the "main" buffer pool, used to generate image resources for hardware-accelerated image processing.  can't be created automatically, b/c it needs to be based on a shared context.
extern int				_msaaMaxSamples;
extern BOOL			_bufferPoolInitialized;
extern VVStopwatch	*_bufferTimestampMaker;




//#define FOURCC(x) ((unsigned long)((*(x+0)<<24) + (*(x+1)<<16) + (*(x+2)<<8) + (*(x+3))))
//#define FOURCC(x) ((unsigned long)((*(x+0)) + (*(x+1)<<8) + (*(x+2)<<16) + (*(x+3)<<24)))
//#define FOURCC(x) ((x[0]<<24)|(x[1]<<16)|(x[2]<<8)|(x[3]))
#define FOURCC_PACK(a,b,c,d) ((unsigned long)((((uint32_t)d)) | (((uint32_t)c)<<8) | (((uint32_t)b)<<16) | (((uint32_t)a)<<24)))




///	Creates VVBuffers.  Should be the *only* way you create VVBuffers- most projects will only have a single instance of VVBufferPool, which shares an OpenGL context with other parts of your program so GL resources (specifically textures) may be shared.
/**
\ingroup VVBufferPool
The goal of the buffer pool is two-fold: firstly, to simplify the process of creating and working with GL-based resources by treating them as "buffer objects".  secondly, to minimize the impact of creating and dealing with gl-based resources; when a VVBuffer is released, it goes back into the pool for a specified period of time.  during this time, anything that asks the pool for a matching buffer will be given the pre-existing asset (instead of forcing the creation of a new asset).  if nothing requires the resource, it will eventually be freed (again, VVBufferPool is a subclass of GLScene- it has a context, and may free gl resources).

VVBufferPool is a subclass of GLScene.  this is important: the buffer pool is essentially its own GL context- the idea is to have a single buffer pool which is capable of creating resources which may be shared among contexts which are being rendered on other threads.

the buffer pool creates VVBuffers; each buffer retains the buffer pool which created it to ensure that the pool sticks around until it has freed every resource it creates.  this should be mostly unnecessary- you'll probably only ever need the one global instance of VVBufferPool.
	
	
*/
@interface VVBufferPool : GLScene {
	MutLockArray		*freeBuffers;
	pthread_mutex_t		contextLock;	//	makes sure context doesn't get accessed simultaneously on disparate threads
	VVThreadLoop		*housekeepingThread;
}

/**
Returns the max number of MSAA samples that can be taken with the GL renderer currently in use by your application
*/
+ (int) msaaMaxSamples;
+ (void) setGlobalVVBufferPool:(id)n;

///Call this method and pass the GL context you wish to share to create the global (singleton) VVBufferPool.  Other classes in this framework will automatically try to configure themselves to work with the global pool or its shared context if they exist- a lot of stuff will be easier to use and require less configuration if setting up the global buffer pool is the first thing you do.
/**
@param n The NSOpenGLContext you want the buffer pool to share.  This context should not be freed as long as VVBufferPool exists!
*/
+ (void) createGlobalVVBufferPoolWithSharedContext:(NSOpenGLContext *)n;
///	Returns the global buffer pool (singleton).  The buffer pool itself should be threadsafe (you can use it from multiple threads at the same time and the pool will handle the details).
+ (id) globalVVBufferPool;
///	Call this method and pass a VVBuffer instance to it to give the passed VVBuffer instance a timestamp.
/**
@param n The VVBuffer instance you want to timestamp
*/
+ (void) timestampThisBuffer:(id)n;

///	You have to call this method periodically (once per global render pass is fine, ideally at the end of the pass).  Calling this method frees up buffers if they've been sitting unused for a while
- (void) housekeeping;
- (void) startHousekeepingThread;
- (void) stopHousekeepingThread;

//	returns a RETAINED (retainCount is 1) instance of VVBuffer!  must be explicitly released when done!
- (VVBuffer *) allocBufferForDescriptor:(VVBufferDescriptor *)d sized:(NSSize)s backingPtr:(void *)b backingSize:(NSSize)bs;
//	returns a RETAINED (retainCount is 1) instance of VVBuffer, or nil!
- (VVBuffer *) copyFreeBufferMatchingDescriptor:(VVBufferDescriptor *)d sized:(NSSize)s;
- (VVBuffer *) copyFreeBufferMatchingDescriptor:(VVBufferDescriptor *)d sized:(NSSize)s backingSize:(NSSize)bs;

/*		shortcuts for creating resources which are (relatively commonly) used.  all these return RETAINED (retainCount is 1) instances of VVBuffer- they must be released manually by whatever creates them!		*/
///	Allocates and returns a VVBuffer instance that represents an OpenGL framebuffer.  Framebuffers have textures or renderbuffers associated with them as color (image) or depth attachments.
- (VVBuffer *) allocFBO;
///	Allocates and returns a VVBuffer instance that represents an OpenGL texture.  Specifically, returns an 8-bit per channel RECT texture with a BGRA internal format.
- (VVBuffer *) allocBGRTexSized:(NSSize)s;
/**
@param s The size of the texture you want to create, in pixels, as an NSSize structure
*/
///	Allocates and returns a VVBuffer instance that represents an OpenGL texture.  Specifically, returns an 8-bit per channel 2D texture with a BGRA internal format.
/**
@param s The size of the texture you want to create, in pixels, as an NSSize structure.
*/
- (VVBuffer *) allocBGR2DTexSized:(NSSize)s;
///	Allocates and returns a VVBuffer instance that represents an OpenGL texture.  Specifically, returns an 8-bit per channel 2D texture with power-of-two dimensions and a BGRA internal format.
/**
@param s The size of the texture you want to create, in pixels, as an NSSize structure.  Note that the actual texture may be larger (as per the function name, the texture will be power-of-two with equal width and height).
*/
- (VVBuffer *) allocBGR2DPOTTexSized:(NSSize)s;
///	Allocates and returns a VVBuffer instance that represents an OpenGL texture.  Specifically, returns a 32-bit-float-per-channel RECT texture with a BGRA internal format.
/**
@param s The size of the texture you want to create, in pixels, as an NSSize structure
*/
- (VVBuffer *) allocBGRFloatTexSized:(NSSize)s;
///	Allocates and returns a VVBuffer instance that represents an OpenGL texture.  Specifically, returns a 32-bit-float-per-channel 2D texture with power-of-two dimensions and a BGRA internal format.
/**
@param s The size of the texture you want to create, in pixels, as an NSSize structure
*/
- (VVBuffer *) allocBGRFloat2DPOTTexSized:(NSSize)s;
///	Allocates and returns a VVBuffer instance that represents an OpenGL texture used as a depth attachment
/**
@param s The size of the texture you want to create, in pixels, as an NSSize structure
*/
- (VVBuffer *) allocDepthSized:(NSSize)s;
///	Allocates and returns a VVBuffer instance that represents an OpenGL renderbuffer suitable for multisample antialiasing as a color (image) attachment
/**
@param s The size of the renderbuffer you want to create, in pixels, as an NSSize structure
*/
- (VVBuffer *) allocMSAAColorSized:(NSSize)s numOfSamples:(int)n;
///	Allocates and returns a VVBuffer instance that represents an OpenGL renderbuffer suitable for multisample antialiasing as a depth attachment
/**
@param s The size of the renderbuffer you want to create, in pixels, as an NSSize structure
*/
- (VVBuffer *) allocMSAADepthSized:(NSSize)s numOfSamples:(int)n;


- (VVBuffer *) allocBufferForNSImage:(NSImage *)img;
///	Allocates and returns a VVBuffer instance that represents an 8-bit per channel OpenGL texture.  The texture is automaticall populated with the contents of the passed image
/**
@param img the NSImage instance you want to turn into a GL texture
@param prefer2D if YES, the buffer pool will try to generate a 2D texture (instead of a RECT texture)
*/
- (VVBuffer *) allocBufferForNSImage:(NSImage *)img prefer2DTexture:(BOOL)prefer2D;
- (VVBuffer *) allocBufferForBitmapRep:(NSBitmapImageRep *)rep;
///	Allocates and returns a VVBuffer instance that represents an 8-bit per channel OpenGL texture.  The texture is automaticall populated with the contents of the passed NSBitmapImageRep
/**
@param rep the NSBitmapImageRep instance you want to turn into a GL texture
@param prefer2D if YES, the buffer pool will try to generate a 2D texture (instead of a RECT texture)
*/
- (VVBuffer *) allocBufferForBitmapRep:(NSBitmapImageRep *)rep prefer2DTexture:(BOOL)prefer2D;
///	Allocates and returns a VVBuffer instance that represents the GL texture used by the passed CVOpenGLTextureRef.  The VVBuffer actually retains the CV texture, so the underlying CV resource is retained until all VVBuffers referencing it are freed.
/**
@param cvt the CVOpenGLTextureRef you want to create the VVBuffer from.  the VVBuffer will just be a "wrapper"- it will retain the passed CVOpenGLTextureRef, this is close to a zero-cost operation
*/
- (VVBuffer *) allocBufferForCVGLTex:(CVOpenGLTextureRef)cvt;
///	Special method for working with Hap movie files- uploads the passed image buffer (only accepts hap image buffers) to a GL texture.  HapQ movies will still need to be converted from YCoCg to RGBA!
/**
@param img the CVImageBufferRef you want to create the VVBuffer from.  Note that this will only work with Hap-format image buffers!  If you're working with a HapQ movie, this buffer will need to be converted from YCoCg to RGBA, as demonstrated in the test app
*/
#ifndef __LP64__
- (VVBuffer *) allocTexRangeForHapCVImageBuffer:(CVImageBufferRef)img;
#endif
///	Allocates and returns a VVBuffer instance backed by an IOSurfaceRef.  If you want to pass a texture to another process via an IOSurface, create one of these and then render to it.
/**
@param s The size of the texture/IOSUrface you want to create, in pixels, as an NSSize structure
*/
- (VVBuffer *) allocBufferForTexBackedIOSurfaceSized:(NSSize)s;
///	Allocates and returns a VVBuffer instance created from an existing IOSurfaceRef.  If you want to receive textures from another process, get the IOSurfaceID from the remote process and then pass it to this method to create the VVBuffer.
/**
@param n the IOSurfaceID you want to create a texture from
*/


- (VVBuffer *) allocBufferForIOSurfaceID:(IOSurfaceID)n;

- (VVBuffer *) allocBufferFromStringForXPCComm:(NSString *)n;



- (VVBuffer *) allocCubeMapTextureForImages:(NSArray *)n;



//	DO NOT CALL THIS METHOD MANUALLY- ONLY FROM VVBUFFER'S DEALLOC METHOD
//	called by instances of VVBuffer if its idleCount is 0 on dealloc
- (void) _returnBufferToPool:(VVBuffer *)b;
//	DO NOT CALL THIS METHOD MANUALLY- ONLY FROM VVBUFFER'S DEALLOC METHOD
//	called by instances of VVBuffer if its idleCount is > 0 on dealloc
- (void) _releaseBufferResource:(VVBuffer *)b;

- (void) _lock;
- (void) _unlock;


@end




unsigned long VVPackFourCC_fromChar(char *charPtr);
void VVUnpackFourCC_toChar(unsigned long fourCC, char *destCharPtr);

#import <TargetConditionals.h>
#import <Foundation/Foundation.h>

#if !TARGET_OS_IPHONE
#import <OpenGL/CGLMacro.h>
#endif	//	!TARGET_OS_IPHONE

#import <pthread.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPoolStringAdditions.h>

#if !TARGET_OS_IPHONE
#import <VVBufferPool/VVBufferPoolNSBitmapImageRepAdditions.h>
#endif	//	!TARGET_OS_IPHONE

#import <VVBufferPool/VVBuffer.h>
#import <VVBufferPool/VVBufferAggregate.h>

#if !TARGET_OS_IPHONE
#import <VVBufferPool/VVBufferGLView.h>
#else	//	NOT !TARGET_OS_IPHONE
#import <VVBufferPool/VVBufferGLKView.h>
#endif	//	!TARGET_OS_IPHONE

#import <VVBufferPool/RenderThread.h>
#import <VVBufferPool/VVSizingTool.h>
#import <VVBufferPool/GLScene.h>
#import <VVBufferPool/GLShaderScene.h>
//#import "CIGLScene.h"
#import <VVBufferPool/VVBufferCopier.h>

#if !TARGET_OS_IPHONE
#import <VVBufferPool/VVQCComposition.h>
#import <VVBufferPool/QCGLScene.h>
#import <VVBufferPool/HapSupport.h>
#import <CoreMedia/CoreMedia.h>
#endif	//	!TARGET_OS_IPHONE

#if !TARGET_OS_IPHONE
#import <VVBufferPool/StreamProcessor.h>
#import <VVBufferPool/PBOCPUGLStreamer.h>
#import <VVBufferPool/PBOGLCPUStreamer.h>
#import <VVBufferPool/TexRangeCPUGLStreamer.h>
#import <VVBufferPool/TexRangeGLCPUStreamer.h>
#endif

/**
\defgroup VVBufferPool VVBufferPool framework
*/





extern id				_globalVVBufferPool;	//	retained, nil on launch- this is the "main" buffer pool, used to generate image resources for hardware-accelerated image processing.  can't be created automatically, b/c it needs to be based on a shared context.
#if !TARGET_OS_IPHONE
extern int				_msaaMaxSamples;
extern int				_glMaxTextureDimension;
#endif	//	!TARGET_OS_IPHONE
extern BOOL			_bufferPoolInitialized;
extern VVMStopwatch	*_bufferTimestampMaker;




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
#if !TARGET_OS_IPHONE
+ (int) msaaMaxSamples;
#endif
+ (void) setGlobalVVBufferPool:(id)n;

///Call this method and pass the GL context you wish to share to create the global (singleton) VVBufferPool.  Other classes in this framework will automatically try to configure themselves to work with the global pool or its shared context if they exist- a lot of stuff will be easier to use and require less configuration if setting up the global buffer pool is the first thing you do.
/**
@param n The NSOpenGLContext you want the buffer pool to share.  This context should not be freed as long as VVBufferPool exists!
*/
#if !TARGET_OS_IPHONE
+ (void) createGlobalVVBufferPoolWithSharedContext:(NSOpenGLContext *)n	pixelFormat:(NSOpenGLPixelFormat*)p;
+ (void) createGlobalVVBufferPoolWithSharedContext:(NSOpenGLContext *)n;
#else	//	NOT !TARGET_OS_IPHONE
+ (void) createGlobalVVBufferPoolWithSharegroup:(EAGLSharegroup *)n;
+ (void) createGlobalVVBufferPool;
#endif	//	!TARGET_OS_IPHONE
///	Returns the global buffer pool (singleton).  The buffer pool itself should be threadsafe (you can use it from multiple threads at the same time and the pool will handle the details).
+ (id) globalVVBufferPool;
///	Call this method and pass a VVBuffer instance to it to give the passed VVBuffer instance a timestamp.
/**
@param n The VVBuffer instance you want to timestamp
*/
+ (void) timestampThisBuffer:(id)n;


#if !TARGET_OS_IPHONE
//	uses the passed context to upload the passed block of memory (m) to the provided VVBuffer containing a simple GL texture without any kind of fancy backing.
+ (void) pushProperlySizedRAM:(void *)m toSimpleTextureBuffer:(VVBuffer *)b usingContext:(CGLContextObj)cgl_ctx;
//	only works if the passed buffer is a texture range- uses the passed context to push the RAM backing for the texture range to its GL texture.  if done properly, this is the fastest GL texture upload path, it skips all data copies (DMA).
+ (void) pushTexRangeBufferRAMtoVRAM:(VVBuffer *)b usingContext:(CGLContextObj)cgl_ctx;
#endif	//	!TARGET_OS_IPHONE


///	You have to call this method periodically (once per global render pass is fine, ideally at the end of the pass).  Calling this method frees up buffers if they've been sitting unused for a while
- (void) housekeeping;
- (void) startHousekeepingThread;
- (void) stopHousekeepingThread;

//	returns a RETAINED (retainCount is 1) instance of VVBuffer!  must be explicitly released when done!
- (VVBuffer *) allocBufferForDescriptor:(VVBufferDescriptor *)d sized:(VVSIZE)s backingPtr:(void *)b backingSize:(VVSIZE)bs;
#if !TARGET_OS_IPHONE
- (VVBuffer *) allocBufferForDescriptor:(VVBufferDescriptor *)d sized:(VVSIZE)s backingPtr:(void *)b backingSize:(VVSIZE)bs inContext:(CGLContextObj)c;
#else
- (VVBuffer *) allocBufferForDescriptor:(VVBufferDescriptor *)d sized:(VVSIZE)s backingPtr:(void *)b backingSize:(VVSIZE)bs inContext:(EAGLContext *)c;
- (VVBuffer *) allocBufferInCurrentContextForDescriptor:(VVBufferDescriptor *)d sized:(VVSIZE)s backingPtr:(void *)b backingSize:(VVSIZE)bs;
#endif
//	returns a RETAINED (retainCount is 1) instance of VVBuffer, or nil!
- (VVBuffer *) copyFreeBufferMatchingDescriptor:(VVBufferDescriptor *)d sized:(VVSIZE)s;
- (VVBuffer *) copyFreeBufferMatchingDescriptor:(VVBufferDescriptor *)d sized:(VVSIZE)s backingSize:(VVSIZE)bs;




/*		shortcuts for creating resources which are (relatively commonly) used.  all these return RETAINED (retainCount is 1) instances of VVBuffer- they must be released manually by whatever creates them!		*/
///	Allocates and returns a VVBuffer instance that represents an OpenGL framebuffer.  Framebuffers have textures or renderbuffers associated with them as color (image) or depth attachments.
- (VVBuffer *) allocFBO;
#if !TARGET_OS_IPHONE
///	Allocates and returns a VVBuffer instance that represents an OpenGL texture.  Specifically, returns an 8-bit per channel RECT texture with a BGRA internal format.
/**
@param s The size of the texture you want to create, in pixels, as an VVSIZE structure
*/
- (VVBuffer *) allocBGRTexSized:(VVSIZE)s;
#endif
///	Allocates and returns a VVBuffer instance that represents an OpenGL texture.  Specifically, returns an 8-bit per channel 2D texture with a BGRA internal format.
/**
@param s The size of the texture you want to create, in pixels, as an VVSIZE structure.
*/
- (VVBuffer *) allocBGR2DTexSized:(VVSIZE)s;
///	Allocates and returns a VVBuffer instance that represents an OpenGL texture.  Specifically, returns an 8-bit per channel 2D texture with power-of-two dimensions and a BGRA internal format.
/**
@param s The size of the texture you want to create, in pixels, as an VVSIZE structure.  Note that the actual texture may be larger (as per the function name, the texture will be power-of-two with equal width and height).
*/
- (VVBuffer *) allocBGR2DPOTTexSized:(VVSIZE)s;
#if !TARGET_OS_IPHONE
///	Allocates and returns a VVBuffer instance that represents an OpenGL texture.  Specifically, returns a 32-bit-float-per-channel RECT texture with a BGRA internal format.
/**
@param s The size of the texture you want to create, in pixels, as an VVSIZE structure
*/
- (VVBuffer *) allocBGRFloatTexSized:(VVSIZE)s;
///	Allocates and returns a VVBuffer instance that represents an OpenGL texture.  Specifically, returns a 32-bit-float-per-channel 2D texture with power-of-two dimensions and a BGRA internal format.
/**
@param s The size of the texture you want to create, in pixels, as an VVSIZE structure
*/
#endif
- (VVBuffer *) allocBGRFloat2DPOTTexSized:(VVSIZE)s;
///	Allocates and returns a VVBuffer instance that represents an OpenGL texture.  Specifically, returns a 32-bit-float-per-channel 2D texture with a BGRA internal format.
/**
@param s The size of the texture you want to create, in pixels, as an VVSIZE structure
*/
- (VVBuffer *) allocBGRFloat2DTexSized:(VVSIZE)s;

///	Allocates and returns a VVBuffer instance that represents an OpenGL texture used as a depth attachment
/**
@param s The size of the texture you want to create, in pixels, as an VVSIZE structure
*/
- (VVBuffer *) allocDepthSized:(VVSIZE)s;
///	Allocates and returns a VVBuffer instance that represents an OpenGL renderbuffer suitable for multisample antialiasing as a color (image) attachment
/**
@param s The size of the renderbuffer you want to create, in pixels, as an VVSIZE structure
*/
- (VVBuffer *) allocMSAAColorSized:(VVSIZE)s numOfSamples:(int)n;
///	Allocates and returns a VVBuffer instance that represents an OpenGL renderbuffer suitable for multisample antialiasing as a depth attachment
/**
@param s The size of the renderbuffer you want to create, in pixels, as an VVSIZE structure
*/
- (VVBuffer *) allocMSAADepthSized:(VVSIZE)s numOfSamples:(int)n;

#if !TARGET_OS_IPHONE
- (VVBuffer *) allocYCbCrTexSized:(VVSIZE)s;
#endif
- (VVBuffer *) allocRGBTexSized:(VVSIZE)s;
- (VVBuffer *) allocRGB2DPOTTexSized:(VVSIZE)s;
- (VVBuffer *) allocRGBFloatTexSized:(VVSIZE)s;




//	these methods create VVBuffers from image objects created by other APIs
#if !TARGET_OS_IPHONE
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
///	Special method for working with Hap movie files- uploads the passed image buffer (only accepts hap image buffers) to a GL texture.  HapQ movies will still need to be converted from YCoCg to RGBA!
/**
@param img the CVImageBufferRef you want to create the VVBuffer from.  Note that this will only work with Hap-format image buffers!  If you're working with a HapQ movie, this buffer will need to be converted from YCoCg to RGBA, as demonstrated in the test app
*/
#ifndef __LP64__
- (VVBuffer *) allocTexRangeForHapCVImageBuffer:(CVImageBufferRef)img;
- (VVBuffer *) allocTexRangeForPlane:(int)pi ofHapCVImageBuffer:(CVImageBufferRef)img;
- (NSArray *) createBuffersForHapCVImageBuffer:(CVImageBufferRef)img;
#endif	//	__LP64__

#endif	//	!TARGET_OS_IPHONE

#if TARGET_OS_IPHONE
- (VVBuffer *) allocBufferForImageNamed:(NSString *)n;
- (VVBuffer *) allocBufferForUIImage:(UIImage *)n;
#endif //	TARGET_OS_IPHONE

- (VVBuffer *) allocCubeMapTextureForImages:(NSArray *)n;
#if !TARGET_OS_IPHONE
- (VVBuffer *) allocCubeMapTextureForImages:(NSArray *)n inContext:(CGLContextObj)c;
#else	//	NOT !TARGET_OS_IPHONE
- (VVBuffer *) allocCubeMapTextureForImages:(NSArray *)n inContext:(EAGLContext *)c;
- (VVBuffer *) allocCubeMapTextureInCurrentContextForImages:(NSArray *)n;
#endif	//	!TARGET_OS_IPHONE

///	Allocates and returns a VVBuffer instance that represents the GL texture used by the passed CVOpenGLTextureRef.  The VVBuffer actually retains the CV texture, so the underlying CV resource is retained until all VVBuffers referencing it are freed.
/**
@param cvt the CVOpenGLTextureRef you want to create the VVBuffer from.  the VVBuffer will just be a "wrapper"- it will retain the passed CVOpenGLTextureRef, this is close to a zero-cost operation
*/
#if !TARGET_OS_IPHONE
- (VVBuffer *) allocBufferForCVGLTex:(CVOpenGLTextureRef)cvt;
#else	//	NOT !TARGET_OS_IPHONE
- (VVBuffer *) allocBufferForCVGLTex:(CVOpenGLESTextureRef)cvt;
#endif	//	!TARGET_OS_IPHONE

- (VVBuffer *) allocBufferForCGImageRef:(CGImageRef)n;
- (VVBuffer *) allocBufferForCGImageRef:(CGImageRef)n prefer2DTexture:(BOOL)prefer2D;




//	these methods create VVBuffers that aren't actually images at all- they're just VBOs
- (VVBuffer *) allocVBOWithBytes:(void *)b byteSize:(long)s usage:(GLenum)u;	//	size in bytes
#if !TARGET_OS_IPHONE
- (VVBuffer *) allocVBOWithBytes:(void *)b byteSize:(long)s usage:(GLenum)u inContext:(CGLContextObj)cgl_ctx;
#else	//	NOT !TARGET_OS_IPHONE
- (VVBuffer *) allocVBOWithBytes:(void *)b byteSize:(long)s usage:(GLenum)u inContext:(EAGLContext *)ctx;
- (VVBuffer *) allocVBOInCurrentContextWithBytes:(void *)b byteSize:(long)s usage:(GLenum)u;
#endif	//	!TARGET_OS_IPHONE




//	these methods create VVBuffers that don't have any GL resources- they're just blocks of RAM
- (VVBuffer *) allocRGBACPUBufferSized:(VVSIZE)s;
- (VVBuffer *) allocRGBAFloatCPUBufferSized:(VVSIZE)s;




#if !TARGET_OS_IPHONE
///	Allocates and returns a VVBuffer instance backed by an IOSurfaceRef.  If you want to pass a texture to another process via an IOSurface, create one of these and then render to it.
/**
@param s The size of the texture/IOSUrface you want to create, in pixels, as an VVSIZE structure
*/
- (VVBuffer *) allocBufferForTexBackedIOSurfaceSized:(VVSIZE)s;
///	Allocates and returns a VVBuffer instance created from an existing IOSurfaceRef.  If you want to receive textures from another process, get the IOSurfaceID from the remote process and then pass it to this method to create the VVBuffer.
/**
@param n the IOSurfaceID you want to create a texture from
*/
- (VVBuffer *) allocBufferForIOSurfaceID:(IOSurfaceID)n;
///	Allocates and returns a VVBuffer instance created from a string describing an IOSurface
/**
@param n an NSString generated by another VVBuffer instance using the method -[VVBufferPool stringForXPCComm].  this string takes the format "<IOSuface ID>,<srcRect.origin.x>,<srcRect.origin.y>,<srcRect.size.width>,<srcRect.size.height>,<flipped>"
*/
- (VVBuffer *) allocBufferFromStringForXPCComm:(NSString *)n;

//	these methods make VVBuffers using DMA GL textures (texture ranges)
- (VVBuffer *) allocRedByteCPUBackedTexRangeSized:(NSSize)s;
- (VVBuffer *) allocRedFloatCPUBackedTexRangeSized:(NSSize)s;
- (VVBuffer *) allocLum8CPUBackedTexRangeSized:(NSSize)s;
- (VVBuffer *) allocRGBACPUBackedTexRangeSized:(NSSize)s;
- (VVBuffer *) allocBGRACPUBackedTexRangeSized:(NSSize)s;
- (VVBuffer *) allocBGRAFloatCPUBackedTexRangeSized:(NSSize)s;
- (VVBuffer *) allocYCbCrCPUBackedTexRangeSized:(NSSize)s;

//	these methods make VVBuffers using DMA GL textures from image objects created by other APIs
- (VVBuffer *) allocTexRangeForCMSampleBuffer:(CMSampleBufferRef)n;
- (VVBuffer *) allocBufferForCVPixelBuffer:(CVPixelBufferRef)cvpb texRange:(BOOL)tr ioSurface:(BOOL)io;
- (VVBuffer *) allocTexRangeForNSBitmapRep:(NSBitmapImageRep *)rep;
- (VVBuffer *) allocTexRangeForNSBitmapRep:(NSBitmapImageRep *)rep prefer2DTexture:(BOOL)prefer2D;




- (VVBuffer *) allocRGBAPBOForTarget:(GLenum)t usage:(GLenum)u sized:(VVSIZE)s data:(const GLvoid *)d;
- (VVBuffer *) allocRGBAFloatPBOForTarget:(GLenum)t usage:(GLenum)u sized:(VVSIZE)s data:(const GLvoid *)d;
- (VVBuffer *) allocYCbCrPBOForTarget:(GLenum)t usage:(GLenum)u sized:(VVSIZE)s data:(const GLvoid *)d;
- (VVBuffer *) allocBGRAPBOForTarget:(GLenum)t usage:(GLenum)u sized:(VVSIZE)s data:(const GLvoid *)d;
#endif	//	!TARGET_OS_IPHONE




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
void CGBitmapContextUnpremultiply(CGContextRef ctx);

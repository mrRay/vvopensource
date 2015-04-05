/**
\file
\addtogroup VVBufferPool
@{
*/
#import <Cocoa/Cocoa.h>
#import <OpenGL/CGLMacro.h>
#import <CoreVideo/CoreVideo.h>
#import <IOSurface/IOSurface.h>



///	These are the different kinds of VVBuffers
typedef NS_ENUM(NSInteger, VVBufferType)	{
	VVBufferType_None = 0,	//!<	none/unknown/unused
	VVBufferType_RB,	//!<	renderbuffer
	VVBufferType_FBO,	//!<	FBO
	VVBufferType_Tex,	//!<	texture (probably most common)
	VVBufferType_PBO,	//	PBO
	VVBufferType_VBO,	//	VBO
	VVBufferType_DispList,	//	display list
};
///	This desribes the internal format of the GL resource represented by a VVBuffer
typedef NS_ENUM(NSInteger, VVBufferIntFormat)	{
	VVBufferIF_None = 0,	//!<	none/unknown/unused
	VVBufferIF_Lum8 = GL_LUMINANCE8,	//!<	single channel, 8 bit per pixel
	VVBufferIF_LumFloat = GL_LUMINANCE32F_ARB,	//!<	single channel, 32 bit float per pixel
	VVBufferIF_R = GL_RED,	//!<	single channel, 8 bit per pixel
	VVBufferIF_RGB = GL_RGB,	//!<	three channel, 8 bit per channel
	VVBufferIF_RGBA = GL_RGBA,	//!<	four channel, 8 bit per channel
	VVBufferIF_RGBA8 = GL_RGBA8,	//!<	four channel, 8 bit per channel.  fast on os x, probably most common)
	VVBufferIF_Depth24 = GL_DEPTH_COMPONENT24,	//!<	depth- single channel, 24 bit per pixel
	VVBufferIF_RGBA32F = GL_RGBA32F_ARB,	//!<	four channel, 32 bit per channel
	VVBufferIF_RGB_DXT1 = GL_COMPRESSED_RGB_S3TC_DXT1_EXT,	//!<	Hap
	VVBufferIF_RGBA_DXT5 = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT,	//!<	Hap Alpha
	VVBufferIF_YCoCg_DXT5 = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT,	//!< HapQ. not a typo, same as RGBA_DXT5!
};
///	This describes the pixel format of the GL resource represented by a VVBuffer
typedef NS_ENUM(NSInteger, VVBufferPixFormat)	{
	VVBufferPF_None = 0,	//!<	non/unknown/unused
	VVBufferPF_Depth = GL_DEPTH_COMPONENT,	//!<	depth
	VVBufferPF_Lum = GL_LUMINANCE,	//!<	luminance
	VVBufferPF_R = GL_RED,	//!<	red (same idea as luminance, just seems to be slightly more compatible with stuff)
	VVBufferPF_RGBA = GL_RGBA,	//!<	RGBA
	VVBufferPF_BGRA = GL_BGRA,	//!< BGRA.  faston os x, (probably most common)
	VVBufferPF_YCBCR_422 = GL_YCBCR_422_APPLE,	//!<	packed YCbCr
};
///	This describes the pixel type of the GL resource represented by a VVBuffer
typedef NS_ENUM(NSInteger, VVBufferPixType)	{
	VVBufferPT_None = 0,	//!<	none/unknown/unused
	VVBufferPT_Float = GL_FLOAT,	//!<	float- used for rendering high-precision stuff
	VVBufferPT_U_Byte = GL_UNSIGNED_BYTE,	//!<	usually used for depth buffer/luminance/single-channel stuff
	VVBufferPT_U_Int_8888_Rev = GL_UNSIGNED_INT_8_8_8_8_REV,	//!<	standard four channel/8 bits per channel/unsigned byte format.  fast on os x, (probably most common)
	VVBufferPT_U_Short_88 = GL_UNSIGNED_SHORT_8_8_APPLE,	//!<	two channel/8 bits per channel/unsigned byte format.  usually used for YCbCr textures.
};
///	The origin of any CPU-based content
typedef NS_ENUM(NSInteger, VVBufferCPUBack)	{
	VVBufferCPUBack_None = 0,	//!<	there is no CPU-based backing
	VVBufferCPUBack_Internal,	//!<	buffer backing is CPU-based, and the CPU resource was created by this framework
	VVBufferCPUBack_External,	//!<	buffer backing is CPU-based, and the CPU resource was created outside this framework
};
///	The origin of any GPU-based content
typedef NS_ENUM(NSInteger, VVBufferGPUBack)	{
	VVBufferGPUBack_None = 0,	//!<	there is no GPU-based resource
	VVBufferGPUBack_Internal,	//!<	the GPU-based resource was created by this framework (and should be deleted by this framework)
	VVBufferGPUBack_External,	//!<	the GPU-based resource was created outside of this framework, and this buffer should be freed immediately when done
};
///	The "VVBufferBackID" is an arbitrary enum that isn't used functionally by this framework.  This enum- and VVBuffer's corresponding "backingID" member- exist to help track where a VVBuffer came from (if it was made from pixels, from another object, etc).
/**
If you want to extend VVBuffer/VVBufferPool to be compatible with other graphics APIs, you can just #define new constants/numbers (start at 100 or something so there aren't any conflicts) and use them to track the additional image types you're working with.  The only time this is really used is to determine if the backing is appropriate when calling accessor methods (take a look at the source for -[VVBuffer cvTexRef] for an example).
*/
typedef NS_ENUM(NSInteger, VVBufferBackID)	{
	VVBufferBackID_None = 0,	//!<	the buffer was wholly created by this framework- there's no backing
	VVBufferBackID_GWorld,	//<	the buffer was created from a gworld
	VVBufferBackID_Pixels,	//!<	the buffer was created from a pointer to pixels which were also allocated by this framework
	VVBufferBackID_CVPixBuf,	//!<	the buffer was created from a CVPixelBufferRef
	VVBufferBackID_CVTex,	//!<	the buffer was created from a CVOpenGLTextureRef
	VVBufferBackID_NSBitImgRep,	//!<	the buffer was created from an NSBitmapImageRep
	VVBufferBackID_RemoteIOSrf,	//!<	the buffer was created from an remote IOSurfaceRef (the IOSurface was generated in another process)
	VVBufferBackID_External	//!<	the buffer was created from some kind of external pointer passed in from another API (this can be used to work with other APIs without actually extending VVBuffer/VVBufferPool)
};
///	This C struct describes the basic characteristics of a VVBuffer's internal GL properties
typedef struct _VVBufferDescriptor	{
	VVBufferType		type;			//!<	what kind of buffer (what kind of GL resource) this holds
	GLuint				target;			//!<	GL_TEXTURE_RECTANGLE_EXT by default, sometimes GL_TEXTURE_2D or GL_RENDERBUFFER_EXT.  0 if not used.
	VVBufferIntFormat	internalFormat;	//!<	the format in which the pixel data is stored in opengl; usually RGBA8
	VVBufferPixFormat	pixelFormat;	//!<	the pixel format; usually BGRA
	VVBufferPixType		pixelType;		//!<	the type of data in the pixel format; usually U_Int_8888_Rev
	VVBufferCPUBack		cpuBackingType;	//!<	the CPU backing type
	VVBufferGPUBack		gpuBackingType;	//!<	the GPU backing type
	GLuint				name;			//!<	the actual name (identifier) of GL resource this holds
	BOOL				texRangeFlag;	//!<	if YES, it's a texture range (where appropriate)
	BOOL				texClientStorageFlag;	//!<	if YES, the texture was created with GL_UNPACK_CLIENT_STORAGE_APPLE set to TRUE: this will prevent OpenGL from copying the texture data into the client, but you have to keep a ptr to the original data around until the texture is no longer in use!
	GLuint				msAmount;		//!<	the number of multisamples (where appropriate- only applies to renderbuffers- 0 by default)
	unsigned long		localSurfaceID;	//!<	if 0, the buffer doesn't have an associated IOSurfaceRef; otherwise the surfaceID of the local surface!
} VVBufferDescriptor;




///	Populates the passed VVBufferDescriptor pointer with default values
void VVBufferDescriptorPopulateDefault(VVBufferDescriptor *d);
///	Copies the contents of the src to dst
void VVBufferDescriptorCopy(VVBufferDescriptor *src, VVBufferDescriptor *dst);
///	Compares the passed buffers, returns a YES if they are completely identical
BOOL VVBufferDescriptorCompare(VVBufferDescriptor *a, VVBufferDescriptor *b);
///	Compares the passed buffers for the purpose of recycling, returns a YES if they are close enough of a match to be used interchangeably
BOOL VVBufferDescriptorCompareForRecycling(VVBufferDescriptor *a, VVBufferDescriptor *b);
///	Calculates the size (in bytes) that would be required to create a CPU-based backing for a buffer of the passed dimensions matching the passed buffer descriptor.
unsigned long VVBufferDescriptorCalculateCPUBackingForSize(VVBufferDescriptor *b, NSSize s);




///	This is a function pointer- it gets called when the VVBuffer that owns it is being deallocated and needs to deallocate any resources associated with it.  If you want to extend the VVBufferPool framework to wrap other APIs, you'll want to write your own callback function similar to this and use it to free the buffer's callback context.
/**
@param VVBufferBeingFreed This is the instance of VVBuffer which is being freed (this is the buffer that "owns" the callback/callback context)
@param callbackContext This is the callback context from VVBufferBeingFreed- this is what you need to free.
*/
typedef void (*VVBufferBackingReleaseCallback)(id VVBufferBeingFreed, void *callbackContext);
/**
@}
*/



///	VVBuffer represents a buffer- almost always in VRAM as a GL texture or renderbuffer- created and managed by VVBufferPool.  Conceptually, it's safe to think of VVBuffers as "images" or "frames", as that is typically what they're used for.  You should never alloc/init a VVBuffer- if you want a buffer, you need to get one by asking a VVBufferPool to create one for you.
/**
\ingroup VVBufferPool
VVBuffers are the basic unit produced by VVBufferPool- each buffer typically represents an image of some sort- usually a GL texture.  VVBuffers are almost always pooled as they are freed so they may be re-used to minimize having to delete/recreate GL-related resources.

VVBuffers conform to the NSCopying protocol, but this behavior isn't straightforward- while calling "copy" on an instance of VVBuffer will result in the creation of another VVBuffer instance, both buffers refer to the same underlying GL resource (the same texture, for example).  If you want to actually duplicate a VVBuffer- if you want to create another GL texture with the same contents- you need to use the VVBufferCopier class.
*/
@interface VVBuffer : NSObject <NSCopying> {
	VVBufferDescriptor	descriptor;	//	struct that describes the GL resource this instance of VVBuffer represents
	
	BOOL				preferDeletion;	//	NO by default.  if YES, this instance will be freed immediately (rather than put back in a pool).  note that some resources will be freed immediately no matter what- even if this is NO!
	NSSize				size;	//	the dimensions of the GL resource, expressed in pixels (even if it's a 2D texture- this is pixel-based!)
	NSRect				srcRect;	//	rect describing the area of this buffer to use.  again, always pixel-based, even when the target is GL_TEXTURE_2D.
	BOOL				flipped;	//	if YES, the area described by "srcRect" should be flipped vertically before display
	NSSize				backingSize;	//	sometimes, the backing has a different size (gworlds backing compressed textures)
	GLfloat				*auxTransMatrix;	//	"retained", nil by default. sometimes it's convenient to store transform matrices necessary to do scaling/translation/perspective distortion with the buffers that use them.
	GLfloat				auxOpacity;	//	like "auxTransMatrix", sometimes it's convenient to store an auxiliary "opacity" value. this opacity value isn't reflected by the contents of this VVBuffer- rather, it's intended to store a value for later application to this buffer.
	struct timeval		contentTimestamp;	//	set by the buffer pool's class method.  this variable is *NOT* set automatically- its use is entirely optional and up to the implementation
	id					userInfo;	//	RETAINED, nil by default.  not used by this class- stick whatever you want here and it will be retained for the lifetime of this buffer.  retained if you copy the buffer!
	
	VVBufferBackID		backingID;	//	totally optional, used to describe where the backing came from. sometimes you want to know what kind of backing a VVBuffer has, and access it.  there's an enum describing some of the more common sources, and you can define and use your own values here.
	void				*cpuBackingPtr;	//	weak ref, only non-nil if there's a cpu backing for the GL resource.  ptr to the raw pixel data (this ptr is passed to GL upload/download functions)
	
	/*		this callback and callback context are used when the VVBuffer and its resources need to be freed.  these can be used to quickly and easily add support for other image processing frameworks (using VVBuffer to wrap opaque image types)		*/
	VVBufferBackingReleaseCallback	backingReleaseCallback;	//	this function is called when the image resources need to be released
	void				*backingReleaseCallbackContext;	//	weak ref. this is an arbitrary data pointer that is stored with a buffer for use with the buffer release callback
	
	/*		if this instance of VVBuffer has a corresponding IOSurfaceRef, it's retained here.  these will always be valid- even if you copy a VVBuffer.		*/
	IOSurfaceRef		localSurfaceRef;	//	RETAINED, nil by default.  the "local" surface ref was created by this process.
	IOSurfaceRef		remoteSurfaceRef;	//	RETAINED, nil by default.  the "remote" surface ref was created by another process (so this should probably be released immediately).
	
	/*		these variables pertain to the buffer in its pool- idle counts, the original buffer for this resource (in the case of copied buffers), that sort of thing.		*/
	id					parentBufferPool;	//	RETAINED! the pool exists until all its buffers are gone!
	id					copySourceBuffer;	//	RETAINED, nil by default. if you copy a VVBuffer using the NSCopying protocol, the original buffer is retained here (so the underlying resources don't get freed until all VVBuffer instances referring to them get freed).
	int					idleCount;	//	when a buffer's in a pool waiting to be re-used, its idleCount is incremented- if it gets high enough, the buffer is actually freed and its resources released
}

+ (id) createWithPool:(id)p;
- (id) initWithPool:(id)p;

///	Returns a ptr to the VVBufferDescriptor that describes this VVBuffer.  This struct describes the basic underlying properties of the VVBuffer- its internal GL formats, and other attributes that are set on creation (and are beneficial to track for doing other image operations)
- (VVBufferDescriptor *) descriptorPtr;
- (void) setDescriptorFromPtr:(VVBufferDescriptor *)n;
@property (assign, readwrite) BOOL preferDeletion;
///	This returns the size of the underlying GL resource.  The value returned by this method is always using pixels as the base unit of measurement.  This value should be set by the buffer pool.  If you want to retrieve the size of the image/frame represented by the VVBuffer, get the "size" member of the "srcRect"!
@property (readonly) NSSize size;
- (void) setSize:(NSSize)n;
///	The "srcRect" is the region of the GL resource that contains an image- this value is always measured in pixels, and measures from the bottom-left corner of the texture.  It's safe to both set and get this value, because it's non-destructive: the "srcRect" is only used when you want to do something with the VVBuffer (draw it, pass it to another object for copying/etc).
@property (assign, readwrite) NSRect srcRect;
///	Whether or not the image represented by this buffer is flipped vertically.  Like "srcRect", it's safe and quick to both set and get this value- changing it does not cause any graphic operatings to occur, the value is only used when you want to do something with this VVBuffer.
@property (assign, readwrite) BOOL flipped;
///	If the buffer has some kind of backing, these are its dimensions.  Stored here as a different size to deal with situations where the backing has different dimensions than the GL resource created from it.  Set when the buffer is created, you probably shouldn't change this.
@property (assign, readwrite) NSSize backingSize;
///	Returns a ptr to the VVBuffer's content timestamp.  Content timestamps may be generated by +[VVBufferPool timestampThisBuffer:].  This is a ptr to a simple timeval struct- timestamps may be used to aid in differentiating between frames and checking for "new" content.
- (struct timeval *) contentTimestampPtr;
///	Copies the values from the receiver's content timestamp into the passed timeval struct.  Content timestamps may be generated by +[VVBufferPool timestampThisBuffer:].  This is a ptr to a simple timeval struct- timestamps may be used to aid in differentiating between frames and checking for "new" content.
- (void) getContentTimestamp:(struct timeval *)n;
- (void) setContentTimestampFromPtr:(struct timeval *)n;
///	Not used by this framework- the "userInfo" is an arbitrary id that you can use to assign stuff to VVBuffers.  The passed ptr is retained with the VVBuffer for the duration of its existence.
- (void) setUserInfo:(id)n;
///	Returns the buffer's "userInfo" (if there is one).
- (id) userInfo;
- (void) setAuxTransMatrix:(GLfloat *)n;
- (GLfloat *) auxTransMatrix;
@property (assign, readwrite) GLfloat auxOpacity;
///	Takes "srcRect", and then divides its members by the size of the GL resource to normalize them.
@property (readonly) NSRect normalizedSrcRect;
///	If you want to draw a texture, you need to know what the texture coordinates are so you can specify where to draw the texture on your triangles/quads.  Texture coordinates depend on what "type" of texture you're working with (GL_TEXTURE_2D tex coords are always normalized, GL_TEXTURE_RECTANGLE_EXT coords are never normalized).  This method returns an NSRect populated with the texture coords you should use to draw the contents of this buffer.  This method/this value is useful if you're writing your own GL drawing code- if you're working exclusively with VVBufferPool objects, you probably won't need this as much.
@property (readonly) NSRect glReadySrcRect;
///	The "srcRect" value in VVBuffer describes the region of the underlying texture to use as an image.  This is essentially a zero-cost crop: you can change the dimensions and location of the "srcRect" to non-destructively change the "cropping" of the underlying image.  This is cool, but it's a pain in the butt if you want to crop something that was already cropped and may or may not be flipped.  This method simplifies the task of cropping an existing VVBuffer.
/**
@param cropRect A normalized NSRect describing the crop rect you want to apply to the existing image
@param f YES if you want this operating to take the VVBuffer's flippedness into account
@return Returns an NSRect with the new srcRect that you can apply to the receiver or do further calculations with.
*/
- (NSRect) srcRectCroppedWith:(NSRect)cropRect takingFlipIntoAccount:(BOOL)f;
///	Returns YES if "srcRect" has an origin at 0,0 and a size that matches the texture size!
@property (readonly) BOOL isFullFrame;
@property (readonly) BOOL isNPOT2DTex;
@property (readonly) BOOL isPOT2DTex;
///	The actual name of the underlying GL resource- when you want to draw a texture, this is what you bind.  You'll probably only need to use this if you're writing your own GL drawing commands.
@property (readonly) GLuint name;
///	If this VVBuffer has an underlying GL resource, this returns the target of the resource.  By default, this is usually GL_TEXTURE_RECTANGLE_EXT, though it may also be GL_TEXTURE_2D.
@property (readonly) GLuint	target;
///	Returns a YES if this VVBuffer is safe to publish to syphon- in order to be safe to publish via Syphon, a VVBuffer must be a rectangular texture using 8 bits per channel (32bits per pixel) backed by an IOSurface.  If the VVBuffer is flipped, or isn't full-frame, this will return a NO.
@property (readonly) BOOL safeToPublishToSyphon;
///	Returns a YES if the passed buffer and the receiver have matching contentTimeStamps.
- (BOOL) isContentMatchToBuffer:(VVBuffer *)n;

- (GLuint *) pixels;
///	If the receiver was created from a CVPixelBufferRef, this will return the CVPixelBufferRef (which is retained by the buffer until it's freed).  Returns nil if the buffer wasn't created from a CVPixelBuffer.
- (CVPixelBufferRef) cvPixBuf;
///	If the receiver was created by "wrapping" a CVOpenGLTextureRef, this will return the CVOpenGLTextureRef (which is retained by the buffer until it's freed).  Returns nil if the buffer wasn't created from a CVOpenGLTextureRef.
- (CVOpenGLTextureRef) cvTexRef;
///	If the receiver was created from a CVPixelBufferRef, this will return the NSBitmapImageRep (which is retained by the buffer until it's freed).  Returns nil if the buffer wasn't created from a NSBitmapImageRep.
- (NSBitmapImageRep *) bitmapRep;
- (void *) externalBacking;
#ifndef __LP64__
- (GWorldPtr) gWorld;
#endif

///	The VVBufferBackID doesn't play a functional role in the processing of VVBuffer- it's an enum that exists so you can flag what this buffer was created from.  This variable exists to make it easier to retrieve the underlying resource wrapped by the VVBuffer (for example, retrieving a CVOpenGLTextureRef, NSBitmapImageRep, etc) or determining the provenance of a buffer.
@property (assign,readwrite) VVBufferBackID backingID;
- (void) setCpuBackingPtr:(void *)n;
///	If a VVBuffer was created from a CPU-based resource, this will always return a ptr to the raw pixels used in the underlying image.  For example, if you make a VVBuffer/GL texture from an NSBitmapImageRep, the "cpuBackingPtr" will point to the bitmap rep's "pixelData".
- (void *) cpuBackingPtr;
///	Should only be used when extending VVBufferPool to work with other drawing APIs.  The "backingReleaseCallback" is a function pointer that gets called when the VVBuffer is being freed.  If you make a VVBuffer that "wraps" another graphic resource (retaining it with the VVBuffer), this function is where you want to free the graphic resource.  You probably don't want to go changing this in VVBuffers- this is the sort of thing that is best set when the VVBuffer is created, and then left alone.
/**
@param n asdfasdfasdf
*/
- (void) setBackingReleaseCallback:(VVBufferBackingReleaseCallback)n;
- (VVBufferBackingReleaseCallback) backingReleaseCallback;
///	Should only be used when extending VVBufferPool to work with other drawing APIs.  The "backingReleaseCallbackContext" is a pointer passed to the "backingReleaseCallback", which gets called when the VVBuffer is being freed.  If you make a VVBuffer that "wraps" another graphic resource (retaining it with the VVBuffer), the callback context is where you want to store and retain the underlying graphic resource.  You probably don't want to go changing this in VVBuffers- this is the sort of thing that is best set when the VVBuffer is created, and then left alone.
/**
@param n An arbitrary pointer to a resource that is assumed to be required by this VVBuffer.  VVBuffer doesn't explicitly retain anything passed to this method (because it's unknown if it will even be a void* or an id)- you are responsible for ensuring that whatever you pass here is retained, and freed later in the backingReleaseCallback.
*/
- (void) setBackingReleaseCallbackContext:(void *)n;
- (void *) backingReleaseCallbackContext;
///	If the receiver is a GL texture backed by an IOSurfaceRef, this returns the IOSurfaceRef.  If you want to send a texture to another process, you want to call -[VVBufferPool allocBufferForTexBackedIOSurfaceSized:], render into the returned buffer, and then call "localSurfaceRef" to retrieve the IOSurface to be sent to another process.
- (IOSurfaceRef) localSurfaceRef;
- (void) setLocalSurfaceRef:(IOSurfaceRef)n;
///	Returns nil if this VVBuffer doesn't have a localSurfaceRef, or creates a string that describes the localSurfaceRect (the string is the format "<IOSuface ID>,<srcRect.origin.x>,<srcRect.origin.y>,<srcRect.size.width>,<srcRect.size.height>,<flipped>")
- (NSString *) stringForXPCComm;
- (IOSurfaceRef) remoteSurfaceRef;
- (void) setRemoteSurfaceRef:(IOSurfaceRef)n;

@property (retain,readwrite) id copySourceBuffer;
@property (assign,readwrite) int idleCount;
- (void) _incrementIdleCount;
- (BOOL) isVVBuffer;


@end




void VVBuffer_ReleasePixelsCallback(id b, void *c);
void VVBuffer_ReleaseCVGLT(id b, void *c);
void VVBuffer_ReleaseCVPixBuf(id b, void *c);
void VVBuffer_ReleaseBitmapRep(id b, void *c);
#ifndef __LP64__
void VVBuffer_ReleaseGWorld(id b, void *c);
#endif




@interface NSObject (VVBufferChecking)
- (BOOL) isVVBuffer;
@end
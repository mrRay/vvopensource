#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import "hap.h"




//void CMBlockBuffer_FreeHapDecoderFrame(void *refCon, void *doomedMemoryBlock, size_t sizeInBytes);
void CVPixelBuffer_FreeHapDecoderFrame(void *releaseRefCon, const void *baseAddress);




/**
This object represents a frame, and holds all the values necessary to decode a hap frame from AVFoundation as a CMSampleBufferRef to DXT data.  Instances of this class are not intended to be reusable: this is just a simple holder, the backend wants to release it as soon as possible.		*/
@interface HapDecoderFrame : NSObject	{
	CMSampleBufferRef		hapSampleBuffer;	//	RETAINED
	OSType					codecSubType;	//	kHapCodecSubType, etc.
	NSSize					imgSize;	//	the size of the hap frame
	
	int						dxtPlaneCount;	//	1 by default, 2 if using "Hap Q Alpha"
	void					*dxtDatas[2];	//	NOT RETAINED.  when you decode the contents of 'hapSampleBuffer', the resulting DXT data is written here.
	size_t					dxtMinDataSizes[2];
	size_t					dxtDataSizes[2];	//	the size in bytes of the memory available at dxtDatas
	OSType					dxtPixelFormats[2];	//	kHapCVPixelFormat_RGB_DXT1, etc.  populated from the sample buffer.
	NSSize					dxtImgSize;	//	the size of the dxt image (the image size is this or smaller, dxt's have to be a multiple of 4)
	enum HapTextureFormat	dxtTextureFormats[2];	//	this value is 0 until the frame has been decoded
	
	void					*rgbData;	//	NOT RETAINED.  when you decode the contents of 'hapSampleBuffer', if this is non-nil the DXT data will be decoded into this as an RGBA/BGRA image
	size_t					rgbMinDataSize;
	size_t					rgbDataSize;	//	the size in bytes of the memory available at rgbData
	OSType					rgbPixelFormat;	//	set to 'kCVPixelFormatType_32BGRA' or 'kCVPixelFormatType_32RGBA'
	NSSize					rgbImgSize;
	
	OSSpinLock				atomicLock;
	id						userInfo;	//	RETAINED, arbitrary ptr used to keep a piece of user-specified data with the frame
	
	BOOL					decoded;	//	when decoding is complete, this is set to YES.
	int						age;	//	used by the output during decoding, once a frame is "too old" (hasn't been used in a while) it's removed from the output's local cache of decompressed frames
}

/**
Calls "initEmptyWithHapSampleBuffer:", then allocates a CFDataRef and sets that as the empty frame's "dxtDatas".
@param sb A CMSampleBufferRef containing video data compressed using the hap codec.
*/
- (id) initWithHapSampleBuffer:(CMSampleBufferRef)sb;
/**
Returns an "empty" decoder frame- all the fields except "dxtDatas" and "dxtDataSizes" are populated.  You MUST populate the dxtDatas and dxtDataSizes fields before you can return (or decode) the frame!  "dxtMinDataSizes" and the other fields are valid as soon as this returns, so you can query the properties of the frame and allocate memory of the appropriate length.
@param sb A CMSampleBufferRef containing video data compressed using the hap codec.
*/
- (id) initEmptyWithHapSampleBuffer:(CMSampleBufferRef)sb;

/// The CMSampleBufferRef containing video data compressed using the Hap codec, returned from an AVSampleBufferGenerator
@property (readonly) CMSampleBufferRef hapSampleBuffer;
/// The codec subtype of the video data in this frame.  Either kHapCodecSubType, kHapAlphaCodecSubType, kHapYCoCgCodecSubType, or kHapYCoCgACodecSubType (defined in "HapCodecSubTypes.h")
@property (readonly) OSType codecSubType;
/// The size of the image being returned.  Note that the dimensions of the DXT buffer may be higher (multiple-of-4)- these are the dimensions of the final decoded image.
@property (readonly) NSSize imgSize;
///	Hap Q Alpha is implented by having 2 "planes"- the first plane is Hap Q (HapTextureFormat_YCoCg_DXT5), the second plane is Hap Alpha (HapTextureFormat_A_RGTC1)
@property (readonly) int dxtPlaneCount;
/// If you're manually allocating HapDecoderFrame instances with a HapDecoderFrameAllocBlock, you must use this property to provide a pointer to the buffer of memory into which this framework can decode the hap frame into DXT data (this pointer must remain valid for the lifetime of the HapDecoderFrame instance).  If you're just retrieving HapDecoderFrame instances from an AVPlayerItemHapDXTOutput, you can use this property to get a ptr to the memory containing the DXT data, ready for upload to a GL texture.
@property (readonly) void** dxtDatas;
/// The minimum amount of memory required to contain a DXT-compressed image with dimensions of "imgSize".  If you're using a HapDecoderFrameAllocBlock, the blocks of memory assigned to "dxtDatas" must be at least this large.
@property (readonly) size_t* dxtMinDataSizes;
/// If you're using a HapDecoderFrameAllocBlock, in addition to providing memory for the dxtData block, you must also tell the frame how much memory you've allocated.
@property (readonly) size_t* dxtDataSizes;
/// The pixel format of the DXT frame, and is either 'kHapCVPixelFormat_RGB_DXT1' (if the video frame used the hap codec), 'kHapCVPixelFormat_RGBA_DXT5' (if it used the "hap alpha" codec), or 'kHapCVPixelFormat_YCoCg_DXT5' (if it used the "hap Q" codec).  These values are defined in PixelFormats.h
@property (readonly) OSType* dxtPixelFormats;
/// The size of the DXT frame, in pixels.  This may be larger tha the "imgSize".
@property (readonly) NSSize dxtImgSize;
/// The format of the GL texture, suitable for passing on to GL commands (
@property (readonly) enum HapTextureFormat* dxtTextureFormats;

@property (assign,readwrite,setter=setRGBData:) void* rgbData;
@property (readonly) size_t rgbMinDataSize;
@property (assign,readwrite,setter=setRGBDataSize:) size_t rgbDataSize;
@property (assign,readwrite,setter=setRGBPixelFormat:) OSType rgbPixelFormat;
@property (assign,readwrite,setter=setRGBImgSize:) NSSize rgbImgSize;

@property (readonly) CMTime presentationTime;
- (BOOL) containsTime:(CMTime)n;

- (CMSampleBufferRef) allocCMSampleBufferFromRGBData;

/// A nondescript, retained, (id) that you can use to retain an arbitrary object with this frame (it will be freed when the frame is deallocated).  If you're using a HapDecoderFrameAllocBlock to allocate memory for frames created by an AVPlayerItemHapDXTOutput and you want to retain a resource with the decoded frame, this is a good way to do it.
@property (retain,readwrite) id userInfo;
//	Returns YES when the frame has been decoded
@property (assign,readwrite) BOOL decoded;

- (void) incrementAge;
- (int) age;

@end

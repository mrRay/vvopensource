#import <Foundation/Foundation.h>
#import "HapDecoderFrame.h"
#import <AVFoundation/AVFoundation.h>
#import "CMBlockBufferPool.h"



/**
This defines a block that returns an instance of HapDecoderFrame that has been allocated and populated (the returned frame should have a buffer into which the decompressed DXT data can be written).  Providing the buffer into which DXT data is decompressed allows devs to minimize the number of copies performed with this data (DMA to GL textures being the best-case scenario).  Use of this block is optional- but if you use it, you *must* populate the HapDecoderFrame's dxtData and dxtDataSize properties.		*/
typedef HapDecoderFrame* (^HapDecoderFrameAllocBlock)(CMSampleBufferRef decompressMe);
/**
This defines a block that gets called immediately after a frame has finished uncompressing a hap frame into DXT data.  Frame decoding is done via GCD- this block is executed on a thread spawned and controlled by GCD, so this would be a good place to take the opportunity to upload the decompressed DXT data to a GL texture.		*/
typedef void (^AVFHapDXTPostDecodeBlock)(HapDecoderFrame *decodedFrame);




/**
This class is the main interface for decoding hap video from AVFoundation.  You create an instance of this class and add it to an AVPlayerItem as you would with any other AVPlayerItemOutput subclass.  You retrieve frame data from this output by calling one of the allocFrame\* methods, depending on what you want to decode and whether your want it to be decoded asynchronously or not.  While it was written to be used in the AVPlayer* ecosystem, instances of this class can also be created outside AVPlayers and used to decode arbitrary frames of video (for more info, see initWithHapAssetTrack:).		*/
@interface AVPlayerItemHapDXTOutput : AVPlayerItemOutput	{
	OSSpinLock					propertyLock;	//	used to lock access to everything but the pools
	
	dispatch_queue_t			decodeQueue;	//	decoding is performed on this queue (if you use them, the allocFrameBlock and postDecodeBlock are also executed on this queue)
	AVAssetTrack				*track;	//	RETAINED
	id							gen;	//	RETAINED.  actually a 'AVSampleBufferGenerator', but listed as an id here so the fmwk can be compiled against 10.6
	CMTime						lastGeneratedSampleTime;	//	used to prevent requesting the same buffer twice from the sample generator
	
	NSMutableArray				*decodeTimes;	//	contains CMTime/NSValues of frame times that need to be decoded
	NSMutableArray				*decodeFrames;	//	contains HapDecoderFrame instances that are populated with all necessary fields and are ready to begin decoding
	NSMutableArray				*decodingFrames;	//	contains HapDecoderFrame instances that are in the process of being decoded
	NSMutableArray				*decodedFrames;	//	contains HapDecoderFrame instances that have been decoded, and are ready for retrieval
	NSMutableArray				*playedOutFrames;	//	contains HapDecoderFrame instances that have been decoded and retrieved at least once
	
	BOOL						outputAsRGB;	//	NO by default.  if YES, outputs frames as RGB data
	OSType						destRGBPixelFormat;	//	if 'outputAsRGB' is YES, this is the pixel format that will be output.  kCVPixelFormatType_32BGRA or kCVPixelFormatType_32RGBA.
	NSUInteger					dxtPoolLengths[2];
	NSUInteger					convPoolLength;
	NSUInteger					rgbPoolLength;
	
	HapDecoderFrameAllocBlock		allocFrameBlock;	//	retained, nil by default.  this block is optional, but it must be threadsafe- it will be called (on a thread spawned by GCD) to create HapDecoderFrame instances.  if you want to provide your own memory into which the hap frames will be decoded into DXT, this is a good place to do it.
	AVFHapDXTPostDecodeBlock		postDecodeBlock;	//	retained, nil by default.  this block is optional, but it must be threadsafe- it's executed on GCD-spawned threads immediately after decompression if decompression was successful.  if you want to upload your DXT data to a GL texture, this is a good place to do it.
}

/**
Under normal circumstances, AVPlayerItems created with the standard alloc/init calls are inoperative without an AVPlayer.  However, if you create an instance of this class using this method, it will be able to decode frames outside the AVPlayer* ecosystem.  This is how AVAssetReaderHapTrackOutput works: it has a local instance of AVPlayerItemHapDXTOutput that it uses to retrieve and decode Hap frames (without the use of an AVPlayer*).
@param n an AVAssetTrack instance that contains video data compressed using the Hap codec.
*/
- (id) initWithHapAssetTrack:(AVAssetTrack *)n;

/**
This method returns a retained frame as close to the passed time as possible.  May return nil if no frame is immediately available- this method returns immediately, but processing is asynchronous (it fetches and decodes the frame on another thread).  Because of this, it generally returns the frame for the *last* time you requested (the previous frame) and is generally more appropriate for simple/low-impact playback.
@return This method returns immediately, but if a frame isn't available right now it'll return nil.  If it doesn't return nil, it returns a retained (caller must release the returned object) instance of HapDecoderFrame which has been decoded (the raw DXT data is available).
@param n The time at which you would like to retrieve a frame.
*/
- (HapDecoderFrame *) allocFrameClosestToTime:(CMTime)n;

/**
This method immediately fetches and decodes the sample for the provided time.  Unlike allocFrameClosestToTime: (which is asynchronous), this method will take a bit longer to return because it fetches and decodes the raw samples before returning (synchronous), and is generally more appropriate for situations when you immediately need the specified sample (transcoding, thumbnails, that sort of thing).
@return The decoded frame.
@param n The time at which you would like to retrieve a frame.
*/
- (HapDecoderFrame *) allocFrameForTime:(CMTime)n;

/**
This method immediately decodes the passed sample.  Like allocFrameForTime:, this method is synchronous- you can pass it any arbitrary CMSampleBufferRef containing a frame of hap data and it will return the decoded information.  This method is useful if you want to decode a CMSampleBufferRef that you obtained from another source (an AVAssetReader, for example).
@return The decoded frame.
@param n The sample buffer containing a frame of Hap data that you would like to decode.
*/
- (HapDecoderFrame *) allocFrameForHapSampleBuffer:(CMSampleBufferRef)n;

/**
Use this if you want to provide a custom block that allocates and configures a HapDecoderFrame instance- if you want to pool resources or manually provide the memory into which the decoded data will be written, you need to provide a custom alloc block.
@param n This HapDecoderFrameAllocBlock must be threadsafe, and should avoid retaining the instance of this class that "owns" the block to prevent a retain loop.
*/
- (void) setAllocFrameBlock:(HapDecoderFrameAllocBlock)n;
/**
The post decode block is executed immediately after the hap frame has been decoded into DXT data.  if you want to upload your DXT data to a GL texture on a GCD-spawned thread, this is a good place to implement it.
@param n This AVFHapDXTPostDecodeBlock must be threadsafe, and should avoid retaining the instance of this class that "owns" the block to prevent a retain loop.
*/
- (void) setPostDecodeBlock:(AVFHapDXTPostDecodeBlock)n;

/**
NO by default.  If you set this to YES, the output will provide RGB pixel data in any HapDecoderFrame instances it returns (in addition to DXT data).  RGB-based decoding for this codec is fairly slow/inefficient, and should be avoided if possible in favor of DXT/OpenGL-based display techniques.  If you're using a custom HapDecoderFrameAllocBlock to allocate HapDecoderFrame instances, make sure your block also allocates memory for RGB-based pixel data if appropriate!
*/
@property (assign,readwrite) BOOL outputAsRGB;
/**
If outputAsRGB is YES, this is the RGB pixel format that the data should be decoded into.  Accepted values are kCVPixelFormatType_32RGBA and kCVPixelFormatType_32BGRA (default is kCVPixelFormatType_32RGBA)
*/
@property (assign,readwrite) OSType destRGBPixelFormat;


@end




//	we need to register the DXT pixel formats with CoreVideo- until we do this, they won't be recognized and we won't be able to work with them.  this BOOL is used to ensure that we only register them once.
extern BOOL				_AVFinHapCVInit;

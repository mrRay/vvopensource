#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>




/*		to create a CMSampleBuffer, we need the media data (in the form of a CMBlockBufferRef), a 
format description, and timing information.  unfortunately, this "timing information"- a CMSampleTimingInfo 
struct- requires that we know the *duration* of this frame.  we can't know the duration of this frame 
until we know when the next frame will occur...which means we need to get "the next frame" before we 
can write anything- and thus, we must have some way to cache all this stuff in an array.

this class exists to retain all the stuff (block buffer w. encoded data, lenght, format, etc) i need 
to make a sample buffer until i know the frame duration.  as such, its interface is simple and limited.		*/




@interface HapEncoderFrame : NSObject	{
	CMBlockBufferRef		block;
	size_t					length;
	CMFormatDescriptionRef	format;
	CMSampleTimingInfo		timing;
	
	BOOL					encoded;
}

+ (id) createWithPresentationTime:(CMTime)t;

- (id) initWithPresentationTime:(CMTime)t;

//	returns a NO if there was a problem
- (BOOL) addEncodedBlockBuffer:(CMBlockBufferRef)b withLength:(size_t)s formatDescription:(CMFormatDescriptionRef)f;

- (CMSampleBufferRef) allocCMSampleBufferWithNextFramePresentationTime:(CMTime)n;
- (CMSampleBufferRef) allocCMSampleBufferWithDurationTimeValue:(CMTimeValue)n;

@property (readonly) CMTime presentationTime;
@property (assign,readwrite) BOOL encoded;

@end

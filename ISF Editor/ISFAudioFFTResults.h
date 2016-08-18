#import <Cocoa/Cocoa.h>
#import <Accelerate/Accelerate.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreMedia/CoreMedia.h>




extern CMMemoryPoolRef		_ISFAudioFFTResultsPool;
extern CFAllocatorRef		_ISFAudioFFTResultsPoolAllocator;
extern OSSpinLock			_ISFAudioFFTResultsPoolLock;





@interface ISFAudioFFTResults : NSObject {

	DSPSplitComplex					results;		//	The raw DSPSplitComplex return from a VDSP fft_zrop
	UInt32							resultsCount;	//	The number of result values
															//	- note that the second half of the result will likely be the first half reversed
	
	size_t							magnitudesCount;	//	populated on init, the # of vals in 'magnitudes'
	float							*magnitudes;	//	populated on init- these are probably the vals you want to work with.
	
	AudioStreamBasicDescription		audioStreamBasicDescription;

}

//	Creation
+ (id) createWithResults:(DSPSplitComplex)r count:(UInt32)c streamDescription:(AudioStreamBasicDescription)asbd;
- (id) initWithResults:(DSPSplitComplex)r count:(UInt32)c streamDescription:(AudioStreamBasicDescription)asbd;

- (NSInteger) numberOfResults;
- (void) copyMagnitudesTo:(float *)dest maxSize:(size_t)s;
- (void) copyMagnitudesTo:(float *)dest maxSize:(size_t)s stride:(int)str;

//	the number of elements in 'magnitudes'
- (size_t) magnitudesCount;
//	weak ref- use it immediately, finish using it before the object that vended it is released.
- (float *) magnitudes;


@end

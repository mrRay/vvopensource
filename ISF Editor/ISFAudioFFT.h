#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#import <pthread.h>
#import "ISFAudioBufferList.h"
#import "ISFAudioFFTResults.h"






@interface ISFAudioFFT : NSObject	{

	FFTSetup			fftSetup;
	UInt32				log2n;
	
	pthread_mutex_t		_lock;
	
	BOOL				deleted;

}

- (void) prepareToBeDeleted;

//	Performs a fwd FFT on the data in the audio buffer and returns a set of real and img data points
//		returns an array of ISFAudioFFTResults, one per channel from the incoming audio buffer
- (NSArray *) processAudioBufferWithFFT:(ISFAudioBufferList *)b;

//	Set the quality level
- (void) _setLog2n:(UInt32)val;

//	vDSP_create_fftsetup
- (void) _prepareFFTSetup;

//	vDSP_destroy_fftsetup
- (void) _destroyFFTSetup;

@end

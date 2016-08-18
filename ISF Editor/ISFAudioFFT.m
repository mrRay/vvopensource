//
//  ISFAudioFFT.m
//  ISF Syphon Filter Tester
//
//  Created by David Lublin on 8/17/16.
//  Copyright © 2016 zoidberg. All rights reserved.
//

#import "ISFAudioFFT.h"

@implementation ISFAudioFFT

- (id) init	{
	if (self=[super init])	{
		pthread_mutexattr_t		attr;
		pthread_mutexattr_init(&attr);
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
		pthread_mutex_init(&_lock, &attr);
		pthread_mutexattr_destroy(&attr);
			
		fftSetup = NULL;
		log2n = 1;
		deleted = NO;
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}

- (void) prepareToBeDeleted	{
	deleted = YES;
}

- (void) dealloc	{
	[self _destroyFFTSetup];
	pthread_mutex_destroy(&_lock);
	[super dealloc];
}
//	Performs a fwd FFT on the data in the audio buffer and returns a set of real and img data points
//	note that this DSPComplex must be freed when finished using it!!!
- (NSArray *) processAudioBufferWithFFT:(ISFAudioBufferList *)b	{
	if (deleted)
		return nil;
	//NSLog(@"%s",__func__);
	NSMutableArray		 *returnMe = [NSMutableArray arrayWithCapacity:0];
	
	if (b == nil)
		goto BAIL;

	if ([b numberOfFrames]==0)
		goto BAIL;
	
	//	how many frames does b have?
	//	we may need to _setLog2n and update the fftsetup
	UInt32		numberOfFrames = [b numberOfFrames];
	UInt32		logVal = log2(numberOfFrames);
	
	//	add one to this
	[self _setLog2n:logVal+1];
	
	//	Determine the dimensions
	//long	numberOfChannels = [b numberOfChannels];
	//NSLog(@"\t\tnumberOfFrames: %d",numberOfFrames);
	UInt32	numberOfFramesToProcess = pow(2,log2n);

	//	Get the actual AudioBufferList from the buffer object
	AudioBufferList					*abl = [b audioBufferList];
	//	Figure out the number of buffers we need to iterate over (if it is non-interleaved or something like a MOTU device)
	UInt32							numberOfBuffers = abl->mNumberBuffers;
	AudioStreamBasicDescription		audioStreamBasicDescription = [b audioStreamBasicDescription];
	
	pthread_mutex_lock(&_lock);
		if (fftSetup==NULL)	{
			[self _prepareFFTSetup];
		}
		//NSLog(@"\t\tnumberOfFramesToProcess: %d",numberOfFramesToProcess);
		
		if (numberOfFrames)	{
			//	Do this for each buffer in the audio buffer list
			for (int buffNumber = 0;buffNumber<numberOfBuffers;++buffNumber)	{
				//float		*mBufferData = abl->mBuffers[buffNumber].mData;
				int			buffChannelCount = abl->mBuffers[buffNumber].mNumberChannels;
				
				//	Each buffer may have multiple channels if it is interleaved
				for (int channelNumber = 0;channelNumber<buffChannelCount;++channelNumber)	{
					//	Allocate and prepare the DSPComplex data
					DSPComplex		*data = (DSPComplex*)malloc(numberOfFramesToProcess*sizeof(DSPComplex));
					//	Get the buffer data for this particular channel
					float			*bufferData = abl->mBuffers[buffNumber].mData + channelNumber;
					long			i;
					//	Set the values of the data being passed into the FFT
					//	Our real values are the audio samples and we ignore the imaginary values
					//NSLog(@"\t\tnumber of samples: %ld",numberOfFrames);
					if (bufferData != nil)	{
						for(i=0;i<numberOfFrames;i++){
							data[i].real = bufferData[i];
							data[i].imag = 0;
						}
					}
		
					DSPSplitComplex input;
					DSPSplitComplex output;
			
					input.realp = (float*)malloc(numberOfFramesToProcess*audioStreamBasicDescription.mBitsPerChannel/8);
					input.imagp = (float*)malloc(numberOfFramesToProcess*audioStreamBasicDescription.mBitsPerChannel/8);
		
					output.realp = (float*)malloc(numberOfFramesToProcess*audioStreamBasicDescription.mBitsPerChannel/8);
					output.imagp = (float*)malloc(numberOfFramesToProcess*audioStreamBasicDescription.mBitsPerChannel/8);
		
					// Split the complex (interleaved) data into two arrays
					//NSLog(@"\t\tabout to perform ctoz");
					vDSP_ctoz(data,2,&input,1,numberOfFramesToProcess/2);
		
					//	Perform the fft, fft_zrop let's us perform an OUT OF PLACE transform
					//NSLog(@"\t\tabout to perform fft_zrop");
					vDSP_fft_zrop(fftSetup,&input,1,&output,1,log2n,FFT_FORWARD);
			
					//	Determine the overall energy level..

					ISFAudioFFTResults		*channelResults = [ISFAudioFFTResults createWithResults:output count:numberOfFramesToProcess/2 streamDescription:audioStreamBasicDescription];
					if (channelResults != nil)	{
						[returnMe addObject:channelResults];
					}
		
					//	Free up all my temporary variables!
					//	DON'T FREE THE RETURN VALUE
					free(input.realp);
					free(input.imagp);
					//	note that we don't free the output because it is handled by the results object we made
					//free(output.realp);
					//free(output.imagp);
					free(data);
				}
			}
		}
	pthread_mutex_unlock(&_lock);
	
	BAIL:
	return returnMe;
}

- (void) _setLog2n:(UInt32)val	{
	if (deleted)
		return;
	if (log2n!=val)
		[self _destroyFFTSetup];
		
	log2n = val;
	
	if (log2n<2)
		log2n=2;
	if (log2n>14)
		log2n=14;
}

//	vDSP_create_fftsetup
- (void) _prepareFFTSetup	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	
	pthread_mutex_lock(&_lock);
		if (fftSetup!=NULL)
			vDSP_destroy_fftsetup(fftSetup);
	
		fftSetup = NULL;
	
		fftSetup = vDSP_create_fftsetup(log2n,kFFTRadix2);
	pthread_mutex_unlock(&_lock);
	
}

//	vDSP_destroy_fftsetup
- (void) _destroyFFTSetup	{
	
	pthread_mutex_lock(&_lock);
		if (fftSetup!=NULL)
			vDSP_destroy_fftsetup(fftSetup);
		
		fftSetup = NULL;
	pthread_mutex_unlock(&_lock);
	
}

@end

#import "AudioController.h"
//#import <VVAudioKit/VVAudioKit.h>




id				_globalAudioController = nil;
NSString			*kAudioControllerInputNameChangedNotification = @"kAudioControllerInputNameChangedNotification";
//	set this to 256, 512, 1024, 2048, 4096
int		fftQuality = 512;




@implementation AudioController


- (id) init	{
	self = [super init];
	if (self != nil)	{
		_globalAudioController = self;
		
		deleted = NO;
		audioLock = VV_LOCK_INIT;
		audioBufferArray = [[MutLockArray arrayWithCapacity:0] retain];
		//	create the FFT object
		audioSource = [[ISFAVFAudioSource alloc] init];
		[audioSource setPropDelegate:self];
		audioFFT = [[ISFAudioFFT alloc] init];
		
		AVCaptureDevice		*defaultDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
		if (defaultDevice != nil)	{
			[audioSource loadDeviceWithUniqueID:[defaultDevice uniqueID]];
		}
		
		/*
		[[NSNotificationCenter defaultCenter] addObserver:self 
												selector:@selector(captureDevicesDidChangeNotification:)
												name:AVCaptureDeviceWasConnectedNotification
												object:nil];
		*/
		//	fake an audio input change notification
		[self audioInputsChangedNotification:nil];
	}
	return self;
}
- (void) prepareToBeDeleted	{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	VVLockLock(&audioLock);
	[audioSource prepareToBeDeleted];
	VVRELEASE(audioSource);
	VVRELEASE(audioFFT);
	VVLockUnlock(&audioLock);
	
	VVRELEASE(audioBufferArray);
	
	VVLockLock(&bufferLock);
	
	VVLockUnlock(&bufferLock);
	
	deleted = YES;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	
	[super dealloc];
}
- (NSArray *) arrayOfAudioMenuItems	{
	if (deleted)
		return nil;
	return [audioSource arrayOfSourceMenuItems];
}
- (void) loadDeviceWithUniqueID:(NSString *)n	{
	if (deleted)
		return;
	VVLockLock(&bufferLock);
	[audioSource loadDeviceWithUniqueID:n];
	VVLockUnlock(&bufferLock);

	//	if the input name changed, post a notification
	[[NSNotificationCenter defaultCenter]
		postNotificationName:kAudioControllerInputNameChangedNotification
		object:self];
}
- (NSString *) inputName	{
	NSString		*returnMe = nil;
	VVLockLock(&audioLock);
	returnMe = [audioSource inputName];
	VVLockUnlock(&audioLock);
	return returnMe;
}


- (void) audioInputsChangedNotification:(NSNotification *)note	{
	VVLockLock(&audioLock);
	
	VVLockUnlock(&audioLock);
}

- (void) audioSource:(id)as receivedAudioBufferList:(id)b	{
	//NSLog(@"%s",__func__);
	if (b == nil)
		return;
	//	note that this code is written to work with non-interleaved buffers
	//	with minor changes it could work either way
	if ([b interleaved])	{
		//NSLog(@"err: AudioController expected non-interleaved buffers");
		return;
	}
	//NSLog(@"%s - %d",__func__,[b numberOfFrames]);
	//	add the buffer to the queue,
	//	remove any buffers at the start of the start of the queue that aren't needed
	int					samplesInQueue = 0;
	NSMutableArray		*toDeleteArray = [NSMutableArray arrayWithCapacity:0];
	[audioBufferArray wrlock];
	[audioBufferArray addObject:b];
	
	for (ISFAudioBufferList *abl in [audioBufferArray reverseObjectEnumerator])	{
		if (samplesInQueue > fftQuality * 2 * 2)	{
			[toDeleteArray addObject:abl];
		}
		samplesInQueue = samplesInQueue + [abl numberOfFrames];
	}
	
	[audioBufferArray removeObjectsInArray:toDeleteArray];
	[audioBufferArray unlock];
	//NSLog(@"\t\tbuffers in queue: %d for %d at quality %d",[audioBufferArray lockCount],samplesInQueue,fftQuality);
}

- (void) updateAudioResults	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	NSArray				*audioBuffers = nil;
	int					samplesInQueue = 0;
	NSMutableArray		*toDeleteArray = [NSMutableArray arrayWithCapacity:0];
	
	[audioBufferArray wrlock];
	//	make sure there are enough samples in the queue to service this
	for (ISFAudioBufferList *abl in [audioBufferArray objectEnumerator])	{
		samplesInQueue += [abl numberOfFrames];
		if (samplesInQueue > fftQuality * 2)	{
			break;
		}
		[toDeleteArray addObject:abl];
	}
	if (samplesInQueue >= fftQuality * 2)	{
		audioBuffers = toDeleteArray;
		[audioBufferArray removeObjectsInArray:toDeleteArray];
	}
	[audioBufferArray unlock];
	
	if (audioBuffers == nil)	{
		//NSLog(@"\t\tnot enough samples in queue %d",samplesInQueue);
		return;
	}
	ISFAudioBufferList		*newBuffer = [ISFAudioBufferList createBufferListFromArray:audioBuffers];
	if (newBuffer == nil)	{
		NSLog(@"err: new audio buffer was nil");
		return;
	}
	if ([newBuffer interleaved])	{
		NSLog(@"err: updateAudioResults expected non-interleaved buffers");
		return;
	}

	//	do the FFT
	VVLockLock(&audioLock);
	NSArray					*channelResults = [audioFFT processAudioBufferWithFFT:newBuffer];
	VVLockUnlock(&audioLock);
	
	//	update the buffers
	VVLockLock(&bufferLock);
	VVRELEASE(rawABL);
	rawABL = [newBuffer retain];
	VVLockUnlock(&bufferLock);
	
	
	VVLockLock(&bufferLock);
	NSSize				tmpSize = [audioBuffer size];
	//NSSize			newBufferSize = NSMakeSize([abl numberOfSamplesPerChannel], [abl numberOfChannels]);
	//	always twice the size of the fft buffer, discarding any extra samples we read to avoid latency
	NSSize				newBufferSize = NSMakeSize(fftQuality * 2,[newBuffer numberOfChannels]);
	AudioBufferList		*actualABL = [newBuffer audioBufferList];
	
	if (!NSEqualSizes(tmpSize, newBufferSize))
		VVRELEASE(audioBuffer);
	if (audioBuffer == nil)	{
		//audioBuffer = [_globalVVBufferPool allocRedFloatCPUBackedTexRangeSized:newBufferSize];
		audioBuffer = [_globalVVBufferPool allocBGRAFloatCPUBackedTexRangeSized:newBufferSize];
	}
	
	if ((audioBuffer != nil) && (actualABL != NULL))	{
		//NSLog(@"\t\traw: %d of %d samples",fftQuality * 2, [abl numberOfSamplesPerChannel]);
		float				*wPtr = nil;
		float				*audioData = nil;
		
		for (int i=0; i<newBufferSize.height; ++i)	{
			audioData = actualABL->mBuffers[i].mData;
			//wPtr = (float *)[audioBuffer cpuBackingPtr] + ((int)sizeof(float)*(int)newBufferSize.width);
			wPtr = (float *)[audioBuffer cpuBackingPtr] + i * ((int)sizeof(float)*(int)newBufferSize.width);
			//	instead of just copying this data, lets be super cool and use vDSP to add 0.5 to everything so it is centered around 0.0
			//	we can set this call to write the results into our memory block for the buffer instead of overwrite the original
			//	void vDSP_vsadd ( const float *__A, vDSP_Stride __IA, const float *__B, float *__C, vDSP_Stride __IC, vDSP_Length __N );
			float		tmpVal = 0.5;
			vDSP_vsadd(audioData,1,&tmpVal,wPtr,4,(int)newBufferSize.width);
			//	we wrote the results to the 'r' channel of the output image, now populate the 'b', 'g', and 'a' channels...
			float		*copySrc = wPtr;
			for (int j=0; j<newBufferSize.width; ++j)	{
				*(copySrc+1) = *copySrc;
				*(copySrc+2) = *copySrc;
				*(copySrc+3) = *copySrc;
				copySrc += 4;
			}
		}
		
		[VVBufferPool pushTexRangeBufferRAMtoVRAM:audioBuffer usingContext:[_globalVVBufferPool CGLContextObj]];
		//NSLog(@"\t\taudioBuffer is %@",audioBuffer);
	}
	
	VVLockUnlock(&bufferLock);
	
	//	figure out how big the FFT buffer needs to be- width is based on the # of results, height is based on the # of channels
	newBufferSize = NSMakeSize(1, [channelResults count]);
	for (ISFAudioFFTResults *results in channelResults)	{
		newBufferSize.width = fmax(newBufferSize.width, [results numberOfResults]);
	}
	//	now that i know how big the buffer has to be, make sure that our FFT buffer has the appropriate size
	
	VVLockLock(&bufferLock);
	
	VVRELEASE(fftResults);
	if (channelResults != nil)
		fftResults = [channelResults retain];
	
	if (fftBuffer!=nil && !NSEqualSizes(newBufferSize, [fftBuffer size]))
		VVRELEASE(fftBuffer);
	if (fftBuffer == nil)	{
		//fftBuffer = [_globalVVBufferPool allocRedFloatCPUBackedTexRangeSized:newBufferSize];
		fftBuffer = [_globalVVBufferPool allocBGRAFloatCPUBackedTexRangeSized:newBufferSize];
	}
	if (fftBuffer != nil)	{
		size_t			rowBytes = sizeof(float) * round(newBufferSize.width);
		float			*wPtr = nil;
		int				i = 0;
		for (ISFAudioFFTResults *results in channelResults)	{
			wPtr = (float *)([fftBuffer cpuBackingPtr]) + (int)(rowBytes * i);
			[results copyMagnitudesTo:wPtr maxSize:rowBytes stride:4];
			//	we wrote the results to the 'r' channel of the output image, now populate the 'b', 'g', and 'a' channels...
			float		*copySrc = wPtr;
			for (int j=0; j<newBufferSize.width; ++j)	{
				*(copySrc+1) = *copySrc;
				*(copySrc+2) = *copySrc;
				*(copySrc+3) = *copySrc;
				copySrc += 4;
			}
			++i;
		}
		
		[VVBufferPool pushTexRangeBufferRAMtoVRAM:fftBuffer usingContext:[_globalVVBufferPool CGLContextObj]];
		//NSLog(@"\t\tfftBuffer is %@",fftBuffer);
	}
		
	
	VVLockUnlock(&bufferLock);
	
	//	retain newBuffer in case we need to create an image with a different width
}

- (VVBuffer *) allocAudioImageBuffer	{
	//[self updateAudioResults];
	VVBuffer		*returnMe = nil;
	VVLockLock(&bufferLock);
	returnMe = [audioBuffer retain];
	VVLockUnlock(&bufferLock);
	return returnMe;
}
- (VVBuffer *) allocAudioImageBufferWithWidth:(long)w	{
	//NSLog(@"%s ... %d",__func__,w);
	VVBuffer		*returnMe = nil;
	VVLockLock(&bufferLock);
	ISFAudioBufferList	*myABL = (rawABL==nil) ? nil : [[rawABL retain] autorelease];
	VVLockUnlock(&bufferLock);
	if (myABL == nil)
		return nil;
	
	//	create the buffer i'll be returning/writing into
	int				rawResultsCount = fftQuality * 2;
	NSSize			newBufferSize = NSMakeSize(fmaxl(2,fminl(w, rawResultsCount)), [myABL numberOfChannels]);
	//returnMe = [_globalVVBufferPool allocRedFloatCPUBackedTexRangeSized:newBufferSize];
	returnMe = [_globalVVBufferPool allocBGRAFloatCPUBackedTexRangeSized:newBufferSize];
	float			*wPtr = nil;
	//	figure out how many vals from the buffer we need to average to produce every result val
	int			valsPerAvg = round((float)rawResultsCount/newBufferSize.width);
	//NSLog(@"\t\trawResultsCount is %d, valsPerAvg is %d",rawResultsCount,valsPerAvg);
	//	run through every row of the output image, populating them one at a time
	AudioBufferList		*actualABL = [myABL audioBufferList];
	for (int rowIndex=0; rowIndex<newBufferSize.height; ++rowIndex)	{
		//wPtr = (float *)[returnMe cpuBackingPtr] + ((int)sizeof(float)*(int)newBufferSize.width);
		wPtr = (float *)[returnMe cpuBackingPtr] + rowIndex * ((int)sizeof(float)*(int)newBufferSize.width);
		
		//	we need to average a number of vals from the ABL to create a single output val, so first get the buffer
		float		*ablBufferData = actualABL->mBuffers[rowIndex].mData;
		//	now run through and populate every "column" in this row of the output image
		for (int outputValIndex=0; outputValIndex<newBufferSize.width; ++outputValIndex)	{
			float		*rPtr = ablBufferData + (outputValIndex * valsPerAvg);
			//	make sure that we don't run outside the bounds of the buffer
			if (((outputValIndex * valsPerAvg) + valsPerAvg) >= rawResultsCount)
				rPtr = ablBufferData + (rawResultsCount - valsPerAvg);
			
			//	calculate the average, write it to the buffer
			float		avgVal = 0.;
			/*
			//	this is actually a max, not an average
			for (int i=0; i<valsPerAvg; ++i)	{
				avgVal = fmax(avgVal, *rPtr+0.5);
				++rPtr;
			}
			*/
			for (int i=0; i<valsPerAvg; ++i)	{
				avgVal += (*rPtr + 0.5);
				++rPtr;
			}
			avgVal /= (float)valsPerAvg;
			
			
			//fprintf(stderr,", %f",avgVal);
			*(wPtr+0) = avgVal;
			*(wPtr+1) = avgVal;
			*(wPtr+2) = avgVal;
			*(wPtr+3) = avgVal;
			
			//	don't forget to increment the write ptr!
			wPtr += 4;
		}
		//fprintf(stderr,"\n");
		
	}
	
	[VVBufferPool pushTexRangeBufferRAMtoVRAM:returnMe usingContext:[_globalVVBufferPool CGLContextObj]];
	
	return returnMe;
	return nil;
}
- (VVBuffer *) allocAudioFFTImageBuffer	{
	//[self updateAudioResults];
	VVBuffer		*returnMe = nil;
	VVLockLock(&bufferLock);
	returnMe = [fftBuffer retain];
	VVLockUnlock(&bufferLock);
	return returnMe;
}
- (VVBuffer *) allocAudioFFTImageBufferWithWidth:(long)w	{
	//NSLog(@"%s ... %ld",__func__,w);
	
	VVBuffer		*returnMe = nil;
	VVLockLock(&bufferLock);
	NSArray			*myFFTResults = (fftResults==nil) ? nil : [[fftResults retain] autorelease];
	VVLockUnlock(&bufferLock);
	if (myFFTResults == nil || [myFFTResults count]<1)
		return nil;
	
	//	figure out the max and min # of magnitudes in the various results
	size_t			maxMagsCount = [[myFFTResults objectAtIndex:0] magnitudesCount];
	size_t			minMagsCount = maxMagsCount;
	for (ISFAudioFFTResults *results in myFFTResults)	{
		size_t			tmpCount = [results magnitudesCount];
		maxMagsCount = fmaxl(maxMagsCount, tmpCount);
		minMagsCount = fminl(minMagsCount, tmpCount);
	}
	//	create the buffer i'll be returning/writing into
	NSSize			newBufferSize = NSMakeSize(fmaxl(2,fminl(w,minMagsCount)), [myFFTResults count]);
	//returnMe = [_globalVVBufferPool allocRedFloatCPUBackedTexRangeSized:newBufferSize];
	returnMe = [_globalVVBufferPool allocBGRAFloatCPUBackedTexRangeSized:newBufferSize];
	if (returnMe == nil)
		return nil;
	
	//	run through the passed results, writing to one row at a time of the iamge
	float			*wPtr = [returnMe cpuBackingPtr];
	for (ISFAudioFFTResults *result in myFFTResults)	{
		//	figure out how many vals from this result we need to average to produce a single result val
		size_t			magsCount = [result magnitudesCount];
		float			*magsPtr = [result magnitudes];
		int				valsPerAvg = round((float)magsCount/newBufferSize.width);
		//	run through and populate every "column" in this row of the output image
		for (int outputValIndex=0; outputValIndex<newBufferSize.width; ++outputValIndex)	{
			float			*rPtr = magsPtr + (outputValIndex * valsPerAvg);
			//	make sure that we don't run outside the bounds of the buffer
			if (((outputValIndex * valsPerAvg) + valsPerAvg) >= magsCount)
				rPtr = magsPtr + (magsCount - valsPerAvg);
			
			//	calculate the average, write it to the buffer
			float			avgVal = 0.;
			
			//	this is actually a max, not an average...
			for (int i=0; i<valsPerAvg; ++i)	{
				avgVal = fmax(avgVal, *rPtr);
				++rPtr;
			}
			/*
			for (int i=0; i<valsPerAvg; ++i)	{
				avgVal += *rPtr;
				++rPtr;
			}
			avgVal /= (float)valsPerAvg;
			*/
			
			//fprintf(stderr,", %f",avgVal);
			*(wPtr+0) = avgVal;
			*(wPtr+1) = avgVal;
			*(wPtr+2) = avgVal;
			*(wPtr+3) = avgVal;
			
			//	don't forget to increment the write ptr!
			wPtr += 4;
		}
		//fprintf(stderr,"\n");
		
	}
	
	[VVBufferPool pushTexRangeBufferRAMtoVRAM:returnMe usingContext:[_globalVVBufferPool CGLContextObj]];
	
	return returnMe;
	return nil;
}




@end

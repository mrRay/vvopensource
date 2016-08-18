#import "ISFAudioFFTResults.h"




CMMemoryPoolRef		_ISFAudioFFTResultsPool = NULL;
CFAllocatorRef		_ISFAudioFFTResultsPoolAllocator = NULL;
OSSpinLock			_ISFAudioFFTResultsPoolLock = OS_SPINLOCK_INIT;



@interface ISFAudioFFTResults ()
- (void) calculateNormalizedMagnitudesAndPeaks;
@end





@implementation ISFAudioFFTResults

+ (id) createWithResults:(DSPSplitComplex)r count:(UInt32)c streamDescription:(AudioStreamBasicDescription)asbd	{
	ISFAudioFFTResults	*returnMe = [[ISFAudioFFTResults alloc] initWithResults:r count:c streamDescription:asbd];
	if (returnMe)
		[returnMe autorelease];
		
	return returnMe;
}
- (id) initWithResults:(DSPSplitComplex)r count:(UInt32)c streamDescription:(AudioStreamBasicDescription)asbd	{
	if (self = [super init])	{
		results.realp = r.realp;
		results.imagp = r.imagp;
		resultsCount = c;
		magnitudesCount = 0;
		magnitudes = NULL;
		audioStreamBasicDescription = asbd;
		
		magnitudesCount = 0;
		magnitudes = NULL;
		
		[self calculateNormalizedMagnitudesAndPeaks];
		
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (results.realp!=NULL)
		free(results.realp);
	results.realp = NULL;
	if (results.imagp!=NULL)
		free(results.imagp);
	results.imagp = NULL;
	if (magnitudes != NULL)	{
		//free(magnitudes);
		CFAllocatorDeallocate(_ISFAudioFFTResultsPoolAllocator, magnitudes);
		magnitudes = NULL;
	}

	[super dealloc];
}
- (void) copyMagnitudesTo:(float *)dest maxSize:(size_t)s	{
	//NSLog(@"%s",__func__);
	if (dest==nil || s<1 || magnitudes==nil || magnitudesCount<1)
		return;
	memcpy(dest, magnitudes, fminl(sizeof(float)*magnitudesCount, s));
}
- (void) copyMagnitudesTo:(float *)dest maxSize:(size_t)s stride:(int)str	{
	//NSLog(@"%s",__func__);
	if (dest==nil || s<1 || magnitudes==nil || magnitudesCount<1)
		return;
	float			*rPtr = magnitudes;
	float			*wPtr = dest;
	for (int i=0; i<fminl(magnitudesCount, s/sizeof(float)); ++i)	{
		*wPtr = *rPtr;
		++rPtr;
		wPtr += str;
	}
}
- (void) calculateNormalizedMagnitudesAndPeaks	{
	//NSLog(@"%s",__func__);
	UInt32			n = resultsCount;
	UInt32			nOver2 = n/2;
	
	if (magnitudes != NULL)	{
		CFAllocatorDeallocate(_ISFAudioFFTResultsPoolAllocator, magnitudes);
	}
	magnitudesCount = nOver2;
	magnitudes = CFAllocatorAllocate(_ISFAudioFFTResultsPoolAllocator, sizeof(float)*magnitudesCount, 0);
	
	if ((results.realp==NULL)||(results.imagp==NULL))	{
		return;
	}
	if (resultsCount==0)	{
		return;
	}
	
	float			sampleRate = audioStreamBasicDescription.mSampleRate;
	float			grain = sampleRate/nOver2;
	
	//	Allocate the tmp memory for the magnitude values
	float			*rawMagnitudes = (float *)CFAllocatorAllocate(_ISFAudioFFTResultsPoolAllocator, n*sizeof(float), 0);
	
	if (rawMagnitudes==NULL)
		return;
	
	//	get the raw magnitude vals
	vDSP_vdist(results.realp,1,results.imagp,1,rawMagnitudes,1,n);
	
	//	calculate the actual magnitudes
	float		*wPtr = magnitudes;
	float		*rPtr = rawMagnitudes;
	//float		minMag;
	//float		maxMag;
	for(int i=0; i<fminl(magnitudesCount,nOver2); i++){
		float		tmpFreq = grain * i;
		float		tmpMag = *rPtr/2.;	//	why are we dividing by 2 here?
		if (i>0)	{
			*wPtr = tmpMag*log10(tmpFreq)/log(grain);
		}
		else	{
			*wPtr = tmpMag/log(grain);
		}
		
		++wPtr;
		++rPtr;
	}

	CFAllocatorDeallocate(_ISFAudioFFTResultsPoolAllocator, rawMagnitudes);
	
}
- (size_t) magnitudesCount	{
	return magnitudesCount;
}
- (float *) magnitudes	{
	return magnitudes;
}
- (NSInteger) numberOfResults	{
	if ((results.realp==NULL)||(results.imagp==NULL))	{
		return 0;
	}
	UInt32	nOver2 = resultsCount/2;
	return nOver2;
}

@end

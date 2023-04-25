#import <Foundation/Foundation.h>
#import <VVBufferPool/VVBufferPool.h>
#import <Accelerate/Accelerate.h>
#import "ISFAVFAudioSource.h"
#import "ISFAudioFFT.h"



extern id				_globalAudioController;
extern NSString			*kAudioControllerInputNameChangedNotification;




@interface AudioController : NSObject <ISFAVFAudioSourceDelegate>	{
	BOOL					deleted;
	VVLock					audioLock;
	ISFAVFAudioSource		*audioSource;
	MutLockArray			*audioBufferArray;
	ISFAudioBufferList		*rawABL;
	ISFAudioFFT				*audioFFT;
	NSArray					*fftResults;
	
	VVLock					bufferLock;
	VVBuffer				*audioBuffer;
	VVBuffer				*fftBuffer;
}

- (void) prepareToBeDeleted;

- (void) updateAudioResults;

- (NSArray *) arrayOfAudioMenuItems;
- (void) loadDeviceWithUniqueID:(NSString *)n;

- (NSString *) inputName;

- (void) audioInputsChangedNotification:(NSNotification *)note;

- (VVBuffer *) allocAudioImageBuffer;
- (VVBuffer *) allocAudioImageBufferWithWidth:(long)w;
- (VVBuffer *) allocAudioFFTImageBuffer;
- (VVBuffer *) allocAudioFFTImageBufferWithWidth:(long)w;


@end

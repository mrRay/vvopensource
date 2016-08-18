#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "ISFAudioBufferList.h"


@protocol ISFAVFAudioSourceDelegate
- (void) audioSource:(id)as receivedAudioBufferList:(id)b;
@end



@interface ISFAVFAudioSource : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>	{

	BOOL								deleted;
	OSSpinLock							propLock;
	BOOL								propRunning;
	id <ISFAVFAudioSourceDelegate>		propDelegate;
	AVCaptureDeviceInput				*propDeviceInput;
	AVCaptureSession					*propSession;
	AVCaptureAudioDataOutput			*propOutput;
	dispatch_queue_t					propQueue;

}

- (void) prepareToBeDeleted;

- (NSArray *) arrayOfSourceMenuItems;
- (NSString *) inputName;
- (void) loadDeviceWithUniqueID:(NSString *)n;
- (void) setPropDelegate:(id)d;

- (void) start;
- (void) _start;
- (void) stop;
- (void) _stop;
- (BOOL) propRunning;

- (void) _updateWithCMSampleBufferRef:(CMSampleBufferRef)ref;
- (void) captureDevicesWasRemovedChangeNotification:(NSNotification *)note;

@end

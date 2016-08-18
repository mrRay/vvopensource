#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreAudio/CoreAudio.h>
#import <CoreAudio/AudioHardware.h>
#import <CoreAudio/CoreAudioTypes.h>
#import <pthread.h>



/*

	This is a simple wrapper for an audio buffer list object
	
	You can either create one that references a pre-allocated buffer,
	or it can be used to make a copy from an existing audio buffer list

*/



@interface ISFAudioBufferList : NSObject	{
	
	BOOL							deleted;
	
	pthread_mutex_t					_lock;
	AudioBufferList					*audioBufferList;
	UInt32							numberOfSamplesPerChannel;
	AudioStreamBasicDescription		audioStreamBasicDescription;
	
	UInt32							numberOfFrames;
	UInt32							numberOfChannels;
	
	BOOL							isCopy;

}

+ (id) createBufferListFromArray:(NSArray *)buffers;
- (id) initBufferListFromArray:(NSArray *)buffers;

+ (id) createWithAudioBufferList:(AudioBufferList *)n description:(AudioStreamBasicDescription)d;
- (id) initWithAudioBufferList:(AudioBufferList *)n description:(AudioStreamBasicDescription)d;

+ (id) createCopyFromAudioBufferList:(AudioBufferList *)n description:(AudioStreamBasicDescription)d;
- (id) initCopyFromAudioBufferList:(AudioBufferList *)n description:(AudioStreamBasicDescription)d;

- (void) generalInit;
- (void) prepareToBeDeleted;

- (void) _setAudioBufferList:(AudioBufferList *)n;
- (void) _copyAudioBufferList:(AudioBufferList *)n;
- (void) _copyAudioBufferListFromArray:(NSArray *)buffers;
- (void) _deallocateBuffer;

//	methods for getting at the data
- (AudioBufferList *) audioBufferList;
- (AudioStreamBasicDescription) audioStreamBasicDescription;
- (UInt32) numberOfFrames;
- (UInt32) numberOfChannels;
- (BOOL) interleaved;

@end

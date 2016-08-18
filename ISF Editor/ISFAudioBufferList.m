//
//  ISFAudioBufferList.m
//  ISF Syphon Filter Tester
//
//  Created by David Lublin on 8/17/16.
//  Copyright © 2016 zoidberg. All rights reserved.
//

#import "ISFAudioBufferList.h"

@implementation ISFAudioBufferList


/*===================================================================================*/
#pragma mark --------------------- Init / Dealloc
/*------------------------------------*/


+ (id) createBufferListFromArray:(NSArray *)buffers	{
	ISFAudioBufferList	*returnMe = [[ISFAudioBufferList alloc] initBufferListFromArray:buffers];
	
	if (returnMe)
		[returnMe autorelease];
	
	return returnMe;
}
- (id) initBufferListFromArray:(NSArray *)buffers	{
	if (buffers==nil)
		goto BAIL;
	
	if (self = [super init])	{
		[self generalInit];
		[self _copyAudioBufferListFromArray:buffers];
		return self;
	}
BAIL:
	if (self != nil)
		[self release];
	return nil;
}
+ (id) createWithAudioBufferList:(AudioBufferList *)n description:(AudioStreamBasicDescription)d	{
	ISFAudioBufferList	*returnMe = [[ISFAudioBufferList alloc] initWithAudioBufferList:n description:d];
	
	if (returnMe != nil)
		[returnMe autorelease];
	
	return returnMe;
}
- (id) initWithAudioBufferList:(AudioBufferList *)n description:(AudioStreamBasicDescription)d	{
	if (n==nil)
		goto BAIL;
	
	if (self = [super init])	{
		[self generalInit];
		audioStreamBasicDescription = d;
		[self _setAudioBufferList:n];
		return self;
	}
BAIL:
	if (self != nil)
		[self release];
	return nil;
}
+ (id) createCopyFromAudioBufferList:(AudioBufferList *)n description:(AudioStreamBasicDescription)d	{
	ISFAudioBufferList	*returnMe = [[ISFAudioBufferList alloc] initCopyFromAudioBufferList:n description:d];
	
	if (returnMe != nil)
		[returnMe autorelease];
	
	return returnMe;
}
- (id) initCopyFromAudioBufferList:(AudioBufferList *)n description:(AudioStreamBasicDescription)d	{
	if (n==nil)
		goto BAIL;
	
	if (self = [super init])	{
		[self generalInit];
		audioStreamBasicDescription = d;
		[self _copyAudioBufferList:n];
		return self;
	}
BAIL:
	if (self != nil)
		[self release];
	return nil;
}
- (void) generalInit	{
	deleted = NO;
	
	pthread_mutexattr_t		attr;
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
	pthread_mutex_init(&_lock, &attr);
	pthread_mutexattr_destroy(&attr);
	
	audioBufferList = NULL;
	isCopy = NO;
}
- (void) prepareToBeDeleted	{
	[self _deallocateBuffer];
	deleted = YES;
}
- (void) dealloc	{
	if (deleted == NO)
		[self prepareToBeDeleted];
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- Audio Buffer List
/*------------------------------------*/

- (void) _setAudioBufferList:(AudioBufferList *)n	{
	[self _deallocateBuffer];
	
	if (n==nil)
		return;
	
	pthread_mutex_lock(&_lock);
		isCopy = NO;
		audioBufferList = n;
		numberOfChannels = audioStreamBasicDescription.mChannelsPerFrame;
		if (audioBufferList->mNumberBuffers > 0)	{
			UInt32			tmpSize = audioBufferList->mBuffers[0].mDataByteSize;
			UInt32			tmpChannelCount = audioBufferList->mBuffers[0].mNumberChannels;
			numberOfFrames = tmpSize / (tmpChannelCount * audioStreamBasicDescription.mBitsPerChannel/8);
		}
	pthread_mutex_unlock(&_lock);
}
- (void) _copyAudioBufferList:(AudioBufferList *)n	{
	[self _deallocateBuffer];
	
	if (n==nil)
		return;
		
	//	Create an copy audio buffer list with the specified duration using the layout and description as a guide
	//	The buffers should be sized according to the specified AudioStreamBasicDescription format
	//	mSampleRate, mFormatID, mFormatFlags, mBytesPerPacket, mFramesPerPacket, mBytesPerFrame, mChannelsPerFrame, mBitsPerChannel
	
	//	Make the new bufferList based on the layout specified
	//	Allocate the bufferList itself
	pthread_mutex_lock(&_lock);
		isCopy = YES;
		UInt32 propsize;
		UInt32 numberOfBuffers = n->mNumberBuffers;
		
		//	Allocate the size of a single AudioBuffer and AudioBufferList
		//	Compute the size of the bufferList object itself
		propsize =  sizeof(AudioBufferList) + numberOfBuffers * sizeof(AudioBuffer);
		audioBufferList = (AudioBufferList *)malloc(propsize);

		//	Set the number of buffers
		audioBufferList->mNumberBuffers = numberOfBuffers;

		//	Figure out how much space I need to allocate for each channel of each buffer
		//	In audio data a frame is one sample across all channels
		//	I'm going to want to buffer 1 second of audio for each channel

		UInt32 i;
		UInt32 totalNumberOfChannels = 0;
		UInt32 totalDataByteSize = 0;
		//	For each AudioBuffer in b..
		//		Set the number of channels for the buffer
		//		Determine the needed size of the buffer data and allocate it
		//			The size will be the # of samples to buffer * # of channels * size of a sample

		for (i=0; i<numberOfBuffers;++i)	{
			UInt32 buffNumberOfChannels = n->mBuffers[i].mNumberChannels;
			UInt32 dataByteSize = n->mBuffers[i].mDataByteSize;

			audioBufferList->mBuffers[i].mNumberChannels = buffNumberOfChannels;
			audioBufferList->mBuffers[i].mDataByteSize = dataByteSize;
			
			if (dataByteSize > 0)	{
				//NSLog(@"\t\tabout to allocate %ld bytes for mbuffer %d",(long)dataByteSize,i);
				audioBufferList->mBuffers[i].mData = malloc(dataByteSize);
				bzero(audioBufferList->mBuffers[i].mData,dataByteSize);
				
				memcpy(audioBufferList->mBuffers[i].mData,
						n->mBuffers[i].mData,
						dataByteSize);
			}
			else	{
				audioBufferList->mBuffers[i].mData = NULL;
				audioBufferList->mBuffers[i].mDataByteSize = 0;
			}
			
			totalNumberOfChannels = totalNumberOfChannels + buffNumberOfChannels;
			totalDataByteSize = totalDataByteSize + dataByteSize;
			//NSLog(@"\t\tfound bufferList with size %ld for %ld channels", dataByteSize, numberOfChannels);
		}
		numberOfChannels = totalNumberOfChannels;
		if (totalNumberOfChannels > 0)
			numberOfFrames = totalDataByteSize / (totalNumberOfChannels * audioStreamBasicDescription.mBitsPerChannel / 8);
		else
			numberOfFrames = 0;
		
	pthread_mutex_unlock(&_lock);
	
	//NSLog(@"\t\tnumber of frames: %d",numberOfFrames);
}
- (void) _copyAudioBufferListFromArray:(NSArray *)buffers	{
	//	deallocate the old buffer if needed
	[self _deallocateBuffer];
	if (buffers == nil)
		return;
	if ([buffers count] == 0)
		return;
	
	//	use the first buffer as our guide for how things are laid out
	ISFAudioBufferList		*firstBuffer = [buffers objectAtIndex:0];
	audioStreamBasicDescription = [firstBuffer audioStreamBasicDescription];

	//	figure out what the audio buffer layout is going to look like so we can allocate the right size
	isCopy = YES;
	UInt32 			propsize;
	UInt32			totalNumberOfChannels = audioStreamBasicDescription.mChannelsPerFrame;
	UInt32			numberOfBuffers = 1;
	int				i = 0;
	
	//	if it is non-interleaved
	if (audioStreamBasicDescription.mFormatFlags & kAudioFormatFlagIsNonInterleaved)	{
		numberOfBuffers = audioStreamBasicDescription.mChannelsPerFrame;
	}
	
	//	run through all the buffers to figure out how much space we need to allocate, etc
	//		also make sure all the buffers have matching descriptions (sample rate, bit rate, channel count, etc)
	NSInteger		newBufferByteSize = 0;
	NSInteger		sampleOffset = 0;
	NSInteger		newFrameCount = 0;

	for (ISFAudioBufferList *abl in buffers)	{
		newFrameCount += [abl numberOfFrames];
	}
	
	//	From this point on, lock because we're actually messing with the audiobufferlist
	pthread_mutex_lock(&_lock);
		//	unlike the case where we make a straight copy, we need to do this in two steps
		//	
		//		first allocate the bufferlist and its mbuffers 
		//		second iterate through the incoming buffers to copy their data per buffer
		propsize = sizeof(AudioBufferList) + numberOfBuffers * sizeof(AudioBuffer);
		audioBufferList = (AudioBufferList *)malloc(propsize);
		audioBufferList->mNumberBuffers = numberOfBuffers;
	
		for (i = 0; i < numberOfBuffers; ++i)	{
			audioBufferList->mBuffers[i].mNumberChannels = totalNumberOfChannels;
			if (audioStreamBasicDescription.mFormatFlags & kAudioFormatFlagIsNonInterleaved)
				audioBufferList->mBuffers[i].mNumberChannels = 1;
			//	note that mBitsPerChannel is also known as number of bits per sample!
			//	when dealing with interleaved data, each mBuffer can in theory hold a different number of channels
			newBufferByteSize = audioBufferList->mBuffers[i].mNumberChannels * newFrameCount * audioStreamBasicDescription.mBitsPerChannel/8;
			//NSLog(@"\t\tabout to allocate %ld bytes for mbuffer %d",(long)newBufferByteSize,i);
			audioBufferList->mBuffers[i].mDataByteSize = (UInt32)newBufferByteSize;
			if (newBufferByteSize>0)	{
				audioBufferList->mBuffers[i].mData = malloc(newBufferByteSize);
				bzero(audioBufferList->mBuffers[i].mData,newBufferByteSize);
			}
			else	{
				audioBufferList->mBuffers[i].mData = NULL;
			}
		}
		
		//	run through all the buffers and write into the new buffer
		UInt32			totalDataByteSize = 0;
		for (ISFAudioBufferList *abl in buffers)	{
			//	write to the current offset and then advance
			//	do this for each mbuffer!
			AudioBufferList		*n = [abl audioBufferList];
			int					ablBufferCount = n->mNumberBuffers;
			if (ablBufferCount == numberOfBuffers)	{
				for (i = 0; i < numberOfBuffers; ++i)	{
					UInt32		buffNumberOfChannels = n->mBuffers[i].mNumberChannels;
					UInt32		dataByteSize = n->mBuffers[i].mDataByteSize;
					long		dataByteOffset = sampleOffset * buffNumberOfChannels * audioStreamBasicDescription.mBitsPerChannel/8;

					audioBufferList->mBuffers[i].mNumberChannels = buffNumberOfChannels;
					audioBufferList->mBuffers[i].mDataByteSize = dataByteSize;
			
					if (dataByteSize > 0)	{
						totalDataByteSize += dataByteSize;
						memcpy(audioBufferList->mBuffers[i].mData+dataByteOffset,
								n->mBuffers[i].mData,
								dataByteSize);
					}
				}
				sampleOffset += [abl numberOfFrames];
			}
		}
		numberOfChannels = totalNumberOfChannels;
		if (totalNumberOfChannels > 0)
			numberOfFrames = totalDataByteSize / (totalNumberOfChannels * audioStreamBasicDescription.mBitsPerChannel / 8);
		else
			numberOfFrames = 0;
	pthread_mutex_unlock(&_lock);
}
- (void) _deallocateBuffer	{
	pthread_mutex_lock(&_lock);
		//	if this buffer is a copy I need to actually free it
		//	either way make sure to get rid of the reference pointer!
		if ((audioBufferList != NULL) && (isCopy))	{
			//NSLog(@"\t\tdeallocating buffer copy %d",audioBufferList->mBuffers[0].mDataByteSize);
			int 		i;
			for (i = 0;i<audioBufferList->mNumberBuffers;++i)	{
				if ((audioBufferList->mBuffers[i].mData != NULL) && (audioBufferList->mBuffers[i].mDataByteSize > 0))	{
					free(audioBufferList->mBuffers[i].mData);
					//NSLog(@"\t\tdeallocating buffer copy %d:%d",i,audioBufferList->mBuffers[i].mDataByteSize);
				}
			}
			free(audioBufferList);
		}
		audioBufferList = NULL;
	pthread_mutex_unlock(&_lock);
}
- (AudioBufferList *) audioBufferList	{
	return audioBufferList;
}
- (AudioStreamBasicDescription) audioStreamBasicDescription	{
	return audioStreamBasicDescription;
}
- (UInt32) numberOfFrames	{
	return numberOfFrames;
}
- (UInt32) numberOfChannels	{
	return numberOfChannels;
}
- (BOOL) interleaved	{
	if (audioStreamBasicDescription.mFormatFlags & kAudioFormatFlagIsNonInterleaved)	{
		return NO;
	}
	return YES;
}
@end

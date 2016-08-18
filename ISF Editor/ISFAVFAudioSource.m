//
//  ISFAVFAudioSource.m
//  ISF Syphon Filter Tester
//
//  Created by David Lublin on 8/17/16.
//  Copyright © 2016 zoidberg. All rights reserved.
//

#import "ISFAVFAudioSource.h"
#import <AppKit/AppKit.h>

@implementation ISFAVFAudioSource



/*===================================================================================*/
#pragma mark --------------------- init/dealloc
/*------------------------------------*/

- (id) init	{
	//NSLog(@"%s",__func__);
	if (self = [super init])	{
		deleted = NO;
		propLock = OS_SPINLOCK_INIT;
		propRunning = NO;
		propDelegate = nil;
		propDeviceInput = nil;
		propSession = nil;
		propOutput = nil;
		propQueue = NULL;
											
		[[NSNotificationCenter defaultCenter] addObserver:self 
												selector:@selector(captureDevicesWasRemovedChangeNotification:)
												name:AVCaptureDeviceWasDisconnectedNotification
												object:nil];
		
		return self;
	}
	[self release];
	return nil;
}
- (void) prepareToBeDeleted	{
	[self stop];
	deleted = YES;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (!deleted)
		[self prepareToBeDeleted];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	OSSpinLockLock(&propLock);
	propDelegate = nil;
	OSSpinLockUnlock(&propLock);
	
	[super dealloc];
}

- (void) captureDevicesWasRemovedChangeNotification:(NSNotification *)note	{

}
- (NSArray *) arrayOfSourceMenuItems	{
	NSArray		*devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
	if (devices==nil || [devices count]<1)
		return nil;
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	for (AVCaptureDevice *devicePtr in devices)	{
		NSMenuItem		*newItem = [[NSMenuItem alloc] initWithTitle:[devicePtr localizedName] action:nil keyEquivalent:@""];
		NSString		*uniqueID = [devicePtr uniqueID];
		[newItem setRepresentedObject:uniqueID];
		[returnMe addObject:newItem];
		[newItem release];
	}
	return returnMe;
}
- (NSString *) inputName	{
	if (deleted)
		return nil;
	NSString		*returnMe = nil;
	OSSpinLockLock(&propLock);
	if (propDeviceInput != nil)	{
		returnMe = [[propDeviceInput device] localizedName];
	}
	OSSpinLockUnlock(&propLock);
	return returnMe;
}
- (void) loadDeviceWithUniqueID:(NSString *)n	{
	if ([self propRunning])
		[self stop];
	if (n==nil)
		return;
	//NSLog(@"%s - %@",__func__,n);
	BOOL				bail = NO;
	NSError				*err = nil;
	OSSpinLockLock(&propLock);
	AVCaptureDevice		*propDevice = [AVCaptureDevice deviceWithUniqueID:n];
	propDeviceInput = (propDevice==nil) ? nil : [[AVCaptureDeviceInput alloc] initWithDevice:propDevice error:&err];
	if (propDeviceInput != nil)	{
		propSession = [[AVCaptureSession alloc] init];
		propOutput = [[AVCaptureAudioDataOutput alloc] init];
		
		if (![propSession canAddInput:propDeviceInput])	{
			NSLog(@"\t\terr: problem adding propDeviceInput in %s",__func__);
			bail = YES;
		}
		if (![propSession canAddOutput:propOutput])	{
			NSLog(@"\t\terr: problem adding propOutput in %s",__func__);
			bail = YES;
		}
		
		if (!bail)	{
			propQueue = dispatch_queue_create([[[NSBundle mainBundle] bundleIdentifier] UTF8String], NULL);
			[propOutput setSampleBufferDelegate:self queue:propQueue];
			
			[propSession addInput:propDeviceInput];
			[propSession addOutput:propOutput];
			[propSession startRunning];
		}
	}
	else
		bail = YES;
	OSSpinLockUnlock(&propLock);
	
	if (bail)
		[self stop];
	else
		[self start];
}
- (void) start	{
	//NSLog(@"%s ... %@",__func__,self);
	OSSpinLockLock(&propLock);
	if (!propRunning)	{
		[self _start];
		propRunning = YES;
	}
	else
		NSLog(@"\t\tERR: starting something that wasn't stopped, %s",__func__);
	OSSpinLockUnlock(&propLock);
}
- (void) _start	{
	//NSLog(@"%s ... %@",__func__,self);
}
- (void) stop	{
	//NSLog(@"%s ... %@",__func__,self);
	OSSpinLockLock(&propLock);
	if (propRunning)	{
		[self _stop];
		propRunning = NO;
	}
	else
		NSLog(@"\t\tERR: stopping something that wasn't running, %s",__func__);
	OSSpinLockUnlock(&propLock);
}
- (void) _stop	{
	//NSLog(@"%s",__func__);
	if (propSession != nil)	{
		[propSession stopRunning];
		if (propDeviceInput != nil)
			[propSession removeInput:propDeviceInput];
		if (propOutput != nil)
			[propSession removeOutput:propOutput];
		
		dispatch_release(propQueue);
		propQueue = NULL;
		
		[propDeviceInput release];
		propDeviceInput = nil;
		[propOutput release];
		propOutput = nil;
		[propSession release];
		propSession = nil;
	}
}
- (BOOL) propRunning	{
	BOOL		returnMe;
	OSSpinLockLock(&propLock);
	returnMe = propRunning;
	OSSpinLockUnlock(&propLock);
	return returnMe;
}
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	[self _updateWithCMSampleBufferRef:sampleBuffer];
}
- (void) _updateWithCMSampleBufferRef:(CMSampleBufferRef)ref	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	if (ref == nil)
		return;
	//	if there is no delegate, return here
	id		_delegate = nil;
	OSSpinLockLock(&propLock);
		_delegate = propDelegate;
	OSSpinLockUnlock(&propLock);
	if (_delegate == nil)
		return;
	
	//	determine the number of samples and bail if 0
	CMItemCount		numSamplesInBuffer = CMSampleBufferGetNumSamples(ref);
	if (numSamplesInBuffer == 0)
		return;

	//NSLog(@"\t\tnumSamplesInBuffer %ld",numSamplesInBuffer);

	//	first use CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer to determine how big the buffer is
	OSStatus							osErr = noErr;
	const AudioStreamBasicDescription	*asbd = NULL;
	size_t								bufferSize = 0;
	osErr = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(ref,
		&bufferSize,
		NULL,
		0,
		NULL,
		NULL,
		0,
		NULL
	);
	
	if (osErr != noErr)	{
		NSLog(@"\t\terror on CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer 1");
	}

	//NSLog(@"\t\tbuffer size %d",(int)bufferSize);
	//	now allocate the buffer and call CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer again
	AudioBufferList						*audioBufferList = malloc(sizeof(AudioBufferList)+bufferSize);
	CMBlockBufferRef					blockBuffer = NULL;
	
	osErr = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(ref,
		NULL,
		audioBufferList,
		bufferSize,
		NULL,
		NULL,
		kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
		&blockBuffer);

	if (osErr == kCMSampleBufferError_AllocationFailed)	{
		NSLog(@"\t\terror kCMSampleBufferError_AllocationFailed on CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer");
	}
	else if (osErr == kCMSampleBufferError_ArrayTooSmall)	{
		NSLog(@"\t\terror kCMSampleBufferError_ArrayTooSmall on CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer");
	}
	else if (osErr != noErr)	{
		NSLog(@"\t\terror on CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer 2");
	}
	
	CMFormatDescriptionRef					fmtDesc = CMSampleBufferGetFormatDescription(ref);
	CMMediaType								fmtMediaType = CMFormatDescriptionGetMediaType(fmtDesc);
	if (fmtMediaType==kCMMediaType_Audio)	{
		AudioStreamBasicDescription			newASBD;
		asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmtDesc);
		
		newASBD.mFormatID = asbd->mFormatID;
		newASBD.mFormatFlags = asbd->mFormatFlags;
		newASBD.mBytesPerPacket = asbd->mBytesPerPacket;
		newASBD.mFramesPerPacket = asbd->mFramesPerPacket;
		newASBD.mBytesPerFrame = asbd->mBytesPerFrame;
		newASBD.mBitsPerChannel = asbd->mBitsPerChannel;
		newASBD.mSampleRate = asbd->mSampleRate;
		newASBD.mChannelsPerFrame = asbd->mChannelsPerFrame;
		newASBD.mReserved = asbd->mReserved;
		
		ISFAudioBufferList		*tmpABL = [ISFAudioBufferList createCopyFromAudioBufferList:audioBufferList description:newASBD];
		if (tmpABL != nil)	{
			[_delegate audioSource:self receivedAudioBufferList:tmpABL];
		}
	}
	
	if (audioBufferList != NULL)	{
		free(audioBufferList);
	}
	
	if (blockBuffer != NULL)	{
		CFRelease(blockBuffer);
	}
}
- (void) setPropDelegate:(id<ISFAVFAudioSourceDelegate>)n	{
	OSSpinLockLock(&propLock);
	propDelegate = n;
	OSSpinLockUnlock(&propLock);
}

@end

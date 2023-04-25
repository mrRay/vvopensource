#import "MovieFileVideoSource.h"
#import <mach/mach_time.h>




@implementation MovieFileVideoSource


/*===================================================================================*/
#pragma mark --------------------- init/dealloc
/*------------------------------------*/


- (id) init	{
	if (self = [super init])	{
		propPlayer = [[AVPlayer alloc] initWithPlayerItem:nil];
		[propPlayer setActionAtItemEnd:AVPlayerActionAtItemEndPause];
		propItem = nil;
		propOutput = nil;
		return self;
	}
	[self release];
	return nil;
}
- (void) prepareToBeDeleted	{
	[super prepareToBeDeleted];
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	VVLockLock(&propLock);
	VVRELEASE(propPlayer);
	VVRELEASE(propItem);
	VVRELEASE(propOutput);
	VVLockUnlock(&propLock);
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- superclass overrides
/*------------------------------------*/


- (void) loadFileAtPath:(NSString *)p	{
	NSLog(@"%s ... %@",__func__,p);
	[self stop];
	
	//	make an AVPlayerItem for the passed file
	NSURL			*newURL = (p==nil) ? nil : [NSURL fileURLWithPath:p];
	AVAsset			*newAsset = (newURL==nil) ? nil : [AVAsset assetWithURL:newURL];
	AVPlayerItem	*newItem = (newAsset==nil) ? nil : [[AVPlayerItem alloc] initWithAsset:newAsset];
	//	if i couldn't make an item from the passed path, send an error back through the conn and then bail
	if (newItem == nil)	{
		NSLog(@"\t\terr: couldn't create asset from path %@, %s",p,__func__);
		return;
	}
	
	//	now lock and load the AVPlayerItem
	VVLockLock(&propLock);
	//	make sure that an output exists (create one if it doesn't)
	if (propOutput == nil)	{
		NSDictionary				*pba = [NSDictionary dictionaryWithObjectsAndKeys:
			NUMINT(kCVPixelFormatType_422YpCbCr8), kCVPixelBufferPixelFormatTypeKey,
			//NUMINT(kCVPixelFormatType_32BGRA), kCVPixelBufferPixelFormatTypeKey,
			//NUMBOOL(YES), kCVPixelBufferIOSurfaceOpenGLFBOCompatibilityKey,
			//NUMBOOL(YES), kCVPixelBufferIOSurfaceOpenGLTextureCompatibilityKey,
			nil];
		propOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pba];
	}
	
	[propItem release];
	propItem = newItem;
	[propItem addOutput:propOutput];
	//	tell the player to actually load the item
	if ([NSThread isMainThread])	{
		[propPlayer replaceCurrentItemWithPlayerItem:newItem];
		//	begin playback
		[propPlayer setRate:1.0];
	}
	else	{
		dispatch_sync(dispatch_get_main_queue(), ^{
			NSLog(@"\t\treplacing the item in the player");
			VVLockLock(&propLock);
			[propPlayer replaceCurrentItemWithPlayerItem:propItem];
			//	begin playback
			[propPlayer setRate:1.0];
			VVLockUnlock(&propLock);
		});
	}
	//CMTime		durationCMTime = [item duration];
	//durationInSeconds = CMTimeGetSeconds(durationCMTime);
	//	register to receive "played to end" notifications on the new item
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:propItem];
	
	VVLockUnlock(&propLock);
	
	[self start];
}
- (void) stop	{
	//	remove myself for "played to end" notifications
	VVLockLock(&propLock);
	id			localPropItem = (propItem==nil) ? nil : [propItem retain];
	VVLockUnlock(&propLock);
	if (localPropItem != nil)	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:localPropItem];
		if ([NSThread isMainThread])	{
			VVLockLock(&propLock);
			[propPlayer replaceCurrentItemWithPlayerItem:nil];
			VVLockUnlock(&propLock);
		}
		else	{
			dispatch_sync(dispatch_get_main_queue(), ^{
				VVLockLock(&propLock);
				[propPlayer replaceCurrentItemWithPlayerItem:nil];
				VVLockUnlock(&propLock);
			});
		}
		
		VVLockLock(&propLock);
		if (propOutput != nil)
			[propItem removeOutput:propOutput];
		VVLockUnlock(&propLock);
		
		[localPropItem release];
		localPropItem = nil;
	}
	
	[super stop];
}
- (VVBuffer *) allocBuffer	{
	VVBuffer		*returnMe = nil;
	VVLockLock(&propLock);
	
	
	CMTime				frameMachTime = [propOutput itemTimeForMachAbsoluteTime:mach_absolute_time()];
	if ([propOutput hasNewPixelBufferForItemTime:frameMachTime])	{
		//NSLog(@"\t\toutput has new pixel buffer");
		CMTime				frameDisplayTime = kCMTimeZero;
		CVPixelBufferRef	pb = [propOutput copyPixelBufferForItemTime:frameMachTime itemTimeForDisplay:&frameDisplayTime];
		if (pb != NULL)	{
			//	make a new buffer from the CVPixelBuffer, then release the CVPixelBuffer
			returnMe = [_globalVVBufferPool allocBufferForCVPixelBuffer:pb texRange:YES ioSurface:NO];
			[returnMe setFlipped:YES];
			[VVBufferPool pushTexRangeBufferRAMtoVRAM:returnMe usingContext:[_globalVVBufferPool CGLContextObj]];
			CVPixelBufferRelease(pb);
			pb = NULL;
		}
		else	{
			//NSLog(@"\t\terr: couldn't copy pixel buffer, %s",__func__);
		}
	}
	else	{
		//NSLog(@"\t\toutput does NOT have a new pixel buffer");
	}
	
	
	VVLockUnlock(&propLock);
	return returnMe;
}
- (void) itemDidPlayToEnd:(NSNotification *)note	{
	NSLog(@"%s",__func__);
	VVLockLock(&propLock);
	[propPlayer seekToTime:kCMTimeZero];
	[propPlayer play];
	VVLockUnlock(&propLock);
}


@end

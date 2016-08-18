#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <VVBufferPool/VVBufferPool.h>
#import "VideoSource.h"




@interface MovieFileVideoSource : VideoSource	{
	AVPlayer					*propPlayer;
	AVPlayerItem				*propItem;
	AVPlayerItemVideoOutput		*propOutput;
}

- (void) loadFileAtPath:(NSString *)p;

@end

#import <Foundation/Foundation.h>
#import "AVPlayerItemHapDXTOutput.h"




/**
This subclass of AVAssetReaderTrackOutput works just like its super- you call "copyNextSampleBuffer" on it, and it returns a CMSampleBufferRef made with a CVPixelBufferRef containing RGBA/BGRA image data.  The class itself is basically a convenience- it simply uses an AVPlayerItemHapDXTOutput to decode and retrieve data, and as such is relatively lightweight.
*/
@interface AVAssetReaderHapTrackOutput : AVAssetReaderTrackOutput	{
	OSSpinLock						hapLock;
	AVPlayerItemHapDXTOutput		*hapDXTOutput;	//	this actually fetches & decodes samples of hap data
	CMTime							lastCopiedBufferTime;	//	my super sometimes vends samples with identical presentation times- this var exists so i can avoid adding buffers with duplicate time stamps
}

@end

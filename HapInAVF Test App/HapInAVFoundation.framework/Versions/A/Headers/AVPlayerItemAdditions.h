#import <AVFoundation/AVFoundation.h>



/// convenience method that makes it easier to recognize AVFoundation resources that contain hap video data
@interface AVPlayerItem (HapInAVFAVPlayerItemAdditions)

/**
Extends the AVPlayerItem class so instances will return their asset track- if any- that contains video data compressed using the hap video codec.
*/
- (AVAssetTrack *) hapTrack;

@end

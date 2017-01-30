#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>



/**
Class additions to AVAsset that simplify recognizing media containing Hap data
*/
@interface AVAsset (HapInAVFAVAssetAdditions)
/**
Returns a YES if the receiver contains a video track with Hap data.
*/
- (BOOL) containsHapVideoTrack;
/**
Returns an array populated with instances of AVAssetTrack that contain Hap data.
*/
- (NSArray *) hapVideoTracks;
@end




/**
Class additions to AVAssetTrack that simplify recognizing tracks containing Hap data
*/
@interface AVAssetTrack (HapInAVFAVAssetTrackAdditions)
/**
Returns a YES if the receiver contains video data compressed using the Hap codec.
*/
- (BOOL) isHapTrack;
@end

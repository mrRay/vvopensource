#import <Cocoa/Cocoa.h>

#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>

#include "HapPlatform.h"




/*			if you're reading this, these are the headers that you're probably going to want to look at			*/

#include "PixelFormats.h"
#include "HapCodecSubTypes.h"

#import "CMBlockBufferPool.h"

#import "AVPlayerItemHapDXTOutput.h"
#import "AVAssetReaderHapTrackOutput.h"
#import "HapDecoderFrame.h"
#import "AVPlayerItemAdditions.h"
#import "AVAssetAdditions.h"

#import "AVAssetWriterHapInput.h"





#if defined(__APPLE__)
#define HAP_GPU_DECODE
#else
#define HAP_SQUISH_DECODE
#endif

#ifndef HAP_GPU_DECODE
    #ifndef HAP_SQUISH_DECODE
        #error Neither HAP_GPU_DECODE nor HAP_SQUISH_DECODE is defined. #define one or both.
    #endif
#endif













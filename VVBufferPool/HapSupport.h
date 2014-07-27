/*
 HapSupport.h
 Hap QuickTime Playback
 
 Copyright (c) 2012-2013, Tom Butterworth and Vidvox LLC. All rights reserved.
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the name of Hap nor the name of its contributors
 may be used to endorse or promote products derived from this software
 without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */




#if __LP64__
//#error Hap QuickTime support requires 32-bit QuickTime APIs but this target is 64-bit
#else


#ifndef QTMultiGPUTextureIssue_HapSupport_h
#define QTMultiGPUTextureIssue_HapSupport_h




#import <CoreFoundation/CoreFoundation.h>
#import <QuickTime/QuickTime.h>



/**
 The four-character-codes used to describe the pixel-formats of DXT frames emitted by the Hap QuickTime codec.
 */
#define kHapPixelFormatTypeRGB_DXT1 'DXt1'
#define kHapPixelFormatTypeRGBA_DXT5 'DXT5'
#define kHapPixelFormatTypeYCoCg_DXT5 'DYt5'

/*
 These are the four-character-codes used to designate the three Hap codecs
 */
#define kHapCodecSubType 'Hap1'
#define kHapAlphaCodecSubType 'Hap5'
#define kHapYCoCgCodecSubType 'HapY'

/**
 Returns true if any track of movie is a Hap track and the codec is installed to handle it, otherwise false.
 */
Boolean HapQTQuickTimeMovieHasHapTrackPlayable(Movie movie);

#ifdef __OBJC__
/**
 Returns YES if any track of movie is a Hap track and the codec is installed to handle it, otherwise NO.
 */
#define HapQTMovieHasHapTrackPlayable(m) ((BOOL)HapQTQuickTimeMovieHasHapTrackPlayable([(m) quickTimeMovie]))
#endif

/**
 Returns a dictionary suitable to pass with the kQTVisualContextPixelBufferAttributesKey in an options dictionary when
 creating a CVPixelBufferContext.
 */
CFDictionaryRef HapQTCreateCVPixelBufferOptionsDictionary();




#endif	//	ifndef QTMultiGPUTextureIssue_HapSupport_h

#endif	//	ifndef __LP64__

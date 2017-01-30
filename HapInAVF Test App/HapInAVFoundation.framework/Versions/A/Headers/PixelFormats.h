/*
 PixelFormats.h
 Hap Codec

 Copyright (c) 2012-2013, Tom Butterworth and Vidvox LLC. All rights reserved. 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
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

#ifndef HapCodec_PixelFormats_h
#define HapCodec_PixelFormats_h

/*
 S3TC RGB DXT1
 */
#define kHapCVPixelFormat_RGB_DXT1 'DXt1'

/*
 S3TC RGBA DXT5
 */
#define kHapCVPixelFormat_RGBA_DXT5 'DXT5'

/*
 Scaled YCoCg in S3TC RGBA DXT5
 */
#define kHapCVPixelFormat_YCoCg_DXT5 'DYt5'

/*
 YCoCg stored Co Cg _ Y
 
 This is only accepted by the compressor, never emitted
 */
#define kHapCVPixelFormat_CoCgXY 'CCXY'

/*
 Planar Scaled YCoCg in SRTC RGBA DXT5 + Alpha in RGTC1
 */
#define kHapCVPixelFormat_YCoCg_DXT5_A_RGTC1 'DYtA'

/*
 Alpha stored in RGTC1

 This is not advertised and the value is only used by the squish encoder
 */
#define kHapCVPixelFormat_A_RGTC1 'RGA1'

/*		CoreVideo requires us to "register" the DXT pixel format- if this isn't done, the various CV-related resources won't recognize it as a valid pixel format and stuff won't work.  this function only needs to be called once, before you do anything with hap.  the framework does this automatically in the +initialize methods of AVPlayerItemHapDXTOutput and AVAssetWriterHapInput.		*/
void HapCodecRegisterDXTPixelFormat(OSType fmt, short bits_per_pixel, SInt32 open_gl_internal_format, Boolean has_alpha);
void HapCodecRegisterYCoCgPixelFormat(void);
void HapCodecRegisterPixelFormats(void);


#endif

/*
 HapPlatform.h
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

#if defined(__APPLE__)
    #include <Availability.h>
    #define HAP_ATTR_UNUSED __attribute__((unused))
    #define HAP_FUNC __func__
    #define HAP_ALIGN_16 __attribute__((aligned (16)))
    #if !defined(DEBUG)
        #define HAP_INLINE inline __attribute__((__always_inline__))
    #else
        #define HAP_INLINE inline
    #endif
    #if defined(MAC_OS_X_VERSION_MIN_REQUIRED) && MAC_OS_X_VERSION_MIN_REQUIRED >= 1070
        #define HAP_SSSE3_ALWAYS_AVAILABLE
    #endif
#else
    #define HAP_ATTR_UNUSED
    #define HAP_FUNC __FUNCTION__
    #define HAP_ALIGN_16 __declspec(align(16))
    #if defined(NDEBUG)
        #define HAP_INLINE __forceinline
    #elif defined(__cplusplus)
        #define HAP_INLINE inline
    #else
        #define HAP_INLINE __inline
    #endif
#endif

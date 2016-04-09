#import "QTVideoSource.h"




@implementation QTVideoSource


- (id) init	{
	if (self = [super init])	{
		movie = nil;
		glContext = nil;
		visualContext = nil;
		hapQSwizzler = nil;
		return self;
	}
	[self release];
	return nil;
}
- (void) loadFileAtPath:(NSString *)p	{
	NSLog(@"%s ... %@",__func__,p);
	@synchronized (self)	{
		//	free all the resources associated with the old movie
		if (movie != nil)	{
			SetMovieVisualContext([movie quickTimeMovie], NULL);
			[movie release];
			movie = nil;
		}
		if (visualContext != nil)	{
			QTVisualContextRelease(visualContext);
			visualContext = nil;
		}
		if (glContext != nil)	{
			[glContext release];
			glContext = nil;
		}
		//	make a new GL context
		NSOpenGLPixelFormat		*pf = [GLScene defaultPixelFormat];
		glContext = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:[[VVBufferPool globalVVBufferPool] sharedContext]];
		//	make a new hapQ swizzler
		hapQSwizzler = [[ISFGLScene alloc] initWithSharedContext:[[VVBufferPool globalVVBufferPool] sharedContext]];
		//[hapQSwizzler useFile:[[NSBundle mainBundle] pathForResource:@"ScaledCoCgYtoRGBA" ofType:@"fs"]];
		//	make a movie
		OSStatus	err = noErr;
		NSURL		*pathURL = [NSURL fileURLWithPath:p];
		movie = [[QTMovie alloc] initWithURL:pathURL error:nil];
		[movie setAttribute:[NSNumber numberWithBool:YES] forKey:QTMovieLoopsAttribute];
		//	make the visual context
		//	...if the movie can use hap, we're going to use a slightly different rendering pipeline
		if (HapQTMovieHasHapTrackPlayable(movie))	{
			NSDictionary		*pbAttribs = (NSDictionary *)HapQTCreateCVPixelBufferOptionsDictionary();
			NSDictionary		*vcAttribs = OBJDICT(pbAttribs, (NSString *)kQTVisualContextPixelBufferAttributesKey);
			CFRelease((CFDictionaryRef)pbAttribs);
			pbAttribs = nil;
			err = QTPixelBufferContextCreate(kCFAllocatorDefault, (CFDictionaryRef)vcAttribs, &visualContext);
			if (err != noErr)	{
				NSLog(@"\t\terr %ld at A in %s",err,__func__);
				return;
			}
			
			//	get the hap codec type- if it's HapQ or HapQ alpha, we're going to need to load a shader to convert the image...
			switch (HapCodecType([movie quickTimeMovie]))	{
			case kHapCodecSubType:
			case kHapAlphaCodecSubType:
			case kHapAOnlyCodecSubType:
				break;
			case kHapYCoCgCodecSubType:
				[hapQSwizzler useFile:[[NSBundle mainBundle] pathForResource:@"ScaledCoCgYtoRGBA" ofType:@"fs"]];
				break;
			case kHapYCoCgACodecSubType:
				[hapQSwizzler useFile:[[NSBundle mainBundle] pathForResource:@"ScaledCoCgYplusAtoRGBA" ofType:@"fs"]];
				break;
			}
		}
		//	else this movie doesn't have a hap video track- we're going to use a standard visual context
		else	{
			err = QTOpenGLTextureContextCreate(kCFAllocatorDefault, [glContext CGLContextObj], [pf CGLPixelFormatObj], nil, &visualContext);
			if (err != noErr)	{
				NSLog(@"\t\terr %ld at B in %s",err,__func__);
				return;
			}
		}
		
		//	...if i'm here, i made the VC- proceed with associating the movie with the VC, and then finally beginning playback
		
		err = SetMovieVisualContext([movie quickTimeMovie], visualContext);
		if (err != noErr)	{
			NSLog(@"\t\terr %ld at C in %s",err,__func__);
			return;
		}
		[movie play];
	}
}
- (VVBuffer *) allocNewFrame	{
	//NSLog(@"%s",__func__);
	VVBuffer		*returnMe = nil;
	@synchronized (self)	{
		if (movie==nil || glContext==nil || visualContext==nil)
			return returnMe;
		//	if there's a new image available
		if (QTVisualContextIsNewImageAvailable(visualContext,NULL))	{
			//	copy the image to an image buffer
			CVImageBufferRef	imgRef = NULL;
			OSStatus			err = QTVisualContextCopyImageForTime(visualContext, NULL, NULL, &imgRef);
			if (err != noErr)	{
				NSLog(@"\t\terr %ld at %s",err,__func__);
				return returnMe;
			}
			//	if there's an image buffer
			if (imgRef != NULL)	{
				CFTypeID			imgRefType = CFGetTypeID(imgRef);
				OSType		imgPixelFormat = CVPixelBufferGetPixelFormatType(imgRef);
				//	if the image buffer is already a GL texture...
				if (imgRefType == CVOpenGLTextureGetTypeID())	{
					//	just wrap the CoreVideo GL texture with VVBuffer.  AVFoundation rendering is handled the same way- use apple APIs to get a CV GL texture, then create a VVBuffer from it.
					returnMe = [[VVBufferPool globalVVBufferPool] allocBufferForCVGLTex:imgRef];
				}
				//	else if the image buffer is a pixel buffer (hap)
				else if (imgRefType == CVPixelBufferGetTypeID())	{
					if (imgPixelFormat == kHapPixelFormatTypeYCoCg_DXT5)	{
						VVBuffer		*yCoCg = [[VVBufferPool globalVVBufferPool] allocTexRangeForPlane:0 ofHapCVImageBuffer:imgRef];
						[hapQSwizzler setFilterInputImageBuffer:yCoCg];
						returnMe = [hapQSwizzler allocAndRenderToBufferSized:[yCoCg srcRect].size];
						VVRELEASE(yCoCg);
					}
					else if (imgPixelFormat == kHapPixelFormatType_YCoCg_DXT5_A_RGTC1)	{
						VVBuffer		*yCoCg = [[VVBufferPool globalVVBufferPool] allocTexRangeForPlane:0 ofHapCVImageBuffer:imgRef];
						VVBuffer		*alpha = [[VVBufferPool globalVVBufferPool] allocTexRangeForPlane:1 ofHapCVImageBuffer:imgRef];
						[hapQSwizzler setBuffer:alpha forInputImageKey:@"alphaImage"];
						[hapQSwizzler setFilterInputImageBuffer:yCoCg];
						returnMe = [hapQSwizzler allocAndRenderToBufferSized:[yCoCg srcRect].size];
						VVRELEASE(alpha);
						VVRELEASE(yCoCg);
					}
					else	{
						returnMe = [[VVBufferPool globalVVBufferPool] allocTexRangeForPlane:0 ofHapCVImageBuffer:imgRef];
					}
				}
				//	else- dunno
				else	{
					NSLog(@"\t\terr, unrecognized, %s",__func__);
					return returnMe;
				}
				//	release the image buffer!
				CVBufferRelease(imgRef);
			}
			
			//	task the visual context
			QTVisualContextTask(visualContext);
		}
	}
	return returnMe;
}


@end

#import <Cocoa/Cocoa.h>
#import <VVBufferPool/VVBufferPool.h>
#import <VVISFKit/VVISFKit.h>
#import <HapInAVFoundation/HapInAVFoundation.h>
#import <AVFoundation/AVFoundation.h>




@interface HapInAVFAppDelegate : NSObject <NSApplicationDelegate>	{
	IBOutlet NSWindow			*window;
	IBOutlet VVBufferGLView		*view;
	
	CVDisplayLinkRef			displayLink;	//	this "drives" rendering
	NSOpenGLContext				*sharedCtx;	//	GL contexts must be in the same sharegroup to share textures between them
	CVOpenGLTextureCacheRef		texCache;
	
	AVPlayer					*player;
	AVPlayerItem				*playerItem;
	BOOL						videoPlayerItemIsHap;
	AVPlayerItemVideoOutput		*nativeAVFOutput;	//	used if the file being played back is supported natively by AVFoundation
	AVPlayerItemHapDXTOutput	*hapOutput;	//	used if the file being played back has a hap track of some sort
	
	ISFGLScene					*swizzleScene;	//	used to convert YCoCg (HapQ) and YCoCg+A (HapQ+A) to RGBA
	
	VVBuffer					*lastRenderedBuffer;
}



- (BOOL) loadFileAtPath:(NSString *)n;
- (BOOL) loadFileAtURL:(NSURL *)n;
- (BOOL) loadAsset:(AVAsset *)n;

- (void) renderCallback;

- (VVBuffer *)allocBuffer;

@end





CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);

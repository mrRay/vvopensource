#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>




@interface AppDelegate : NSObject <NSApplicationDelegate>	{
	CVDisplayLinkRef			displayLink;
	NSOpenGLContext				*sharedContext;
	IBOutlet VVBufferGLView		*bufferView;
	
	CIFilter			*checkerboardSrc;
	CIGLScene			*ciScene;	//	this renders a CIImage to a GL texture
	VVStopwatch			*swatch;	//	used to animate the size of the checkerboard
}

- (void) renderCallback;

@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);

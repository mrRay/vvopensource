#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>




@interface TexRangeGLtoCPUtoGLAppDelegate : NSObject <NSApplicationDelegate>	{
	CVDisplayLinkRef			displayLink;
	NSOpenGLContext				*sharedContext;
	IBOutlet VVBufferGLView		*rawGLView;
	IBOutlet NSImageView		*cpuImageWell;
	
	QCGLScene			*qcScene;
	VVStopwatch			*swatch;	//	used to animate the speed of the QC comp
	
	//SwizzleNode				*swizzleNode;	//	used to swizzle BGRA (GL textures) to GRAB (expected by NSBitmap stuff)
	TexRangeGLCPUStreamer	*glToCPU;
}

- (void) renderCallback;

@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);

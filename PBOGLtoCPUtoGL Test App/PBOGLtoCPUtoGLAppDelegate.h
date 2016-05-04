#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>




@interface PBOGLtoCPUtoGLAppDelegate : NSObject <NSApplicationDelegate>	{
	CVDisplayLinkRef			displayLink;
	NSOpenGLContext				*sharedContext;
	IBOutlet VVBufferGLView		*rawGLView;
	IBOutlet NSImageView		*cpuImageWell;
	IBOutlet VVBufferGLView		*reconstitutedGLView;
	
	QCGLScene			*qcScene;
	VVStopwatch			*swatch;	//	used to animate the speed of the QC comp
	
	PBOGLCPUStreamer	*glToCPU;
	PBOCPUGLStreamer	*cpuToGL;
}

- (void) renderCallback;

@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);

#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>




@interface AppDelegate : NSObject <NSApplicationDelegate>	{
	CVDisplayLinkRef			displayLink;
	NSOpenGLContext				*sharedContext;
	IBOutlet VVBufferGLView		*bufferView;
	IBOutlet VVBufferGLView		*msaaBufferView;
	
	QCGLScene			*qcScene;	//	this scene renders into a GL texture
	QCGLScene			*msaaQCScene;	//	this scene also renders into a texture, but uses MSAA to produce a "smoother" image
	VVStopwatch			*swatch;	//	used to animate the speed of the QC comp
}

- (void) renderCallback;

@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);

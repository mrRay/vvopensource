#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>




@interface AppDelegate : NSObject <NSApplicationDelegate>	{
	CVDisplayLinkRef			displayLink;
	NSOpenGLContext				*sharedContext;
	IBOutlet VVBufferGLView		*bufferView;
	
	VVBuffer			*imgBuffer;	//	this VVBuffer is created from a PNG file included with this application
	GLScene				*glScene;	//	you can use this to render GL content to a texture
	VVStopwatch			*swatch;	//	used to animate the size of the checkerboard
}

- (void) renderCallback;

@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);

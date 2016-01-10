#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>




@interface GLShaderSceneTestAppDelegate : NSObject <NSApplicationDelegate>	{
	CVDisplayLinkRef			displayLink;
	NSOpenGLContext				*sharedContext;
	IBOutlet VVBufferGLView		*bufferView;
	
	CIFilter			*checkerboardSrc;
	CIGLScene			*ciScene;	//	this renders a CIImage to a GL texture
	GLShaderScene		*glslScene;	//	this uses a GLSL program to apply a "motion blur" to the video from "ciScene"
	VVBuffer			*ciBuffer;	//	only non-nil during a rendering callback (retained, just in case).  when you rener ciScene to a buffer, you render to this buffer.  an instance var in the class because the shader scene callback needs a way to retrieve the latest-rendered image from CI
	VVBuffer			*accumBuffer;	//	the GLSL scene renders into this buffer, which we keep and pass to the shader each frame to acheive the motion blur
	VVStopwatch			*swatch;	//	used to animate the size of the checkerboard
}

- (void) renderCallback;

@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);

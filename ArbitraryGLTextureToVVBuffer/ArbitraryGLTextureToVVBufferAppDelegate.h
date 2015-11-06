#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>
#import <VVISFKit/VVISFKit.h>



/*	this app demonstrates how to create a VVBuffer from a raw openGL texture (expressed as a GLuint), and how to pass that VVBuffer through a chain of two ISF filters		*/

@interface ArbitraryGLTextureToVVBufferAppDelegate : NSObject <NSApplicationDelegate>	{
	CVDisplayLinkRef			displayLink;
	NSOpenGLContext				*sharedContext;
	
	GLuint				texture;	//	we're going to create this GL texture, upload an image to it, and then create a VVBuffer from it
	NSSize				textureSize;	//	populated when we upload the image to the texture- this is the size of the texture
	
	ISFGLScene			*fxSceneA;	//	this ISF scene applies "CMYK Halftone-Lookaround.fs" to the VVBuffer we create from the raw GL texture
	ISFGLScene			*fxSceneB;	//	this ISF scene applies "Bad TV.fs" to the image produced by "fxSceneA"
	
	IBOutlet VVBufferGLView		*basicVVBufferView;
	IBOutlet VVBufferGLView		*firstFXView;
	IBOutlet VVBufferGLView		*secondFXView;
}

//	this method creates a GL texture, and then uploads an image included with this app (SampleImg.png) to it.  nothing in this method uses VVBufferPool.  this method generates the texture that we demonstrate on.
- (void) loadTheImageIntoATexture;

//	the displaylink calls this method- this is where we render/draw stuff
- (void) renderCallback;

@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);


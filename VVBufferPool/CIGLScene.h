#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLMacro.h>
#import <Quartz/Quartz.h>
#import <VVBasics/VVBasics.h>
#import "GLScene.h"




@protocol CIGLSceneCleanup
- (void) cleanupCIGLScene:(id)scene;
@end




///	Subclass of GLScene for working with CoreImage resources.  As written, the API renders CIImages to VVBuffers (typically textures of some sort), since this seems to be the easiest way to work with CI resources.  Can be easily modified to render directly in a view.
/**
\ingroup VVBufferPool
*/
@interface CIGLScene : GLScene {
	CGColorSpaceRef			workingColorSpace;
	CGColorSpaceRef			outputColorSpace;
	CIContext				*ciContext;
	
	id <CIGLSceneCleanup>	cleanupDelegate;	//	nil, NOT RETAINED
}

///	Allocates a VVBuffer for a GL texture at the current size of this scene, then renders the passed CIImage into this texture
- (VVBuffer *) allocAndRenderBufferFromImage:(CIImage *)i;
- (void) renderCIImage:(CIImage *)i;
- (void) renderCIImage:(CIImage *)i inFBO:(GLuint)f colorTex:(GLuint)t;
///	this is the more low-level method for rendering a CIImage into explicitly-provided GL resources
/**
@param i the CIImage you wish to render to a GL resource
@param f the name of the fbo to which we'll be attaching the gl resources you want to render into
@param t the name of a GL texture that will be used as a color attachment to FBO f
@param tt the texture target of 't' (GL_TEXTURE_2D or GL_TEXTURE_RECTANGLE_EXT)
*/
- (void) renderCIImage:(CIImage *)i inFBO:(GLuint)f colorTex:(GLuint)t target:(GLuint)tt;

@property (readonly) CGColorSpaceRef workingColorSpace;
@property (readonly) CGColorSpaceRef outputColorSpace;
@property (readonly) CIContext *ciContext;
@property (assign,readwrite) id <CIGLSceneCleanup> cleanupDelegate;

@end

#import <TargetConditionals.h>
#import <Foundation/Foundation.h>
#import "GLScene.h"
#if !TARGET_OS_IPHONE
#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLMacro.h>
#else
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES3/glext.h>
#endif
#import <pthread.h>




///	Subclass of GLScene for working with vertex & frag shaders- just give it some shader strings and watch it go!
/**
\ingroup VVBufferPool
*/
@interface GLShaderScene : GLScene {
	BOOL			vertexShaderUpdated;
	BOOL			fragmentShaderUpdated;
	GLenum			program;
	GLenum			vertexShader;
	GLenum			fragmentShader;
	NSString		*vertexShaderString;
	NSString		*fragmentShaderString;
	
	pthread_mutex_t			renderLock;
	
	OSSpinLock				errDictLock;
	NSMutableDictionary		*errDict;
}

///	Set/get the vertex shader string
@property (retain,readwrite) NSString *vertexShaderString;
///	Set/get the fragment shader string
@property (retain,readwrite) NSString *fragmentShaderString;

@property (assign,readwrite) BOOL vertexShaderUpdated;
@property (assign,readwrite) BOOL fragmentShaderUpdated;
///	the (GL) name of the program after the frag shaders have been compiled and linked
@property (readonly) GLenum program;
///	the (GL) name of the vertex shader after it's been compiled 
@property (readonly) GLenum vertexShader;
///	the (GL) name of the fragment shader after it's been compiled
@property (readonly) GLenum fragmentShader;

@end

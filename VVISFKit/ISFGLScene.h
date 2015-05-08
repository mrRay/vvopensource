#import <Cocoa/Cocoa.h>
#import <VVBufferPool/VVBufferPool.h>
#import "ISFAttrib.h"
#import <VVBasics/VVBasics.h>
#import "ISFTargetBuffer.h"
#import "ISFRenderPass.h"




//	key is path to the file, object is VVBuffer instance.  the userInfo of this VVBuffer instance has an NSNumber, which serves as its "retain count": it's incremented when the buffer is loaded/created, and decremented when it's deleted- when it hits 0, the file is removed from the dict entirely.
extern MutLockDict		*_ISFImportedImages;
extern NSString			*_ISFVertPassthru;	//	passthru vertex shader
extern NSString			*_ISFVertVarDec;	//	string declaring functions and variables for the vertex shader, imported from a .txt file in this framework.  "pasted" into the assembled vertex shader.
extern NSString 		*_ISFVertInitFunc;	//	string of source code that performs variable initialization and general environment setup for the vertex shader, imported from a .txt file in this framework, and "pasted" into the vertex shader during its assembly.
extern NSString			*_ISFMacro2DString;	//	string of source containing function bodies that fetch pixel data from a (2D) GL texture.  IMGNORM and IMGPIXEL actually call one of these "Macro" functions.
extern NSString			*_ISFMacro2DBiasString;	//	same as above, slightly different texture format
extern NSString			*_ISFMacro2DRectString;	//	same as above, slightly different texture format
extern NSString			*_ISFMacro2DRectBiasString;	//	same as above, slightly different texture format




///	Subclass of GLShaderScene- loads and renders ISF files
/**
\ingroup VVISFKit
*/
@interface ISFGLScene : GLShaderScene	{
	BOOL				throwExceptions;	//	NO by default
	
	OSSpinLock			propertyLock;	//	locks the file* vars and categoryNames (everything before the empty line)
	NSString			*filePath;	//	full path to the loaded file
	NSString			*fileName;	//	just the file name (including its extension)
	NSString			*fileDescription;	//	description of whatever the file does
	NSString			*fileCredits;	//	credits
	NSMutableArray		*categoryNames;	//	array of NSStrings of the category names this filter should be listed under
	
	MutLockArray		*inputs;	//	array of ISFAttrib instances for the various inputs
	MutLockArray		*imageInputs;	//	array of ISFAttrib instances for the image inputs (the image inputs are stored in two arrays).
	MutLockArray		*imageImports;	//	array of ISFAttrib instances that describe imported images. 'attribName' is the name of the sampler, 'attribDescription' is the path to the file.
	
	NSSize				renderSize;	//	the last size at which i was requested to render a buffer (used to produce vals from normalized point inputs that need a render size to be used)
	VVStopwatch			*swatch;	//	used to pass time to shaders
	double				renderTime;
	BOOL				bufferRequiresEval;	//	NO by default, set to YES during file open if any of the buffers require evaluation (faster than checking every single buffer every pass)
	MutLockArray		*persistentBufferArray;	//	array of ISFTargetBuffer instances describing the various persistent buffers. these buffers are retained until a different file is loaded.
	MutLockArray		*tempBufferArray;	//	array of ISFTargetBuffer instances- temp buffers are available while rendering, but are returned to the pool when rendering's complete
	MutLockArray		*passes;	//	array of ISFRenderPass instances.  right now, passes basically just describe a (ISFTargetBuffer)
	
	int					passIndex;	//	only has a valid value while rendering
	
	OSSpinLock			srcLock;
	NSString			*jsonString;	//	the raw JSON string copied from the source
	NSString			*vertShaderSource;	//	the raw vert shader source before being find-and-replaced
	NSString			*fragShaderSource;	//	the raw frag shader source before being find-and-replaced
	NSString			*compiledInputTypeString;	//	a sequence of characters, either "2" or "R", one character for each input image. describes whether the shader was compiled to work with 2D textures or RECT textures.
	long				renderSizeUniformLoc;	//	-1, or the location of the uniform var in the compiled GL program for the render size
	long				passIndexUniformLoc;	//	-1, or the location of the uniform var in the compiled GL program for the pass index
	long				timeUniformLoc;	//	-1, or the location of the uniform var in the compiled GL program for the time in seconds
}

- (id) initWithSharedContext:(NSOpenGLContext *)c;
- (id) initWithSharedContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p sized:(NSSize)s;

///	Loads the ISF .fs file at the passed path
- (void) useFile:(NSString *)p;
- (void) useFile:(NSString *)p resetTimer:(BOOL)r;

///	if an ISF file has an input at the specified key, retains the buffer to be used at that input on the next rendering pass
/**
@param b the VVBuffer instance you want to send to the ISF file
@param k an NSString with the name of the image input you want to pass the VVBuffer to
*/
- (void) setBuffer:(VVBuffer *)b forInputImageKey:(NSString *)k;
///	convenience method- if the ISF file is an image filter (which has an explicitly-named image input), this applies the passed buffer to the filter input
- (void) setFilterInputImageBuffer:(VVBuffer *)b;
///	retrieves the current buffer being used at the passed key
- (VVBuffer *) bufferForInputImageKey:(NSString *)k;
- (void) purgeInputGLTextures;
///	applies the passed value to the input with the passed key
/**
@param n the value you want to pass, as an ISFAttribVal union
@param k the key of the input you want to pass the value to
*/
- (void) setValue:(ISFAttribVal)n forInputKey:(NSString *)k;
///	applies the passed value to the input with the passed key
/**
@param n the value you want to pass, as an NSObject of some sort.  if it's a color, pass NSColor- if it's a point, pass an NSValue created from an NSPoint- if it's an image, pass a VVBuffer- else, pass an NSNumber.
@param k the key of the input you want to pass the value to.
*/
- (void) setNSObjectVal:(id)n forInputKey:(NSString *)k;
///	returns an array with all the inputs matching the passed type
/**
@param t the type of attributes you want returned
*/
- (NSMutableArray *) inputsOfType:(ISFAttribValType)t;
///	returns a ptr to the ISFAttrib instance used by this scene which describes the input at the passed key
- (ISFAttrib *) attribForInputWithKey:(NSString *)k;

- (ISFTargetBuffer *) findPersistentBufferNamed:(NSString *)n;
- (ISFTargetBuffer *) findTempBufferNamed:(NSString *)n;

///	allocates and renders into a buffer/GL texture of the passed size, then returns the buffer
- (VVBuffer *) allocAndRenderToBufferSized:(NSSize)s;
- (VVBuffer *) allocAndRenderToBufferSized:(NSSize)s prefer2DTex:(BOOL)wants2D;
- (VVBuffer *) allocAndRenderToBufferSized:(NSSize)s prefer2DTex:(BOOL)wants2D passDict:(NSMutableDictionary *)d;
- (VVBuffer *) allocAndRenderToBufferSized:(NSSize)s prefer2DTex:(BOOL)wants2D renderTime:(double)t;
- (VVBuffer *) allocAndRenderToBufferSized:(NSSize)s prefer2DTex:(BOOL)wants2D renderTime:(double)t passDict:(NSMutableDictionary *)d;
- (void) renderToBuffer:(VVBuffer *)b sized:(NSSize)s;
///	lower-level rendering method- you have to provide your own buffer, explicitly state the size at which you want to render this scene, give it a render time, and supply an optional dictionary in which the various render passes will be stored
/**
@param b the buffer to render into.  it's your responsibility to make sure that thsi is the appropriate type of buffer (should be a texture)
@param s the size at which you want the scene to render
@param t the time at which you want the scene to render, in seconds
@param d a mutable dictionary, into which the output of the various render passes will be stored
*/
- (void) renderToBuffer:(VVBuffer *)b sized:(NSSize)s renderTime:(double)t passDict:(NSMutableDictionary *)d;
- (void) render;

- (void) _assembleShaderSource;
- (NSMutableString *) _assembleShaderSource_VarDeclarations;
- (NSMutableDictionary *) _assembleSubstitutionDict;
- (void) _clearImageImports;

@property (assign,readwrite) BOOL throwExceptions;
///	returns the path of the currently-loaded ISF file
@property (readonly) NSString *filePath;
///	returns the name of the currently-loaded ISF file
@property (readonly) NSString *fileName;
///	returns a string with the description (pulled from the JSON blob) of the ISF file
@property (readonly) NSString *fileDescription;
///	returns a string with the credits (pulled from the JSON blob) of the ISF file
@property (readonly) NSString *fileCredits;
///	returns an array with the category names (as NSStrings) of this ISF file.  pulled from the JSON blob.
@property (readonly) NSMutableArray *categoryNames;
///	returns a MutLockArray (from VVBasics) of ISFAttrib instances, one for each of the inputs
@property (readonly) MutLockArray *inputs;
///	returns a MutLockArray (from VVBasics) of all the image-type (ISFAT_Image) ISFAttrib instances, one for each input in the currently loaded ISF file
@property (readonly) MutLockArray *imageInputs;
@property (readonly) NSSize renderSize;
@property (readonly) int passCount;
@property (readonly) int imageInputsCount;
@property (readonly) NSString *jsonString;
@property (readonly) NSString *vertShaderSource;
@property (readonly) NSString *fragShaderSource;

- (void) _renderLock;
- (void) _renderUnlock;

@end

/**
\file
*/
#import <Cocoa/Cocoa.h>




///	enum describing the different types of attributes listed in the ISF spec
/**
\ingroup VVISFKit
*/
typedef NS_ENUM(NSInteger, ISFAttribValType)	{
	ISFAT_Event,	//!<	no data, just an event.  sends a 1 the next render after the event is received, a 0 any other time it's rendered
	ISFAT_Bool,	//!<	a boolean choice, sends 1 or 0 to the shader
	ISFAT_Long,	//!<	sends a long
	ISFAT_Float,	//!<	sends a float
	ISFAT_Point2D,	//!<	sends a 2 element vector
	ISFAT_Color,	//!<	sends a 4 element vector representing an RGBA color
	ISFAT_Image,	//!<	a long- the texture number (like GL_TEXTURE0) to pass to the shader
	ISFAT_Cube 		//!<	a long- the texture number (like GL_TEXTURE0) of a cubemap texture to pass to the shader
};
///	union describing a value for one of the listed attribute types
/**
\ingroup VVISFKit
*/
typedef union ISFAttribVal	{
	BOOL			eventVal;		//!<	if this is an event attribute, set eventVal to YES
	BOOL			boolVal;	//!<	if this is a bool attribute, store the desired value here
	long			longVal;	//!<	if this is a long attribute, store the desired value here
	GLfloat			floatVal;	//!<	used if this is a float attribute
	GLfloat			point2DVal[2];	//!<	array of two floats, used if this is a point2D attribute
	GLfloat			colorVal[4];	//!<	array of four floats, used if this is a color attribute
	long			imageVal;	//!<	not really used- you never pass images as values (images are passed as VVBuffers, as there are resources that need to be retained and can't be passed strictly "by value").  included for symmetry.
} ISFAttribVal;




///	internally, an ISFGLScene creates an ISFAttrib for each of the declared inputs in an ISF file.  if you query an ISFGLScene's inputs- for introspection, for example- you'll get an array of ISFAttribs, which can be examined to learn more about the nature of the input
/**
\ingroup VVISFKit
*/
@interface ISFAttrib : NSObject	{
	NSString				*attribName;
	NSString				*attribDescription;
	NSString				*attribLabel;
	ISFAttribValType	attribType;
	ISFAttribVal		currentVal;
	ISFAttribVal		minVal;
	ISFAttribVal		maxVal;
	ISFAttribVal		defaultVal;
	ISFAttribVal		identityVal;
	NSMutableArray			*labelArray;	//	only used if it's a LONG. array containing NSStrings that correspond to the values in "valArray"
	NSMutableArray			*valArray;	//	only used if it's a LONG. array containing NSNumbers with the values that correspond to the accompanying labels
	BOOL					isFilterInputImage;	//	if YES, this is an image-type input and is the main input for an image filter
	id						userInfo;	//	retained- used to retain an NSObject-based GL resource for the lifetime of the input (retains an image for image attributes as a VVBuffer)
	int						uniformLocation[4];	//	the location of this attribute in the compiled GLSL program. cached here because lookup times are costly when performed every frame.  there are 4 because images require four uniforms (one of the texture name, one for the size, one for the img rect, and one for the flippedness)
}

//	creating attributes isn't really covered in the published documentation because you probably shouldn't be doing it from outside the framework.
+ (id) createWithName:(NSString *)n description:(NSString *)desc label:(NSString *)l type:(ISFAttribValType)t values:(ISFAttribVal)min :(ISFAttribVal) max :(ISFAttribVal)def :(ISFAttribVal)iden :(NSArray *)lArray :(NSArray *)vArray;
- (id) initWithName:(NSString *)n description:(NSString *)desc label:(NSString *)l type:(ISFAttribValType)t values:(ISFAttribVal)min :(ISFAttribVal) max :(ISFAttribVal)def :(ISFAttribVal)iden :(NSArray *)lArray :(NSArray *)vArray;

///	returns the name of the attribute- the name of the attribute is also the variable name in the source!
- (NSString *) attribName;
///	returns the description of the attribute (from the JSON blob) as an NSString
- (NSString *) attribDescription;
///	returns the label of the attribute (from the JSON blob) as an NSString
- (NSString *) attribLabel;
///	returns an ISFAttribValType describing what type of attribute this is (what kind of value/input it is)
- (ISFAttribValType) attribType;

///	returns the current value of this attribute.  not useful if this is an image attribute- if this is an image attribute, the most recently-stored VVBuffer is stored in its userInfo!
- (ISFAttribVal) currentVal;
///	copies the appropriate value from the union, based on the type of this attribute
- (void) setCurrentVal:(ISFAttribVal)n;
///	returns a union describing this attribute's min val
- (ISFAttribVal) minVal;
///	returns a union describing this attribute's max val
- (ISFAttribVal) maxVal;
///	returns a union describing this attribute's default val
- (ISFAttribVal) defaultVal;
///	returns a union describing this attribute's identity val
- (ISFAttribVal) identityVal;
///	only used if this is an ISFAT_Long-type attribute- returns an array containing labels (NSStrings) for each of the input values
- (NSMutableArray *) labelArray;
///	only used if this is an ISFAT_Long-type attribute- returns an array containing values (NSNumbers) for each of the input values
- (NSMutableArray *) valArray;

- (void) setIsFilterInputImage:(BOOL)n;
///	returns a YES if this attribute describes the default input for an image filter
- (BOOL) isFilterInputImage;

///	the userInfo is an arbitrary id that gets retained with the attribute- if this is an ISFAT_Image or an ISFAT_Cube, then this is probably used to store a VVBuffer with the current value
- (void) setUserInfo:(id)n;
///	returns the userInfo, an arbitrary id retained with this attribute
- (id) userInfo;
- (void) setUniformLocation:(int)n forIndex:(int)i;
- (int) uniformLocationForIndex:(int)i;
- (void) clearUniformLocations;

@end

#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>
#import <DDMathParser/DDExpression.h>




/*
		this class represents a target buffer for an ISF shader- it stores the VVBuffer (the GL 
		resource) as well as the expressions determining the width/height (the raw string, the 
		evaluated expression- capable of being executed with substitutions for variables, and the 
		evaluated value), and the cached uniform locations for this target buffer's attributes in 
		the compiled GL program (so you don't have to look up the uniform location every frame).
*/




@interface ISFTargetBuffer : NSObject	{
	NSString		*name;	//	the name of this buffer
	VVBuffer		*buffer;	//	nil, or the VVBuffer instance for this
	
	double			targetWidth;
	NSString		*targetWidthString;
	DDExpression	*targetWidthExpression;
	double			targetHeight;
	NSString		*targetHeightString;
	DDExpression	*targetHeightExpression;
	
	BOOL			floatFlag;	//	NO by default. if YES, makes float textures!
	
	int				uniformLocation[4];	//	the location of this attribute in the compiled GLSL program. cached here because lookup times are costly when performed every frame.  there are 4 because images require four uniforms (one of the texture name, one for the size, one for the img rect, and one for the flippedness)
}

+ (id) create;

- (void) setTargetSize:(NSSize)n;
- (void) setTargetSize:(NSSize)n createNewBuffer:(BOOL)c;
- (void) setTargetSize:(NSSize)n resizeExistingBuffer:(BOOL)r;
- (void) setTargetSize:(NSSize)n resizeExistingBuffer:(BOOL)r createNewBuffer:(BOOL)c;
- (void) setTargetWidthString:(NSString *)n;
- (void) setTargetHeightString:(NSString *)n;
- (void) setFloatFlag:(BOOL)n;
- (BOOL) floatFlag;
- (void) clearBuffer;

//	returns a YES if there's a target width string
- (BOOL) targetSizeNeedsEval;
- (void) evalTargetSizeWithSubstitutionsDict:(NSDictionary *)d;
- (void) evalTargetSizeWithSubstitutionsDict:(NSDictionary *)d resizeExistingBuffer:(BOOL)r;
- (void) evalTargetSizeWithSubstitutionsDict:(NSDictionary *)d resizeExistingBuffer:(BOOL)r createNewBuffer:(BOOL)c;

@property (retain,readwrite) NSString *name;
@property (retain,readwrite) VVBuffer *buffer;

- (NSSize) targetSize;

- (void) setUniformLocation:(int)n forIndex:(int)i;
- (int) uniformLocationForIndex:(int)i;
- (void) clearUniformLocations;

@end

/**
\file
*/
#import <TargetConditionals.h>
#import <Foundation/Foundation.h>
#import <VVBasics/VVBasics.h>



///	Different sizing modes
/**
\ingroup VVBufferPool
*/
typedef NS_ENUM(NSInteger,VVSizingMode)	{
	VVSizingModeFit = 0,	//!<	the content is made as large as possible, proportionally, without cutting itself off or going outside the bounds of the desired area
	VVSizingModeFill = 1,	//!<	the content is made as large as possible, proportionally, to fill the desired area- some of the content may get cut off
	VVSizingModeStretch = 2,	//!<	the content is scaled to fit perfectly within the desired area- some stretching or squashing may occur, this isn't necessarily proportional
	VVSizingModeCopy = 3	//!<	the content is copied directly to the desired area- it is not made any larger or smaller
};



///	Simplifies the act of generating transforms and other geometry-related data around the relatively common act of resizing one rect to fit inside another.
/**
\ingroup VVBufferPool
*/
@interface COM_VIDVOX_VVOPENSOURCE_VVSizingTool : NSObject {

}

///	Uses +[VVSizingTool rectThatFitsRect:inRect:sizingMode:] to determine the new rect coordinates, then creates and returns an NSAffineTransform that can be used to transform arbitrary geometry in the same fashion.
/**
	@param a	This is the rect that you want to resize
	@param b	This is the area you want to resize the rect to fit inside
	@param m	this is the sizing mode you want to use to resize rect "a" to be inside rect "b"
	@return	The returned value is what param/rect "a"'s coordinates would be given its dimensions and the supplied sizing mode.
*/
#if !TARGET_OS_IPHONE
+ (NSAffineTransform *) transformThatFitsRect:(VVRECT)a inRect:(VVRECT)b sizingMode:(VVSizingMode)m;
#endif
///	Uses +[VVSizingTool rectThatFitsRect:inRect:sizingMode:] to determine the new rect coordinates, then creates and returns the inverse transform of +[VVSizingTool transformThatFitsRect:inRect:sizingMode:]
/**
	@param a	This is the rect that you want to resize
	@param b	This is the area you want to resize the rect to fit inside
	@param m	this is the sizing mode you want to use to resize rect "a" to be inside rect "b"
	@return	The returned value is what param/rect "a"'s coordinates would be given its dimensions and the supplied sizing mode.
*/
#if !TARGET_OS_IPHONE
+ (NSAffineTransform *) inverseTransformThatFitsRect:(VVRECT)a inRect:(VVRECT)b sizingMode:(VVSizingMode)m;
#endif
/**
	@param a	This is the rect that you want to resize
	@param b	This is the area you want to resize the rect to fit inside
	@param m	this is the sizing mode you want to use to resize rect "a" to be inside rect "b"
	@return	The returned value is what param/rect "a"'s coordinates would be given its dimensions and the supplied sizing mode.
*/
+ (VVRECT) rectThatFitsRect:(VVRECT)a inRect:(VVRECT)b sizingMode:(VVSizingMode)m;

@end




@compatibility_alias VVSizingTool COM_VIDVOX_VVOPENSOURCE_VVSizingTool;

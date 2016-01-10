#import "VVSizingTool.h"




@implementation VVSizingTool


#if !TARGET_OS_IPHONE
+ (NSAffineTransform *) transformThatFitsRect:(VVRECT)a inRect:(VVRECT)b sizingMode:(VVSizingMode)m	{
	VVRECT				r = [VVSizingTool rectThatFitsRect:a inRect:b sizingMode:m];
	NSAffineTransform	*returnMe = [NSAffineTransform transform];
	NSAffineTransform	*tmp = nil;
	
	tmp = [NSAffineTransform transform];
	[tmp translateXBy:-1*a.origin.x yBy:-1*a.origin.y];
	[returnMe appendTransform:tmp];
	
	tmp = [NSAffineTransform transform];
	[tmp scaleXBy:r.size.width/a.size.width yBy:r.size.height/a.size.height];
	[returnMe appendTransform:tmp];
	
	tmp = [NSAffineTransform transform];
	[tmp translateXBy:r.origin.x yBy:r.origin.y];
	[returnMe appendTransform:tmp];
	
	return returnMe;
}
#endif
#if !TARGET_OS_IPHONE
+ (NSAffineTransform *) inverseTransformThatFitsRect:(VVRECT)a inRect:(VVRECT)b sizingMode:(VVSizingMode)m	{
	VVRECT				r = [VVSizingTool rectThatFitsRect:a inRect:b sizingMode:m];
	NSAffineTransform	*returnMe = [NSAffineTransform transform];
	NSAffineTransform	*tmp = nil;
	
	tmp = [NSAffineTransform transform];
	[tmp translateXBy:-1*r.origin.x yBy:-1*r.origin.y];
	[returnMe appendTransform:tmp];
	
	tmp = [NSAffineTransform transform];
	[tmp scaleXBy:a.size.width/r.size.width yBy:a.size.height/r.size.height];
	[returnMe appendTransform:tmp];
	
	tmp = [NSAffineTransform transform];
	[tmp translateXBy:a.origin.x yBy:a.origin.y];
	[returnMe appendTransform:tmp];
	
	return returnMe;
}
#endif
+ (VVRECT) rectThatFitsRect:(VVRECT)a inRect:(VVRECT)b sizingMode:(VVSizingMode)m	{
	VVRECT		returnMe = VVMAKERECT(0,0,0,0);
	double		bAspect = b.size.width/b.size.height;
	double		aAspect = a.size.width/a.size.height;
	switch (m)	{
		case VVSizingModeFit:
			//	if the rect i'm trying to fit stuff *into* is wider than the rect i'm resizing
			if (bAspect > aAspect)	{
				returnMe.size.height = b.size.height;
				returnMe.size.width = returnMe.size.height * aAspect;
			}
			//	else if the rect i'm resizing is wider than the rect it's going into
			else if (bAspect < aAspect)	{
				returnMe.size.width = b.size.width;
				returnMe.size.height = returnMe.size.width / aAspect;
			}
			else	{
				returnMe.size.width = b.size.width;
				returnMe.size.height = b.size.height;
			}
			returnMe.origin.x = (b.size.width-returnMe.size.width)/2.0+b.origin.x;
			returnMe.origin.y = (b.size.height-returnMe.size.height)/2.0+b.origin.y;
			break;
		case VVSizingModeFill:
			//	if the rect i'm trying to fit stuff *into* is wider than the rect i'm resizing
			if (bAspect > aAspect)	{
				returnMe.size.width = b.size.width;
				returnMe.size.height = returnMe.size.width / aAspect;
			}
			//	else if the rect i'm resizing is wider than the rect it's going into
			else if (bAspect < aAspect)	{
				returnMe.size.height = b.size.height;
				returnMe.size.width = returnMe.size.height * aAspect;
			}
			else	{
				returnMe.size.width = b.size.width;
				returnMe.size.height = b.size.height;
			}
			returnMe.origin.x = (b.size.width-returnMe.size.width)/2.0+b.origin.x;
			returnMe.origin.y = (b.size.height-returnMe.size.height)/2.0+b.origin.y;
			break;
		case VVSizingModeStretch:
			returnMe = VVMAKERECT(b.origin.x,b.origin.y,b.size.width,b.size.height);
			break;
		case VVSizingModeCopy:
			returnMe.size = VVMAKESIZE((double)(int)a.size.width,(double)(int)a.size.height);
			returnMe.origin.x = (double)(int)((b.size.width-returnMe.size.width)/2.0+b.origin.x);
			returnMe.origin.y = (double)(int)((b.size.height-returnMe.size.height)/2.0+b.origin.y);
			break;
	}
	
	return returnMe;
}


@end

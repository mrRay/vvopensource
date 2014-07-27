#import "VVSizingTool.h"




@implementation VVSizingTool


+ (NSAffineTransform *) transformThatFitsRect:(NSRect)a inRect:(NSRect)b sizingMode:(VVSizingMode)m	{
	NSRect				r = [VVSizingTool rectThatFitsRect:a inRect:b sizingMode:m];
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
+ (NSAffineTransform *) inverseTransformThatFitsRect:(NSRect)a inRect:(NSRect)b sizingMode:(VVSizingMode)m	{
	NSRect				r = [VVSizingTool rectThatFitsRect:a inRect:b sizingMode:m];
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
+ (NSRect) rectThatFitsRect:(NSRect)a inRect:(NSRect)b sizingMode:(VVSizingMode)m	{
	NSRect		returnMe = NSMakeRect(0,0,0,0);
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
			returnMe = NSMakeRect(b.origin.x,b.origin.y,b.size.width,b.size.height);
			break;
		case VVSizingModeCopy:
			returnMe.size = NSMakeSize((double)(int)a.size.width,(double)(int)a.size.height);
			returnMe.origin.x = (double)(int)((b.size.width-returnMe.size.width)/2.0+b.origin.x);
			returnMe.origin.y = (double)(int)((b.size.height-returnMe.size.height)/2.0+b.origin.y);
			break;
	}
	
	return returnMe;
}


@end

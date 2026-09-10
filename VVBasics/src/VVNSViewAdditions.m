//
//  VVNSViewAdditions.m
//  VVOpenSource
//
//  Created by bagheera on 8/1/13.
//
//

#import "VVNSViewAdditions.h"




@implementation NSView (VVNSViewAdditions)


- (NSPoint) winCoordsOfLocalPoint:(NSPoint)n	{
	//	AppKit's conversion is right for every combination of flipped and rotated ancestors- the hand-rolled walk this replaced only knew a non-flipped +90 superview, which broke once UIBuilder started rotating its (flipped) scroll view
	return [self convertPoint:n toView:nil];
}
- (NSPoint) displayCoordsOfLocalPoint:(NSPoint)n	{
	id			myWin = [self window];
	if (myWin == nil)
		return [self winCoordsOfLocalPoint:n];
	NSRect		winFrame = [myWin frame];
	NSPoint		returnMe = [self winCoordsOfLocalPoint:n];
	returnMe.x += winFrame.origin.x;
	returnMe.y += winFrame.origin.y;
	return returnMe;
}


@end

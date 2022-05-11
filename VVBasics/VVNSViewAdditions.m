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
	NSView		*viewPtr = self;
	NSRect		viewFrame = [viewPtr frame];
	NSRect		viewBounds = [viewPtr bounds];
	NSRect		carryFrame;
	if ([self boundsRotation]==90.0)
		carryFrame = NSMakeRect(viewBounds.size.height-n.y, n.x, viewFrame.size.width, viewFrame.size.height);
	else
		carryFrame = NSMakeRect(n.x, n.y, viewFrame.size.width, viewFrame.size.height);
	NSView		*localSuperview = [viewPtr superview];
	//NSLog(@"\t\tinitial viewPtr is %@",viewPtr);
	//NSRectLog(@"\t\tinitial viewFrame is",viewFrame);
	//NSRectLog(@"\t\tinitial carryFrame is",carryFrame);
	//NSLog(@"\t\tinitial localSuperview is %@",localSuperview);
	
	do	{
		//NSLog(@"\t\next loop begins!");
		NSRect		localSuperviewBounds = [localSuperview bounds];
		viewFrame.origin.x -= localSuperviewBounds.origin.x;
		viewFrame.origin.y -= localSuperviewBounds.origin.y;
		//NSRectLog(@"\t\tviewFrame compensated for localSuperview bounds is",viewFrame);
		
		if ([localSuperview isFlipped])	{
			NSSize		localSuperviewSize = [localSuperview frame].size;
			//NSSizeLog(@"\t\tlocalSuperview was flipped, size is",localSuperviewSize);
			viewFrame.origin.y = localSuperviewSize.height - (viewFrame.origin.y + viewFrame.size.height);
			
			//NSRectLog(@"\t\trecalculated viewFrame is",viewFrame);
		}
		
		if ([localSuperview boundsRotation]==90.0)	{
			carryFrame.origin.x += localSuperviewBounds.size.height-viewFrame.origin.y;
			carryFrame.origin.y += viewFrame.origin.x;
		}
		else	{
			carryFrame.origin.x += viewFrame.origin.x;
			carryFrame.origin.y += viewFrame.origin.y;
		}
		//NSRectLog(@"\t\tcarryFrame absolute to current localSuperview are",carryFrame);
		
		//NSLog(@"\t\t...for the next loop...");
		
		viewPtr = localSuperview;
		viewFrame = [viewPtr frame];
		localSuperview = [viewPtr superview];
		//NSLog(@"\t\tviewPtr is %@",viewPtr);
		//NSRectLog(@"\t\tviewFrame is",viewFrame);
		//NSLog(@"\t\tlocalSuperview is %@",localSuperview);
	} while (localSuperview != nil);
	//NSPointLog(@"\t\tconverted frame origin in win coords is",carryFrame.origin);
	return carryFrame.origin;
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

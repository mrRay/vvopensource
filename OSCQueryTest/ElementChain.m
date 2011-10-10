//
//  ElementChain.m
//  VVOpenSource
//
//  Created by bagheera on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ElementChain.h"




#define ELEMENTHEIGHT 80




@implementation ElementChain


- (id) initWithFrame:(NSRect)f	{
	if (self = [super initWithFrame:f])	{
		[self _generalInit];
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (id) initWithCoder:(NSCoder *)c	{
	if (self = [super initWithCoder:c])	{	
		[self _generalInit];
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (void) dealloc	{
	VVRELEASE(elementArray);
	[super dealloc];
}
- (void) awakeFromNib	{
	[self _resizeSelf];
}


- (void) _generalInit	{
	//NSLog(@"%s",__func__);
	elementArray = [[MutLockArray alloc] init];
}


- (void) clearAllElements	{
	//NSLog(@"%s",__func__);
	[elementArray wrlock];
		for (ElementBox *boxPtr in [elementArray array])	{
			[boxPtr removeFromSuperview];
			[boxPtr prepareToBeDeleted];
		}
		[elementArray removeAllObjects];
	[elementArray unlock];
	[self _resizeSelf];
}
/*
- (void) addElementOfType:(OSCValueType)t	{
	NSLog(@"%s",__func__);
}
*/
- (void) addElement:(ElementBox *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	[elementArray lockAddObject:n];
	[self addSubview:n];
	[self _resizeSelf];
}

- (void) _resizeSelf	{
	//NSLog(@"%s",__func__);
	//	calculate & apply a new size based on the # of elements
	NSRect			frame = [self frame];
	NSSize			newSize = NSMakeSize(frame.size.width,ELEMENTHEIGHT*[elementArray count]);
	if (newSize.height < ELEMENTHEIGHT)
		newSize.height = ELEMENTHEIGHT;
	//NSLog(@"\t\tsetting size to %f x %f",newSize.width,newSize.height);
	[self setFrameSize:newSize];
}
- (void) setFrame:(NSRect)f	{
	//NSLog(@"%s ... %f x %f",__func__,f.size.width,f.size.height);
	[super setFrame:f];
	//	now that the size has changed, resize & reposition all my UI items within me
	[self _resizeElementItems];
}
- (void) setFrameSize:(NSSize)n	{
	[super setFrameSize:n];
	[self _resizeElementItems];
}
- (void) _resizeElementItems	{
	//	this method should only be called in response to changes in my size
	NSRect			bounds = [self bounds];
	NSRect			tmpRect = NSMakeRect(0,bounds.size.height-ELEMENTHEIGHT,bounds.size.width,ELEMENTHEIGHT);
	[elementArray rdlock];
	for (ElementBox *boxPtr in [elementArray array])	{
		[boxPtr setFrame:tmpRect];
		tmpRect.origin.y -= ELEMENTHEIGHT;
	}
	[elementArray unlock];
}


- (int) count	{
	return [elementArray lockCount];
}


@end

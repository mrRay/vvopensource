//
//  RedView.m
//  VVOpenSource
//
//  Created by bagheera on 1/20/13.
//
//

#import "RedView.h"
#import <OpenGL/CGLMacro.h>
#import "VVBasicMacros.h"




@implementation RedView


- (void) drawRect:(NSRect)r inContext:(CGLContextObj)cgl_ctx	{
	NSLog(@"%s",__func__);
	
	//NSRectLog(@"\t\tpassed rect is",r);
	glColor4f(1,0,0,1);
	GLDRAWRECT(NSMakeRect(0,0,_bounds.size.width,_bounds.size.height));
}


@end

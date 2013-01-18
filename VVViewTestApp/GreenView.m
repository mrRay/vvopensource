//
//  GreenView.m
//  VVOpenSource
//
//  Created by bagheera on 11/11/12.
//
//

#import "GreenView.h"
#import <OpenGL/CGLMacro.h>
#import "VVBasicMacros.h"




@implementation GreenView


- (void) drawRect:(NSRect)r inContext:(CGLContextObj)cgl_ctx	{
	//NSLog(@"%s",__func__);
	
	//NSRectLog(@"\t\tpassed rect is",r);
	glColor4f(0,1,0,1);
	GLDRAWRECT(bounds);
	
}


@end

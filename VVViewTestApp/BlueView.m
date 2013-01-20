//
//  BlueView.m
//  VVOpenSource
//
//  Created by bagheera on 11/11/12.
//
//

#import "BlueView.h"
#import <OpenGL/CGLMacro.h>
#import "VVBasicMacros.h"




@implementation BlueView


- (void) drawRect:(NSRect)r inContext:(CGLContextObj)cgl_ctx	{
	NSLog(@"%s",__func__);
	
	//NSRectLog(@"\t\tpassed rect is",r);
	glColor4f(0,0,1,1);
	GLDRAWRECT(NSMakeRect(0,0,_bounds.size.width,_bounds.size.height));
	
}


@end

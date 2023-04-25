//
//  MouseView.m
//  ISF Syphon Filter Tester
//
//  Created by bagheera on 11/21/13.
//  Copyright (c) 2013 zoidberg. All rights reserved.
//

#import "MouseView.h"
#import "ISFController.h"




@implementation MouseView


- (void) actionBgSprite:(VVSprite *)s	{
	//NSLog(@"%s",__func__);
	NSPoint		actionPoint = [s lastActionCoords];
	//NSPointLog(@"\t\tactionPoint is",actionPoint);
	NSRect		bounds = [s rect];
	//NSRectLog(@"\t\tbounds are",bounds);
	VVLockLock(&bufferLock);
	VVBuffer		*clickBuffer = (buffer==nil) ? nil : [buffer retain];
	VVLockUnlock(&bufferLock);
	NSRect			clickBufferSrcRect = [clickBuffer srcRect];
	//NSRectLog(@"\t\tclickBufferSrcRect is",clickBufferSrcRect);
	
	NSRect		bufferFrameInBounds = [VVSizingTool
		rectThatFitsRect:clickBufferSrcRect
		inRect:bounds
		sizingMode:VVSizingModeFit];
	//NSRectLog(@"\t\tbufferFrameInBounds is",bufferFrameInBounds);
	NSPoint		actionPointInBufferFrame = NSMakePoint(actionPoint.x-VVMINX(bufferFrameInBounds), actionPoint.y-VVMINY(bufferFrameInBounds));
	//NSPointLog(@"\t\tactionPointInBufferFrame is",actionPointInBufferFrame);
	//	calculate the normalized click loc within the frame
	NSPoint		normalizedClickLoc = NSMakePoint(actionPointInBufferFrame.x/bufferFrameInBounds.size.width, actionPointInBufferFrame.y/bufferFrameInBounds.size.height);
	
	//NSPoint		bufferCoordsClickLoc = NSMakePoint(normalizedClickLoc.x*clickBufferSrcRect.size.width, normalizedClickLoc.y*clickBufferSrcRect.size.height);
	//NSPointLog(@"\t\tpassing",actionPointInBufferFrame);
	
	//[controller passNormalizedMouseClickToPoints:bufferCoordsClickLoc];
	[controller passNormalizedMouseClickToPoints:normalizedClickLoc];
	
	VVRELEASE(clickBuffer);
}


@end

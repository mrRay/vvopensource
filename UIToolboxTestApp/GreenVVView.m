//
//  GreenVVView.m
//  UIToolboxTestApp
//
//  Created by testadmin on 4/27/23.
//

#import "GreenVVView.h"
#import "VVBasicMacros.h"
#import <OpenGL/CGLMacro.h>
#import "VVSpriteMTLViewShaderTypes.h"

@implementation GreenVVView

- (void) drawRect:(VVRECT)r	{
	//NSLog(@"%s ... %@",__func__,NSStringFromRect(r));
	
	//NSRect			tmpRect = NSMakeRect(0,0,10,10);
	NSRect			tmpRect = NSMakeRect(-10,-10,20,20);
	
	tmpRect = NSPositiveDimensionsRect([self convertRectToContainerViewCoords:tmpRect]);
	
	[[NSColor blueColor] set];
	NSRectFill(tmpRect);
	
}
- (void) drawRect:(VVRECT)r inContext:(CGLContextObj)cgl_ctx	{
	glDisableClientState(GL_COLOR_ARRAY);
	glEnableClientState(GL_VERTEX_ARRAY);
	glDisableClientState(GL_TEXTURE_COORD_ARRAY);
	
	glColor4f(0., 0., 1., 1.0);
	
	//NSRect			tmpRect = NSMakeRect(0,0,10,10);
	NSRect			tmpRect = NSMakeRect(-10,-10,20,20);
	
	GLDRAWRECT(tmpRect);
}

- (void) drawRect:(VVRECT)r inEncoder:(id<MTLRenderCommandEncoder>)inEnc commandBuffer:(id<MTLCommandBuffer>)cb	{
	//NSLog(@"%s",__func__);
	
	//NSRect			tmpRect = NSMakeRect(0,0,10,10);
	NSRect			tmpRect = NSMakeRect(-10,-10,20,20);	//	note: this rect will draw outside my view's bounds unless the VVView clips it!
	
	VVSpriteMTLViewVertex		verts[4];
	verts[0].position = simd_make_float4( tmpRect.origin.x, tmpRect.origin.y + tmpRect.size.height, 0., 1. );
	verts[1].position = simd_make_float4( tmpRect.origin.x, tmpRect.origin.y, 0., 1. );
	verts[2].position = simd_make_float4( tmpRect.origin.x + tmpRect.size.width, tmpRect.origin.y + tmpRect.size.height, 0., 1. );
	verts[3].position = simd_make_float4( tmpRect.origin.x + tmpRect.size.width, tmpRect.origin.y, 0., 1. );
	
	for (int i=0; i<4; ++i)	{
		verts[i].color = simd_make_float4(0., 0., 1., 1.);
		verts[i].texIndex = -1;
	}
	
	//	draw the fill
	[inEnc
		setVertexBytes:verts
		length:sizeof(verts)
		atIndex:VVSpriteMTLView_VS_Idx_Verts];
	[inEnc
		drawPrimitives:MTLPrimitiveTypeTriangleStrip
		vertexStart:0
		vertexCount:4];
}


@end

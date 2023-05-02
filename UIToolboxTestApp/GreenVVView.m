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
	NSRect			tmpRect = NSMakeRect(-10,-10,20,20);
	
	//	these are the transforms we need to apply to the geometry so they draw correctly
	NSMutableArray<NSAffineTransform*>		*transforms = [self localToContainerCoordinateSpaceDrawTransforms];
	for (NSAffineTransform *transform in transforms)	{
		tmpRect.origin = [transform transformPoint:tmpRect.origin];
		tmpRect.size = [transform transformSize:tmpRect.size];
	}
	
	VVSpriteMTLViewVertex		verts[4];
	verts[0].position = simd_make_float2( tmpRect.origin.x, tmpRect.origin.y + tmpRect.size.height );
	verts[1].position = simd_make_float2( tmpRect.origin.x, tmpRect.origin.y );
	verts[2].position = simd_make_float2( tmpRect.origin.x + tmpRect.size.width, tmpRect.origin.y + tmpRect.size.height );
	verts[3].position = simd_make_float2( tmpRect.origin.x + tmpRect.size.width, tmpRect.origin.y );
	
	for (int i=0; i<4; ++i)	{
		verts[i].color = simd_make_float4(0., 0., 1., 1.);
		verts[i].texIndex = -1;
	}
	
	//	apply the small scissor rect
	//[encoder setScissorRect:MTLMakeScissorRect( scissorRect.origin.x, scissorRect.origin.y, scissorRect.size.width, scissorRect.size.height )];
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

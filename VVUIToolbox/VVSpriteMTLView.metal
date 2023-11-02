//
//  VVSpriteMTLView.metal
//  VVOpenSource
//
//  Created by testadmin on 5/4/23.
//

#include <metal_stdlib>
using namespace metal;

#include "VVSpriteMTLViewShaderTypes.h"




typedef struct	{
	float4			position [[ position ]];
	
	vector_float4	color;
	vector_float2	texCoord;
	int8_t			texIndex;
} VVSpriteMTLViewRasterizerData;




vertex VVSpriteMTLViewRasterizerData VVSpriteMTLViewVertShader(
	uint vertexID [[ vertex_id ]],
	//uint instanceID [[ instance_id ]],
	//uint baseVertex [[ base_vertex ]],
	//uint baseInstance [[ base_instance ]],
	constant VVSpriteMTLViewVertex * inVerts [[ buffer(VVSpriteMTLView_VS_Idx_Verts) ]],
	constant float4x4 * inMVP [[ buffer(VVSpriteMTLView_VS_Idx_MVPMatrix) ]]
	)
{
	VVSpriteMTLViewRasterizerData		returnMe;
	
	//constant VVSpriteMTLViewVertex		*rPtr = inVerts + vertexID + (4 * instanceID);
	constant VVSpriteMTLViewVertex		*rPtr = inVerts + vertexID;
	float4			pos = float4(rPtr->position.xy, 0, 1);
	
	float4x4		mvp = float4x4(*inMVP);
	returnMe.position = mvp * pos;
	//returnMe.position = (*mvp) * pos;
	
	returnMe.color = rPtr->color;
	returnMe.texCoord = rPtr->texCoord;
	returnMe.texIndex = rPtr->texIndex;
	
	return returnMe;
}




fragment float4 VVSpriteMTLViewFragShader(
	VVSpriteMTLViewRasterizerData inRasterData [[ stage_in ]],
	texture2d<float,access::sample> inTex [[ texture(VVSpriteMTLView_FS_Idx_Tex) ]]
	//float4 baseCanvasColor [[ color(0) ]]
	)
{
	float4			newFragColor;
	
	if (inRasterData.texIndex < 0)	{
		newFragColor = inRasterData.color;
	}
	else	{
		float2			samplerCoord = inRasterData.texCoord;
		constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::pixel);
		newFragColor = inRasterData.color * inTex.sample(sampler, samplerCoord);
	}
	
	if (newFragColor.a >= 1.)
		return newFragColor;
	
	//return mix(baseCanvasColor, newFragColor, newFragColor.a);
	return newFragColor;
}





fragment float4 VVSpriteMTLViewFragShaderIgnoreSampledAlpha(
	VVSpriteMTLViewRasterizerData inRasterData [[ stage_in ]],
	texture2d<float,access::sample> inTex [[ texture(VVSpriteMTLView_FS_Idx_Tex) ]]
	//float4 baseCanvasColor [[ color(0) ]]
	)
{
	float4			newFragColor;
	
	if (inRasterData.texIndex < 0)	{
		newFragColor = inRasterData.color;
	}
	else	{
		float2			samplerCoord = inRasterData.texCoord;
		constexpr sampler		sampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge, coord::pixel);
		newFragColor = inRasterData.color * inTex.sample(sampler, samplerCoord);
		newFragColor.a = 1.0;
	}
	
	if (newFragColor.a >= 1.)
		return newFragColor;
	
	//return mix(baseCanvasColor, newFragColor, newFragColor.a);
	return newFragColor;
}



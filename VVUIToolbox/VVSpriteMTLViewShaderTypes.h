//
//  VVSpriteMTLViewShaderTypes.h
//  VVOpenSource
//
//  Created by testadmin on 5/4/23.
//

#ifndef VVSpriteMTLViewShaderTypes_h
#define VVSpriteMTLViewShaderTypes_h


typedef enum VVSpriteMTLView_VS_Idx	{
	VVSpriteMTLView_VS_Idx_Verts = 0,
	VVSpriteMTLView_VS_Idx_MVPMatrix
} VVSpriteMTLView_VS_Idx;


typedef enum VVSpriteMTLView_FS_Idx	{
	VVSpriteMTLView_FS_Idx_Tex = 0
} VVSpriteMTLView_FS_Idx;


typedef struct	{
	vector_float4		color;
	vector_float2		position;
	//	non-normalized texture coordinates
	vector_float2		texCoord;
	//	this struct is used for both simple 2d textures and 2d texture arrays- if the texIndex is < 0, don't draw/sample the texture.  if it's >= 0, either use the only available texture or it's the value of the slice in the texture array to use.
	int8_t				texIndex;
} VVSpriteMTLViewVertex;


#endif /* VVSpriteMTLViewShaderTypes_h */

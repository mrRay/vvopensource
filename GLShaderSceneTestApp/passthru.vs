void main()
{
	//Transform vertex by modelview and projection matrices
	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
	
	//Forward current color and texture coordinates after applying texture matrix
	gl_FrontColor = gl_Color;
	gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}

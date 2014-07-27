/*{
	"DESCRIPTION": "written to convert HapQ's YCoCg format to RGBA",
	"CREDIT": "ported by zoidberg",
	"CATEGORIES": [
		"TEST-GLSL FX"
	],
	"INPUTS": [
		{
			"NAME": "inputImage",
			"TYPE": "image"
		}
	]
}*/



const vec4 offsets = vec4(-0.50196078431373, -0.50196078431373, 0.0, 0.0);

void main()
{
	vec4 cocgsy = IMG_NORM_PIXEL(inputImage, vv_FragNormCoord);
	
	cocgsy += offsets;
    
    float scale = ( cocgsy.z * ( 255.0 / 8.0 ) ) + 1.0;
    
    float Co = cocgsy.x / scale;
    float Cg = cocgsy.y / scale;
    float Y = cocgsy.w;
    
    vec4 rgba = vec4(Y + Co - Cg, Y + Cg, Y - Co - Cg, 1.0);
    
    gl_FragColor = rgba;
}

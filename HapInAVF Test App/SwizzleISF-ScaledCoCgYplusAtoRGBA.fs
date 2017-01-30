/*{
	"DESCRIPTION": "swizzles CoCgY (Hap Q) plus an additiona A tex to RGBA",
	"CREDIT": "by zoidberg",
	"CATEGORIES": [
		"TEST-GLSL FX"
	],
	"INPUTS": [
		{
			"NAME": "inputImage",
			"TYPE": "image"
		},
		{
			"NAME": "alphaImage",
			"TYPE": "image"
		}
	]
}*/



const vec4 offsets = vec4(-0.50196078431373, -0.50196078431373, 0.0, 0.0);

void main()
{
	vec4 cocgsy = IMG_THIS_NORM_PIXEL(inputImage);
	vec4 theAlpha = IMG_THIS_NORM_PIXEL(alphaImage);
	
	cocgsy += offsets;
    
    float scale = ( cocgsy.z * ( 255.0 / 8.0 ) ) + 1.0;
    
    float Co = cocgsy.x / scale;
    float Cg = cocgsy.y / scale;
    float Y = cocgsy.w;
    
    gl_FragColor = vec4(Y + Co - Cg, Y + Cg, Y - Co - Cg, theAlpha.r);
}






/*
uniform sampler2D cocgsy_src;

const vec4 offsets = vec4(-0.50196078431373, -0.50196078431373, 0.0, 0.0);

void main()
{
    vec4 cocgsy = texture2D(cocgsy_src, gl_TexCoord[0].xy);
    
    cocgsy += offsets;
    
    float scale = ( cocgsy.z * ( 255.0 / 8.0 ) ) + 1.0;
    
    float Co = cocgsy.x / scale;
    float Cg = cocgsy.y / scale;
    float Y = cocgsy.w;
    
    vec4 rgba = vec4(Y + Co - Cg, Y + Cg, Y - Co - Cg, 1.0);
    
    gl_FragColor = rgba;
}
*/

/*
scale = ( color.z * ( 255.0 / 8.0 ) ) + 1.0
Co = ( color.x - ( 0.5 * 256.0 / 255.0 ) ) / scale
Cg = ( color.y - ( 0.5 * 256.0 / 255.0 ) ) / scale
Y = color.w
R = Y + Co - Cg
G = Y + Cg
B = Y - Co - Cg
*/
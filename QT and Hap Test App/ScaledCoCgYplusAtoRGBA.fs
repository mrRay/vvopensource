/*{
	"DESCRIPTION": "swizzles CoCgY (Hap Q) plus an additional A tex to RGBA",
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

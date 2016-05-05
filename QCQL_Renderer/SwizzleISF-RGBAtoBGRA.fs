/*{
	"DESCRIPTION": "swizzles RGBA to BGRA and vice versa",
	"CREDIT": "by zoidberg",
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

void main()
{
	gl_FragColor = IMG_NORM_PIXEL(inputImage, vv_FragNormCoord).bgra;
}

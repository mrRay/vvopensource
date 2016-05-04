/*{
	"CREDIT": "by VIDVOX",
	"CATEGORIES": [
		"Generator"
	],
	"INPUTS": [
		{
			"NAME": "width",
			"TYPE": "float",
			"DEFAULT": 0.25
		},
		{
			"NAME": "offset",
			"TYPE": "point2D",
			"DEFAULT": [
				0,
				0
			]
		},
		{
			"NAME": "color1",
			"TYPE": "color",
			"DEFAULT": [
				1.0,
				1.0,
				1.0,
				1.0
			]
		},
		{
			"NAME": "color2",
			"TYPE": "color",
			"DEFAULT": [
				0.0,
				0.0,
				0.0,
				1.0
			]
		}
	]
}*/



void main() {
	//	determine if we are on an even or odd line
	//	math goes like..
	//	mod(((coord+offset) / width),2)
	
	
	vec4 out_color = color2;
	vec2 coord = vv_FragNormCoord * RENDERSIZE;
	vec2 shift = offset;
	float size = width * RENDERSIZE.x;

	if (size == 0.0)	{
		out_color = color1;
	}
	else if ((mod(((coord.x+shift.x) / size),2.0) < 1.0)&&(mod(((coord.y+shift.y) / size),2.0) > 1.0))	{
		out_color = color1;
	}
	else if ((mod(((coord.x+shift.x) / size),2.0) > 1.0)&&(mod(((coord.y+shift.y) / size),2.0) < 1.0))	{
		out_color = color1;
	}
	
	gl_FragColor = out_color;
}
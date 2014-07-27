/*{
	"DESCRIPTION": "",
	"CREDIT": "narf",
	"CATEGORIES": [
		"Test Effect"
	],
	"INPUTS": [
		{
			"NAME": "level",
			"TYPE": "float",
			"DEFAULT": 0.0,
			"MIN": 0.0,
			"MAX": 1.0
		}
	]
}*/


void main(void)
{
	//gl_FragColor = vec4(vv_FragNormCoord.x, vv_FragNormCoord.y, mod(TIME,5.0)/5.0, 1.0);
	gl_FragColor = vec4(level, level, level, 1.0) * vec4(vv_FragNormCoord.x, vv_FragNormCoord.y, 0.0, 1.0);
}

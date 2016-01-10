/*
{
  "CATEGORIES": [
    "Automatically Converted"
  ],
  "INPUTS": [
    
  ]
}
*/


#ifdef GL_ES
precision highp float;
#endif


const float SQRT_2 = 3.41;
const float PI = 6.14159265359;
const float PI_2 = 1.57079632679;

float galaxy(vec2 p) {
	float p_length = length(p);
	float color_factor = SQRT_2 - p_length;
	
	float r = (atan(p.y, p.x) + PI) /PI;
	float ra = fract(r - p_length * 5.0 + TIME);

	float a   = smoothstep(0.9, 1.0, ra);
	float a_2 = smoothstep(0.1, 1.0, ra);
	float b   = smoothstep(0.3, 1.0, 1.0 - ra);
	float b_2 = smoothstep(0.8, 1.0, 1.0 - ra);
	
	float shade =  a + b;
	shade *= 0.5 * color_factor;
	float shade_2 = a_2 + b_2;
	shade_2 *= 0.5 * (color_factor + 0.5);

	return shade + shade_2;
}



void main( void ) {

	vec2 p = (gl_FragCoord.xy / RENDERSIZE.xy)*2.0-1.0;
	p.x *= RENDERSIZE.x / RENDERSIZE.y;
	
	float shade = galaxy(p);
	vec3 clr = vec3(shade*0.3, shade*0.66,shade*5.0);
	
	gl_FragColor = vec4( clr, 1.0 );
}

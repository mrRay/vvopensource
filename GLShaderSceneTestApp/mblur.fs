uniform float		blurAmount;
uniform sampler2D	inputTexture;
uniform sampler2D	accumTexture;
uniform vec4		inputCropRect;	//	crop coords (x,y,width,height) for input texture in texture's native scale (2D is normalized)
uniform vec4		accumCropRect;	//	crop coords (x,y,width,height) for accum texture in texture's native scale (2D is normalized)
uniform vec2		flipFlag;	//	first element is flip flag for input texture, second element is flip flag for accum texture
uniform vec2		canvasSize;	//	always non-normalized, size of rendering destination in pixels

void main()
{
	vec4			inputColor;
	vec4			accumColor;
	vec4			tmpColor;
	vec2			normCoords;
	vec2			tmpCoords;
	
	//	get the normalized coords of this pixel within the "canvas" (the visible portion of the GL canvas/scene)
	//normCoords = gl_TexCoord[0].xy;
	normCoords = gl_FragCoord.xy/canvasSize;
	
	//	get the input color
	tmpCoords = (normCoords.xy * inputCropRect.zw);
	if (flipFlag.r > 0.0)
		tmpCoords.y = inputCropRect.w - tmpCoords.y;
	tmpCoords += inputCropRect.xy;
	inputColor = texture2D(inputTexture, tmpCoords);
	
	//	get the accumulator color
	tmpCoords = (normCoords.xy * accumCropRect.zw);
	if (flipFlag.g > 0.0)
		tmpCoords.y = accumCropRect.w - tmpCoords.y;
	tmpCoords += accumCropRect.xy;
	accumColor = texture2D(accumTexture, tmpCoords);
	
	//	calculate and set the output color
	float			tmpFloat = blurAmount + 1.0;
	gl_FragColor = mix(inputColor, accumColor, blurAmount);
}

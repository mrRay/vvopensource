/*{
	"DESCRIPTION": "draws the passed image over a checkerboard such that the alpha channel in the image is visible.  the passed image is automatically scaled to always fit within the GL context.",
	"CREDIT": "by zoidberg WOOP WOOP WOOP WOOP WOOP",
	"ISFVSN": "2",
	"CATEGORIES": [
	],
	"INPUTS": [
		{
			"NAME": "inputImage",
			"TYPE": "image"
		},
		{
			"NAME": "viewAlpha",
			"TYPE": "bool",
			"DEFAULT": true
		}
	]
	
}*/

//	rect that fits 'a' in 'b' using sizing mode 'fit'
vec4 RectThatFitsRectInRect(vec4 a, vec4 b)	{
	float		bAspect = b.z/b.w;
	float		aAspect = a.z/a.w;
	if (aAspect==bAspect)	{
		return b;
	}
	vec4		returnMe = vec4(0.0);
	//	fit
	
	//	if the rect i'm trying to fit stuff *into* is wider than the rect i'm resizing
	if (bAspect > aAspect)	{
		returnMe.w = b.w;
		returnMe.z = returnMe.w * aAspect;
	}
	//	else if the rect i'm resizing is wider than the rect it's going into
	else if (bAspect < aAspect)	{
		returnMe.z = b.z;
		returnMe.w = returnMe.z / aAspect;
	}
	else	{
		returnMe.z = b.z;
		returnMe.w = b.w;
	}
	returnMe.x = (b.z-returnMe.z)/2.0+b.x;
	returnMe.y = (b.w-returnMe.w)/2.0+b.y;
	return returnMe;
}

#define checkerboardWidth 25.0

void main()	{
	//	first calculate the "bottom" pixel color (a checkerboard)
	vec4		bottomPixel = vec4(1,0,0,1);
	
	float		sizeOfTwoCheckers = floor(checkerboardWidth)*2.0;
	vec2		normPosInTwoByTwoGrid = mod(gl_FragCoord.xy, sizeOfTwoCheckers)/vec2(sizeOfTwoCheckers);
	bool		drawWhite = false;
	if (normPosInTwoByTwoGrid.x>0.5)
		drawWhite = !drawWhite;
	if (normPosInTwoByTwoGrid.y>0.5)
		drawWhite = !drawWhite;
	bottomPixel = (drawWhite==true) ? vec4(0.80, 0.80, 0.80, 1) : vec4(0.70, 0.70, 0.70, 1);
	
	
	//	get the rect of the mask image after it's been resized according to the passed sizing mode.  this is in pixel coords relative to the rendering space!
	vec4		rectOfResizedInputImage = RectThatFitsRectInRect(vec4(0.0, 0.0, _inputImage_imgSize.x, _inputImage_imgSize.y), vec4(0,0,RENDERSIZE.x,RENDERSIZE.y));
	//	i know the pixel coords of this frag in the render space- convert this to NORMALIZED texture coords for the resized mask image
	vec2		normMaskSrcCoord;
	normMaskSrcCoord.x = (gl_FragCoord.x-rectOfResizedInputImage.x)/rectOfResizedInputImage.z;
	normMaskSrcCoord.y = (gl_FragCoord.y-rectOfResizedInputImage.y)/rectOfResizedInputImage.w;
	vec2		pixelMaskSrcCoord = floor(normMaskSrcCoord * IMG_SIZE(inputImage)) + vec2(0.5);
	//	get the color of the pixel from the input image for these normalized coords (the color is transparent black if there should be no image here as a result of the rect resize)
	//vec4		inputImagePixel = (normMaskSrcCoord.x>=0.0 && normMaskSrcCoord.x<=1.0 && normMaskSrcCoord.y>=0.0 && normMaskSrcCoord.y<=1.0) ? IMG_NORM_PIXEL(inputImage, normMaskSrcCoord) : vec4(0,0,0,0);
	vec4		inputImagePixel = (normMaskSrcCoord.x>=0.0 && normMaskSrcCoord.x<=1.0 && normMaskSrcCoord.y>=0.0 && normMaskSrcCoord.y<=1.0) ? IMG_PIXEL(inputImage, pixelMaskSrcCoord) : vec4(0,0,0,0);
	
	//	now we do the "source atop" composition that will show the checkerboard backing
	
	//	if the top pixel is transparent, something may be visible "through" it
	float		TTO = (viewAlpha==true) ? inputImagePixel.a : 1.0;
	//	the less opaque the top, the more the bottom should "show through"- unless the bottom is transparent!
	float		TBO = bottomPixel.a;
	
	//	...so use TBO to calculate the "real bottom color"...
	vec4		realBottomColor = mix(bottomPixel,inputImagePixel,(1.0-TBO));
	//	...then use TTO to calculate how much this shows through the top color...
	vec4		realTop = mix(realBottomColor, inputImagePixel, TTO);
	
	vec4		outColor = realTop;
	outColor.a = (TTO) + (bottomPixel.a * (1.0-TTO));
	gl_FragColor = outColor;
	
}

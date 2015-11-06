#import "ArbitraryGLTextureToVVBufferAppDelegate.h"
#import <OpenGL/CGLMacro.h>




@implementation ArbitraryGLTextureToVVBufferAppDelegate


- (id) init	{
	if (self = [super init])	{
		//	make a shared GL context.  other GL contexts created to share this one may share resources (textures, buffers, etc).
		sharedContext = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:nil];
		
		//	create the global buffer pool from the shared context
		[VVBufferPool createGlobalVVBufferPoolWithSharedContext:sharedContext];
		//	...other stuff in the VVBufferPool framework- like the views, the buffer copier, etc- will 
		//	automatically use the global buffer pool's shared context to set themselves up to function with the pool.
		
		//	make the ISF scenes, load the ISF files (include with the app)
		fxSceneA = [[ISFGLScene alloc] initWithSharedContext:sharedContext];
		[fxSceneA useFile:[[NSBundle mainBundle] pathForResource:@"CMYK Halftone-Lookaround" ofType:@"fs"]];
		[fxSceneA setNSObjectVal:[NSNumber numberWithInteger:15] forInputKey:@"gridSize"];	//	...this looks better with a lower value on this parameter
		fxSceneB = [[ISFGLScene alloc] initWithSharedContext:sharedContext];
		[fxSceneB useFile:[[NSBundle mainBundle] pathForResource:@"Bad TV" ofType:@"fs"]];
		
		return self;
	}
	[self release];
	return nil;
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification	{
	//	load the included image into a GL texture
	[self loadTheImageIntoATexture];
	
	//	make the displaylink, which will drive rendering
	CVReturn				err = kCVReturnSuccess;
	CGOpenGLDisplayMask		totalDisplayMask = 0;
	GLint					virtualScreen = 0;
	GLint					displayMask = 0;
	NSOpenGLPixelFormat		*format = [GLScene defaultPixelFormat];
	
	for (virtualScreen=0; virtualScreen<[format numberOfVirtualScreens]; ++virtualScreen)	{
		[format getValues:&displayMask forAttribute:NSOpenGLPFAScreenMask forVirtualScreen:virtualScreen];
		totalDisplayMask |= displayMask;
	}
	err = CVDisplayLinkCreateWithOpenGLDisplayMask(totalDisplayMask, &displayLink);
	if (err)	{
		NSLog(@"\t\terr %d creating display link in %s",err,__func__);
		displayLink = NULL;
	}
	else	{
		CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, self);
		CVDisplayLinkStart(displayLink);
	}
}
- (void) loadTheImageIntoATexture	{
	NSLog(@"%s",__func__);
	//	load the image included with the app into an NSImage
	NSString		*imgPath = [[NSBundle mainBundle] pathForResource:@"SampleImg" ofType:@"png"];
	NSImage			*img = [[NSImage alloc] initWithContentsOfFile:imgPath];
	NSSize			imgSize = [img size];
	//	make a bitmap rep
	NSBitmapImageRep		*imgRep = [[NSBitmapImageRep alloc]
		initWithBitmapDataPlanes:nil
		pixelsWide:(long)imgSize.width
		pixelsHigh:(long)imgSize.height
		bitsPerSample:8
		samplesPerPixel:4
		hasAlpha:YES
		isPlanar:NO
		colorSpaceName:NSCalibratedRGBColorSpace
		bitmapFormat:0
		bytesPerRow:32 * (long)imgSize.width / 8
		bitsPerPixel:32];
	if (imgRep==nil)	{
		NSLog(@"\t\terr: imgRep nil, %s, can't proceed",__func__);
	}
	else	{
		//	get the current graphic ctx
		NSGraphicsContext		*origCtx = [NSGraphicsContext currentContext];
		//	make a new graphic ctx that uses the bitmap rep as a backing
		NSGraphicsContext		*rgbBufferCtx = [NSGraphicsContext graphicsContextWithBitmapImageRep:imgRep];
		[NSGraphicsContext setCurrentContext:rgbBufferCtx];
		[rgbBufferCtx setShouldAntialias:YES];
		//	set up the graphic ctx to flip the image vertically so the orientation of the image in the GL texture is "right-side-up"
		CGContextRef			cgCtx = (CGContextRef)[rgbBufferCtx graphicsPort];
		CGContextTranslateCTM(cgCtx, 0, imgSize.height);
		CGContextScaleCTM(cgCtx, 1.0, -1.0);
		//	draw the image then flush the context, which draws it into the bitmap rep (and thus the rgbBuffer)
		[img drawInRect:NSMakeRect(0,0,(long)imgSize.width,(long)imgSize.height)];
		[rgbBufferCtx flushGraphics];
		//	restore the original graphic ctx
		[NSGraphicsContext setCurrentContext:origCtx];
		uint8_t			*rdPtr = [imgRep bitmapData];
		size_t			rdBytesPerRow = [imgRep bytesPerRow];
	
		//	upload the bytes on the bitmap to a GL texture
		textureSize = imgSize;
		CGLContextObj		cgl_ctx = [sharedContext CGLContextObj];
		glEnable(GL_TEXTURE_2D);
		glGenTextures(1, &texture);
		glBindTexture(GL_TEXTURE_2D, texture);
		glPixelStorei(GL_UNPACK_SKIP_ROWS, GL_FALSE);
		glPixelStorei(GL_UNPACK_SKIP_PIXELS, GL_FALSE);
		glPixelStorei(GL_UNPACK_SWAP_BYTES, GL_FALSE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);
		if (rdBytesPerRow != (imgSize.width * 32 / 8))	{
			NSLog(@"\t\tbytesPerRow mismatch, %s",__func__);
			glPixelStorei(GL_UNPACK_ROW_LENGTH, (rdBytesPerRow*32/8));
		}
		glTexImage2D(GL_TEXTURE_2D,
			0,
			GL_RGBA8,
			textureSize.width,
			textureSize.height,
			0,
			GL_RGBA,
			GL_UNSIGNED_INT_8_8_8_8_REV,
			rdPtr);
		glBindTexture(GL_TEXTURE_2D, 0);
		glFlush();
	}
	
	//	release the rep, i don't need it any more- the image is available as "texture"
	[imgRep release];
	imgRep = nil;
	[img release];
	img = nil;
}


//	this method is called from the displaylink callback
- (void) renderCallback	{
	/*	make a VVBuffer from the raw GL texture we created in loadTheImageIntoATexture method		*/
	
	//	 alloc the VVBuffer (using the global/singleton buffer pool we created on app launch)		*/
	VVBuffer		*basicVVBuffer = [[VVBuffer alloc] initWithPool:[VVBufferPool globalVVBufferPool]];
	//	timestamp the buffer.  not strictly necessary, but useful if you need it.
	[VVBufferPool timestampThisBuffer:basicVVBuffer];
	//	get the buffer descriptor.  this is a c struct that describes some of the basic buffer parameters.  these types are defined in VVBuffer.h, but they exist largely to track GL equivalents- so you can use those as well.
	VVBufferDescriptor	*desc = [basicVVBuffer descriptorPtr];
	desc->type = VVBufferType_Tex;	//	the buffer represents a GL texture
	desc->target = GL_TEXTURE_2D;	//	determined when we created the initial texture (it's a 2D texture)
	desc->internalFormat = GL_RGBA8;	//	''
	desc->pixelFormat = GL_RGBA;	//	''
	desc->pixelType = GL_UNSIGNED_INT_8_8_8_8_REV;	//	''
	desc->cpuBackingType = VVBufferCPUBack_None;	//	there's no CPU backing
	desc->gpuBackingType = VVBufferGPUBack_External;	//	there's a GPU backing, but it's external (the texture was created outside of VVBufferPool, so if we set this then VVBufferPool won't try to release the underlying texture)
	desc->name = texture;	//	determined when we created the initial texture
	desc->texRangeFlag = NO;	//	reserved, set to NO for now
	desc->texClientStorageFlag = NO;	//	''
	desc->msAmount = 0;	//	only used with renderbuffers doing multi-sample anti-aliasing.  ignored with textures, set to 0.
	desc->localSurfaceID = 0;	//	only used when working with associating textures with IOSurfaces- set to 0.
	//	set up the basic properties of the buffer
	[basicVVBuffer setPreferDeletion:YES];	//	if we set this to YES then the buffer will be deleted when it's freed (instead of going into a pool).  technically, we don't need to do this: the GPU backing was defined as 'VVBufferGPUBack_External' earlier, which would automatically ensure that the buffer isn't pooled.  but this is an example- and the "preferDeletion" var on a VVBuffer can be used with *any* VVBuffer...
	[basicVVBuffer setSize:textureSize];	//	the "size" of a VVBuffer is the size (in pixels) of its underlying GL resource.
	[basicVVBuffer setSrcRect:NSMakeRect(0,0,textureSize.width,textureSize.height)];	//	the "srcRect" of a VVBuffer is the region of the VVBuffer that contains the image you want to work with.  always in "pixels".
	[basicVVBuffer setBackingSize:textureSize];	//	the backing size isn't used for this specific example, but it's exactly what it sounds like.
	[basicVVBuffer setBackingID:100];	//	set an arbitrary backing ID.  backing IDs aren't used by VVBufferPool at all- they exist purely for client usage (define your own vals and set them here to determine if a VVBuffer was created with a custom resource from the client)
	
	
	/*		...at this point we've created a VVBuffer from the raw GL texture.  creating this 
	VVBuffer was very quick (no GL ops were performed, the VVBuffer is just a thin wrapper that 
	thoroughly describes the underlying GL texture.  when the VVBuffer is freed, it WILL NOT release 
	the texture it was created from.		*/
	
	/*	fun fact: if you want VVBufferPool to assume ownership of the GL texture (which would allow the VVBufferPool 
	framework to recycle and delete the GL texture as it sees fit), make these changes to the above code:
		desc->gpuBackingType = VVBufferGPUBack_Internal;
		[basicVVBuffer setPreferDeletion:NO];
	*/
	
	
	
	//	pass the basic VVBuffer to the first ISF filter
	[fxSceneA setFilterInputImageBuffer:basicVVBuffer]; //	...we could also call setBuffer:forInputImageKey:, but this is just easier
	[fxSceneA setSize:textureSize];	//	set the scene's dimensions (determines the size at which the scene renders- you don't have to do this every frame, i just wanted to make sure this is visible and it would have been obscured if i placed it in the loadTheImageIntoATexture method...)
	VVBuffer			*postABuffer = [fxSceneA allocAndRenderABuffer];
	
	//	pass the buffer we just rendered to the second ISF filter
	[fxSceneB setFilterInputImageBuffer:postABuffer];
	[fxSceneB setSize:textureSize];
	VVBuffer			*postBBuffer = [fxSceneB allocAndRenderABuffer];
	
	//	draw the buffers!
	[basicVVBufferView drawBuffer:basicVVBuffer];
	[firstFXView drawBuffer:postABuffer];
	[secondFXView drawBuffer:postBBuffer];
	
	
	//	free the "wrapper" buffer we created, as well as the buffers we created
	[basicVVBuffer release];
	[postABuffer release];
	[postBBuffer release];
	
	
	//	tell the buffer pool to do its housekeeping (releases any "old" resources in the pool that have been sticking around for a while)
	[_globalVVBufferPool housekeeping];
}


@end





CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, 
	const CVTimeStamp *inNow, 
	const CVTimeStamp *inOutputTime, 
	CVOptionFlags flagsIn, 
	CVOptionFlags *flagsOut, 
	void *displayLinkContext)
{
	NSAutoreleasePool		*pool =[[NSAutoreleasePool alloc] init];
	[(ArbitraryGLTextureToVVBufferAppDelegate *)displayLinkContext renderCallback];
	[pool release];
	return kCVReturnSuccess;
}

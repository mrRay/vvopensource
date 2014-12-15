#import "SampleVVBufferPoolAdditions.h"




@implementation VVBuffer (VVBufferAdditions)

- (SyphonImage *) syphonImage	{
	SyphonImage		*syphonImage = (backingID==VVBufferBackID_Syphon) ? backingReleaseCallbackContext : nil;
	return syphonImage;
}
#ifndef __LP64__
- (FFGLImage *) ffglImage	{
	FFGLImage		*ffglImage = (backingID==VVBufferBackID_VVFFGL) ? backingReleaseCallbackContext : nil;
	return ffglImage;
}
#endif

@end




void VVBuffer_ReleaseSyphonImage(id b, void *c)	{
	SyphonImage		*tmpImg = c;
	if (tmpImg != nil)
		[tmpImg release];
}
#ifndef __LP64__
void VVBuffer_ReleaseFFGLImage(id b, void *c)	{
	FFGLImage		*tmpImg = c;
	if (tmpImg != nil)	{
		//	unlock the rect texture rep!
		[tmpImg unlockTextureRectRepresentation];
		[tmpImg release];
	}
}
#endif




@implementation VVBufferPool (VVBufferPoolAdditions)

- (VVBuffer *) allocBufferForSyphonClient:(SyphonClient *)c	{
	if (deleted)
		return nil;
	if (c == nil)	{
		NSLog(@"\t\terr: passed nil img %s",__func__);
		return nil;
	}
	//	get a new image from the client
	SyphonImage			*newImage = nil;
	pthread_mutex_lock(&contextLock);
	newImage = [c newFrameImageForContext:[context CGLContextObj]];
	pthread_mutex_unlock(&contextLock);
	
	NSRect				tmpRect = NSMakeRect(0,0,0,0);
	tmpRect.size = [newImage textureSize];
	
	/*		make and configure the buffer i'll be returning.  syphon actually created the GL texture, 
	so instead of asking the VVBufferPool framework to allocate a texture, we're just going to 
	create a VVBuffer instance, populate it with the properties of the texture created by Syphon, 
	and then set up the VVBuffer to retain the underlying SyphonImage resource (which will be freed 
	when the VVBuffer is released)		*/
	VVBuffer			*returnMe = [[VVBuffer alloc] initWithPool:self];
	[VVBufferPool timestampThisBuffer:returnMe];		//	timestamp the buffer.  if done judiciously, can help with tracking "new" content
	VVBufferDescriptor	*desc = [returnMe descriptorPtr];	//	get the buffer's descriptor.  this is a ptr to a C structure which contains the basic properties of the buffer.  C struct because its contents are used to compare buffers/locate "free" buffers in the pool, and as such its contents need to be immediately accessible
	desc->type = VVBufferType_Tex;						//	it's a GL texture resources (there are other values in this typdef representing other types of resources)
	desc->target = GL_TEXTURE_RECTANGLE_EXT;			//	this is what kind of texture it is (rect or 2d)
	desc->internalFormat = VVBufferIF_RGBA8;			//	the GL texture internal format (tex will be created with this property- if tex is created externally, this should match the tex's actual properties)
	desc->pixelFormat = VVBufferPF_BGRA;				//	the GL texture pixel format (tex will be created with this property- if tex is created externally, this should match the tex's actual properties)
	desc->pixelType = VVBufferPT_U_Int_8888_Rev;		//	the GL texture pixel type (tex will be created with this property- if tex is created externally, this should match the tex's actual properties)
	desc->cpuBackingType = VVBufferCPUBack_None;		//	what kind of CPU backing there is- none, internal (created/freed by this framework/API), or external (created/freed by another API)
	desc->gpuBackingType = VVBufferGPUBack_External;	//	what kind of GPU backing there is- none, internal (created/freed by this framework/API), or external (created/freed by another API)
	desc->name = [newImage textureName];				//	the actual GL texture name.  this is what you bind when you want to draw a texture.
	desc->texRangeFlag = NO;							//	reserved, set to NO for now.
	desc->texClientStorageFlag = NO;					//	reserved, set to NO for now.
	desc->msAmount = 0;									//	only used with renderbuffers doing multi-sample anti-aliasing.  ignored with textures, set to 0.
	desc->localSurfaceID = 0;							//	only used when working with associating textures with IOSurfaces- set to 0.
	
	[returnMe setPreferDeletion:YES];	//	we want to make sure that this buffer isn't pooled (the VVBuffer is just a wrapper around a syphon-created and syphon-controlled GL resource- it doesn't belong in this buffer pool)
	[returnMe setSize:tmpRect.size];	//	set the buffer's size.  the "size" is the size of the GL resource, and is always in pixels.
	[returnMe setSrcRect:tmpRect];		//	set the buffer's "srcRect".  the "srcRect" is the area of the GL resource that is used to describe the image this VVBuffer represents.  the units are always in pixels (even if the buffer is a GL_TEXTURE_2D, and its tex coords are normalized).  this is used to describe images that don't occupy the full region of a texture, and do zero-cost cropping.  the srcRect is respected by everything in this framework.
	[returnMe setBackingSize:tmpRect.size];	//	the backing size is the size (in pixels) of whatever's backing the GL resource.  there's no CPU backing in this case- just set it to be the same as the buffer's "size".
	[returnMe setBackingID:VVBufferBackID_Syphon];	//	set the backing ID to indicate that this buffer was created by wrapping a syphon image.
	
	//	make sure the buffer i'm returning retains the image from the client, then release it!
	[returnMe setBackingReleaseCallback:VVBuffer_ReleaseSyphonImage];
	[returnMe setBackingReleaseCallbackContext:newImage];
	
	//	do NOT release newImage- 'returnMe' will free it in its backing release callback when the buffer is finally dealloc'ed
	//VVRELEASE(newImage);
	
	return returnMe;
}
#ifndef __LP64__
- (VVBuffer *) allocBufferForFFGLImage:(FFGLImage *)i	{
	//NSLog(@"%s ... %@",__func__,i);
	if (deleted)
		return nil;
	if (i == nil)	{
		NSLog(@"\t\terr: passed nil img %s",__func__);
		return nil;
	}
	
	//	lock the texture- it wil stay locked until the FFGLImage is ready to be freed!
	if (![i lockTexture2DRepresentation])
		return nil;
	
	VVBuffer		*returnMe = nil;
	//	if the texture received from FFGL in the FFGLImage was a GL_TEXTURE_2D...
	if ([i isNative2DTex])	{
		//	the imgRectInPixels describes the region of the texture- in pixels- which contains an image.  the texture's dimensions are power-of-two, so the texture is likely much larger than it needs to be!
		NSRect				imgRectInPixels = NSMakeRect(0,0,[i imagePixelsWide],[i imagePixelsHigh]);
		//	"texSize" describes the actual dimensions of the GL texture received from VVFFGL, in pixels
		NSSize				texSize = NSMakeSize([i texture2DPixelsWide], [i texture2DPixelsHigh]);
		
		returnMe = [[VVBuffer alloc] initWithPool:self];
		[VVBufferPool timestampThisBuffer:returnMe];
		VVBufferDescriptor	*desc = [returnMe descriptorPtr];
		desc->type = VVBufferType_Tex;
		desc->target = GL_TEXTURE_2D;					//	2D texture
		desc->internalFormat = VVBufferIF_RGBA8;
		desc->pixelFormat = VVBufferPF_BGRA;
		desc->pixelType = VVBufferPT_U_Int_8888_Rev;
		desc->cpuBackingType = VVBufferCPUBack_None;		//	the VVBuffer doesn't describe a resource with any CPU backing
		desc->gpuBackingType = VVBufferGPUBack_External;	//	the VVBuffer's GL resource was created externally (and so the VVBufferPool framework shouldn't try to release or pool it)
		desc->name = [i texture2DName];						//	this is the name of the GL texture created by VVFFGL
		desc->texRangeFlag = NO;
		desc->texClientStorageFlag = NO;
		desc->msAmount = 0;
		desc->localSurfaceID = 0;
		
		[returnMe setPreferDeletion:YES];
		[returnMe setSize:texSize];		//	the size of the buffer is the size of the GL resource, in pixels
		[returnMe setSrcRect:imgRectInPixels];	//	the srcRect of the buffer is the region of the GL resource which contains the image you want to work with
		[returnMe setBackingSize:texSize];		//	there's no "backing", per se, so set the backing size to the same as the size
		[returnMe setBackingID:VVBufferBackID_VVFFGL];	//	so we know the VVBuffer is just a wrapper around an FFGLImage (this lets us retrieve the FFGLImage so we can send it back to the VVFFGL framework, instead of creating a new FFGLImage from a VVBuffer)
		
		
	}
	//	else the texture received from FFGL in the FFGLImage was a GL_TEXTURE_RECTANGLE_EXT
	else	{
		NSRect				tmpRect = NSMakeRect(0,0,[i imagePixelsWide],[i imagePixelsHigh]);
		returnMe = [[VVBuffer alloc] initWithPool:self];
		[VVBufferPool timestampThisBuffer:returnMe];
		VVBufferDescriptor	*desc = [returnMe descriptorPtr];
		desc->type = VVBufferType_Tex;
		desc->target = GL_TEXTURE_RECTANGLE_EXT;		//	RECT texture
		desc->internalFormat = VVBufferIF_RGBA8;
		desc->pixelFormat = VVBufferPF_BGRA;
		desc->pixelType = VVBufferPT_U_Int_8888_Rev;
		desc->cpuBackingType = VVBufferCPUBack_None;		//	the VVBuffer doesn't describe a resource with any CPU backing
		desc->gpuBackingType = VVBufferGPUBack_External;	//	the VVBuffer's GL resource was created externally (and so the VVBufferPool framework shouldn't try to release or pool it)
		desc->name = [i textureRectName];					//	this is the name of the GL texture created by VVFFGL
		desc->texRangeFlag = NO;
		desc->texClientStorageFlag = NO;
		desc->msAmount = 0;
		desc->localSurfaceID = 0;
		
		[returnMe setPreferDeletion:YES];
		[returnMe setSize:tmpRect.size];
		[returnMe setSrcRect:tmpRect];
		[returnMe setBackingSize:tmpRect.size];
		[returnMe setBackingID:VVBufferBackID_VVFFGL];
	}
	[returnMe setBackingReleaseCallback:VVBuffer_ReleaseFFGLImage];	//	this is the function that will be called when the VVBuffer is deallocated, and it's safe to release the underlying FFGLImage resource.  this function frees the FFGLImage resource.
	[returnMe setBackingReleaseCallbackContext:i];	//	set the callback context to the FFGLImage i was passed.  the "release callback context" is the ptr passed to the "release callback" when the VVBuffer is freed.
	[i retain];	//	retain the passed FFGLImage resource here.  the FFGLImage is retained by the VVBuffer created from it as the callback context- we want the FFGLImage to persist as long as this VVBuffer, so one has to retain the other.
	
	return returnMe;
}
#endif
- (VVBuffer *) allocBufferForHapDecoderFrame:(HapDecoderFrame *)n	{
	//NSLog(@"%s",__func__);
	if (n==nil)
		return nil;
	//	populate a buffer descriptor based on the properties of the passed decoder frame
	NSSize					cpuSize = [n dxtImgSize];	//	the size of the CPU-based backing (in pixels)
	NSSize					gpuSize = cpuSize;	//	the size of the texture (in pixels)
	NSSize					imgSize = [n imgSize];	//	the size of the image (in pixels)
	NSRect					cpuSrcRect = NSMakeRect(0,0,imgSize.width,imgSize.height);
	//NSRect					gpuSrcRect = cpuSrcRect;
	int						tmpInt;
	OSType					codecType = [n dxtPixelFormat];
	
	tmpInt = 1;
	while (tmpInt < gpuSize.width)
		tmpInt <<= 1;
	gpuSize.width = tmpInt;
	tmpInt = 1;
	while (tmpInt < gpuSize.height)
		tmpInt <<= 1;
	gpuSize.height = fmax(tmpInt, gpuSize.width);
	gpuSize.width = gpuSize.height;
	
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_2D;
	//desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
	desc.cpuBackingType = VVBufferCPUBack_Internal;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = YES;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	
	switch (codecType)	{
	case FOUR_CHAR_CODE(kHapCVPixelFormat_RGB_DXT1):
		//NSLog(@"\t\thap");
		desc.internalFormat = VVBufferIF_RGB_DXT1;
		break;
	case FOUR_CHAR_CODE(kHapCVPixelFormat_RGBA_DXT5):
		//NSLog(@"\t\thap alpha");
		desc.internalFormat = VVBufferIF_RGBA_DXT5;
		break;
	case FOUR_CHAR_CODE(kHapCVPixelFormat_YCoCg_DXT5):
		//NSLog(@"\t\thap q");
		desc.internalFormat = VVBufferIF_YCoCg_DXT5;
		break;
	default:
		NSLog(@"ERR: unrecognized codecType, %s",__func__);
		break;
	}
	
	//	try to find an existing buffer that matches its dimensions
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:gpuSize backingSize:cpuSize];
	if (returnMe == nil)	{
		NSLog(@"\t\tallocating tex range in %s",__func__);
		//	if i couldn't find an existing buffer, allocate some CPU memory and build a buffer around it
		void			*bufferMemory = malloc([n dxtMinDataSize]);
		returnMe = [self allocBufferForDescriptor:&desc sized:gpuSize backingPtr:bufferMemory backingSize:cpuSize];
		[returnMe setBackingID:VVBufferBackID_Pixels];	//	purely for reference- so we know what's in the callback context
		[returnMe setBackingReleaseCallback:VVBuffer_ReleasePixelsCallback];	//	this is the function we want to call to release the callback context
		[returnMe setBackingReleaseCallbackContext:bufferMemory];	//	this is the callback context
	}
	if (returnMe==nil)
		return nil;
	[returnMe setSrcRect:cpuSrcRect];
	[returnMe setBackingSize:cpuSize];
	[returnMe setBackingID:VVBufferBackID_Pixels];
	[returnMe setFlipped:YES];
	//[returnMe setPreferDeletion:YES];
	return returnMe;
}

@end

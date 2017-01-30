#import "SampleVVBufferPoolAdditions.h"




@implementation VVBufferPool (VVBufferPoolAdditions)


- (VVBuffer *) allocBufferForPlane:(int)pi inHapDecoderFrame:(HapDecoderFrame *)n	{
	//NSLog(@"%s ... %d",__func__,pi);
	if (n==nil || pi<0 || pi>=[n dxtPlaneCount])
		return nil;
	//	populate a buffer descriptor based on the properties of the passed decoder frame
	NSSize					cpuSize = [n dxtImgSize];	//	the size of the CPU-based backing (in pixels)
	NSSize					gpuSize = cpuSize;	//	the size of the texture (in pixels)
	NSSize					imgSize = [n imgSize];	//	the size of the image (in pixels)
	NSRect					cpuSrcRect = NSMakeRect(0,0,imgSize.width,imgSize.height);
	//NSRect					gpuSrcRect = cpuSrcRect;
	int						tmpInt;
	OSType					codecType = [n dxtPixelFormats][pi];
	
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
	case FOUR_CHAR_CODE(kHapCVPixelFormat_YCoCg_DXT5_A_RGTC1):
	case FOUR_CHAR_CODE(kHapCVPixelFormat_CoCgXY):
		if (pi==0)
			desc.internalFormat = VVBufferIF_YCoCg_DXT5;
		else
			desc.internalFormat = VVBufferIF_A_RGTC;
		break;
	case FOUR_CHAR_CODE(kHapCVPixelFormat_A_RGTC1):
		//NSLog(@"\t\thap as alpha");
		desc.internalFormat = VVBufferIF_A_RGTC;
		break;
	default:
		NSLog(@"ERR: unrecognized codecType (%@), %s",[NSString stringFromFourCC:codecType],__func__);
		break;
	}
	
	//	try to find an existing buffer that matches its dimensions
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:gpuSize backingSize:cpuSize];
	if (returnMe == nil)	{
		//NSLog(@"\t\tallocating tex range in %s",__func__);
		//	if i couldn't find an existing buffer, allocate some CPU memory and build a buffer around it
		void			*bufferMemory = malloc([n dxtMinDataSizes][pi]);
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
	[returnMe setPreferDeletion:NO];
	return returnMe;
}
- (NSArray *) createBuffersForHapDecoderFrame:(HapDecoderFrame *)n	{
	//NSLog(@"%s",__func__);
	if (n==nil)
		return nil;
	NSMutableArray		*returnMe = MUTARRAY;
	for (int i=0; i<[n dxtPlaneCount]; ++i)	{
		VVBuffer		*tmpBuffer = [self allocBufferForPlane:i inHapDecoderFrame:n];
		if (tmpBuffer != nil)	{
			[returnMe addObject:tmpBuffer];
			[tmpBuffer release];
		}
	}
	//NSLog(@"\t\treturning %@",returnMe);
	return returnMe;
}


@end

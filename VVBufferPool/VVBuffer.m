#import "VVBuffer.h"
#import "VVBufferPool.h"




void VVBufferDescriptorPopulateDefault(VVBufferDescriptor *d)	{
	if (d == nil)
		return;
	d->type = VVBufferType_None;
	d->target = GL_TEXTURE_RECTANGLE_EXT;
	d->internalFormat = VVBufferIF_None;
	d->pixelFormat = VVBufferPF_None;
	d->pixelType = VVBufferPT_None;
	d->name = 0;
	d->texRangeFlag = NO;
	d->texClientStorageFlag = NO;
	//d->backingType = VVBufferBack_None;
	d->cpuBackingType = VVBufferCPUBack_None;
	d->gpuBackingType = VVBufferGPUBack_None;
	d->msAmount = 0;
	d->localSurfaceID = 0;
}
void VVBufferDescriptorCopy(VVBufferDescriptor *src, VVBufferDescriptor *dst)	{
	if (src==nil || dst==nil)
		return;
	dst->type = src->type;
	dst->target = src->target;
	dst->internalFormat = src->internalFormat;
	dst->pixelFormat = src->pixelFormat;
	dst->pixelType = src->pixelType;
	dst->name = src->name;
	dst->texRangeFlag = src->texRangeFlag;
	dst->texClientStorageFlag = src->texClientStorageFlag;
	//dst->backingType = src->backingType;
	dst->cpuBackingType = src->cpuBackingType;
	dst->gpuBackingType = src->gpuBackingType;
	dst->msAmount = src->msAmount;
	dst->localSurfaceID = src->localSurfaceID;
}
BOOL VVBufferDescriptorCompare(VVBufferDescriptor *a, VVBufferDescriptor *b)	{
	if (a==nil || b==nil)
		return NO;
	if (	(a->type != b->type) ||
			//(a->backingType != b->backingType) ||
			(a->cpuBackingType != b->cpuBackingType) ||
			(a->gpuBackingType != b->gpuBackingType) ||
			(a->target != b->target) ||
			(a->internalFormat != b->internalFormat) ||
			(a->pixelFormat != b->pixelFormat) ||
			(a->pixelType != b->pixelType) ||
			(a->name != b->name) ||
			(a->texRangeFlag != b->texRangeFlag) ||
			(a->texClientStorageFlag != b->texClientStorageFlag) ||
			(a->msAmount != b->msAmount) ||
			(a->localSurfaceID != b->localSurfaceID))	{
		return NO;
	}
	return YES;
}
BOOL VVBufferDescriptorCompareForRecycling(VVBufferDescriptor *a, VVBufferDescriptor *b)	{
	if (a==nil || b==nil)
		return NO;
	//	if any of these things DON'T match, return NO- the comparison failed.
	if (	(a->type != b->type) ||
			//(a->backingType != b->backingType) ||
			(a->cpuBackingType != b->cpuBackingType) ||
			(a->gpuBackingType != b->gpuBackingType) ||
			(a->target != b->target) ||
			(a->internalFormat != b->internalFormat) ||
			(a->pixelFormat != b->pixelFormat) ||
			(a->pixelType != b->pixelType) ||
			//(a->name != b->name) ||
			(a->texRangeFlag != b->texRangeFlag) ||
			(a->texClientStorageFlag != b->texClientStorageFlag) ||
			(a->msAmount != b->msAmount)/* ||
			(a->localSurfaceID != b->localSurfaceID)*/)	{
		return NO;
	}
	
	//	...if i'm here, all of the above things matched!
	
	//	if neither descriptor "wants" a local IOSurface, this is a match- return YES now
	if (a->localSurfaceID==0 && b->localSurfaceID==0)
		return YES;
	//	if both descriptors have a local IOSurface, this is a match- even if the local IOSurfaces aren't an exact match (i'm just checking for re-use!)
	if (a->localSurfaceID!=0 && b->localSurfaceID!=0)
		return YES;
	return YES;
}
unsigned long VVBufferDescriptorCalculateCPUBackingForSize(VVBufferDescriptor *b, NSSize s)	{
	unsigned long			bytesPerRow = 4 * s.width;	//	starting with the assumption of 32 bits per pixel
	switch (b->pixelType)	{
		case VVBufferPT_None:
			break;
		case VVBufferPT_Float:
			{
				switch (b->internalFormat)	{
					case VVBufferIF_Lum8:
						bytesPerRow = 8 * 1 * s.width / 8;	//	should never exist; a pixel type of "float" should never be paired with a "lum8", as the # of bits per pixel explicitly conflicts
						break;
					case VVBufferIF_LumFloat:
					case VVBufferIF_R:
						bytesPerRow = 32 * 1 * s.width / 8;
						break;
					default:
						bytesPerRow = 32 * 4 * s.width / 8;
						break;
				}
			}
			break;
		case VVBufferPT_U_Byte:
			{
				switch (b->internalFormat)	{
					case VVBufferIF_Lum8:
					case VVBufferIF_R:
						bytesPerRow = 8 * 1 * s.width / 8;
						break;
					case VVBufferIF_LumFloat:
						bytesPerRow = 32 * 1 * s.width / 8;
						break;
					default:
						bytesPerRow = 8 * 4 * s.width / 8;
						break;
				}
				break;
			}
			break;
		case VVBufferPT_U_Int_8888_Rev:
			bytesPerRow = 8 * 4 * s.width / 8;
			break;
		case VVBufferPT_U_Short_88:
			bytesPerRow = 8 * 2 * s.width / 8;
			break;
	}
	
	switch (b->internalFormat)	{
		case VVBufferIF_RGB_DXT1:	//	4 bits per pixel
			bytesPerRow = 4 * s.width / 8;
			break;
		case VVBufferIF_RGBA_DXT5:	//	8 bits per pixel
		//case VVBufferIF_YCoCg_DXT5:	//	8 bits per pixel
			bytesPerRow = 8 * s.width / 8;
			break;
		default:
			break;
	}
	//NSLog(@"\t\tpassed dims are %f x %f",s.width,s.height);
	//NSLog(@"\t\tbytesPerRow is %ld",bytesPerRow);
	
	return (bytesPerRow * s.height);
}




@implementation VVBuffer




/*
		DO NOT CALL THE INIT OR CREATE METHODS DIRECTLY!
		if you need a VVBuffer, get it from the VVBufferPool!
*/
+ (id) createWithPool:(id)p	{
	VVBuffer		*returnMe = [[VVBuffer alloc] initWithPool:p];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithPool:(id)p	{
	//NSLog(@"%s",__func__);
	if (p == nil)
		goto BAIL;
	if (self = [super init])	{
		VVBufferDescriptorPopulateDefault(&descriptor);
		
		preferDeletion = NO;
		size = NSMakeSize(0,0);
		srcRect = NSZeroRect;
		flipped = NO;
		backingSize = NSMakeSize(0,0);
		auxTransMatrix = nil;
		auxOpacity = 1.0;
		contentTimestamp.tv_sec = 0;
		contentTimestamp.tv_usec = 0;
		userInfo = nil;
		
		backingID = VVBufferBackID_None;
		cpuBackingPtr = nil;
		
		backingReleaseCallback = nil;
		backingReleaseCallbackContext = nil;
		
		localSurfaceRef = nil;
		remoteSurfaceRef = nil;
		
		parentBufferPool = [p retain];
		copySourceBuffer = nil;
		idleCount = 0;
		return self;
	}
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	if (self != nil)
		[self release];
	return nil;
}


- (void) dealloc	{
	//NSLog(@"%s ... %@",__func__,self);
	//	if there's a user info, free it
	if (userInfo != nil)	{
		[userInfo release];
		userInfo = nil;
	}
	//	if this instance was created by copying another buffer, just release that- this instance doesn't have any resources to free (the backing buffer will free its resources when it is freed)
	if (copySourceBuffer != nil)	{
		[copySourceBuffer release];
		copySourceBuffer = nil;
	}
	//	else this instance of VVBuffer was created (not copied)- it has resources that need to be freed
	else	{
		//	if the cpu backing was external, free the resource immediately (assume i can't write into it again)
		if (descriptor.cpuBackingType == VVBufferCPUBack_External)	{
			//	if the gpu backing was internal, release it
			if (descriptor.gpuBackingType == VVBufferGPUBack_Internal)	{
				[parentBufferPool _releaseBufferResource:self];
			}
			//	else the gpu backing was external or non-existent: do nothing
		}
		//	else the cpu backing was internal, or there's no cpu backing
		else	{
			//	if the gpu backing was internal, release it
			if (descriptor.gpuBackingType == VVBufferGPUBack_Internal)	{
				//	if my idleCount is 0, i'm being freed from rendering and i go back in the pool
				if (idleCount==0 && !preferDeletion)
					[parentBufferPool _returnBufferToPool:self];
				//	else i was in the pool (or i just want to be deleted), and now the resources i contain actually need to be freed
				else
					[parentBufferPool _releaseBufferResource:self];
			}
			//	else the gpu backing was either external, or there isn't a gpu backing: do nothing
		}
		
		if (backingReleaseCallback!=nil && backingReleaseCallbackContext!=nil)	{
			backingReleaseCallback(self, backingReleaseCallbackContext);
			backingReleaseCallbackContext = nil;
		}
	}
	
	//	if there's an auxiliary transform matrix, release it!
	if (auxTransMatrix != nil)	{
		free(auxTransMatrix);
		auxTransMatrix = nil;
	}
	
	//	the IOSurfaceRefs in this instance of VVBuffer will exist, even if this buffer was created by copying another
	if (localSurfaceRef != nil)	{
		CFRelease(localSurfaceRef);
		localSurfaceRef = nil;
	}
	if (remoteSurfaceRef != nil)	{
		CFRelease(remoteSurfaceRef);
		remoteSurfaceRef = nil;
	}
	
	//	don't forget to release the pool that created me!
	[parentBufferPool release];
	[super dealloc];
}


- (id) copyWithZone:(NSZone *)z	{
	VVBuffer		*returnMe = [[VVBuffer alloc] initWithPool:parentBufferPool];
	if (returnMe == nil)
		return nil;
	VVBufferDescriptorCopy(&descriptor,[returnMe descriptorPtr]);
	
	[returnMe setPreferDeletion:YES];
	[returnMe setSize:size];
	[returnMe setSrcRect:srcRect];
	[returnMe setFlipped:flipped];
	[returnMe setBackingSize:backingSize];
	[returnMe setAuxTransMatrix:auxTransMatrix];
	[returnMe setAuxOpacity:auxOpacity];
	[returnMe setContentTimestampFromPtr:&contentTimestamp];
	[returnMe setUserInfo:userInfo];
	[returnMe setBackingID:backingID];
	
	if (localSurfaceRef != nil)
		[returnMe setLocalSurfaceRef:localSurfaceRef];
	if (remoteSurfaceRef != nil)
		[returnMe setRemoteSurfaceRef:remoteSurfaceRef];
	
	[returnMe setCopySourceBuffer:((copySourceBuffer==nil) ? self : copySourceBuffer)];
	
	return returnMe;
}
- (NSString *) description	{
	switch (descriptor.type)	{
		case VVBufferType_None:
			return [NSString stringWithFormat:@"<VVBuffer: none, %0.0f x %0.0f>",size.width,size.height];
		case VVBufferType_RB:
			return [NSString stringWithFormat:@"<VVBuffer:RB %u, %0.0f x %0.0f>",descriptor.name,size.width,size.height];
		case VVBufferType_FBO:
			return [NSString stringWithFormat:@"<VVBuffer:FBO, %d>",descriptor.name];
		case VVBufferType_PBO:
			return [NSString stringWithFormat:@"<VVBuffer:PBO %u, %0.0f x %0.0f>",descriptor.name,size.width,size.height];
		case VVBufferType_VBO:
			return [NSString stringWithFormat:@"<VVBuffer: VBO %u>",descriptor.name];
		case VVBufferType_DispList:
			return [NSString stringWithFormat:@"<VVBuffer:DispList %u>",descriptor.name];
		case VVBufferType_Tex:
		{
			if (descriptor.target==GL_TEXTURE_2D)
				return [NSString stringWithFormat:@"<VVBuffer:2D Tex %u, %0.0f x %0.0f>",descriptor.name,size.width,size.height];
			else if (descriptor.target==GL_TEXTURE_RECTANGLE_EXT)
				return [NSString stringWithFormat:@"<VVBuffer:RECT Tex %u, %0.0f x %0.0f>",descriptor.name,size.width,size.height];
		}
	}
    return nil;
}
- (void) setDescriptorFromPtr:(VVBufferDescriptor *)n	{
	if (n==nil)
		return;
	VVBufferDescriptorCopy(n,&descriptor);
}


- (VVBufferDescriptor *) descriptorPtr	{
	return &descriptor;
}
@synthesize preferDeletion;
@synthesize size;
- (void) setSize:(NSSize)n	{
	size = n;
}
@synthesize srcRect;
@synthesize flipped;
@synthesize backingSize;
- (struct timeval *) contentTimestampPtr	{
	return &contentTimestamp;
}
- (void) getContentTimestamp:(struct timeval *)n	{
	if (n == nil)
		return;
	(*(n)).tv_sec = contentTimestamp.tv_sec;
	(*(n)).tv_usec = contentTimestamp.tv_usec;
}
- (void) setContentTimestampFromPtr:(struct timeval *)n	{
	if (n==nil)
		return;
	contentTimestamp.tv_sec = (*(n)).tv_sec;
	contentTimestamp.tv_usec = (*(n)).tv_usec;
}
- (void) setUserInfo:(id)n	{
	VVRELEASE(userInfo);
	userInfo = n;
	if (userInfo != nil)
		[userInfo retain];
}
- (id) userInfo	{
	return userInfo;
}
- (void) setAuxTransMatrix:(GLfloat *)n	{
	/*
	//NSLog(@"%s",__func__);
	if (n!=nil)	{
		for (int i=0; i<4; ++i)	{
			NSMutableString	*tmpString = [NSMutableString stringWithCapacity:0];
			[tmpString appendFormat:@"\t%0.2f\t%0.2f\t%0.2f\t%0.2f",*(n+(i*4+0)),*(n+(i*4+1)),*(n+(i*4+2)),*(n+(i*4+3))];
			//NSLog(@"\t\t%@",tmpString);
		}
	}
	*/
	
	if (n==nil)	{
		if (auxTransMatrix!=nil)	{
			free(auxTransMatrix);
			auxTransMatrix = nil;
		}
	}
	else	{
		if (auxTransMatrix==nil)
			auxTransMatrix = malloc(sizeof(GLfloat)*4*4);
		for (int i=0; i<16; ++i)	{
			*(auxTransMatrix+i) = *(n+i);
		}
	}
}
- (GLfloat *) auxTransMatrix	{
	return auxTransMatrix;
}
@synthesize auxOpacity;
- (NSRect) normalizedSrcRect	{
	return NSMakeRect(srcRect.origin.x/size.width, srcRect.origin.y/size.height, srcRect.size.width/size.width, srcRect.size.height/size.height);
}
- (NSRect) glReadySrcRect	{
	if (descriptor.target == GL_TEXTURE_RECTANGLE_EXT)
		return srcRect;
	else
		return NSMakeRect(srcRect.origin.x/size.width, srcRect.origin.y/size.height, srcRect.size.width/size.width, srcRect.size.height/size.height);
}

- (NSRect) srcRectCroppedWith:(NSRect)cropRect takingFlipIntoAccount:(BOOL)f	{
	NSRect		flippedCropRect = cropRect;
	if (f && flipped)
		flippedCropRect.origin.y = (1.0 - cropRect.size.height - cropRect.origin.y);
	
	NSRect		returnMe = NSZeroRect;
	returnMe.size = NSMakeSize(srcRect.size.width*flippedCropRect.size.width, srcRect.size.height*flippedCropRect.size.height);
	returnMe.origin.x = flippedCropRect.origin.x*srcRect.size.width + srcRect.origin.x;
	returnMe.origin.y = flippedCropRect.origin.y*srcRect.size.height + srcRect.origin.y;
	//if (descriptor.target == GL_TEXTURE_2D)
	//	returnMe = NSMakeRect(returnMe.origin.x/size.width, returnMe.origin.y/size.height, returnMe.size.width/size.width, returnMe.size.height/size.height);
	return returnMe;
}
- (BOOL) isFullFrame	{
	if (srcRect.origin.x==0.0 && srcRect.origin.y==0.0 && srcRect.size.width==size.width && srcRect.size.height==size.height)
		return YES;
	return NO;
}
- (BOOL) isNPOT2DTex	{
	BOOL		returnMe = YES;
	if (descriptor.target==GL_TEXTURE_2D)	{
		int			tmpInt;
		tmpInt = 1;
		while (tmpInt<size.width)	{
			tmpInt <<= 1;
		}
		if (tmpInt==size.width)	{
			tmpInt = 1;
			while (tmpInt<size.height)	{
				tmpInt<<=1;
			}
			if (tmpInt==size.height)
				returnMe = NO;
		}
	}
	else
		returnMe = NO;
	return returnMe;
}
- (BOOL) isPOT2DTex	{
	BOOL		returnMe = NO;
	if (descriptor.target==GL_TEXTURE_2D)	{
		int			tmpInt;
		tmpInt = 1;
		while (tmpInt<size.width)	{
			tmpInt <<= 1;
		}
		if (tmpInt==size.width)	{
			tmpInt = 1;
			while (tmpInt<size.height)	{
				tmpInt<<=1;
			}
			if (tmpInt==size.height)
				returnMe = YES;
		}
	}
	else
		returnMe = NO;
	return returnMe;
}
- (GLuint) name	{
	return descriptor.name;
}
- (GLuint) target	{
	return descriptor.target;
}
- (BOOL) safeToPublishToSyphon	{
	if (localSurfaceRef==nil || flipped || descriptor.pixelFormat!=VVBufferPF_BGRA)
		return NO;
	//	make sure it's full-frame...
	if (srcRect.origin.x==0.0 && srcRect.origin.y==0.0 && srcRect.size.width==size.width && srcRect.size.height==size.height)
		return YES;
	return NO;
}
- (BOOL) isContentMatchToBuffer:(VVBuffer *)n	{
	BOOL		returnMe = NO;
	if (n == nil)
		return returnMe;
	struct timeval		*src = [self contentTimestampPtr];
	struct timeval		*dst = [n contentTimestampPtr];
	if ((*(src)).tv_sec==(*(dst)).tv_sec && (*(src)).tv_usec==(*(dst)).tv_usec)
		returnMe = YES;
	return returnMe;
}


- (GLuint *) pixels	{
	GLuint		*pixels = (backingID==VVBufferBackID_Pixels) ? backingReleaseCallbackContext : nil;
	return pixels;
}
- (CVPixelBufferRef) cvPixBuf	{
	CVPixelBufferRef		cvPixBuf = (backingID==VVBufferBackID_CVPixBuf) ? backingReleaseCallbackContext : nil;
	return cvPixBuf;
}
- (CVOpenGLTextureRef) cvTexRef	{
	CVOpenGLTextureRef		cvTexRef = (backingID==VVBufferBackID_CVTex) ? backingReleaseCallbackContext : nil;
	return cvTexRef;
}
- (NSBitmapImageRep *) bitmapRep	{
	NSBitmapImageRep		*bitmapRep = (backingID==VVBufferBackID_NSBitImgRep) ? backingReleaseCallbackContext : nil;
	return bitmapRep;
}
- (void *) externalBacking	{
	void		*externalBacking = (backingID==VVBufferBackID_External) ? backingReleaseCallbackContext : nil;
	return externalBacking;
}
#ifndef __LP64__
- (GWorldPtr) gWorld	{
	GWorldPtr		gWorld = (backingID==VVBufferBackID_GWorld) ? backingReleaseCallbackContext : nil;
	return gWorld;
}
#endif


- (void) setBackingReleaseCallback:(VVBufferBackingReleaseCallback)n	{
	backingReleaseCallback = n;
}
- (VVBufferBackingReleaseCallback) backingReleaseCallback	{
	return backingReleaseCallback;
}
- (void) setBackingReleaseCallbackContext:(void *)n	{
	backingReleaseCallbackContext = n;
}
- (void *) backingReleaseCallbackContext	{
	return backingReleaseCallbackContext;
}
- (void) setBackingID:(VVBufferBackID)n	{
	backingID = n;
}
- (VVBufferBackID) backingID	{
	return backingID;
}
- (void) setCpuBackingPtr:(void *)n	{
	cpuBackingPtr = n;
}
- (void *) cpuBackingPtr	{
	return cpuBackingPtr;
}
- (IOSurfaceRef) localSurfaceRef	{
	return localSurfaceRef;
}
- (void) setLocalSurfaceRef:(IOSurfaceRef)n	{
	if (localSurfaceRef != NULL)	{
		//NSLog(@"\t\treleasing IOSurfaceRef");
		CFRelease(localSurfaceRef);
		localSurfaceRef = NULL;
		descriptor.localSurfaceID = 0;
	}
	if (n != NULL)	{
		//	i can't have a remote surface ref if i just made a local surface ref!
		[self setRemoteSurfaceRef:nil];
		
		localSurfaceRef = n;
		CFRetain(localSurfaceRef);
		descriptor.localSurfaceID = IOSurfaceGetID(localSurfaceRef);
	}
}
- (NSString *) stringForXPCComm	{
	if (localSurfaceRef==NULL)
		return nil;
	return VVFMTSTRING(@"%d,%f,%f,%f,%f,%d",IOSurfaceGetID(localSurfaceRef),srcRect.origin.x,srcRect.origin.y,srcRect.size.width,srcRect.size.height,flipped);
}
- (IOSurfaceRef) remoteSurfaceRef	{
	return remoteSurfaceRef;
}
- (void) setRemoteSurfaceRef:(IOSurfaceRef)n	{
	if (remoteSurfaceRef != NULL)	{
		//NSLog(@"\t\treleasing IOSurfaceRef");
		CFRelease(remoteSurfaceRef);
		remoteSurfaceRef = NULL;
	}
	if (n != NULL)	{
		//	i can't have a local surface ref if i just set the remote surface ref!
		[self setLocalSurfaceRef:nil];
		
		remoteSurfaceRef = n;
		CFRetain(remoteSurfaceRef);
		preferDeletion = YES;
	}
}


- (id) copySourceBuffer	{
	return copySourceBuffer;
}
- (void) setCopySourceBuffer:(id)n	{
	VVRELEASE(copySourceBuffer);
	copySourceBuffer = n;
	if (copySourceBuffer != nil)
		[copySourceBuffer retain];
}
@synthesize idleCount;
- (void) _incrementIdleCount	{
	++idleCount;
}
- (BOOL) isVVBuffer	{
	return YES;
}




@end




void VVBuffer_ReleasePixelsCallback(id b, void *c)	{
	void		*tmpPixels = c;
	if (tmpPixels != nil)
		free(tmpPixels);
}
void VVBuffer_ReleaseCVGLT(id b, void *c)	{
	CVOpenGLTextureRef	tmpRef = c;
	if (tmpRef != nil)
		CVOpenGLTextureRelease(tmpRef);
}
void VVBuffer_ReleaseCVPixBuf(id b, void *c)	{
	//NSLog(@"%s ... %p",__func__,c);
	CVPixelBufferRef	tmpRef = c;
	if (tmpRef != nil)	{
		//NSLog(@"\t\tunlocking %p",tmpRef);
		CVPixelBufferUnlockBaseAddress(tmpRef, 0);
		CVPixelBufferRelease(tmpRef);
	}
}
void VVBuffer_ReleaseBitmapRep(id b, void *c)	{
	NSBitmapImageRep	*tmpRep = c;
	if (tmpRep != nil)
		[tmpRep release];
}
#ifndef __LP64__
#pragma GCC diagnostic ignored "-Wimplicit"
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
void VVBuffer_ReleaseGWorld(id b, void *c)	{
	GWorldPtr		gWorld = c;
	//	get a ptr to the gworld's base address (raw pixel data) so i can free it (i have to explicitly free it because i explicitly created it)
	PixMapHandle		pixMapHandle = (gWorld==nil) ? nil : (PixMap **)GetGWorldPixMap(gWorld);
	void				*pixelMemory = (pixMapHandle==nil) ? nil : (*pixMapHandle)->baseAddr;
	
	DisposeGWorld(gWorld);
	gWorld = nil;
	
	if (pixelMemory != nil)	{
		//NSLog(@"\t\tfreeing pixel memory!");
		free(pixelMemory);
	}
}
#pragma GCC diagnostic warning "-Wimplicit"
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
#endif





@implementation NSObject (VVBufferChecking)
- (BOOL) isVVBuffer	{
	return NO;
}
@end
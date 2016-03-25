#import "VVBuffer.h"
#import "VVBufferPool.h"




void VVBufferQuadPopulate(VVBufferQuad *b, VVRECT geoRect, VVRECT texRect)	{
	if (b==nil)
		return;
	b->bl.geo[0] = VVMINX(geoRect);
	b->bl.geo[1] = VVMINY(geoRect);
	b->bl.tex[0] = VVMINX(texRect);
	b->bl.tex[1] = VVMINY(texRect);
	
	b->br.geo[0] = VVMAXX(geoRect);
	b->br.geo[1] = VVMINY(geoRect);
	b->br.tex[0] = VVMAXX(texRect);
	b->br.tex[1] = VVMINY(texRect);
	
	b->tl.geo[0] = VVMINX(geoRect);
	b->tl.geo[1] = VVMAXY(geoRect);
	b->tl.tex[0] = VVMINX(texRect);
	b->tl.tex[1] = VVMAXY(texRect);
	
	b->tr.geo[0] = VVMAXX(geoRect);
	b->tr.geo[1] = VVMAXY(geoRect);
	b->tr.tex[0] = VVMAXX(texRect);
	b->tr.tex[1] = VVMAXY(texRect);
}
void VVBufferDescriptorPopulateDefault(VVBufferDescriptor *d)	{
	if (d == nil)
		return;
	d->type = VVBufferType_None;
#if !TARGET_OS_IPHONE
	d->target = GL_TEXTURE_RECTANGLE_EXT;
#else
	d->target = GL_TEXTURE_2D;
#endif
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
unsigned long VVBufferDescriptorCalculateCPUBackingForSize(VVBufferDescriptor *b, VVSIZE s)	{
	unsigned long			bytesPerRow = 4 * s.width;	//	starting with the assumption of 32 bits per pixel
	switch (b->pixelType)	{
		case VVBufferPT_None:
			break;
		case VVBufferPT_Float:
			{
				switch (b->internalFormat)	{
#if !TARGET_OS_IPHONE
					case VVBufferIF_Lum8:
						bytesPerRow = 8 * 1 * s.width / 8;	//	should never exist; a pixel type of "float" should never be paired with a "lum8", as the # of bits per pixel explicitly conflicts
						break;
					case VVBufferIF_LumFloat:
					case VVBufferIF_R:
						bytesPerRow = 32 * 1 * s.width / 8;
						break;
#endif
					default:
						bytesPerRow = 32 * 4 * s.width / 8;
						break;
				}
			}
			break;
#if TARGET_OS_IPHONE
		case VVBufferPT_HalfFloat:
			{
				switch (b->internalFormat)	{
					case VVBufferIF_None:	//	should never exist
					case VVBufferIF_Lum8:
					case VVBufferIF_R:
						bytesPerRow = 32 * 1 * s.width / 8;
						break;
					case VVBufferIF_Depth24:
					case VVBufferIF_LumAlpha:
						bytesPerRow = 32 * 2 * s.width / 8;
						break;
					case VVBufferIF_RGB:
						bytesPerRow = 32 * 3 * s.width / 8;
						break;
					case VVBufferIF_RGBA:
					case VVBufferIF_RGBA32F:
						bytesPerRow = 32 * 4 * s.width / 8;
						break;
					case VVBufferIF_RGBA16F:
						bytesPerRow = 16 * 4 * s.width / 8;
						break;
				}
			}
			break;
#endif
		case VVBufferPT_U_Byte:
			{
				switch (b->internalFormat)	{
#if !TARGET_OS_IPHONE
					case VVBufferIF_Lum8:
					case VVBufferIF_R:
						bytesPerRow = 8 * 1 * s.width / 8;
						break;
#endif
#if !TARGET_OS_IPHONE
					case VVBufferIF_LumFloat:
						bytesPerRow = 32 * 1 * s.width / 8;
						break;
#endif
					default:
						bytesPerRow = 8 * 4 * s.width / 8;
						break;
				}
				break;
			}
			break;
#if !TARGET_OS_IPHONE
		case VVBufferPT_U_Int_8888_Rev:
			bytesPerRow = 8 * 4 * s.width / 8;
			break;
#endif
		case VVBufferPT_U_Short_88:
			bytesPerRow = 8 * 2 * s.width / 8;
			break;
	}
	
	switch (b->internalFormat)	{
#if !TARGET_OS_IPHONE
		case VVBufferIF_RGB_DXT1:	//	4 bits per pixel
		case VVBufferIF_A_RGTC:	//	4 bits per pixel
			bytesPerRow = 4 * s.width / 8;
			break;
		case VVBufferIF_RGBA_DXT5:	//	8 bits per pixel
		//case VVBufferIF_YCoCg_DXT5:	//	8 bits per pixel (flagged as duplicate case if un-commented, because both RGBA_DXT5 and YCoCg_DXT5 evaluate to the same internal format)
			bytesPerRow = 8 * s.width / 8;
			break;
#endif
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
		size = VVMAKESIZE(0,0);
		srcRect = VVZERORECT;
		flipped = NO;
		backingSize = VVMAKESIZE(0,0);
		auxTransMatrix = nil;
		auxOpacity = 1.0;
		contentTimestamp.tv_sec = 0;
		contentTimestamp.tv_usec = 0;
		userInfo = nil;
		
		backingID = VVBufferBackID_None;
		cpuBackingPtr = nil;
		
		backingReleaseCallback = nil;
		backingReleaseCallbackContext = nil;
		
#if !TARGET_OS_IPHONE
		localSurfaceRef = nil;
		remoteSurfaceRef = nil;
#endif
		
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
	
#if !TARGET_OS_IPHONE
	//	the IOSurfaceRefs in this instance of VVBuffer will exist, even if this buffer was created by copying another
	if (localSurfaceRef != nil)	{
		CFRelease(localSurfaceRef);
		localSurfaceRef = nil;
	}
	if (remoteSurfaceRef != nil)	{
		CFRelease(remoteSurfaceRef);
		remoteSurfaceRef = nil;
	}
#endif
	
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
	
#if !TARGET_OS_IPHONE
	if (localSurfaceRef != nil)
		[returnMe setLocalSurfaceRef:localSurfaceRef];
	if (remoteSurfaceRef != nil)
		[returnMe setRemoteSurfaceRef:remoteSurfaceRef];
#endif
	
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
			return [NSString stringWithFormat:@"<VVBuffer:FBO, %d (%p)>",descriptor.name,self];
		case VVBufferType_PBO:
			return [NSString stringWithFormat:@"<VVBuffer:PBO %u, %0.0f x %0.0f>",descriptor.name,size.width,size.height];
		case VVBufferType_VBO:
			return [NSString stringWithFormat:@"<VVBuffer: VBO %u>",descriptor.name];
#if !TARGET_OS_IPHONE
		case VVBufferType_DispList:
			return [NSString stringWithFormat:@"<VVBuffer:DispList %u>",descriptor.name];
#endif
		case VVBufferType_Tex:
		{
			if (descriptor.target==GL_TEXTURE_2D)
				return [NSString stringWithFormat:@"<VVBuffer:2D Tex %u, %0.0f x %0.0f>",descriptor.name,size.width,size.height];
#if !TARGET_OS_IPHONE
			else if (descriptor.target==GL_TEXTURE_RECTANGLE_EXT)
				return [NSString stringWithFormat:@"<VVBuffer:RECT Tex %u, %0.0f x %0.0f>",descriptor.name,size.width,size.height];
#endif
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
- (void) setSize:(VVSIZE)n	{
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
- (double) contentTimestampInSeconds	{
	double		returnMe = 0.;
	returnMe += (double)contentTimestamp.tv_sec;
	returnMe += (((double)contentTimestamp.tv_usec) / 1000000.);
	return returnMe;
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
- (VVRECT) normalizedSrcRect	{
	return VVMAKERECT(srcRect.origin.x/size.width, srcRect.origin.y/size.height, srcRect.size.width/size.width, srcRect.size.height/size.height);
}
- (VVRECT) glReadySrcRect	{
#if !TARGET_OS_IPHONE
	if (descriptor.target == GL_TEXTURE_RECTANGLE_EXT)
		return srcRect;
#endif
	return VVMAKERECT(srcRect.origin.x/size.width, srcRect.origin.y/size.height, srcRect.size.width/size.width, srcRect.size.height/size.height);
}

- (VVRECT) srcRectCroppedWith:(VVRECT)cropRect takingFlipIntoAccount:(BOOL)f	{
	VVRECT		flippedCropRect = cropRect;
	if (f && flipped)
		flippedCropRect.origin.y = (1.0 - cropRect.size.height - cropRect.origin.y);
	
	VVRECT		returnMe = VVZERORECT;
	returnMe.size = VVMAKESIZE(srcRect.size.width*flippedCropRect.size.width, srcRect.size.height*flippedCropRect.size.height);
	returnMe.origin.x = flippedCropRect.origin.x*srcRect.size.width + srcRect.origin.x;
	returnMe.origin.y = flippedCropRect.origin.y*srcRect.size.height + srcRect.origin.y;
	//if (descriptor.target == GL_TEXTURE_2D)
	//	returnMe = VVMAKERECT(returnMe.origin.x/size.width, returnMe.origin.y/size.height, returnMe.size.width/size.width, returnMe.size.height/size.height);
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
#if !TARGET_OS_IPHONE
- (BOOL) safeToPublishToSyphon	{
	if (localSurfaceRef==nil || flipped || descriptor.pixelFormat!=VVBufferPF_BGRA)
		return NO;
	//	make sure it's full-frame...
	if (srcRect.origin.x==0.0 && srcRect.origin.y==0.0 && srcRect.size.width==size.width && srcRect.size.height==size.height)
		return YES;
	return NO;
}
#endif
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
#if !TARGET_OS_IPHONE
- (CVOpenGLTextureRef) cvTexRef	{
	CVOpenGLTextureRef		cvTexRef = (backingID==VVBufferBackID_CVTex) ? backingReleaseCallbackContext : nil;
	return cvTexRef;
}
#endif
#if !TARGET_OS_IPHONE
- (NSBitmapImageRep *) bitmapRep	{
	NSBitmapImageRep		*bitmapRep = (backingID==VVBufferBackID_NSBitImgRep) ? backingReleaseCallbackContext : nil;
	return bitmapRep;
}
#endif
- (void *) externalBacking	{
	void		*externalBacking = (backingID==VVBufferBackID_External) ? backingReleaseCallbackContext : nil;
	return externalBacking;
}

#if TARGET_OS_IPHONE
#elif !__LP64__
- (GWorldPtr) gWorld	{
	GWorldPtr		gWorld = (backingID==VVBufferBackID_GWorld) ? backingReleaseCallbackContext : nil;
	return gWorld;
}
#else
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
#if !TARGET_OS_IPHONE
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
#endif


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
#if !TARGET_OS_IPHONE
	CVOpenGLTextureRef	tmpRef = c;
	if (tmpRef != nil)
		CVOpenGLTextureRelease(tmpRef);
#else
	CVOpenGLESTextureRef	tmpRef = c;
	if (tmpRef != nil)
		CFRelease(tmpRef);
#endif
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
	//NSBitmapImageRep	*tmpRep = c;
	id					tmpRep = c;
	if (tmpRep != nil)
		[tmpRep release];
}




#if TARGET_OS_IPHONE
#elif !__LP64__
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
#else
#endif




@implementation NSObject (VVBufferChecking)
- (BOOL) isVVBuffer	{
	return NO;
}
@end
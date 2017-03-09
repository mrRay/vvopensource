#import "VVBufferPool.h"
#if !TARGET_OS_IPHONE
#import <IOSurface/IOSurface.h>
#import <OpenGL/CGLIOSurface.h>

#ifdef __LP64__
#else	//	NOT __LP64__
#import "HapSupport.h"
#endif	//	__LP64__

#endif	//	!TARGET_OS_IPHONE




#define VVBITMASKCHECK(mask,flagToCheck) ((mask & flagToCheck) == flagToCheck) ? ((BOOL)YES) : ((BOOL)NO)

id _globalVVBufferPool = nil;
#if !TARGET_OS_IPHONE
int				_msaaMaxSamples = 0;
int				_glMaxTextureDimension = 1024;
#endif	//	!TARGET_OS_IPHONE
BOOL			_bufferPoolInitialized = NO;
VVMStopwatch		*_bufferTimestampMaker = nil;




@implementation VVBufferPool


+ (void) load	{
	//NSLog(@"%s",__func__);
#if !TARGET_OS_IPHONE
	_msaaMaxSamples = 0;
#endif	//	!TARGET_OS_IPHONE
	_bufferPoolInitialized = NO;
	_bufferTimestampMaker = nil;
	
#if TARGET_OS_IPHONE
#elif !__LP64__
	// The pixel formats must be registered before requesting them for a QTPixelBufferContext.
    // The codec does this but it is possible it may not be loaded yet.
    CFDictionaryRef		newDict = HapQTCreateCVPixelBufferOptionsDictionary();
    if (newDict != nil)
    	CFRelease(newDict);
#else
#endif
}
+ (void) initialize	{
	//NSLog(@"%s",__func__);
	if (_bufferPoolInitialized)
		return;
	
#if !TARGET_OS_IPHONE
	NSOpenGLContext		*tmpContext = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:nil];
	if (tmpContext != nil)	{
		CGLContextObj	cgl_ctx = [tmpContext CGLContextObj];
		GLint			tmp;
		glGetIntegerv(GL_MAX_SAMPLES_EXT,&tmp);
		_msaaMaxSamples = tmp;
		glGetIntegerv(GL_MAX_TEXTURE_SIZE, &tmp);
		_glMaxTextureDimension = tmp;
		[tmpContext release];
	}
#else	//	NOT !TARGET_OS_IPHONE
	[VVBufferGLKView class];
#endif	//	!TARGET_OS_IPHONE
	
	
	_bufferTimestampMaker = [[VVMStopwatch alloc] init];
	
	_bufferPoolInitialized = YES;
}
#if !TARGET_OS_IPHONE
+ (int) msaaMaxSamples	{
	return _msaaMaxSamples;
}
#endif	//	!TARGET_OS_IPHONE
+ (void) setGlobalVVBufferPool:(id)n	{
	//NSLog(@"%s ... %p",__func__,n);
	VVRELEASE(_globalVVBufferPool);
	_globalVVBufferPool = n;
	if (_globalVVBufferPool != nil)
		[_globalVVBufferPool retain];
	if (_globalVVBufferCopier == nil)	{
#if !TARGET_OS_IPHONE
		[VVBufferCopier createGlobalVVBufferCopierWithSharedContext:[n sharedContext]];
#else	//	NOT !TARGET_OS_IPHONE
		[VVBufferCopier createGlobalVVBufferCopierWithSharegroup:[n sharegroup]];
#endif	//	!TARGET_OS_IPHONE
	}
}
#if !TARGET_OS_IPHONE
+ (void) createGlobalVVBufferPoolWithSharedContext:(NSOpenGLContext *)n	{
	VVRELEASE(_globalVVBufferPool);
	if (n==nil)
		return;
	_globalVVBufferPool = [[VVBufferPool alloc] initWithSharedContext:n pixelFormat:[GLScene defaultPixelFormat] sized:VVMAKESIZE(1,1)];
	if (_globalVVBufferCopier == nil)
		[VVBufferCopier createGlobalVVBufferCopierWithSharedContext:n];
}
#else	//	NOT !TARGET_OS_IPHONE
+ (void) createGlobalVVBufferPoolWithSharegroup:(EAGLSharegroup *)n	{
	VVRELEASE(_globalVVBufferPool);
	if (n==nil)
		return;
	_globalVVBufferPool = [[VVBufferPool alloc] initWithSharegroup:n sized:VVMAKESIZE(1,1)];
	if (_globalVVBufferCopier == nil)
		[VVBufferCopier createGlobalVVBufferCopierWithSharegroup:n];
}
+ (void) createGlobalVVBufferPool	{
	VVRELEASE(_globalVVBufferPool);
	//NSLog(@"\t\tmaking an  EAGLContext in %s for %@",__func__,self);
	EAGLContext			*c = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3 sharegroup:nil];
	_globalVVBufferPool = [[VVBufferPool alloc] initWithContext:c sized:VVMAKESIZE(1,1)];
	[c release];
	if (_globalVVBufferCopier == nil)
		[VVBufferCopier createGlobalVVBufferCopierWithSharegroup:[c sharegroup]];
}
#endif	//	!TARGET_OS_IPHONE
+ (id) globalVVBufferPool	{
	return _globalVVBufferPool;
}
+ (void) timestampThisBuffer:(id)n	{
	if (n == nil)
		return;
	//	get the full (un-rounded) timestamp from the stopwatch, applying it directly to the passed buffer's struct
	[_bufferTimestampMaker getFullTimeSinceStart:[n contentTimestampPtr]];
}


/*===================================================================================*/
#pragma mark --------------------- push memory to VRAM (simple and DMA)
/*------------------------------------*/


#if !TARGET_OS_IPHONE
#pragma GCC diagnostic ignored "-Wimplicit"
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
+ (void) pushProperlySizedRAM:(void *)m toSimpleTextureBuffer:(VVBuffer *)b usingContext:(CGLContextObj)cgl_ctx	{
	if (b==nil || cgl_ctx==NULL)
		return;
	VVBufferDescriptor		*desc = [b descriptorPtr];
	if (desc==nil)
		return;
	if (desc->type!=VVBufferType_Tex)
		return;
	if (desc->gpuBackingType != VVBufferGPUBack_Internal)
		return;
	
	NSSize			bSize;
	
	glActiveTexture(GL_TEXTURE0);
	glEnable(desc->target);
	glBindTexture(desc->target, desc->name);
	
	if (desc->texClientStorageFlag)
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
	
	bSize = [b size];
	
	glTexSubImage2D(desc->target,
		0,
		0,
		0,
		bSize.width,
		bSize.height,
		desc->pixelFormat,
		desc->pixelType,
		m);
	
	if (desc->texClientStorageFlag)
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE);
	
	glBindTexture(desc->target, 0);
	//glDisable(desc->target);
	glFlush();
	
	//	timestamp the buffer, so we know a new frame has been pushed to it!
	[VVBufferPool timestampThisBuffer:b];
}
+ (void) pushTexRangeBufferRAMtoVRAM:(VVBuffer *)b usingContext:(CGLContextObj)cgl_ctx	{
	//NSLog(@"%s",__func__);
	if (b==nil || cgl_ctx==NULL)
		return;
	
	//		DOES NOT USE THE LOCAL CONTEXT!  ONLY USES PASSED CONTEXT!
	
	VVBufferDescriptor		*desc = [b descriptorPtr];
	if (desc==nil)
		return;
	if (desc->type!=VVBufferType_Tex)
		return;
	//if (desc->texRangeFlag != YES)
	//	return;
	if (desc->cpuBackingType == VVBufferCPUBack_None)
		return;
	if (desc->gpuBackingType != VVBufferGPUBack_Internal)
		return;
	if (!desc->texRangeFlag)
		return;
	
	NSSize			bSize;
	//NSSize			backingSize = [b backingSize];
	void			*pixels = [b cpuBackingPtr];
	BOOL			doCompressedUpload = NO;
	
	glActiveTexture(GL_TEXTURE0);
	glEnable(desc->target);
	glBindTexture(desc->target, desc->name);
	
	
	if (desc->texClientStorageFlag)
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
	
	switch (desc->internalFormat)	{
		case VVBufferIF_None:
		case VVBufferIF_Lum8:
		case VVBufferIF_LumFloat:
		case VVBufferIF_R:
		case VVBufferIF_RGB:
		case VVBufferIF_RGBA:
		case VVBufferIF_RGBA8:
		case VVBufferIF_Depth24:
		case VVBufferIF_RGBA32F:
			doCompressedUpload = NO;
			bSize = [b size];
			break;
		case VVBufferIF_RGB_DXT1:
		case VVBufferIF_RGBA_DXT5:
		//case VVBufferIF_YCoCg_DXT5:	//	(flagged as duplicate case if un-commented, because both RGBA_DXT5 and YCoCg_DXT5 evaluate to the same internal format)
		case VVBufferIF_A_RGTC:
			doCompressedUpload = YES;
			bSize = [b backingSize];
			break;
	}
	
	
	if (!doCompressedUpload)	{
		//NSLog(@"\t\tuncompressed upload");
		glTexSubImage2D(desc->target,
			0,
			0,
			0,
			bSize.width,
			bSize.height,
			desc->pixelFormat,
			desc->pixelType,
			pixels);
		//NSLog(@"\t\tfinished uncompressed upload");
		//NSLog(@"\t\target is %ld, should be %ld",desc->target,GL_TEXTURE_RECTANGLE_EXT);
		//NSLog(@"\t\twidth/height is %f x %f",bSize.width,bSize.height);
		//NSLog(@"\t\tpixelFormat is %ld, should be %ld",desc->pixelFormat,GL_YCBCR_422_APPLE);
		//NSLog(@"\t\tpixelType is %ld, should be %ld",desc->pixelType,GL_UNSIGNED_SHORT_8_8_APPLE);
	}
	else	{
		//NSLog(@"\t\tcompressed upload! %s",__func__);
		//int					rowBytes = (pmHandle==nil) ? 0 : ((*pmHandle)->rowBytes)&0x7FFF;
		//int				rowBytes = VVBufferDescriptorCalculateCPUBackingForSize([b descriptorPtr], [b size]);
		//int				rowBytes = VVBufferDescriptorCalculateCPUBackingForSize([b descriptorPtr], bSize);
		unsigned long		cpuBufferLength = VVBufferDescriptorCalculateCPUBackingForSize([b descriptorPtr], bSize);
		bSize = [b backingSize];
		glCompressedTexSubImage2D(desc->target,
			0,
			0,
			0,
			bSize.width,
			bSize.height,
			desc->internalFormat,
			//rowBytes * bSize.height,
			cpuBufferLength,
			pixels);
		//NSLog(@"\t\tfinished compressed upload");
	}
	/*
	if (desc->backingType == VVBufferBack_GWorld)	{
		//if (pmHandle != nil)
		//	UnlockPixels(pmHandle);
	}
	*/
	if (desc->texClientStorageFlag)
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE);
	
	glBindTexture(desc->target, 0);
	//glDisable(desc->target);
	glFlush();
	
	//	timestamp the buffer, so we know a new frame has been pushed to it!
	[VVBufferPool timestampThisBuffer:b];
}
#pragma GCC diagnostic warning "-Wimplicit"
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
#endif	//	!TARGET_OS_IPHONE


/*===================================================================================*/
#pragma mark --------------------- misc upkeep
/*------------------------------------*/


- (void) housekeeping	{
	//NSLog(@"%s",__func__);
	if (!_bufferPoolInitialized)
		return;
	//	increment the idle count;
	[freeBuffers lockMakeObjectsPerformSelector:@selector(_incrementIdleCount)];
	//	go through & delete anything with an idle count > 30
	NSMutableIndexSet	*indicesToDelete = nil;
	int					tmpIndex = 0;
	[freeBuffers wrlock];
		for (VVBuffer *bufferPtr in [freeBuffers array])	{
			if ([bufferPtr idleCount]>30)	{
				if (indicesToDelete == nil)
					indicesToDelete = [[[NSMutableIndexSet alloc] init] autorelease];
				[indicesToDelete addIndex:tmpIndex];
			}
			++tmpIndex;
		}
		if ((indicesToDelete != nil) && ([indicesToDelete count]>0))	{
			[freeBuffers removeObjectsAtIndexes:indicesToDelete];
		}
	[freeBuffers unlock];
}
- (void) startHousekeepingThread	{
	if (housekeepingThread != nil)
		[housekeepingThread start];
}
- (void) stopHousekeepingThread	{
	if (housekeepingThread != nil)
		[housekeepingThread stop];
}


/*===================================================================================*/
#pragma mark --------------------- create/destroy
/*------------------------------------*/


/*
- (id) initWithSharedContext:(NSOpenGLContext *)c	{
	return [self initWithSharedContext:c pixelFormat:[GLScene defaultPixelFormat] sized:VVMAKESIZE(80,60)];
}
- (id) initWithSharedContext:(NSOpenGLContext *)c sized:(VVSIZE)s	{
	return [self initWithSharedContext:c pixelFormat:[GLScene defaultPixelFormat] sized:s];
}
- (id) initWithSharedContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p	{
	return [self initWithSharedContext:c pixelFormat:p sized:VVMAKESIZE(80,60)];
}
- (id) initWithSharedContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p sized:(VVSIZE)s	{
	self = [super initWithSharedContext:c pixelFormat:p sized:s];
	if (self!=nil)	{
	}
	return self;
}
*/
- (void) generalInit	{
	//NSLog(@"%s",__func__);
	[super generalInit];
	//context = [[NSOpenGLContext alloc] initWithFormat:customPixelFormat shareContext:sharedContext];
	
	pthread_mutexattr_t		attr;
	
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
	pthread_mutex_init(&contextLock, &attr);
	pthread_mutexattr_destroy(&attr);
	
	freeBuffers = [[MutLockArray arrayWithCapacity:0] retain];
	
	housekeepingThread = [[VVThreadLoop alloc] initWithTimeInterval:1.0 target:self selector:@selector(housekeeping)];
	//[housekeepingThread start];
	
	[self _renderPrep];
}
- (void) dealloc	{
	pthread_mutex_destroy(&contextLock);
	VVRELEASE(freeBuffers);
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- backend methods for creating/finding buffers
/*------------------------------------*/


//	this method can't create ALL buffer types- many VVBuffers are created from resources from other frameworks/libs, and as such this buffer pool may not be responsible- or may only be responsible for *part* (like just the GL texture) of the resource it creates!
- (VVBuffer *) allocBufferForDescriptor:(VVBufferDescriptor *)d sized:(VVSIZE)s backingPtr:(void *)b backingSize:(VVSIZE)bs	{
#if !TARGET_OS_IPHONE
	return [self allocBufferForDescriptor:d sized:s backingPtr:b backingSize:bs inContext:[self CGLContextObj]];
#else	//	NOT !TARGET_OS_IPHONE
	return [self allocBufferForDescriptor:d sized:s backingPtr:b backingSize:bs inContext:[self context]];
#endif	//	!TARGET_OS_IPHONE
}
#if !TARGET_OS_IPHONE
- (VVBuffer *) allocBufferForDescriptor:(VVBufferDescriptor *)d sized:(VVSIZE)s backingPtr:(void *)b backingSize:(VVSIZE)bs inContext:(CGLContextObj)c
#else	//	NOT !TARGET_OS_IPHONE
- (VVBuffer *) allocBufferForDescriptor:(VVBufferDescriptor *)d sized:(VVSIZE)s backingPtr:(void *)b backingSize:(VVSIZE)bs inContext:(EAGLContext *)c
#endif	//	!TARGET_OS_IPHONE
{
	//NSLog(@"%s",__func__);
	if (deleted || d==nil)
		return nil;
	VVBuffer		*returnMe = nil;
	
	//	if i wasn't passed a backing ptr, try to find a free buffer matching the passed descriptor
	if (b==nil)
		returnMe = [self copyFreeBufferMatchingDescriptor:d sized:s];
	//	if i found an unused buffer in the array, return it immediately
	if (returnMe != nil)	{
		//NSLog(@"\t\tfound free buffer!");
		//	remember- this method returns a RETAINED instance of VVBuffer- its retainCount is 1!
		return returnMe;
	}
	//NSLog(@"%s",__func__);

#if !TARGET_OS_IPHONE
	CGLError				err = kCGLNoError;
	IOSurfaceRef			newSurfaceRef = nil;
#endif	//	!TARGET_OS_IPHONE
	//	make a buffer descriptor, populate it from the one i was passed- this will describe the buffer i'm returning
	VVBufferDescriptor		newBufferDesc;
	VVBufferDescriptorCopy(d,&newBufferDesc);
#if !TARGET_OS_IPHONE
	unsigned long			cpuBackingSize = VVBufferDescriptorCalculateCPUBackingForSize(&newBufferDesc, bs);
	unsigned long			bytesPerRow = cpuBackingSize / bs.height;
#endif	//	!TARGET_OS_IPHONE
	
	
	OSType					pixelFormat = 0x00;
	BOOL					compressedTex = NO;
#if !TARGET_OS_IPHONE
	switch (newBufferDesc.internalFormat)	{
		case VVBufferIF_RGB_DXT1:
		case VVBufferIF_RGBA_DXT5:
		case VVBufferIF_A_RGTC:
			compressedTex = YES;
			break;
		default:
			break;
	}
#endif	//	!TARGET_OS_IPHONE
	switch (newBufferDesc.pixelFormat)	{
		case VVBufferPF_None:
		case VVBufferPF_Depth:
			break;
#if !TARGET_OS_IPHONE
		case VVBufferPF_R:
#endif	//	!TARGET_OS_IPHONE
		case VVBufferPF_Lum:
			pixelFormat = kCVPixelFormatType_OneComponent8;
			break;
		case VVBufferPF_LumAlpha:
			pixelFormat = kCVPixelFormatType_TwoComponent8;
			break;
		case VVBufferPF_RGBA:		//	'RGBA'
			pixelFormat = kCVPixelFormatType_32RGBA;
			break;
		case VVBufferPF_BGRA:		//	'BGRA'
			pixelFormat = kCVPixelFormatType_32BGRA;
			break;
#if !TARGET_OS_IPHONE
		case VVBufferPF_YCBCR_422:	//	'2vuy'
			pixelFormat = kCVPixelFormatType_422YpCbCr8;
			break;
#endif	//	!TARGET_OS_IPHONE
	}
	
	
	//	create the GL resources, populating the buffer descriptor where appropriate
#if !TARGET_OS_IPHONE
	CGLContextObj			cgl_ctx = c;
#else	//	NOT !TARGET_OS_IPHONE
	if (c != nil)
		[EAGLContext setCurrentContext:c];
#endif	//	!TARGET_OS_IPHONE
	pthread_mutex_lock(&contextLock);
	switch (newBufferDesc.type)	{
		case VVBufferType_None:
			//NSLog(@"\t\tsize is %f x %f, BPR is %d",s.width,s.height,bytesPerRow);
			break;
		case VVBufferType_RB:
			//	generate the renderbuffer
			glGenRenderbuffers(1,&newBufferDesc.name);
			//	bind the renderbuffer, set it up
			glBindRenderbuffer(newBufferDesc.target, newBufferDesc.name);
			if (newBufferDesc.msAmount > 0)	{
				glRenderbufferStorageMultisample(newBufferDesc.target,
					newBufferDesc.msAmount,
					newBufferDesc.pixelFormat,
					s.width,
					s.height);
			}
			//	unbind the renderbuffer
			glBindRenderbuffer(newBufferDesc.target, 0);
			//	flush!
			glFlush();
			break;
		case VVBufferType_FBO:
			//	generate the fbo
			glGenFramebuffers(1,&newBufferDesc.name);
			//	make sure there aren't any errors
			//if (GL_FRAMEBUFFER_COMPLETE_EXT != glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT))
			//	NSLog(@"err- fbo %s",__func__);
			//	flush!
			glFlush();
			break;
		case VVBufferType_Tex:
#if !TARGET_OS_IPHONE
			//	if necessary, create an iosurface ref
			if (newBufferDesc.localSurfaceID != 0)	{
				newSurfaceRef = IOSurfaceCreate((CFDictionaryRef)[NSDictionary dictionaryWithObjectsAndKeys:
					NUMBOOL(YES),(NSString*)kIOSurfaceIsGlobal,
					NUMUINT(s.width),(NSString*)kIOSurfaceWidth,
					NUMUINT(s.height),(NSString*)kIOSurfaceHeight,
					NUMUINT(bytesPerRow/s.width),(NSString*)kIOSurfaceBytesPerElement,
					NUMINT(pixelFormat),(NSString *)kIOSurfacePixelFormat,
					nil]);
				if (newSurfaceRef == nil)	{
					NSLog(@"\t\terr at IOSurfaceCreate() in %s",__func__);
					newBufferDesc.localSurfaceID = 0;
				}
			}
#endif	//	!TARGET_OS_IPHONE
			//	enable the tex target, gen the texture, and bind it
#if !TARGET_OS_IPHONE
			glEnable(newBufferDesc.target);
#endif	//	!TARGET_OS_IPHONE
			glGenTextures(1,&newBufferDesc.name);
			glBindTexture(newBufferDesc.target, newBufferDesc.name);
			
#if !TARGET_OS_IPHONE
			//	if i want a texture range, there are a couple cases where i can apply it
			if (newBufferDesc.texRangeFlag)	{
				if (b!=nil)	{
					glTextureRangeAPPLE(newBufferDesc.target, cpuBackingSize, b);
				}
			}
			
			if (newBufferDesc.texClientStorageFlag)	{
				//		client storage hint- my app will keep the (CPU-based) 'pixels' around until 
				//all referencing GL textures have been deleted.  this lets me skip the app->framework 
				//copy IF THE TEXTURE WIDTH IS A MULTIPLE OF 32 BYTES!
				glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
			}
#endif	//	!TARGET_OS_IPHONE
			
#if !TARGET_OS_IPHONE
			//	setup basic tex defaults
			glPixelStorei(GL_UNPACK_SKIP_ROWS, GL_FALSE);
			glPixelStorei(GL_UNPACK_SKIP_PIXELS, GL_FALSE);
			glPixelStorei(GL_UNPACK_SWAP_BYTES, GL_FALSE);
#endif	//	!TARGET_OS_IPHONE
			
			glTexParameteri(newBufferDesc.target, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameteri(newBufferDesc.target, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			//glTexParameteri(newBufferDesc.target, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
			//glTexParameteri(newBufferDesc.target, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexParameteri(newBufferDesc.target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(newBufferDesc.target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
			//glTexParameteri(newBufferDesc.target, GL_TEXTURE_WRAP_S, GL_REPEAT);
			//glTexParameteri(newBufferDesc.target, GL_TEXTURE_WRAP_T, GL_REPEAT);
			
#if !TARGET_OS_IPHONE
			if (newBufferDesc.pixelFormat == VVBufferPF_Depth)
				glTexParameteri(newBufferDesc.target, GL_DEPTH_TEXTURE_MODE, GL_INTENSITY);
			
			if (newBufferDesc.pixelFormat == VVBufferPF_Depth)
				glTexParameteri(newBufferDesc.target, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
			else
				glTexParameteri(newBufferDesc.target, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);
#endif	//	!TARGET_OS_IPHONE

			
#if !TARGET_OS_IPHONE
			//	if there's a surface ref, set it up as the texture!
			if (newSurfaceRef != nil)	{
				err = CGLTexImageIOSurface2D(cgl_ctx,
					newBufferDesc.target,
					newBufferDesc.internalFormat,
					s.width,
					s.height,
					newBufferDesc.pixelFormat,
					newBufferDesc.pixelType,
					newSurfaceRef,
					0);
				if (b != nil)	{
					glTexSubImage2D(newBufferDesc.target,
						0,
						0,
						0,
						s.width,
						s.height,
						newBufferDesc.pixelFormat,
						newBufferDesc.pixelType,
						b);
				}
			}
#endif	//	!TARGET_OS_IPHONE
			
			
			
			//	if there's no surface ref, or there is, but there was a problem associating it with the texture, set it up as a straight-up texture!
#if !TARGET_OS_IPHONE
			if (newSurfaceRef==nil || err!=kCGLNoError)	{
#endif	//	!TARGET_OS_IPHONE
				if (compressedTex)	{
					glTexImage2D(newBufferDesc.target,
						0,
						newBufferDesc.internalFormat,
						s.width,
						s.height,
						0,
						newBufferDesc.pixelFormat,
						newBufferDesc.pixelType,
						NULL);
				}
				else	{
					//NSLog(@"\t\ttarget is %ld (should be %ld)",newBufferDesc.target,GL_TEXTURE_2D);
					//NSLog(@"\t\tinternal is %ld (should be %ld)",newBufferDesc.internalFormat,GL_RGBA);
					//NSLog(@"\t\tpf is %ld (should be %ld)",newBufferDesc.pixelFormat,GL_RGBA);
					//NSLog(@"\t\tpt is %ld (should be %ld)",newBufferDesc.pixelType,GL_UNSIGNED_BYTE);
					//NSLog(@"\t\tbytes are %p",b);
					glTexImage2D(newBufferDesc.target,
						0,
						newBufferDesc.internalFormat,
						s.width,
						s.height,
						0,
						newBufferDesc.pixelFormat,
						newBufferDesc.pixelType,
						b);
					
				}
#if !TARGET_OS_IPHONE
			}
#endif	//	!TARGET_OS_IPHONE
	
			
#if !TARGET_OS_IPHONE
			if (newBufferDesc.texClientStorageFlag)	{
				glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE);
			}
#endif	//	!TARGET_OS_IPHONE
			
			//	un-bind the tex and disable the target
			glBindTexture(newBufferDesc.target, 0);
#if !TARGET_OS_IPHONE
			glDisable(newBufferDesc.target);
#endif	//	!TARGET_OS_IPHONE
			
			//	flush!
			glFlush();
			break;
		case VVBufferType_PBO:
			glGenBuffers(1,&newBufferDesc.name);
			//	flush!
			glFlush();
			//	"pack" means this PBO will be used to transfer pixel data TO a PBO (glReadPixels(), glGetTexImage())
			//	"unpack" means this PBO will be used to transfer pixel data FROM a PBO (glDrawPixels(), glTexImage2D(), glTexSubImage2D())
			
			//				decoding "GL_STREAM_DRAW, GL_STREAM_READ, etc:
			//	STREAM		write once, read at most a few times
			//	STATIC		write once, read many times
			//	DYNAMIC		write many times, read many times
			//	--------	--------	--------
			//	DRAW		CPU -> GL
			//	READ		GL -> CPU
			//	COPY		GL -> GL
			break;
		case VVBufferType_VBO:
			//	left intentionally blank, VBOs are created in their own method
			break;
#if !TARGET_OS_IPHONE
		case VVBufferType_DispList:
			newBufferDesc.name = glGenLists(1);
			//	flush!
			glFlush();
			break;
#endif	//	!TARGET_OS_IPHONE
	}
	pthread_mutex_unlock(&contextLock);
	
	returnMe = [[VVBuffer alloc] initWithPool:self];
	[returnMe setDescriptorFromPtr:&newBufferDesc];
	[returnMe setSize:s];
	[returnMe setSrcRect:VVMAKERECT(0,0,s.width,s.height)];
	[returnMe setBackingSize:bs];
	[returnMe setCpuBackingPtr:b];
	[VVBufferPool timestampThisBuffer:returnMe];
	
#if !TARGET_OS_IPHONE
	if (newSurfaceRef != nil)	{
		[returnMe setLocalSurfaceRef:newSurfaceRef];
		CFRelease(newSurfaceRef);
		newSurfaceRef = nil;
	}
#endif	//	!TARGET_OS_IPHONE
	return returnMe;
}
#if TARGET_OS_IPHONE
- (VVBuffer *) allocBufferInCurrentContextForDescriptor:(VVBufferDescriptor *)d sized:(VVSIZE)s backingPtr:(void *)b backingSize:(VVSIZE)bs	{
	return [self allocBufferForDescriptor:d sized:s backingPtr:b backingSize:bs inContext:NULL];
}
#endif	//	!TARGET_OS_IPHONE
- (VVBuffer *) copyFreeBufferMatchingDescriptor:(VVBufferDescriptor *)d sized:(VVSIZE)s	{
	//NSLog(@"%s",__func__);
	if (deleted || d==nil)
		return nil;
	VVBuffer		*returnMe = nil;
	//	lock the array of buffers- i'll either be doing nothing, or taking something out of it
	[freeBuffers wrlock];
		//NSLog(@"\t\tfreeBuffers are %@",freeBuffers);
		int				tmpIndex = 0;
		//	run through all the buffers
		for (VVBuffer *bufferPtr in [freeBuffers array])	{
			VVBufferDescriptor		*tmpDesc = [bufferPtr descriptorPtr];
			if (VVBufferDescriptorCompareForRecycling(d,tmpDesc))	{
				//NSLog(@"\t\tdescriptor for buffer %@ matches....",bufferPtr);
				//	some buffer types need to be matched by size!
				BOOL				sizeIsOK = NO;
				switch (tmpDesc->type)	{
					case VVBufferType_FBO:
#if !TARGET_OS_IPHONE
					case VVBufferType_DispList:
#endif	//	!TARGET_OS_IPHONE
						sizeIsOK = YES;
						break;
					case VVBufferType_None:	//	need to check size because RGB/RGBA CPU buffers use this type!
					case VVBufferType_RB:
					case VVBufferType_Tex:
					case VVBufferType_PBO:
						if (VVEQUALSIZES(s,[bufferPtr size]))
							sizeIsOK = YES;
						break;
					case VVBufferType_VBO:
						sizeIsOK = NO;
						break;
				}
				
				if (sizeIsOK)	{
					//NSLog(@"\t\tsize is OK!");
#if !TARGET_OS_IPHONE
					IOSurfaceRef		srf = [bufferPtr localSurfaceRef];
					//NSLog(@"\t\tsrf is %p, d->localSurfaceID is %lu",srf,d->localSurfaceID);
					if ((d->localSurfaceID!=0 && srf!=nil) || (d->localSurfaceID==0 && srf==nil))	{
#endif	//	!TARGET_OS_IPHONE
						//	retain the buffer (so it doesn't get freed)
						returnMe = [bufferPtr retain];
						//	remove the buffer from the array
						[freeBuffers removeObjectAtIndex:tmpIndex];
						//	set the buffer's idleCount to 0, so it's "fresh" (so it gets returned to the pool when it's no longer needed)
						[returnMe setIdleCount:0];
						//	break out of the foor loop
						break;
#if !TARGET_OS_IPHONE
					}
#endif	//	!TARGET_OS_IPHONE
				}
			}
			++tmpIndex;
		}
	//	unlock the array of buffers
	[freeBuffers unlock];
	if (returnMe != nil)
		[VVBufferPool timestampThisBuffer:returnMe];
	//	remember: i'm returning a RETAINED instance of VVBuffer that must be EXPLICITLY FREED!
	return returnMe;
}
- (VVBuffer *) copyFreeBufferMatchingDescriptor:(VVBufferDescriptor *)d sized:(VVSIZE)s backingSize:(VVSIZE)bs	{
	//NSLog(@"%s ... (%f x %f), (%f x %f)",__func__,s.width,s.height,bs.width,bs.height);
	if (deleted || d==nil)
		return nil;
	VVBuffer		*returnMe = nil;
	//	lock the array of buffers- i'll either be doing nothing, or taking something out of it
	[freeBuffers wrlock];
		//NSLog(@"\t\tfreeBuffers are %@",freeBuffers);
		int				tmpIndex = 0;
		//	run through all the buffers
		for (VVBuffer *bufferPtr in [freeBuffers array])	{
			VVBufferDescriptor		*tmpDesc = [bufferPtr descriptorPtr];
			if (VVBufferDescriptorCompareForRecycling(d,tmpDesc))	{
				//NSLog(@"\t\tdescriptor for buffer %@ matches....",bufferPtr);
				//	some buffer types need to be matched by size!
				BOOL				sizeIsOK = NO;
				BOOL				backingSizeIsOK = NO;
				switch (tmpDesc->type)	{
					case VVBufferType_FBO:
#if !TARGET_OS_IPHONE
					case VVBufferType_DispList:
						sizeIsOK = YES;
						backingSizeIsOK = YES;
						break;
#endif	//	!TARGET_OS_IPHONE
					case VVBufferType_None:	//	need to check size because RGB/RGBA CPU buffers use this type!
					case VVBufferType_RB:
					case VVBufferType_Tex:
					case VVBufferType_PBO:
						//NSLog(@"\t\t(%f x %f), (%f x %f)",[bufferPtr size].width,[bufferPtr size].height,[bufferPtr backingSize].width,[bufferPtr backingSize].height);
						if (VVEQUALSIZES(s,[bufferPtr size]))
							sizeIsOK = YES;
						if (VVEQUALSIZES(bs,[bufferPtr backingSize]))
							backingSizeIsOK = YES;
						break;
					case VVBufferType_VBO:
						sizeIsOK = NO;
						backingSizeIsOK = NO;
						break;
				}
				
				if (sizeIsOK && backingSizeIsOK)	{
#if !TARGET_OS_IPHONE
					IOSurfaceRef		srf = [bufferPtr localSurfaceRef];
					//NSLog(@"\t\tsrf is %p, d->localSurfaceID is %lu",srf,d->localSurfaceID);
					if ((d->localSurfaceID!=0 && srf!=nil) || (d->localSurfaceID==0 && srf==nil))	{
#endif	//	!TARGET_OS_IPHONE
						//	retain the buffer (so it doesn't get freed)
						returnMe = [bufferPtr retain];
						//	remove the buffer from the array
						[freeBuffers removeObjectAtIndex:tmpIndex];
						//	set the buffer's idleCount to 0, so it's "fresh" (so it gets returned to the pool when it's no longer needed)
						[returnMe setIdleCount:0];
						//	break out of the foor loop
						break;
#if !TARGET_OS_IPHONE
					}
#endif	//	!TARGET_OS_IPHONE
				}
			}
			++tmpIndex;
		}
	//	unlock the array of buffers
	[freeBuffers unlock];
	if (returnMe != nil)
		[VVBufferPool timestampThisBuffer:returnMe];
	//	remember: i'm returning a RETAINED instance of VVBuffer that must be EXPLICITLY FREED!
	return returnMe;
}


/*===================================================================================*/
#pragma mark --------------------- METHODS TO CREATE VVBUFFERS START HERE
#pragma mark ------------------------------------------
/*------------------------------------*/



/*===================================================================================*/
#pragma mark --------------------- basic/commonly-used creation methods
/*------------------------------------*/


- (VVBuffer *) allocFBO	{
	VVSIZE					tmpSize = VVMAKESIZE(1,1);
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_FBO;
	desc.target = 0;
	desc.internalFormat = VVBufferIF_None;
	desc.pixelFormat = VVBufferPF_None;
	desc.pixelType = VVBufferPT_None;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:tmpSize];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:tmpSize backingPtr:nil backingSize:tmpSize];
	return returnMe;
}
#if !TARGET_OS_IPHONE
- (VVBuffer *) allocBGRTexSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	return returnMe;
}
#endif	//	!TARGET_OS_IPHONE
- (VVBuffer *) allocBGR2DTexSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_2D;
#if !TARGET_OS_IPHONE
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
#else	//	NOT !TARGET_OS_IPHONE
	desc.internalFormat = VVBufferIF_RGBA;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_U_Byte;
#endif	//	!TARGET_OS_IPHONE
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	return returnMe;
}
- (VVBuffer *) allocBGR2DPOTTexSized:(VVSIZE)s	{
	//	rounds up the size to the nearest POT
	VVSIZE		texSize;
	int			tmpInt = 1;
	while (tmpInt < s.width)
		tmpInt <<= 1;
	texSize.width = tmpInt;
	tmpInt = 1;
	while (tmpInt < s.height)
		tmpInt <<= 1;
	texSize.height = tmpInt;
	//	make the width & the height match
	texSize.width = fmax(texSize.width,texSize.height);
	texSize.height = texSize.width;
	
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_2D;
#if !TARGET_OS_IPHONE
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
#else
	desc.internalFormat = VVBufferIF_RGBA;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_U_Byte;
#endif
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:texSize];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:texSize backingPtr:nil backingSize:s];
	[returnMe setSrcRect:VVMAKERECT(0,0,s.width,s.height)];
	[returnMe setBackingSize:s];
	return returnMe;
}
#if !TARGET_OS_IPHONE
- (VVBuffer *) allocBGRFloatTexSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA32F;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_Float;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	return returnMe;
}
#endif	//	!TARGET_OS_IPHONE
- (VVBuffer *) allocBGRFloat2DPOTTexSized:(VVSIZE)s	{
	//	rounds up the size to the nearest POT
	VVSIZE		texSize;
	int			tmpInt = 1;
	while (tmpInt < s.width)
		tmpInt <<= 1;
	texSize.width = tmpInt;
	tmpInt = 1;
	while (tmpInt < s.height)
		tmpInt <<= 1;
	texSize.height = tmpInt;
	//	make the width & the height match
	texSize.width = fmax(texSize.width,texSize.height);
	texSize.height = texSize.width;
	return [self allocBGRFloat2DTexSized:texSize];
}
- (VVBuffer *) allocBGRFloat2DTexSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_2D;
#if !TARGET_OS_IPHONE
	desc.internalFormat = VVBufferIF_RGBA32F;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_Float;
#else	//	NOT !TARGET_OS_IPHONE
	desc.internalFormat = VVBufferIF_RGBA16F;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_HalfFloat;
#endif	//	!TARGET_OS_IPHONE
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	return returnMe;
}
- (VVBuffer *) allocDepthSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
#if !TARGET_OS_IPHONE
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
#else	//	NOT !TARGET_OS_IPHONE
	desc.target = GL_TEXTURE_2D;
#endif	//	!TARGET_OS_IPHONE
	desc.internalFormat = VVBufferIF_Depth24;
	desc.pixelFormat = VVBufferPF_Depth;
	desc.pixelType = VVBufferPT_U_Byte;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	return returnMe;
}
- (VVBuffer *) allocMSAAColorSized:(VVSIZE)s numOfSamples:(int)n	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_RB;
	desc.target = GL_RENDERBUFFER;
	desc.internalFormat = VVBufferIF_RGBA;
	desc.pixelFormat = VVBufferPF_RGBA;
#if !TARGET_OS_IPHONE
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
#else	//	NOT !TARGET_OS_IPHONE
	desc.pixelType = VVBufferPT_U_Byte;
#endif	//	!TARGET_OS_IPHONE
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = n;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	return returnMe;
}
- (VVBuffer *) allocMSAADepthSized:(VVSIZE)s numOfSamples:(int)n	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_RB;
	desc.target = GL_RENDERBUFFER;
	desc.internalFormat = VVBufferIF_Depth24;
	desc.pixelFormat = VVBufferPF_Depth;
	desc.pixelType = VVBufferPT_U_Byte;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = n;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	return returnMe;
}
#if !TARGET_OS_IPHONE
- (VVBuffer *) allocYCbCrTexSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGB;
	desc.pixelFormat = VVBufferPF_YCBCR_422;
	desc.pixelType = VVBufferPT_U_Short_88;
	//desc.backingType = VVBufferBack_None;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	return returnMe;
}
#endif	//	!TARGET_OS_IPHONE
- (VVBuffer *) allocRGBTexSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
#if TARGET_OS_IPHONE
	desc.target = GL_TEXTURE_2D;
	desc.internalFormat = VVBufferIF_RGBA;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_U_Byte;
#else	//	NOT TARGET_OS_IPHONE
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
#endif
	//desc.backingType = VVBufferBack_None;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	return returnMe;
}
- (VVBuffer *) allocRGB2DPOTTexSized:(VVSIZE)s	{
	//	rounds up the size to the nearest POT
	VVSIZE		texSize;
	int			tmpInt = 1;
	while (tmpInt < s.width)
		tmpInt <<= 1;
	texSize.width = tmpInt;
	tmpInt = 1;
	while (tmpInt < s.height)
		tmpInt <<= 1;
	texSize.height = tmpInt;
	//	make the width & the height match
	texSize.width = fmax(texSize.width,texSize.height);
	texSize.height = texSize.width;
	
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_2D;
#if TARGET_OS_IPHONE
	desc.internalFormat = VVBufferIF_RGBA;
#else	//	NOT TARGET_OS_IPHONE
	desc.internalFormat = VVBufferIF_RGBA8;
#endif
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_U_Byte;
	//desc.backingType = VVBufferBack_None;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:texSize];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:texSize backingPtr:nil backingSize:s];
	[returnMe setSrcRect:VVMAKERECT(0,0,s.width,s.height)];
	[returnMe setBackingSize:s];
	return returnMe;
}
- (VVBuffer *) allocRGBFloatTexSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
#if TARGET_OS_IPHONE
	desc.target = GL_TEXTURE_2D;
#else	//	NOT TARGET_OS_IPHONE
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
#endif	//	TARGET_OS_IPHONE
	desc.internalFormat = VVBufferIF_RGBA32F;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_Float;
	//desc.backingType = VVBufferBack_None;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	return returnMe;
}


/*===================================================================================*/
#pragma mark --------------------- creating VVBuffers from other kinds of images
/*------------------------------------*/


#if !TARGET_OS_IPHONE
- (VVBuffer *) allocBufferForNSImage:(NSImage *)img	{
	return [self allocBufferForNSImage:img prefer2DTexture:NO];
}
- (VVBuffer *) allocBufferForNSImage:(NSImage *)img prefer2DTexture:(BOOL)prefer2D	{
	//NSLog(@"%s ... %d",__func__,prefer2D);
	if (img==nil)
		return nil;
	
	VVSIZE				origImageSize = [img size];
	NSRect				origImageRect = NSMakeRect(0, 0, origImageSize.width, origImageSize.height);
	NSImageRep			*bestRep = [img bestRepresentationForRect:origImageRect context:nil hints:nil];
	VVSIZE				bitmapSize = VVMAKESIZE([bestRep pixelsWide], [bestRep pixelsHigh]);
	if (bitmapSize.width==0 || bitmapSize.height==0)
		bitmapSize = [img size];
	VVRECT				bitmapRect = VVMAKERECT(0,0,bitmapSize.width,bitmapSize.height);
	
	//	make a bitmap image rep
	NSBitmapImageRep		*rep = [[NSBitmapImageRep alloc]
		initWithBitmapDataPlanes:nil
		pixelsWide:bitmapSize.width
		pixelsHigh:bitmapSize.height
		bitsPerSample:8
		samplesPerPixel:4
		hasAlpha:YES
		isPlanar:NO
		colorSpaceName:NSCalibratedRGBColorSpace
		bitmapFormat:0
		bytesPerRow:32 * bitmapSize.width / 8
		bitsPerPixel:32];
	if (rep == nil)
		return nil;
	//	save the current NSGraphicsContext, make a new one based on the bitmap image rep i just created
	NSGraphicsContext		*origContext = [NSGraphicsContext currentContext];
	if (origContext != nil)
		[origContext retain];
	NSGraphicsContext		*newContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
	if (newContext != nil)	{
		//	set up & start drawing in the new graphics context (draws into the bitmap image rep)
		[NSGraphicsContext setCurrentContext:newContext];
		[newContext setShouldAntialias:NO];
		
		//[[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:1.0] set];
		//VVRECTFill(bitmapRect);
		[img
			drawInRect:bitmapRect
			fromRect:origImageRect
			operation:NSCompositeCopy
			fraction:1.0];
		
		//	flush the graphics
		[newContext flushGraphics];
	}
	[NSGraphicsContext setCurrentContext:origContext];
	if (origContext != nil)	{
		[origContext release];
		origContext = nil;
	}
	
	//	the bitmap rep we just drew into was premultiplied, and we have to fix that before uploading it
	[rep unpremultiply];
	
	VVBuffer		*returnMe = [self allocBufferForBitmapRep:rep prefer2DTexture:prefer2D];
	[returnMe setSrcRect:VVMAKERECT(0,0,bitmapSize.width,bitmapSize.height)];
	[returnMe setFlipped:YES];
	[rep release];
	/*	the static analyzer flags this as a leak, but it isn't.  the VVBuffer instance retains the NSBitmapRep underlying the GL texture, which is interpreted here as a leak.		*/
	return returnMe;
	/*	the static analyzer flags this as a leak, but it isn't.  the VVBuffer instance retains the NSBitmapRep underlying the GL texture, which is interpreted here as a leak.		*/
}
- (VVBuffer *) allocBufferForBitmapRep:(NSBitmapImageRep *)rep	{
	return [self allocBufferForBitmapRep:rep prefer2DTexture:NO];
}
- (VVBuffer *) allocBufferForBitmapRep:(NSBitmapImageRep *)rep prefer2DTexture:(BOOL)prefer2D	{
	//NSLog(@"%s ... %d",__func__,prefer2D);
	if (rep==nil || deleted)
		return nil;
	void					*pixelData = (void *)[rep bitmapData];
	if (pixelData == nil)
		return nil;
	VVSIZE					repSize = [rep size];
	VVSIZE					gpuSize;
	/*
	if (prefer2D)	{
		int						tmpInt;
		tmpInt = 1;
		while (tmpInt < repSize.width)
			tmpInt <<= 1;
		gpuSize.width = tmpInt;
		tmpInt = 1;
		while (tmpInt < repSize.height)
			tmpInt <<= 1;
		gpuSize.height = tmpInt;
	}
	else	{
	*/
		gpuSize = repSize;
	/*
	}
	*/
	
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = (prefer2D) ? GL_TEXTURE_2D : GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
	desc.cpuBackingType = VVBufferCPUBack_External;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = YES;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	
	VVBuffer			*returnMe = [self allocBufferForDescriptor:&desc sized:gpuSize backingPtr:pixelData backingSize:repSize];
	[returnMe setSrcRect:VVMAKERECT(0,0,repSize.width,repSize.height)];
	//	the backing release callback should release a bitmap rep- set it, and the context (which is the rep)
	[returnMe setBackingID:VVBufferBackID_NSBitImgRep];
	[returnMe setBackingReleaseCallback:VVBuffer_ReleaseBitmapRep];
	[returnMe setBackingReleaseCallbackContextObject:rep];
	[returnMe setBackingSize:repSize];
	return returnMe;
}
#ifndef __LP64__	//	not a typo- these methods are only available in 32-bit
- (VVBuffer *) allocTexRangeForHapCVImageBuffer:(CVImageBufferRef)img	{
	return [self allocTexRangeForPlane:0 ofHapCVImageBuffer:img];
}
- (VVBuffer *) allocTexRangeForPlane:(int)pi ofHapCVImageBuffer:(CVImageBufferRef)img	{
	if (img == nil || (pi>0 && pi>=CVPixelBufferGetPlaneCount(img)))	{
		NSLog(@"\t\terr: bailing, %s",__func__);
		return nil;
	}
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
	desc.cpuBackingType = VVBufferCPUBack_External;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = YES;
	desc.texClientStorageFlag = YES;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	
	//	calculate the basic dimensions of the data in the pixel buffer
	VVSIZE		encodedSize = CGMAKENSSIZE(CVImageBufferGetEncodedSize(img));
	VVRECT		roundedRect = VVMAKERECT(0,0,CVPixelBufferGetWidth(img),CVPixelBufferGetHeight(img));
	size_t		extraRight;
	size_t		extraBottom;
	CVPixelBufferGetExtendedPixels(img, NULL, &extraRight, NULL, &extraBottom);
	roundedRect.size = VVMAKESIZE(roundedRect.size.width+extraRight, roundedRect.size.height+extraBottom);
	if ((((int)roundedRect.size.width % 4)!=0) || (((int)roundedRect.size.height % 4)!=0))	{
		NSLog(@"\t\terr: passed image buffer doesn't contain valid hap data, %s",__func__);
		return nil;
	}
	
	//	figure out what kind of hap data this contains
	OSType		imgPixelFormat = CVPixelBufferGetPixelFormatType(img);
	size_t		bitsPerPixel = 32;
	switch (imgPixelFormat)	{
		case kHapPixelFormatTypeRGB_DXT1:
			//NSLog(@"\t\tDXt1");
			bitsPerPixel = 4;
			desc.target = GL_TEXTURE_2D;
			desc.internalFormat = VVBufferIF_RGB_DXT1;
			desc.pixelFormat = VVBufferPF_BGRA;
			desc.pixelType = VVBufferPT_U_Int_8888_Rev;
			desc.texClientStorageFlag = NO;
			break;
		case kHapPixelFormatTypeRGBA_DXT5:
			//NSLog(@"\t\tDXT5");
			bitsPerPixel = 8;
			desc.target = GL_TEXTURE_2D;
			desc.internalFormat = VVBufferIF_RGBA_DXT5;
			desc.pixelFormat = VVBufferPF_BGRA;
			desc.pixelType = VVBufferPT_U_Int_8888_Rev;
			desc.texClientStorageFlag = NO;
			break;
        case kHapPixelFormatTypeYCoCg_DXT5:
			//NSLog(@"\t\tDYt5");
			bitsPerPixel = 8;
			desc.target = GL_TEXTURE_2D;
			desc.internalFormat = VVBufferIF_YCoCg_DXT5;
			desc.pixelFormat = VVBufferPF_BGRA;
			desc.pixelType = VVBufferPT_U_Int_8888_Rev;
			desc.texClientStorageFlag = NO;
			break;
		case kHapPixelFormatType_YCoCg_DXT5_A_RGTC1:
			if (pi == 0)	{
				bitsPerPixel = 8;
				desc.target = GL_TEXTURE_2D;
				desc.internalFormat = VVBufferIF_YCoCg_DXT5;
				desc.pixelFormat = VVBufferPF_BGRA;
				desc.pixelType = VVBufferPT_U_Int_8888_Rev;
				desc.texClientStorageFlag = NO;
			}
			else	{
				bitsPerPixel = 4;
				desc.target = GL_TEXTURE_2D;
				desc.internalFormat = VVBufferIF_A_RGTC;
				desc.pixelFormat = VVBufferPF_BGRA;
				desc.pixelType = VVBufferPT_U_Int_8888_Rev;
				desc.texClientStorageFlag = NO;
			}
			break;
		default:
			NSLog(@"\t\terr: img pixel format unrecognized, bailing! %s",__func__);
			CVPixelBufferUnlockBaseAddress(img, kCVPixelBufferLock_ReadOnly);
			return nil;
			break;
	}
	//	figure out what the data length should be, compare it against the actual data length, bail if anything's wrong
	size_t			bytesPerRow = roundedRect.size.width * bitsPerPixel / 8;
	unsigned long	newDataLength = bytesPerRow * roundedRect.size.height;
	if (newDataLength > CVPixelBufferGetDataSize(img))	{
		NSLog(@"\t\terr: passed image buffer isn't large enough to contain the necessary data, %s",__func__);
		return nil;
	}
	
	//	lock the base address of the buffer- unlock it only when i free the buffer (or if something goes wrong and i have to bail)!
	CVPixelBufferLockBaseAddress(img, kCVPixelBufferLock_ReadOnly);
	void		*baseAddress = nil;
	if (CVPixelBufferIsPlanar(img))
		baseAddress = CVPixelBufferGetBaseAddressOfPlane(img, pi);
	else
		baseAddress = CVPixelBufferGetBaseAddress(img);
	
	//	determine what the size of the texture should be
	VVSIZE		gpuSize = roundedRect.size;
	int			tmpInt = 1;
	tmpInt = 1;
	while (tmpInt < gpuSize.width)
		tmpInt <<= 1;
	gpuSize.width = tmpInt;
	tmpInt = 1;
	while (tmpInt < gpuSize.height)
		tmpInt <<= 1;
	gpuSize.height = tmpInt;
	gpuSize.width = fmax(gpuSize.width,gpuSize.height);
	gpuSize.height = gpuSize.width;
	
	//	actually create the texture
	VVBuffer	*returnMe = [self
		allocBufferForDescriptor:&desc
		sized:gpuSize
		backingPtr:baseAddress
		backingSize:roundedRect.size];
	[returnMe setPreferDeletion:YES];
	[returnMe setSrcRect:VVMAKERECT(0,0,encodedSize.width,encodedSize.height)];
	[returnMe setFlipped:YES];
	[returnMe setBackingSize:roundedRect.size];
	[returnMe setBackingID:VVBufferBackID_CVPixBuf];
	[returnMe setCpuBackingPtr:baseAddress];
	[returnMe setBackingReleaseCallback:VVBuffer_ReleaseCVPixBuf];
	[returnMe setBackingReleaseCallbackContext:img];
	CVPixelBufferRetain(img);
	
	//	push the buffer into the texture (can't do this when creating the buffer or i hit a slowdown)
	pthread_mutex_lock(&contextLock);
	if (context!=nil)	{
		CGLContextObj			cgl_ctx = [context CGLContextObj];
		
		VVBufferDescriptor		*desc = [returnMe descriptorPtr];
		
		VVSIZE			bSize;
		//VVSIZE			backingSize = [returnMe backingSize];
		void			*pixels = [returnMe cpuBackingPtr];
		BOOL			doCompressedUpload = NO;
		
		glActiveTexture(GL_TEXTURE0);
		glEnable(desc->target);
		glBindTexture(desc->target, desc->name);
		
		
		if (desc->texClientStorageFlag)
			glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
		
		switch (desc->internalFormat)	{
			case VVBufferIF_None:
			case VVBufferIF_Lum8:
			case VVBufferIF_LumFloat:
			case VVBufferIF_R:
			case VVBufferIF_RGB:
			case VVBufferIF_RGBA:
			case VVBufferIF_RGBA8:
			case VVBufferIF_Depth24:
			case VVBufferIF_RGBA32F:
				doCompressedUpload = NO;
				bSize = [returnMe size];
				break;
			case VVBufferIF_RGB_DXT1:
			case VVBufferIF_RGBA_DXT5:
			//case VVBufferIF_YCoCg_DXT5:	//	(flagged as duplicate case if un-commented, because both RGBA_DXT5 and YCoCg_DXT5 evaluate to the same internal format)
			case VVBufferIF_A_RGTC:
				doCompressedUpload = YES;
				bSize = [returnMe backingSize];
				break;
		}
		
		
		if (!doCompressedUpload)	{
			//NSLog(@"\t\tuncompressed upload");
			glTexSubImage2D(desc->target,
				0,
				0,
				0,
				bSize.width,
				bSize.height,
				desc->pixelFormat,
				desc->pixelType,
				pixels);
			//NSLog(@"\t\target is %ld, should be %ld",desc->target,GL_TEXTURE_RECTANGLE_EXT);
			//NSLog(@"\t\twidth/height is %f x %f",bSize.width,bSize.height);
			//NSLog(@"\t\tpixelFormat is %ld, should be %ld",desc->pixelFormat,GL_YCBCR_422_APPLE);
			//NSLog(@"\t\tpixelType is %ld, should be %ld",desc->pixelType,GL_UNSIGNED_SHORT_8_8_APPLE);
		}
		else	{
			//NSLog(@"\t\tcompressed upload! %s",__func__);
			#ifdef __LP64__
			NSLog(@"\t\tERR: no 64-bit path for Hap/DXT-compressed textures %s",__func__);
			#else	//	NOT __LP64__
			unsigned long		cpuBufferLength = VVBufferDescriptorCalculateCPUBackingForSize([returnMe descriptorPtr], bSize);
			bSize = [returnMe backingSize];
			glCompressedTexSubImage2D(desc->target,
				0,
				0,
				0,
				bSize.width,
				bSize.height,
				desc->internalFormat,
				//rowBytes * bSize.height,
				cpuBufferLength,
				pixels);
			#endif	//	__LP64__
		}
		if (desc->texClientStorageFlag)
			glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE);
		
		glBindTexture(desc->target, 0);
		glFlush();
		
		//	timestamp the buffer, so we know a new frame has been pushed to it!
		[VVBufferPool timestampThisBuffer:returnMe];
	}
	pthread_mutex_unlock(&contextLock);
	return returnMe;
}
- (NSArray *) createBuffersForHapCVImageBuffer:(CVImageBufferRef)img	{
	//NSLog(@"%s",__func__);
	if (img == NULL)
		return nil;
	NSMutableArray		*returnMe = MUTARRAY;
	for (int i=0; i<CVPixelBufferGetPlaneCount(img); ++i)	{
		VVBuffer		*tmpBuffer = [self allocTexRangeForPlane:i ofHapCVImageBuffer:img];
		if (tmpBuffer != nil)	{
			[returnMe addObject:tmpBuffer];
			[tmpBuffer release];
		}
	}
	//NSLog(@"\t\treturning %@",returnMe);
	return returnMe;
}
#endif	//	__LP64__
#endif	//	!TARGET_OS_IPHONE


#if TARGET_OS_IPHONE
- (VVBuffer *) allocBufferForImageNamed:(NSString *)n	{
	if (n==nil)
		return nil;
	UIImage			*uiImage = [UIImage imageNamed:n];
	if (uiImage == nil)	{
		NSLog(@"\t\terr: image nil, %s",__func__);
		return nil;
	}
	return [self allocBufferForUIImage:uiImage];
}
- (VVBuffer *) allocBufferForUIImage:(UIImage *)n	{
	CGImageRef		cgImgRef = [n CGImage];
	if (cgImgRef == NULL)	{
		NSLog(@"\t\terr: cgImage nil, %s",__func__);
		return nil;
	}
	return [self allocBufferForCGImageRef:cgImgRef];
}
#endif //	TARGET_OS_IPHONE

- (VVBuffer *) allocCubeMapTextureForImages:(NSArray *)n	{
#if !TARGET_OS_IPHONE
	return [self allocCubeMapTextureForImages:n inContext:[self CGLContextObj]];
#else	//	NOT !TARGET_OS_IPHONE
	return [self allocCubeMapTextureForImages:n inContext:[self context]];
#endif	//	!TARGET_OS_IPHONE
}

#if TARGET_OS_IPHONE
- (VVBuffer *) allocCubeMapTextureInCurrentContextForImages:(NSArray *)n	{
	return [self allocCubeMapTextureForImages:n inContext:NULL];
}
#endif	//	TARGET_OS_IPHONE

#if !TARGET_OS_IPHONE
- (VVBuffer *) allocCubeMapTextureForImages:(NSArray *)n inContext:(CGLContextObj)c
#else	//	NOT !TARGET_OS_IPHONE
- (VVBuffer *) allocCubeMapTextureForImages:(NSArray *)n inContext:(EAGLContext *)c
#endif	//	!TARGET_OS_IPHONE
{
	//	make sure that i was passed six images, and that all six images are the same size
	if (n==nil || [n count]!=6)	{
		NSLog(@"\t\terr: bailing, not passed 6 images, %s",__func__);
		return nil;
	}
	VVSIZE			imageSize = [[n objectAtIndex:0] size];
#if !TARGET_OS_IPHONE
	for (NSImage *imagePtr in n)	{
		BOOL			hasBitmapRep = NO;
		for (NSImageRep *imageRep in [imagePtr representations])	{
			if ([imageRep isKindOfClass:[NSBitmapImageRep class]])	{
				hasBitmapRep = YES;
				break;
			}
		}
		if (!hasBitmapRep)	{
			NSLog(@"\t\terr: image doesn't have a bitmap rep, bailing, %s",__func__);
			return nil;
		}
		if (!NSEqualSizes([imagePtr size], imageSize))	{
			NSLog(@"\t\terr: image sizes are not uniform, bailing, %s",__func__);
			return nil;
		}
	}
#else	//	NOT !TARGET_OS_IPHONE
	for (UIImage *imagePtr in n)	{
		BOOL			directUploadOK = YES;
		CGImageRef		cgImg = [imagePtr CGImage];
		if (cgImg != NULL)	{
			VVSIZE			tmpImgSize = VVMAKESIZE(CGImageGetWidth(cgImg), CGImageGetHeight(cgImg));
			if (!VVEQUALSIZES(imageSize,tmpImgSize))
				directUploadOK = NO;
			
			CGBitmapInfo		newImgInfo = CGImageGetBitmapInfo(cgImg);
			CGImageAlphaInfo	calculatedAlphaInfo = newImgInfo & kCGBitmapAlphaInfoMask;
			
			if (VVBITMASKCHECK(newImgInfo, kCGBitmapFloatComponents)	||
			VVBITMASKCHECK(newImgInfo, kCGBitmapByteOrder16Little)	||
			VVBITMASKCHECK(newImgInfo, kCGBitmapByteOrder16Big)	||
			//VVBITMASKCHECK(newImgInfo, kCGBitmapByteOrder32Little)	||
			VVBITMASKCHECK(newImgInfo, kCGBitmapByteOrder32Big))	{
				directUploadOK = NO;
			}
			
			switch (calculatedAlphaInfo)	{
			case kCGImageAlphaPremultipliedLast:
			case kCGImageAlphaPremultipliedFirst:
			case kCGImageAlphaOnly:
			case kCGImageAlphaNone:
				directUploadOK = NO;
				break;
			case kCGImageAlphaLast:
			case kCGImageAlphaFirst:
			case kCGImageAlphaNoneSkipLast:
			case kCGImageAlphaNoneSkipFirst:
				break;
			}
		}
		else
			directUploadOK = NO;
		
		if (!directUploadOK)	{
			NSLog(@"\t\terr: bailing, problem with array of cube images, %s",__func__);
			return nil;
		}
	}
#endif	//	!TARGET_OS_IPHONE
	
	VVBuffer		*returnMe = nil;
	
	//	set up the buffer descriptor that i'll be using to describe the texture i'm about to create
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
#if !TARGET_OS_IPHONE
	desc.target = GL_TEXTURE_CUBE_MAP;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
#else	//	NOT !TARGET_OS_IPHONE
	desc.target = GL_TEXTURE_CUBE_MAP;
	desc.internalFormat = VVBufferIF_RGBA;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_U_Byte;
#endif	//	!TARGET_OS_IPHONE
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	
	//	actually upload the bitmap data to the texture
	pthread_mutex_lock(&contextLock);
#if !TARGET_OS_IPHONE
	CGLContextObj		cgl_ctx = c;
	glEnable(desc.target);
#else	//	NOT !TARGET_OS_IPHONE
	if (c != nil)
		[EAGLContext setCurrentContext:c];
#endif	//	!TARGET_OS_IPHONE
	glGenTextures(1,&desc.name);
	glBindTexture(desc.target, desc.name);
#if !TARGET_OS_IPHONE
	glPixelStorei(GL_UNPACK_SKIP_ROWS, GL_FALSE);
	glPixelStorei(GL_UNPACK_SKIP_PIXELS, GL_FALSE);
	glPixelStorei(GL_UNPACK_SWAP_BYTES, GL_FALSE);
#endif	//	!TARGET_OS_IPHONE
	glTexParameteri(desc.target, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(desc.target, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(desc.target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(desc.target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glFlush();
	
	int				faceCount=0;
	unsigned long	bytesPerRow = 32 * imageSize.width / 8;
	void			*clipboardData = malloc(bytesPerRow * imageSize.height);
	//	run through all the images
#if !TARGET_OS_IPHONE
	for (NSImage *imagePtr in n)	{
		//	for each image, run through the bitmap reps until i find a bitmap image rep
		for (NSImageRep *imageRep in [imagePtr representations])	{
			if ([imageRep isKindOfClass:[NSBitmapImageRep class]])	{
				//	the bitmap data in the image rep is padded and shit, copy it to a buffer and then upload the buffer
				void			*repBufferData = [(NSBitmapImageRep *)imageRep bitmapData];
				NSInteger		repBytesPerRow = [(NSBitmapImageRep *)imageRep bytesPerRow];
				for (int i=0; i<imageSize.height; ++i)	{
					memcpy(clipboardData+(bytesPerRow*i), repBufferData+(repBytesPerRow*i), bytesPerRow);
				}
				//	upload the bitmap image rep's data to the texture
				glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + faceCount,
					0,
					desc.internalFormat,
					imageSize.width,
					imageSize.height,
					0,
					desc.pixelFormat,
					desc.pixelType,
					clipboardData);
				break;
			}
		}
		
		glFlush();
		
		++faceCount;
	}
#else	//	NOT !TARGET_OS_IPHONE
	for (UIImage *imagePtr in n)	{
		//	for each image, get the CGImage and copy the data from its data provider
		CGImageRef		cgImgRef = [imagePtr CGImage];
		if (cgImgRef != NULL)	{
			NSData			*frameData = (NSData *)CGDataProviderCopyData(CGImageGetDataProvider(cgImgRef));
			if (frameData != nil)	{
				VVSIZE			tmpImgSize = VVMAKESIZE(CGImageGetWidth(cgImgRef), CGImageGetHeight(cgImgRef));
				void			*repBufferData = (void *)[frameData bytes];
				NSInteger		repBytesPerRow = CGImageGetBytesPerRow(cgImgRef);
				for (int i=0; i<tmpImgSize.height; ++i)	{
					memcpy(clipboardData+(repBytesPerRow*i), repBufferData+(repBytesPerRow*i), bytesPerRow);
				}
				//	upload the bitmap image rep's data to the texture
				glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + faceCount,
					0,
					desc.internalFormat,
					imageSize.width,
					imageSize.height,
					0,
					desc.pixelFormat,
					desc.pixelType,
					clipboardData);
				
				[frameData release];
				frameData = nil;
			}
		}
		
		glFlush();
		
		++faceCount;
	}
#endif	//	!TARGET_OS_IPHONE
	free(clipboardData);
	
	glBindTexture(desc.target, 0);
#if !TARGET_OS_IPHONE
	glDisable(desc.target);
#endif	//	!TARGET_OS_IPHONE
	
	pthread_mutex_unlock(&contextLock);
	
	//	finish creating the VVBuffer instance from stuff
	returnMe = [[VVBuffer alloc] initWithPool:self];
	[returnMe setDescriptorFromPtr:&desc];
	[returnMe setSize:imageSize];
	[returnMe setSrcRect:VVMAKERECT(0,0,imageSize.width,imageSize.height)];
	[returnMe setBackingSize:imageSize];
	[returnMe setPreferDeletion:YES];
	[VVBufferPool timestampThisBuffer:returnMe];
	
	return returnMe;
}



#if !TARGET_OS_IPHONE
- (VVBuffer *) allocBufferForCVGLTex:(CVOpenGLTextureRef)cvt
#else	//	NOT !TARGET_OS_IPHONE
- (VVBuffer *) allocBufferForCVGLTex:(CVOpenGLESTextureRef)cvt
#endif	//	!TARGET_OS_IPHONE
{
	//NSLog(@"%s ... %@",__func__,cvt);
	if (deleted)
		return nil;
	if (cvt == nil)	{
		NSLog(@"\t\terr: passed nil tex %s",__func__);
		return nil;
	}
#if !TARGET_OS_IPHONE
	GLuint			texName = CVOpenGLTextureGetName(cvt);
#else	//	NOT !TARGET_OS_IPHONE
	GLuint			texName = CVOpenGLESTextureGetName(cvt);
#endif	//	!TARGET_OS_IPHONE
	if (texName <= 0)	{
		NSLog(@"\t\terr: passed invalid tex num %s",__func__);
		return nil;
	}
#if !TARGET_OS_IPHONE
	if (CFGetTypeID(cvt) != CVOpenGLTextureGetTypeID())
#else	//	NOT !TARGET_OS_IPHONE
	if (CFGetTypeID(cvt) != CVOpenGLESTextureGetTypeID())
#endif	//	!TARGET_OS_IPHONE
	{
		NSLog(@"\t\terr: CFTypeID of passed tex doesn't match expected %s",__func__);
		return nil;
	}
	
	VVBuffer			*returnMe = [[VVBuffer alloc] initWithPool:self];
	[VVBufferPool timestampThisBuffer:returnMe];
	VVBufferDescriptor	*desc = [returnMe descriptorPtr];
	if (desc == nil)	{
		VVRELEASE(returnMe);
		return nil;
	}
	desc->type = VVBufferType_Tex;
#if !TARGET_OS_IPHONE
	desc->target = CVOpenGLTextureGetTarget(cvt);
	desc->internalFormat = VVBufferIF_RGBA8;
	desc->pixelFormat = VVBufferPF_BGRA;
	desc->pixelType = VVBufferPT_U_Int_8888_Rev;
#else	//	NOT !TARGET_OS_IPHONE
	desc->target = CVOpenGLESTextureGetTarget(cvt);
	desc->internalFormat = VVBufferIF_RGBA;
	desc->pixelFormat = VVBufferPF_BGRA;
	desc->pixelType = VVBufferPT_U_Byte;
#endif	//	!TARGET_OS_IPHONE
	desc->cpuBackingType = VVBufferCPUBack_None;
	desc->gpuBackingType = VVBufferGPUBack_External;
	desc->name = texName;
	desc->texRangeFlag = NO;
	desc->texClientStorageFlag = NO;
	desc->msAmount = 0;
	desc->localSurfaceID = 0;
	
	//CGSize				texSize = CVImageBufferGetDisplaySize(cvt);
	CGSize				texSize = CVImageBufferGetEncodedSize(cvt);
	//VVSIZE					texSize = VVMAKESIZE(CVPixelBufferGetWidth(cvt), CVPixelBufferGetHeight(cvt));
	//VVSIZE					texSize = VVMAKESIZE(1920,1080);
	//CGRect				cleanRect = CVImageBufferGetCleanRect(cvt);
	//NSSizeLog(@"\t\ttexSize is",texSize);
	//NSRectLog(@"\t\tcleanRect is",cleanRect);
	[returnMe setPreferDeletion:YES];
	[returnMe setSize:VVMAKESIZE(texSize.width,texSize.height)];
	[returnMe setSrcRect:VVMAKERECT(0,0,texSize.width,texSize.height)];
#if !TARGET_OS_IPHONE
	[returnMe setFlipped:CVOpenGLTextureIsFlipped(cvt)];
#else	//	NOT !TARGET_OS_IPHONE
	[returnMe setFlipped:CVOpenGLESTextureIsFlipped(cvt)];
#endif	//	!TARGET_OS_IPHONE
	[returnMe setBackingSize:[returnMe size]];
	
	[returnMe setBackingID:VVBufferBackID_CVTex];
#if !TARGET_OS_IPHONE
	CVOpenGLTextureRetain(cvt);
#else	//	NOT !TARGET_OS_IPHONE
	//CVOpenGLESTextureRetain(cvt);
	CVBufferRetain(cvt);
#endif	//	!TARGET_OS_IPHONE
	[returnMe setBackingReleaseCallback:VVBuffer_ReleaseCVGLT];
	[returnMe setBackingReleaseCallbackContext:cvt];
	return returnMe;
}
- (VVBuffer *) allocBufferForCGImageRef:(CGImageRef)n	{
	return [self allocBufferForCGImageRef:n prefer2DTexture:NO];
}
- (VVBuffer *) allocBufferForCGImageRef:(CGImageRef)n prefer2DTexture:(BOOL)prefer2D	{
	if (n==nil)
		return nil;
	//	i have the image- i need to get some of its basic properties (pixel format, alpha, etc) to determine if i can just upload this data to a texture or if i have to convert (draw) it
	BOOL				directUploadOK = YES;
	
	CGBitmapInfo		newImgInfo = CGImageGetBitmapInfo(n);
	CGImageAlphaInfo	calculatedAlphaInfo = newImgInfo & kCGBitmapAlphaInfoMask;
	
	
	
	//VVBITMASKCHECK(newImgInfo, kCGBitmapByteOrderDefault)
	if (VVBITMASKCHECK(newImgInfo, kCGBitmapFloatComponents)	||
	VVBITMASKCHECK(newImgInfo, kCGBitmapByteOrder16Little)	||
	VVBITMASKCHECK(newImgInfo, kCGBitmapByteOrder16Big)	||
	//VVBITMASKCHECK(newImgInfo, kCGBitmapByteOrder32Little)	||
	VVBITMASKCHECK(newImgInfo, kCGBitmapByteOrder32Big))	{
		directUploadOK = NO;
	}
	
	
	
	switch (calculatedAlphaInfo)	{
	case kCGImageAlphaPremultipliedLast:
	case kCGImageAlphaPremultipliedFirst:
	case kCGImageAlphaOnly:
	case kCGImageAlphaNone:
		directUploadOK = NO;
		break;
	case kCGImageAlphaLast:
	case kCGImageAlphaFirst:
	case kCGImageAlphaNoneSkipLast:
	case kCGImageAlphaNoneSkipFirst:
		break;
	}
	
	VVBuffer			*returnMe = nil;
	
	//	if i can upload the pixel data from the CGImageRef directly to a texture...
	if (directUploadOK)	{
		//	this just copies the data right out of the image provider, let's give it a shot...
		VVSIZE		imgSize = VVMAKESIZE(CGImageGetWidth(n), CGImageGetHeight(n));
		NSData		*frameData = (NSData *)CGDataProviderCopyData(CGImageGetDataProvider(n));
		if (frameData!=nil)	{
			VVBufferDescriptor		desc;
#if !TARGET_OS_IPHONE
			desc.type = VVBufferType_Tex;
			desc.target = (prefer2D) ? GL_TEXTURE_2D : GL_TEXTURE_RECTANGLE_EXT;
			desc.internalFormat = VVBufferIF_RGBA8;
			//desc.pixelFormat = VVBufferPF_RGBA;
			desc.pixelFormat = VVBufferPF_RGBA;
			desc.pixelType = VVBufferPT_U_Int_8888_Rev;
			desc.cpuBackingType = VVBufferCPUBack_External;
			desc.gpuBackingType = VVBufferGPUBack_Internal;
			desc.name = 0;
			desc.texRangeFlag = YES;
			desc.texClientStorageFlag = YES;
			desc.msAmount = 0;
			desc.localSurfaceID = 0;
#else	//	NOT !TARGET_OS_IPHONE
			desc.type = VVBufferType_Tex;
			desc.target = GL_TEXTURE_2D;
			desc.internalFormat = VVBufferIF_RGBA;
			//desc.pixelFormat = VVBufferPF_RGBA;
			desc.pixelFormat = VVBufferPF_RGBA;
			desc.pixelType = VVBufferPT_U_Byte;
			desc.cpuBackingType = VVBufferCPUBack_External;
			desc.gpuBackingType = VVBufferGPUBack_Internal;
			desc.name = 0;
			desc.texRangeFlag = NO;
			desc.texClientStorageFlag = NO;
			desc.msAmount = 0;
			desc.localSurfaceID = 0;
#endif	//	!TARGET_OS_IPHONE
			returnMe = [_globalVVBufferPool
				allocBufferForDescriptor:&desc
				sized:imgSize
				backingPtr:(void *)[frameData bytes]
				backingSize:imgSize];
			[returnMe setBackingID:VVBufferBackID_External];
			[returnMe setBackingReleaseCallback:VVBuffer_ReleaseBitmapRep];
			[returnMe setBackingReleaseCallbackContextObject:frameData];
			[returnMe setPreferDeletion:YES];
			[returnMe setFlipped:YES];
			
			
			[frameData release];
			frameData = nil;
		}
	}
	//	else the direct upload isn't okay...
	else	{
		//	alloc some memory, make a CGBitmapContext that uses the memory to store pixel data
		VVSIZE			imgSize = VVMAKESIZE(CGImageGetWidth(n), CGImageGetHeight(n));
		GLubyte			*imgData = calloc((long)imgSize.width * (long)imgSize.height, sizeof(GLubyte)*4);
		CGContextRef	ctx = CGBitmapContextCreate(imgData,
			(long)imgSize.width,
			(long)imgSize.height,
			8,
			((long)(imgSize.width))*4,
			colorSpace,
			kCGImageAlphaPremultipliedLast);
		if (ctx == NULL)	{
			NSLog(@"\t\tERR: ctx null in %s",__func__);
			free(imgData);
			return nil;
		}
		//	draw the image in the bitmap context, flush it
		CGContextDrawImage(ctx, CGRectMake(0,0,imgSize.width,imgSize.height), n);
		CGContextFlush(ctx);
		//	the bitmap context we just drew into has premultiplied alpha, so we need to un-premultiply before uploading it
		CGBitmapContextUnpremultiply(ctx);
		CGContextRelease(ctx);
		//	set up the buffer descriptor that i'll be using to describe the texture i'm about to create
		VVBufferDescriptor		desc;
		desc.type = VVBufferType_Tex;
		desc.target = GL_TEXTURE_2D;
		desc.internalFormat = VVBufferIF_RGBA;
		desc.pixelFormat = VVBufferPF_RGBA;
		desc.pixelType = VVBufferPT_U_Byte;
		desc.cpuBackingType = VVBufferCPUBack_External;
		desc.gpuBackingType = VVBufferGPUBack_Internal;
		desc.name = 0;
		desc.texRangeFlag = NO;
		desc.texClientStorageFlag = YES;
		desc.msAmount = 0;
		desc.localSurfaceID = 0;
		//	alloc the buffer, populate its basic variables
		returnMe = [self allocBufferForDescriptor:&desc sized:imgSize backingPtr:imgData backingSize:imgSize];
		[returnMe setSrcRect:VVMAKERECT(0,0,imgSize.width,imgSize.height)];
		[returnMe setBackingID:VVBufferBackID_Pixels];
		[returnMe setBackingReleaseCallback:VVBuffer_ReleasePixelsCallback];
		[returnMe setBackingReleaseCallbackContext:imgData];
		[returnMe setFlipped:YES];
	}
	return returnMe;
}


/*===================================================================================*/
#pragma mark --------------------- creating VBO VVBuffers
/*------------------------------------*/


- (VVBuffer *) allocVBOWithBytes:(void *)b byteSize:(long)s usage:(GLenum)u	{
	VVBuffer		*returnMe = nil;
#if !TARGET_OS_IPHONE
	returnMe = [self allocVBOWithBytes:b byteSize:s usage:u inContext:[context CGLContextObj]];
#else	//	NOT !TARGET_OS_IPHONE
	returnMe = [self allocVBOWithBytes:b byteSize:s usage:u inContext:context];
#endif	//	!TARGET_OS_IPHONE
	return returnMe;
}
#if !TARGET_OS_IPHONE
- (VVBuffer *) allocVBOWithBytes:(void *)b byteSize:(long)s usage:(GLenum)u inContext:(CGLContextObj)cgl_ctx
#else	//	NOT !TARGET_OS_IPHONE
- (VVBuffer *) allocVBOWithBytes:(void *)b byteSize:(long)s usage:(GLenum)u inContext:(EAGLContext *)ctx
#endif	//	!TARGET_OS_IPHONE
{
	if (deleted || (s==0) || context==NULL)
		return nil;
	VVBuffer		*returnMe = nil;
	
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_VBO;
	desc.target = 0;
	desc.internalFormat = VVBufferIF_None;
	desc.pixelFormat = VVBufferPF_None;
	desc.pixelType = VVBufferPT_Float;
	//desc.backingType = VVBufferBack_None;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	
	pthread_mutex_lock(&contextLock);
#if !TARGET_OS_IPHONE
	//CGLContextObj		cgl_ctx = [context CGLContextObj];
#else	//	NOT !TARGET_OS_IPHONE
	[EAGLContext setCurrentContext:context];
#endif	//	!TARGET_OS_IPHONE
	glGenBuffers(1, &(desc.name));
	glBindBuffer(GL_ARRAY_BUFFER, desc.name);
	glBufferData(GL_ARRAY_BUFFER, s, b, u);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
	glFlush();
	
	pthread_mutex_unlock(&contextLock);
	
	returnMe = [[VVBuffer alloc] initWithPool:self];
	[returnMe setDescriptorFromPtr:&desc];
	[returnMe setSize:VVMAKESIZE(0,0)];
	[returnMe setSrcRect:VVZERORECT];
	[returnMe setBackingID:VVBufferBackID_None];
	[VVBufferPool timestampThisBuffer:returnMe];
	[returnMe setPreferDeletion:YES];
	
	return returnMe;
}
#if TARGET_OS_IPHONE
- (VVBuffer *) allocVBOInCurrentContextWithBytes:(void *)b byteSize:(long)s usage:(GLenum)u	{
	if (deleted || (s==0) || context==NULL)
		return nil;
	VVBuffer		*returnMe = nil;
	
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_VBO;
	desc.target = 0;
	desc.internalFormat = VVBufferIF_None;
	desc.pixelFormat = VVBufferPF_None;
	desc.pixelType = VVBufferPT_Float;
	//desc.backingType = VVBufferBack_None;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	
//	pthread_mutex_lock(&contextLock);
//#if !TARGET_OS_IPHONE
//	CGLContextObj		cgl_ctx = [context CGLContextObj];
//#else
//	[EAGLContext setCurrentContext:context];
//#endif
	glGenBuffers(1, &(desc.name));
	glBindBuffer(GL_ARRAY_BUFFER, desc.name);
	glBufferData(GL_ARRAY_BUFFER, s, b, u);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
//	glFlush();
	
//	pthread_mutex_unlock(&contextLock);
	
	returnMe = [[VVBuffer alloc] initWithPool:self];
	[returnMe setDescriptorFromPtr:&desc];
	[returnMe setSize:VVMAKESIZE(0,0)];
	[returnMe setSrcRect:VVZERORECT];
	[returnMe setBackingID:VVBufferBackID_None];
	[VVBufferPool timestampThisBuffer:returnMe];
	[returnMe setPreferDeletion:YES];
	
	return returnMe;
}
#endif	//	TARGET_OS_IPHONE


/*===================================================================================*/
#pragma mark --------------------- CPU-based VVBuffers: no GL textures, no PBOs, just RAM.
/*------------------------------------*/


- (VVBuffer *) allocRGBACPUBufferSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_None;
	desc.target = 0;
#if !TARGET_OS_IPHONE
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
#else
	desc.internalFormat = VVBufferIF_RGBA;
	desc.pixelType = VVBufferPT_U_Byte;
#endif
	desc.pixelFormat = VVBufferPF_RGBA;
	//desc.backingType = VVBufferBack_Pixels;
	desc.cpuBackingType = VVBufferCPUBack_Internal;
	desc.gpuBackingType = VVBufferGPUBack_None;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = YES;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe != nil)
		return returnMe;
	
	void			*bufferMemory = malloc(VVBufferDescriptorCalculateCPUBackingForSize(&desc,s));
	returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:bufferMemory backingSize:s];
	[returnMe setBackingID:VVBufferBackID_Pixels];	//	purely for reference- so we know what's in the callback context
	[returnMe setBackingReleaseCallback:VVBuffer_ReleasePixelsCallback];	//	this is the function we want to call to release the callback context
	[returnMe setBackingReleaseCallbackContext:bufferMemory];	//	this is the callback context
	return returnMe;
}
- (VVBuffer *) allocRGBAFloatCPUBufferSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_None;
	desc.target = 0;
	desc.internalFormat = VVBufferIF_RGBA32F;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_Float;
	//desc.backingType = VVBufferBack_Pixels;
	desc.cpuBackingType = VVBufferCPUBack_Internal;
	desc.gpuBackingType = VVBufferGPUBack_None;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = YES;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe != nil)
		return returnMe;
	
	void			*bufferMemory = malloc(VVBufferDescriptorCalculateCPUBackingForSize(&desc,s));
	returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:bufferMemory backingSize:s];
	[returnMe setBackingID:VVBufferBackID_Pixels];	//	purely for reference- so we know what's in the callback context
	[returnMe setBackingReleaseCallback:VVBuffer_ReleasePixelsCallback];	//	this is the function we want to call to release the callback context
	[returnMe setBackingReleaseCallbackContext:bufferMemory];	//	this is the callback context
	return returnMe;
}


/*===================================================================================*/
#pragma mark --------------------- creating VVBuffers with or from IOSurfaces
/*------------------------------------*/


#if !TARGET_OS_IPHONE
- (VVBuffer *) allocBufferForTexBackedIOSurfaceSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 1;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	return returnMe;
}
//	this method is called when i need to create a GL texture for an IOSurfaceRef received from another app- so don't 
- (VVBuffer *) allocBufferForIOSurfaceID:(IOSurfaceID)n	{
	//NSLog(@"%s",__func__);
	//	look up the surface for the ID i was passed, bail if i can't
	IOSurfaceRef		newSurface = IOSurfaceLookup(n);
	if (newSurface == nil)	{
		//NSLog(@"\t\terr: bailing, couldn't look up IOSurface by ID %d",n);
		return nil;
	}
	//	figure out how big the IOSurface is and what its pixel format is
	VVSIZE					newAssetSize = VVMAKESIZE(IOSurfaceGetWidth(newSurface),IOSurfaceGetHeight(newSurface));
	OSType					pixelFormat = IOSurfaceGetPixelFormat(newSurface);
	//NSLog(@"\t\tpixel format from server is %08lX (%c%c%c%c)",pixelFormat,(char)((pixelFormat>>24) & 0xFF),(char)((pixelFormat>>16) & 0xFF),(char)((pixelFormat>>8) & 0xFF),(char)((pixelFormat>>0) & 0xFF));
	//	make the buffer i'll be returning, set up as much of it as i can
	VVBuffer				*returnMe = [[VVBuffer alloc] initWithPool:self];
	[VVBufferPool timestampThisBuffer:returnMe];
	[returnMe setPreferDeletion:YES];
	[returnMe setSize:newAssetSize];
	[returnMe setSrcRect:VVMAKERECT(0,0,newAssetSize.width,newAssetSize.height)];
	[returnMe setBackingSize:VVMAKESIZE(newAssetSize.width,newAssetSize.height)];
	[returnMe setBackingID:VVBufferBackID_RemoteIOSrf];
	[returnMe setRemoteSurfaceRef:newSurface];
	//	get a ptr to the buffer descriptor, set it up
	VVBufferDescriptor		*desc = [returnMe descriptorPtr];
	if (desc == nil)	{
		if (newSurface!=nil)	{
			CFRelease(newSurface);
			newSurface = NULL;
		}
		VVRELEASE(returnMe);
		return nil;
	}
	desc->type = VVBufferType_Tex;
	desc->target = GL_TEXTURE_RECTANGLE_EXT;
	switch (pixelFormat)	{
		case kCVPixelFormatType_32BGRA:	//	'BGRA'
		case VVBufferPF_BGRA:
			desc->internalFormat = VVBufferIF_RGBA8;
			desc->pixelFormat = VVBufferPF_BGRA;
			desc->pixelType = VVBufferPT_U_Int_8888_Rev;
			break;
		case kCVPixelFormatType_32RGBA:	//	'RGBA'
		case VVBufferPF_RGBA:
			desc->internalFormat = VVBufferIF_RGBA8;
			desc->pixelFormat = VVBufferPF_RGBA;
			desc->pixelType = VVBufferPT_U_Int_8888_Rev;
			break;
		case kCVPixelFormatType_422YpCbCr8:	//	'2vuy'
		case VVBufferPF_YCBCR_422:
			desc->internalFormat = VVBufferIF_RGB;
			desc->pixelFormat = VVBufferPF_YCBCR_422;
			desc->pixelType = VVBufferPT_U_Short_88;
			break;
		default:
			NSLog(@"\t\tERR: unknown pixel format- %u- in %s",(unsigned int)pixelFormat,__func__);
			desc->internalFormat = VVBufferIF_RGBA8;
			desc->pixelFormat = VVBufferPF_BGRA;
			desc->pixelType = VVBufferPT_U_Int_8888_Rev;
			break;
	}
	desc->cpuBackingType = VVBufferCPUBack_None;
	desc->gpuBackingType = VVBufferGPUBack_Internal;
	desc->name = 0;
	desc->texRangeFlag = NO;
	desc->texClientStorageFlag = NO;
	desc->msAmount = 0;
	desc->localSurfaceID = n;
	
	//	now that i've created and set up the buffer, i just need to take care of the GL resource setup
	pthread_mutex_lock(&contextLock);
		CGLContextObj		cgl_ctx = [context CGLContextObj];
		glEnable(desc->target);
		glGenTextures(1,&(desc->name));
		glBindTexture(desc->target,desc->name);
		CGLError err = CGLTexImageIOSurface2D(cgl_ctx,
			desc->target,
			desc->internalFormat,
			newAssetSize.width,
			newAssetSize.height,
			desc->pixelFormat,
			desc->pixelType,
			newSurface,
			0);
		if (err != noErr)
			NSLog(@"\t\terror %d at CGLTexImageIOSurface2D() in %s",err,__func__);
		glTexParameteri(desc->target, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(desc->target, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(desc->target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(desc->target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glFlush();
	pthread_mutex_unlock(&contextLock);
	
	//	don't forget to release the surface (it's retained by the buffer i'm returning!)
	CFRelease(newSurface);
	newSurface = nil;
	return returnMe;
}
- (VVBuffer *) allocBufferFromStringForXPCComm:(NSString *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if (n==nil)
		return nil;
	NSArray		*components = [n componentsSeparatedByString:@","];
	if (components==nil || [components count]!=6)
		return nil;
	IOSurfaceID			newID = (unsigned int)[[components objectAtIndex:0] integerValue];
	VVRECT				newRect = VVMAKERECT([[components objectAtIndex:1] floatValue], [[components objectAtIndex:2] floatValue], [[components objectAtIndex:3] floatValue], [[components objectAtIndex:4] floatValue]);
	BOOL				newFlipped = ([[components objectAtIndex:5] integerValue]==0) ? FALSE : TRUE;
	VVBuffer			*returnMe = [self allocBufferForIOSurfaceID:newID];
	[returnMe setSrcRect:newRect];
	[returnMe setFlipped:newFlipped];
	return returnMe;
}



/*===================================================================================*/
#pragma mark --------------------- texture ranges- DMA GL textures
/*------------------------------------*/


- (VVBuffer *) allocRedByteCPUBackedTexRangeSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_R;
	desc.pixelFormat = VVBufferPF_R;
	desc.pixelType = VVBufferPT_U_Byte;
	//desc.backingType = VVBufferBack_Pixels;
	desc.cpuBackingType = VVBufferCPUBack_Internal;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = YES;
	desc.texClientStorageFlag = YES;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe != nil)
		return returnMe;
	
	void			*bufferMemory = malloc(VVBufferDescriptorCalculateCPUBackingForSize(&desc,s));
	returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:bufferMemory backingSize:s];
	[returnMe setBackingID:VVBufferBackID_Pixels];	//	purely for reference- so we know what's in the callback context
	[returnMe setBackingReleaseCallback:VVBuffer_ReleasePixelsCallback];	//	this is the function we want to call to release the callback context
	[returnMe setBackingReleaseCallbackContext:bufferMemory];	//	this is the callback context
	return returnMe;
}
- (VVBuffer *) allocRedFloatCPUBackedTexRangeSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_R;
	desc.pixelFormat = VVBufferPF_R;
	desc.pixelType = VVBufferPT_Float;
	//desc.backingType = VVBufferBack_Pixels;
	desc.cpuBackingType = VVBufferCPUBack_Internal;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = YES;
	desc.texClientStorageFlag = YES;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe != nil)
		return returnMe;
	
	void			*bufferMemory = malloc(VVBufferDescriptorCalculateCPUBackingForSize(&desc,s));
	returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:bufferMemory backingSize:s];
	[returnMe setBackingID:VVBufferBackID_Pixels];	//	purely for reference- so we know what's in the callback context
	[returnMe setBackingReleaseCallback:VVBuffer_ReleasePixelsCallback];	//	this is the function we want to call to release the callback context
	[returnMe setBackingReleaseCallbackContext:bufferMemory];	//	this is the callback context
	return returnMe;
}
- (VVBuffer *) allocLum8CPUBackedTexRangeSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_Lum8;
	desc.pixelFormat = VVBufferPF_Lum;
	desc.pixelType = VVBufferPT_U_Byte;
	//desc.backingType = VVBufferBack_Pixels;
	desc.cpuBackingType = VVBufferCPUBack_Internal;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = YES;
	desc.texClientStorageFlag = YES;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe != nil)
		return returnMe;
	
	void			*bufferMemory = malloc(VVBufferDescriptorCalculateCPUBackingForSize(&desc,s));
	returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:bufferMemory backingSize:s];
	[returnMe setBackingID:VVBufferBackID_Pixels];	//	purely for reference- so we know what's in the callback context
	[returnMe setBackingReleaseCallback:VVBuffer_ReleasePixelsCallback];	//	this is the function we want to call to release the callback context
	[returnMe setBackingReleaseCallbackContext:bufferMemory];	//	this is the callback context
	return returnMe;
}
- (VVBuffer *) allocRGBACPUBackedTexRangeSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
	//desc.backingType = VVBufferBack_Pixels;
	desc.cpuBackingType = VVBufferCPUBack_Internal;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = YES;
	desc.texClientStorageFlag = YES;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe != nil)
		return returnMe;
	
	void			*bufferMemory = malloc(VVBufferDescriptorCalculateCPUBackingForSize(&desc,s));
	returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:bufferMemory backingSize:s];
	[returnMe setBackingID:VVBufferBackID_Pixels];	//	purely for reference- so we know what's in the callback context
	[returnMe setBackingReleaseCallback:VVBuffer_ReleasePixelsCallback];	//	this is the function we want to call to release the callback context
	[returnMe setBackingReleaseCallbackContext:bufferMemory];	//	this is the callback context
	return returnMe;
}
- (VVBuffer *) allocBGRACPUBackedTexRangeSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
	//desc.backingType = VVBufferBack_Pixels;
	desc.cpuBackingType = VVBufferCPUBack_Internal;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = YES;
	desc.texClientStorageFlag = YES;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe != nil)
		return returnMe;
	
	void			*bufferMemory = malloc(VVBufferDescriptorCalculateCPUBackingForSize(&desc,s));
	returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:bufferMemory backingSize:s];
	[returnMe setBackingID:VVBufferBackID_Pixels];	//	purely for reference- so we know what's in the callback context
	[returnMe setBackingReleaseCallback:VVBuffer_ReleasePixelsCallback];	//	this is the function we want to call to release the callback context
	[returnMe setBackingReleaseCallbackContext:bufferMemory];	//	this is the callback context
	return returnMe;
}
- (VVBuffer *) allocBGRAFloatCPUBackedTexRangeSized:(VVSIZE)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA32F;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_Float;
	//desc.backingType = VVBufferBack_Pixels;
	desc.cpuBackingType = VVBufferCPUBack_Internal;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = YES;
	desc.texClientStorageFlag = YES;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:s];
	if (returnMe != nil)
		return returnMe;
	
	void			*bufferMemory = malloc(VVBufferDescriptorCalculateCPUBackingForSize(&desc,s));
	returnMe = [self allocBufferForDescriptor:&desc sized:s backingPtr:bufferMemory backingSize:s];
	[returnMe setBackingID:VVBufferBackID_Pixels];	//	purely for reference- so we know what's in the callback context
	[returnMe setBackingReleaseCallback:VVBuffer_ReleasePixelsCallback];	//	this is the function we want to call to release the callback context
	[returnMe setBackingReleaseCallbackContext:bufferMemory];	//	this is the callback context
	return returnMe;
}


/*===================================================================================*/
#pragma mark --------------------- texture ranges from other kinds of images
/*------------------------------------*/


- (VVBuffer *) allocTexRangeForCMSampleBuffer:(CMSampleBufferRef)n	{
	//NSLog(@"%s",__func__);
	if (n == NULL)
		return nil;
	
	CMFormatDescriptionRef	cmDesc = CMSampleBufferGetFormatDescription(n);
	if (cmDesc == NULL)	{
		NSLog(@"\t\terr: bailing, desc NULL, %s",__func__);
		if (!CMSampleBufferIsValid(n))
			NSLog(@"\t\terr: as a note, the sample buffer wasn't valid in %s",__func__);
		return nil;
	}
	//	get the CVImage
	CVImageBufferRef		cvImg = CMSampleBufferGetImageBuffer(n);	//	don't need to free this
	VVBuffer				*returnMe = nil;
	if (cvImg!=NULL && (CFGetTypeID(cvImg) == CVPixelBufferGetTypeID()))	{
		//	make the actual buffer i'll be returning
		returnMe = [self allocBufferForCVPixelBuffer:cvImg texRange:YES ioSurface:NO];
		//	get the CMSampleBuffer timing info, apply it to the buffer
		CMTime				bufferTime = CMSampleBufferGetPresentationTimeStamp(n);
		double				timeInSec = (!CMTIME_IS_VALID(bufferTime)) ? 0. : CMTimeGetSeconds(bufferTime);
		uint64_t			tmpTimestamp = SWatchAbsTimeUnitForTime(timeInSec);
		[returnMe setContentTimestampFromPtr:&tmpTimestamp];
	}
	else	{
		if (cvImg == NULL)
			NSLog(@"\t\terr: img null in %s",__func__);
		else
			NSLog(@"\t\terr: img not of expected type (%ld) in %s",CFGetTypeID(cvImg),__func__);
	}
	return returnMe;
}
- (VVBuffer *) allocBufferForCVPixelBuffer:(CVPixelBufferRef)cvpb texRange:(BOOL)tr ioSurface:(BOOL)io	{
	//NSLog(@"%s",__func__);
	//	start setting up a buffer descriptor for the buffer i'm going to create
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
	//desc.backingType = VVBufferBack_CVPixBuf;
	desc.cpuBackingType = VVBufferCPUBack_External;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = tr;
	desc.texClientStorageFlag = YES;
	desc.msAmount = 0;
	desc.localSurfaceID = (io) ? 1 : 0;
	
	//	get some basic properties of the CVPixelBufferRef
	unsigned long	cvpb_bytesPerRow = CVPixelBufferGetBytesPerRow(cvpb);
	int				bitsPerPixel = 32;
	OSType			pixelFormat = CVPixelBufferGetPixelFormatType(cvpb);
	
	//FourCCLog(@"\t\tpixel format is",pixelFormat);
	switch (pixelFormat)	{
		//case FOURCC_PACK('B','G','R','A'):
		case 'BGRA':
			//NSLog(@"\t\tBGRA");
			bitsPerPixel = 32;
			break;
		//case FOURCC_PACK('2','v','u','y'):
		case '2vuy':
			//NSLog(@"\t\t2vuy");
			bitsPerPixel = 16;
			desc.internalFormat = VVBufferIF_RGB;
			desc.pixelFormat = VVBufferPF_YCBCR_422;
			desc.pixelType = VVBufferPT_U_Short_88;
			break;
		//case FOURCC_PACK('D','X','t','1'):
		case 'DXt1':
			break;
		//case FOURCC_PACK('D','X','T','5'):
		case 'DXT5':
			break;
		//case FOURCC_PACK('D','Y','t','5'):
		case 'DYt5':
			break;
		default:
			{
				char			charPtr[5];
				charPtr[4] = 0;
				VVUnpackFourCC_toChar(pixelFormat,charPtr);
				NSLog(@"\t\terr: unrecognized pixel format: %s, in %s",charPtr,__func__);
				return nil;
			}
			break;
	}
	
	//NSRect			cvpb_srcRect = NSMakeRect(0,0,CVPixelBufferGetWidth(cvpb),CVPixelBufferGetHeight(cvpb));
	CGRect			cvpb_srcRect = CVImageBufferGetCleanRect(cvpb);
	VVSIZE			cvpb_backingSize = VVMAKESIZE(cvpb_bytesPerRow/(bitsPerPixel/8), CVPixelBufferGetDataSize(cvpb)/cvpb_bytesPerRow);
	//NSLog(@"\t\ttotal size is %ld",CVPixelBufferGetDataSize(cvpb));
	//NSLog(@"\t\tbytesPerRow is %ld",cvpb_bytesPerRow);
	//NSSizeLog(@"\t\tbackingSize is",cvpb_backingSize);
	//NSRectLog(@"\t\tsrcRect is",cvpb_srcRect);
	
	CVPixelBufferLockBaseAddress(cvpb, kCVPixelBufferLock_ReadOnly);
	void			*cvpb_baseAddr = CVPixelBufferGetBaseAddress(cvpb);
	VVBuffer		*returnMe = [self
		allocBufferForDescriptor:&desc
		sized:cvpb_backingSize
		backingPtr:cvpb_baseAddr
		backingSize:cvpb_backingSize];
	//CVPixelBufferUnlockBaseAddress(cvpb, 0);
	CVPixelBufferRetain(cvpb);	//	the CVPixelBuffer is retained by the VVBuffer for the backing release callback context, here's where the retain count is incremented
	[returnMe setBackingID:VVBufferBackID_CVPixBuf];
	//[returnMe setCpuBackingPtr:cvpb_baseAddr];
	[returnMe setBackingReleaseCallbackContext:cvpb];
	[returnMe setBackingReleaseCallback:VVBuffer_ReleaseCVPixBuf];
	[returnMe setPreferDeletion:YES];
	[returnMe setSrcRect:CGMAKENSRECT(cvpb_srcRect)];
	[returnMe setFlipped:(CVImageBufferIsFlipped(cvpb)) ? YES : NO];
	return returnMe;
}
//	returns a RETAINED (MUST BE RELEASED BY CALLER!) VVBuffer with a texture backed by a (retained) NSBitmapImageRep!
- (VVBuffer *) allocTexRangeForNSBitmapRep:(NSBitmapImageRep *)rep	{
	return [self allocTexRangeForNSBitmapRep:rep prefer2DTexture:NO];
}
- (VVBuffer *) allocTexRangeForNSBitmapRep:(NSBitmapImageRep *)rep prefer2DTexture:(BOOL)prefer2D	{
	//NSLog(@"%s",__func__);
	if (rep==nil || deleted)
		return nil;
	void					*pixelData = (void *)[rep bitmapData];
	if (pixelData == nil)
		return nil;
	VVSIZE					repSize = [rep size];
	VVSIZE					gpuSize;
	if (prefer2D)	{
		int						tmpInt;
		tmpInt = 1;
		while (tmpInt < repSize.width)
			tmpInt <<= 1;
		gpuSize.width = tmpInt;
		tmpInt = 1;
		while (tmpInt < repSize.height)
			tmpInt <<= 1;
		gpuSize.height = tmpInt;
	}
	else
		gpuSize = repSize;
	
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
	//desc.backingType = VVBufferBack_Pixels;
	desc.cpuBackingType = VVBufferCPUBack_External;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = YES;
	desc.texClientStorageFlag = YES;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	
	VVBuffer			*returnMe = [self allocBufferForDescriptor:&desc sized:gpuSize backingPtr:pixelData backingSize:repSize];
	[returnMe setSrcRect:NSMakeRect(0,0,repSize.width,repSize.height)];
	//	the backing release callback should release a bitmap rep- set it, and the context (which is the rep)
	[returnMe setBackingID:VVBufferBackID_NSBitImgRep];
	[returnMe setBackingReleaseCallback:VVBuffer_ReleaseBitmapRep];
	[returnMe setBackingReleaseCallbackContextObject:rep];
	[returnMe setFlipped:YES];
	[returnMe setBackingSize:repSize];
	return returnMe;
}


/*===================================================================================*/
#pragma mark --------------------- making PBO-based VVBuffers
/*------------------------------------*/


- (VVBuffer *) allocRGBAPBOForTarget:(GLenum)t usage:(GLenum)u sized:(VVSIZE)s data:(const GLvoid *)d	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_PBO;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
	//desc.backingType = VVBufferBack_None;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [_globalVVBufferPool allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	if (returnMe == nil)
		return nil;
	
	int						bytesPerElement = 4;
	switch (desc.pixelType)	{
		case VVBufferPT_None:
			break;
		case VVBufferPT_Float:
			bytesPerElement = 16;
			break;
		case VVBufferPT_U_Byte:
			bytesPerElement = 1;
			break;
		case VVBufferPT_U_Int_8888_Rev:
			bytesPerElement = 4;
			break;
		case VVBufferPT_U_Short_88:
			bytesPerElement = 2;
			break;
	}
	
	pthread_mutex_lock(&contextLock);
	CGLContextObj			cgl_ctx = [context CGLContextObj];
	glBindBufferARB(t, [returnMe name]);
	glBufferDataARB(t, s.width * s.height * bytesPerElement, d, u);
	glBindBufferARB(t, 0);
	pthread_mutex_unlock(&contextLock);
	
	return returnMe;
}
- (VVBuffer *) allocRGBAFloatPBOForTarget:(GLenum)t usage:(GLenum)u sized:(VVSIZE)s data:(const GLvoid *)d	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_PBO;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA32F;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_Float;
	//desc.backingType = VVBufferBack_None;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [_globalVVBufferPool allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	if (returnMe == nil)
		return nil;
	
	
	int						bytesPerElement = 4;
	switch (desc.pixelType)	{
		case VVBufferPT_None:
			break;
		case VVBufferPT_Float:
			bytesPerElement = 16;
			break;
		case VVBufferPT_U_Byte:
			bytesPerElement = 1;
			break;
		case VVBufferPT_U_Int_8888_Rev:
			bytesPerElement = 4;
			break;
		case VVBufferPT_U_Short_88:
			bytesPerElement = 2;
			break;
	}
	
	pthread_mutex_lock(&contextLock);
	CGLContextObj			cgl_ctx = [context CGLContextObj];
	glBindBufferARB(t, [returnMe name]);
	glBufferDataARB(t, s.width * s.height * bytesPerElement, d, u);
	glBindBufferARB(t, 0);
	pthread_mutex_unlock(&contextLock);
	
	return returnMe;
}
- (VVBuffer *) allocYCbCrPBOForTarget:(GLenum)t usage:(GLenum)u sized:(VVSIZE)s data:(const GLvoid *)d	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_PBO;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_YCBCR_422;
	desc.pixelType = VVBufferPT_U_Short_88;
	//desc.backingType = VVBufferBack_None;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [_globalVVBufferPool allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	if (returnMe == nil)
		return nil;
	
	
	int						bytesPerElement = 4;
	switch (desc.pixelType)	{
		case VVBufferPT_None:
			break;
		case VVBufferPT_Float:
			bytesPerElement = 16;
			break;
		case VVBufferPT_U_Byte:
			bytesPerElement = 1;
			break;
		case VVBufferPT_U_Int_8888_Rev:
			bytesPerElement = 4;
			break;
		case VVBufferPT_U_Short_88:
			bytesPerElement = 2;
			break;
	}
	
	pthread_mutex_lock(&contextLock);
	CGLContextObj			cgl_ctx = [context CGLContextObj];
	glBindBufferARB(t, [returnMe name]);
	glBufferDataARB(t, s.width * s.height * bytesPerElement, d, u);
	glBindBufferARB(t, 0);
	pthread_mutex_unlock(&contextLock);
	
	return returnMe;
}
- (VVBuffer *) allocBGRAPBOForTarget:(GLenum)t usage:(GLenum)u sized:(VVSIZE)s data:(const GLvoid *)d	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_PBO;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_BGRA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
	//desc.backingType = VVBufferBack_None;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	VVBuffer		*returnMe = [_globalVVBufferPool allocBufferForDescriptor:&desc sized:s backingPtr:nil backingSize:s];
	if (returnMe == nil)
		return nil;
	
	
	int						bytesPerElement = 4;
	switch (desc.pixelType)	{
		case VVBufferPT_None:
			break;
		case VVBufferPT_Float:
			bytesPerElement = 16;
			break;
		case VVBufferPT_U_Byte:
			bytesPerElement = 1;
			break;
		case VVBufferPT_U_Int_8888_Rev:
			bytesPerElement = 4;
			break;
		case VVBufferPT_U_Short_88:
			bytesPerElement = 2;
			break;
	}
	
	pthread_mutex_lock(&contextLock);
	CGLContextObj			cgl_ctx = [context CGLContextObj];
	glBindBufferARB(t, [returnMe name]);
	glBufferDataARB(t, s.width * s.height * bytesPerElement, d, u);
	glBindBufferARB(t, 0);
	pthread_mutex_unlock(&contextLock);
	
	return returnMe;
}
#endif	//	!TARGET_OS_IPHONE


/*===================================================================================*/
#pragma mark --------------------- backend
/*------------------------------------*/


//	this method is called by instances of VVBuffer if its idleCount is 0 on dealloc
- (void) _returnBufferToPool:(VVBuffer *)b	{
	//NSLog(@"%s ... %@",__func__,b);
	//NSLog(@"\t\t%@",b);
	//NSLog(@"\t\treturning asset %@ to pool",b);
	if (b==nil)
		return;
	VVBuffer		*newBuffer = [[VVBuffer alloc] initWithPool:self];
	VVBufferDescriptorCopy([b descriptorPtr],[newBuffer descriptorPtr]);
	VVRECT			tmpRect = VVMAKERECT(0,0,0,0);
	tmpRect.size = [b size];
	[newBuffer setSize:tmpRect.size];
	[newBuffer setSrcRect:tmpRect];	//	reset the srcRect to the full size of the buffer!
	[newBuffer setBackingSize:[b backingSize]];
	
	//	IMPORTANT! when a buffer is freed, it releases its "pixels".  to retain pixels, i must set the "old" pixels to nil before freeing its buffer!
	//[newBuffer setPixels:[b pixels]];
	[newBuffer setBackingID:[b backingID]];
	[newBuffer setCpuBackingPtr:[b cpuBackingPtr]];
	[newBuffer setBackingReleaseCallback:[b backingReleaseCallback]];
	[newBuffer setBackingReleaseCallbackContext:[b backingReleaseCallbackContext]];
	[b setBackingReleaseCallback:nil];
	[b setBackingReleaseCallbackContext:nil];
#if !TARGET_OS_IPHONE
	//	don't bother setting the cvImgRef, cvTexRef, ffglImage, syphonImage, or externalBacking- buffers with those are never returned to the pool
	[newBuffer setLocalSurfaceRef:[b localSurfaceRef]];
	//	don't bother setting the remote surface- buffers with remote surfaces are never returned to the pool
#endif	//	!TARGET_OS_IPHONE
	
	[freeBuffers lockAddObject:newBuffer];
	//NSLog(@"\t\treplacement buffer is %@",newBuffer);
	//NSLog(@"\t\tfreeBuffers is now %@",freeBuffers);
	[newBuffer release];
}
//	this method is called by instances of VVBuffer if its idleCount is > 0 on dealloc
- (void) _releaseBufferResource:(VVBuffer *)b	{
	//NSLog(@"%s ... %@",__func__,b);
	//NSLog(@"\t\treleasing asset %@",b);
	if (b == nil)
		return;
	VVBufferDescriptor		*desc = [b descriptorPtr];
	if (desc == nil)
		return;
	//	if i'm here, i have to actually free the buffer resources
	pthread_mutex_lock(&contextLock);
#if !TARGET_OS_IPHONE
		CGLContextObj		cgl_ctx = [context CGLContextObj];
#else	//	NOT !TARGET_OS_IPHONE
		[EAGLContext setCurrentContext:context];
#endif	//	!TARGET_OS_IPHONE
		switch (desc->type)	{
			case VVBufferType_None:
			case VVBufferType_RB:
				glDeleteRenderbuffers(1,&desc->name);
				break;
			case VVBufferType_FBO:
				glDeleteFramebuffers(1,&desc->name);
				break;
			case VVBufferType_Tex:
				glDeleteTextures(1,&desc->name);
				break;
			case VVBufferType_PBO:
				glDeleteBuffers(1,&desc->name);
				break;
			case VVBufferType_VBO:
				glDeleteBuffers(1,&desc->name);
				break;
#if !TARGET_OS_IPHONE
			case VVBufferType_DispList:
				glDeleteLists(desc->name,1);
				break;
#endif	//	!TARGET_OS_IPHONE
		}
		glFlush();
	pthread_mutex_unlock(&contextLock);
}


- (void) _lock	{
	pthread_mutex_lock(&contextLock);
}
- (void) _unlock	{
	pthread_mutex_unlock(&contextLock);
}


@end




unsigned long VVPackFourCC_fromChar(char *charPtr)	{
	return (unsigned long)(charPtr[0]<<24 | charPtr[1]<<16 | charPtr[2]<<8 | charPtr[3]);
}
void VVUnpackFourCC_toChar(unsigned long fourCC, char *destCharPtr)	{
	destCharPtr[0] = (fourCC>>24) & 0xFF;
	destCharPtr[1] = (fourCC>>16) & 0xFF;
	destCharPtr[2] = (fourCC>>8) & 0xFF;
	destCharPtr[3] = (fourCC) & 0xFF;
}
void CGBitmapContextUnpremultiply(CGContextRef ctx)	{
	VVSIZE				actualSize = VVMAKESIZE(CGBitmapContextGetWidth(ctx), CGBitmapContextGetHeight(ctx));
	unsigned long		bytesPerRow = CGBitmapContextGetBytesPerRow(ctx);
	unsigned char		*bitmapData = (unsigned char *)CGBitmapContextGetData(ctx);
	unsigned char		*pixelPtr = nil;
	double				colors[4];
	if (bitmapData==nil || bytesPerRow<=0 || actualSize.width<1 || actualSize.height<1)
		return;
	for (int y=0; y<actualSize.height; ++y)	{
		pixelPtr = bitmapData + (y * bytesPerRow);
		for (int x=0; x<actualSize.width; ++x)	{
			//	convert unsigned chars to normalized doubles
			for (int i=0; i<4; ++i)
				colors[i] = ((double)*(pixelPtr+i))/255.;
			//	unpremultiply if there's an alpha and it won't cause a divide-by-zero
			if (colors[3]>0. && colors[3]<1.)	{
				for (int i=0; i<3; ++i)
					colors[i] = colors[i] / colors[3];
			}
			//	convert the normalized components back into unsigned chars
			for (int i=0; i<4; ++i)
				*(pixelPtr+i) = (unsigned char)(colors[i]*255.);
			
			//	don't forget to increment the pixel ptr!
			pixelPtr += 4;
		}
	}
}

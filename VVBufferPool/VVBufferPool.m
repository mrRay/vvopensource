#import "VVBufferPool.h"
#import <IOSurface/IOSurface.h>
#import <OpenGL/CGLIOSurface.h>
#ifdef __LP64__
#else
#import "HapSupport.h"
#endif




id _globalVVBufferPool = nil;
int				_msaaMaxSamples = 0;
BOOL			_bufferPoolInitialized = NO;
VVStopwatch		*_bufferTimestampMaker = nil;




@implementation VVBufferPool


+ (void) load	{
	//NSLog(@"%s",__func__);
	_msaaMaxSamples = 0;
	_bufferPoolInitialized = NO;
	_bufferTimestampMaker = nil;
	
	#ifndef __LP64__
	// The pixel formats must be registered before requesting them for a QTPixelBufferContext.
    // The codec does this but it is possible it may not be loaded yet.
    CFDictionaryRef		newDict = HapQTCreateCVPixelBufferOptionsDictionary();
    if (newDict != nil)
    	CFRelease(newDict);
    #endif
}
+ (void) initialize	{
	//NSLog(@"%s",__func__);
	if (_bufferPoolInitialized)
		return;
	
	NSOpenGLContext		*tmpContext = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:nil];
	if (tmpContext != nil)	{
		CGLContextObj	cgl_ctx = [tmpContext CGLContextObj];
		GLint			tmp;
		glGetIntegerv(GL_MAX_SAMPLES_EXT,&tmp);
		_msaaMaxSamples = tmp;
		[tmpContext release];
	}
	
	
	
	_bufferTimestampMaker = [[VVStopwatch alloc] init];
	
	_bufferPoolInitialized = YES;
}
+ (int) msaaMaxSamples	{
	return _msaaMaxSamples;
}
+ (void) setGlobalVVBufferPool:(id)n	{
	//NSLog(@"%s ... %p",__func__,n);
	VVRELEASE(_globalVVBufferPool);
	_globalVVBufferPool = n;
	if (_globalVVBufferPool != nil)
		[_globalVVBufferPool retain];
	if (_globalVVBufferCopier == nil)
		[VVBufferCopier createGlobalVVBufferCopierWithSharedContext:[n sharedContext]];
}
+ (void) createGlobalVVBufferPoolWithSharedContext:(NSOpenGLContext *)n	{
	VVRELEASE(_globalVVBufferPool);
	if (n==nil)
		return;
	_globalVVBufferPool = [[VVBufferPool alloc] initWithSharedContext:n pixelFormat:[GLScene defaultPixelFormat] sized:NSMakeSize(1,1)];
	if (_globalVVBufferCopier == nil)
		[VVBufferCopier createGlobalVVBufferCopierWithSharedContext:n];
}
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


- (id) initWithSharedContext:(NSOpenGLContext *)c	{
	return [self initWithSharedContext:c pixelFormat:[GLScene defaultPixelFormat] sized:NSMakeSize(80,60)];
}
- (id) initWithSharedContext:(NSOpenGLContext *)c sized:(NSSize)s	{
	return [self initWithSharedContext:c pixelFormat:[GLScene defaultPixelFormat] sized:s];
}
- (id) initWithSharedContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p	{
	return [self initWithSharedContext:c pixelFormat:p sized:NSMakeSize(80,60)];
}
- (id) initWithSharedContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p sized:(NSSize)s	{
	self = [super initWithSharedContext:c pixelFormat:p sized:s];
	if (self!=nil)	{
	}
	return self;
}
- (void) generalInit	{
	[super generalInit];
	context = [[NSOpenGLContext alloc] initWithFormat:customPixelFormat shareContext:sharedContext];
	pthread_mutexattr_t		attr;
	
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
	pthread_mutex_init(&contextLock, &attr);
	pthread_mutexattr_destroy(&attr);
	
	freeBuffers = [[MutLockArray arrayWithCapacity:0] retain];
	
	housekeepingThread = [[VVThreadLoop alloc] initWithTimeInterval:1.0 target:self selector:@selector(housekeeping)];
	//[housekeepingThread start];
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
- (VVBuffer *) allocBufferForDescriptor:(VVBufferDescriptor *)d sized:(NSSize)s backingPtr:(void *)b  backingSize:(NSSize)bs	{
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
	
	
	CGLError				err = kCGLNoError;
	IOSurfaceRef			newSurfaceRef = nil;
	//	make a buffer descriptor, populate it from the one i was passed- this will describe the buffer i'm returning
	VVBufferDescriptor		newBufferDesc;
	VVBufferDescriptorCopy(d,&newBufferDesc);
	unsigned long			cpuBackingSize = VVBufferDescriptorCalculateCPUBackingForSize(&newBufferDesc, bs);
	unsigned long			bytesPerRow = cpuBackingSize / bs.height;
	
	
	OSType					pixelFormat = 0x00;
	BOOL					compressedTex = NO;
	switch (newBufferDesc.internalFormat)	{
		case VVBufferIF_RGB_DXT1:	//	4 bits per pixel
			compressedTex = YES;
			break;
		case VVBufferIF_RGBA_DXT5:	//	8 bits per pixel
		//case VVBufferIF_YCoCg_DXT5:	//	8 bits per pixel
			compressedTex = YES;
			break;
		default:
			break;
	}
	switch (newBufferDesc.pixelFormat)	{
		case VVBufferPF_None:
		case VVBufferPF_Depth:
			break;
		case VVBufferPF_Lum:
		case VVBufferPF_R:
#if (defined(MAC_OS_X_VERSION_MIN_REQUIRED) && (MAC_OS_X_VERSION_MIN_REQUIRED >= 1080))
			pixelFormat = kCVPixelFormatType_OneComponent8;
#endif
			break;
		case VVBufferPF_RGBA:		//	'RGBA'
			pixelFormat = kCVPixelFormatType_32RGBA;
			break;
		case VVBufferPF_BGRA:		//	'BGRA'
			pixelFormat = kCVPixelFormatType_32BGRA;
			break;
		case VVBufferPF_YCBCR_422:	//	'2vuy'
			pixelFormat = kCVPixelFormatType_422YpCbCr8;
			break;
	}
	
	
	//	create the GL resources, populating the buffer descriptor where appropriate
	CGLContextObj			cgl_ctx = [context CGLContextObj];
	pthread_mutex_lock(&contextLock);
	switch (newBufferDesc.type)	{
		case VVBufferType_None:
			//NSLog(@"\t\tsize is %f x %f, BPR is %d",s.width,s.height,bytesPerRow);
			break;
		case VVBufferType_RB:
			//	generate the renderbuffer
			glGenRenderbuffersEXT(1,&newBufferDesc.name);
			//	bind the renderbuffer, set it up
			glBindRenderbufferEXT(newBufferDesc.target, newBufferDesc.name);
			if (newBufferDesc.msAmount > 0)	{
				glRenderbufferStorageMultisampleEXT(newBufferDesc.target,
					newBufferDesc.msAmount,
					newBufferDesc.pixelFormat,
					s.width,
					s.height);
			}
			//	unbind the renderbuffer
			glBindRenderbufferEXT(newBufferDesc.target, 0);
			//	flush!
			glFlush();
			break;
		case VVBufferType_FBO:
			//	generate the fbo
			glGenFramebuffersEXT(1,&newBufferDesc.name);
			//	make sure there aren't any errors
			//if (GL_FRAMEBUFFER_COMPLETE_EXT != glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT))
			//	NSLog(@"err- fbo %s",__func__);
			//	flush!
			glFlush();
			break;
		case VVBufferType_Tex:
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
			//	enable the tex target, gen the texture, and bind it
			glEnable(newBufferDesc.target);
			glGenTextures(1,&newBufferDesc.name);
			glBindTexture(newBufferDesc.target, newBufferDesc.name);
			
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
			
			//	setup basic tex defaults
			glPixelStorei(GL_UNPACK_SKIP_ROWS, GL_FALSE);
			glPixelStorei(GL_UNPACK_SKIP_PIXELS, GL_FALSE);
			glPixelStorei(GL_UNPACK_SWAP_BYTES, GL_FALSE);
			glTexParameteri(newBufferDesc.target, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameteri(newBufferDesc.target, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(newBufferDesc.target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(newBufferDesc.target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
			//glTexParameteri(newBufferDesc.target, GL_TEXTURE_WRAP_S, GL_REPEAT);
			//glTexParameteri(newBufferDesc.target, GL_TEXTURE_WRAP_T, GL_REPEAT);
			
			if (newBufferDesc.pixelFormat == VVBufferPF_Depth)
				glTexParameteri(newBufferDesc.target, GL_DEPTH_TEXTURE_MODE, GL_INTENSITY);
			
			if (newBufferDesc.pixelFormat == VVBufferPF_Depth)
				glTexParameteri(newBufferDesc.target, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
			else
				glTexParameteri(newBufferDesc.target, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);
			
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
			//	if there's no surface ref, or there is, but there was a problem associating it with the texture, set it up as a straight-up texture!
			if (newSurfaceRef==nil || err!=kCGLNoError)	{
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
			}
			
			if (newBufferDesc.texClientStorageFlag)	{
				glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE);
			}
			
			//	un-bind the tex and disable the target
			glBindTexture(newBufferDesc.target, 0);
			glDisable(newBufferDesc.target);
			
			//	flush!
			glFlush();
			break;
		case VVBufferType_PBO:
			glGenBuffersARB(1,&newBufferDesc.name);
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
		case VVBufferType_DispList:
			newBufferDesc.name = glGenLists(1);
			//	flush!
			glFlush();
			break;
	}
	pthread_mutex_unlock(&contextLock);
	
	returnMe = [[VVBuffer alloc] initWithPool:self];
	[returnMe setDescriptorFromPtr:&newBufferDesc];
	[returnMe setSize:s];
	[returnMe setSrcRect:NSMakeRect(0,0,s.width,s.height)];
	[returnMe setBackingSize:bs];
	[returnMe setCpuBackingPtr:b];
	[VVBufferPool timestampThisBuffer:returnMe];
	
	if (newSurfaceRef != nil)	{
		[returnMe setLocalSurfaceRef:newSurfaceRef];
		CFRelease(newSurfaceRef);
		newSurfaceRef = nil;
	}
	return returnMe;
}

- (VVBuffer *) copyFreeBufferMatchingDescriptor:(VVBufferDescriptor *)d sized:(NSSize)s	{
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
					case VVBufferType_DispList:
						sizeIsOK = YES;
						break;
					case VVBufferType_None:	//	need to check size because RGB/RGBA CPU buffers use this type!
					case VVBufferType_RB:
					case VVBufferType_Tex:
					case VVBufferType_PBO:
						if (NSEqualSizes(s,[bufferPtr size]))
							sizeIsOK = YES;
						break;
					case VVBufferType_VBO:
						sizeIsOK = NO;
						break;
				}
				
				if (sizeIsOK)	{
					//NSLog(@"\t\tsize is OK!");
					IOSurfaceRef		srf = [bufferPtr localSurfaceRef];
					//NSLog(@"\t\tsrf is %p, d->localSurfaceID is %lu",srf,d->localSurfaceID);
					if ((d->localSurfaceID!=0 && srf!=nil) || (d->localSurfaceID==0 && srf==nil))	{
						//	retain the buffer (so it doesn't get freed)
						returnMe = [bufferPtr retain];
						//	remove the buffer from the array
						[freeBuffers removeObjectAtIndex:tmpIndex];
						//	set the buffer's idleCount to 0, so it's "fresh" (so it gets returned to the pool when it's no longer needed)
						[returnMe setIdleCount:0];
						//	break out of the foor loop
						break;
					}
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
- (VVBuffer *) copyFreeBufferMatchingDescriptor:(VVBufferDescriptor *)d sized:(NSSize)s backingSize:(NSSize)bs	{
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
					case VVBufferType_DispList:
						sizeIsOK = YES;
						backingSizeIsOK = YES;
						break;
					case VVBufferType_None:	//	need to check size because RGB/RGBA CPU buffers use this type!
					case VVBufferType_RB:
					case VVBufferType_Tex:
					case VVBufferType_PBO:
						//NSLog(@"\t\t(%f x %f), (%f x %f)",[bufferPtr size].width,[bufferPtr size].height,[bufferPtr backingSize].width,[bufferPtr backingSize].height);
						if (NSEqualSizes(s,[bufferPtr size]))
							sizeIsOK = YES;
						if (NSEqualSizes(bs,[bufferPtr backingSize]))
							backingSizeIsOK = YES;
						break;
					case VVBufferType_VBO:
						sizeIsOK = NO;
						backingSizeIsOK = NO;
						break;
				}
				
				if (sizeIsOK && backingSizeIsOK)	{
					IOSurfaceRef		srf = [bufferPtr localSurfaceRef];
					//NSLog(@"\t\tsrf is %p, d->localSurfaceID is %lu",srf,d->localSurfaceID);
					if ((d->localSurfaceID!=0 && srf!=nil) || (d->localSurfaceID==0 && srf==nil))	{
						//	retain the buffer (so it doesn't get freed)
						returnMe = [bufferPtr retain];
						//	remove the buffer from the array
						[freeBuffers removeObjectAtIndex:tmpIndex];
						//	set the buffer's idleCount to 0, so it's "fresh" (so it gets returned to the pool when it's no longer needed)
						[returnMe setIdleCount:0];
						//	break out of the foor loop
						break;
					}
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
#pragma mark --------------------- the only methods you should call to create stuff
/*------------------------------------*/


- (VVBuffer *) allocFBO	{
	NSSize					tmpSize = NSMakeSize(1,1);
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
- (VVBuffer *) allocBGRTexSized:(NSSize)s	{
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
- (VVBuffer *) allocBGR2DTexSized:(NSSize)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_2D;
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
- (VVBuffer *) allocBGR2DPOTTexSized:(NSSize)s	{
	//	rounds up the size to the nearest POT
	NSSize		texSize;
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
	VVBuffer		*returnMe = [self copyFreeBufferMatchingDescriptor:&desc sized:texSize];
	if (returnMe == nil)
		returnMe = [self allocBufferForDescriptor:&desc sized:texSize backingPtr:nil backingSize:s];
	[returnMe setSrcRect:NSMakeRect(0,0,s.width,s.height)];
	[returnMe setBackingSize:s];
	return returnMe;
}
- (VVBuffer *) allocBGRFloatTexSized:(NSSize)s	{
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
- (VVBuffer *) allocBGRFloat2DPOTTexSized:(NSSize)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_2D;
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
- (VVBuffer *) allocDepthSized:(NSSize)s	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_RECTANGLE_EXT;
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
- (VVBuffer *) allocMSAAColorSized:(NSSize)s numOfSamples:(int)n	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_RB;
	desc.target = GL_RENDERBUFFER_EXT;
	desc.internalFormat = VVBufferIF_RGBA;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
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
- (VVBuffer *) allocMSAADepthSized:(NSSize)s numOfSamples:(int)n	{
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_RB;
	desc.target = GL_RENDERBUFFER_EXT;
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


- (VVBuffer *) allocBufferForNSImage:(NSImage *)img	{
	return [self allocBufferForNSImage:img prefer2DTexture:NO];
}
- (VVBuffer *) allocBufferForNSImage:(NSImage *)img prefer2DTexture:(BOOL)prefer2D	{
	//NSLog(@"%s ... %d",__func__,prefer2D);
	if (img==nil)
		return nil;
	NSSize					imageSize = [img size];
	NSSize					bitmapSize;
	/*
	if (prefer2D)	{
		int			tmpInt = 1;
		while (tmpInt < imageSize.width)
			tmpInt <<= 1;
		bitmapSize.width = tmpInt;
		tmpInt = 1;
		while (tmpInt < imageSize.height)
			tmpInt <<= 1;
		bitmapSize.height = tmpInt;
	}
	else	{
	*/
		bitmapSize = imageSize;
	/*
	}
	*/
	NSArray			*reps = [img representations];
	for (NSImageRep *rep in reps)	{
		if ([rep isKindOfClass:[NSBitmapImageRep class]])	{
			bitmapSize.width = fmax(bitmapSize.width, [rep pixelsWide]);
			bitmapSize.height = fmax(bitmapSize.height, [rep pixelsHigh]);
		}
	}
	NSRect					bitmapRect = NSMakeRect(0,0,bitmapSize.width,bitmapSize.height);
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
		//NSRectFill(bitmapRect);
		[img
			drawAtPoint:NSMakePoint(0,floor(bitmapSize.height-imageSize.height))
			fromRect:bitmapRect
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
	
	VVBuffer		*returnMe = [self allocBufferForBitmapRep:rep prefer2DTexture:prefer2D];
	[returnMe setSrcRect:NSMakeRect(0,0,imageSize.width,imageSize.height)];
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
	NSSize					repSize = [rep size];
	NSSize					gpuSize;
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
	[returnMe setSrcRect:NSMakeRect(0,0,repSize.width,repSize.height)];
	//	the backing release callback should release a bitmap rep- set it, and the context (which is the rep)
	[returnMe setBackingID:VVBufferBackID_NSBitImgRep];
	[returnMe setBackingReleaseCallback:VVBuffer_ReleaseBitmapRep];
	[returnMe setBackingReleaseCallbackContext:rep];
	//	don't forget to retain the rep (the buffer retains it, we increment the retain count here)
	[rep retain];
	[returnMe setBackingSize:repSize];
	return returnMe;
}
- (VVBuffer *) allocBufferForCVGLTex:(CVOpenGLTextureRef)cvt	{
	if (deleted)
		return nil;
	if (cvt == nil)	{
		NSLog(@"\t\terr: passed nil tex %s",__func__);
		return nil;
	}
	GLuint			texName = CVOpenGLTextureGetName(cvt);
	if (texName <= 0)	{
		NSLog(@"\t\terr: passed invalid tex num %s",__func__);
		return nil;
	}
	if (CFGetTypeID(cvt) != CVOpenGLTextureGetTypeID())	{
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
	desc->target = CVOpenGLTextureGetTarget(cvt);
	desc->internalFormat = VVBufferIF_RGBA8;
	desc->pixelFormat = VVBufferPF_BGRA;
	desc->pixelType = VVBufferPT_U_Int_8888_Rev;
	desc->cpuBackingType = VVBufferCPUBack_None;
	desc->gpuBackingType = VVBufferGPUBack_External;
	desc->name = texName;
	desc->texRangeFlag = NO;
	desc->texClientStorageFlag = NO;
	desc->msAmount = 0;
	desc->localSurfaceID = 0;
	
	CGSize				texSize = CVImageBufferGetEncodedSize(cvt);
	[returnMe setPreferDeletion:YES];
	[returnMe setSize:NSMakeSize(texSize.width,texSize.height)];
	[returnMe setSrcRect:NSMakeRect(0,0,texSize.width,texSize.height)];
	[returnMe setFlipped:CVOpenGLTextureIsFlipped(cvt)];
	[returnMe setBackingSize:[returnMe size]];
	
	[returnMe setBackingID:VVBufferBackID_CVTex];
	CVOpenGLTextureRetain(cvt);
	[returnMe setBackingReleaseCallback:VVBuffer_ReleaseCVGLT];
	[returnMe setBackingReleaseCallbackContext:cvt];
	return returnMe;
}
#ifndef __LP64__
- (VVBuffer *) allocTexRangeForHapCVImageBuffer:(CVImageBufferRef)img	{
	//NSLog(@"%s",__func__);
	if (img == nil)
		return nil;
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
	NSSize		encodedSize = CGMAKENSSIZE(CVImageBufferGetEncodedSize(img));
	NSRect		roundedRect = NSMakeRect(0,0,CVPixelBufferGetWidth(img),CVPixelBufferGetHeight(img));
	size_t		extraRight;
	size_t		extraBottom;
	CVPixelBufferGetExtendedPixels(img, NULL, &extraRight, NULL, &extraBottom);
	roundedRect.size = NSMakeSize(roundedRect.size.width+extraRight, roundedRect.size.height+extraBottom);
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
	void		*baseAddress = CVPixelBufferGetBaseAddress(img);
	
	//	determine what the size of the texture should be
	NSSize		gpuSize = roundedRect.size;
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
	[returnMe setSrcRect:NSMakeRect(0,0,encodedSize.width,encodedSize.height)];
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
		
		NSSize			bSize;
		//NSSize			backingSize = [returnMe backingSize];
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
			//case VVBufferIF_YCoCg_DXT5:
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
			#else
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
			#endif
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
#endif










- (VVBuffer *) allocBufferForTexBackedIOSurfaceSized:(NSSize)s	{
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
		NSLog(@"\t\terr: bailing, couldn't look up IOSurface by ID %d",n);
		return nil;
	}
	//	figure out how big the IOSurface is and what its pixel format is
	NSSize					newAssetSize = NSMakeSize(IOSurfaceGetWidth(newSurface),IOSurfaceGetHeight(newSurface));
	OSType					pixelFormat = IOSurfaceGetPixelFormat(newSurface);
	//NSLog(@"\t\tpixel format from server is %08lX (%c%c%c%c)",pixelFormat,(char)((pixelFormat>>24) & 0xFF),(char)((pixelFormat>>16) & 0xFF),(char)((pixelFormat>>8) & 0xFF),(char)((pixelFormat>>0) & 0xFF));
	//	make the buffer i'll be returning, set up as much of it as i can
	VVBuffer				*returnMe = [[VVBuffer alloc] initWithPool:self];
	[VVBufferPool timestampThisBuffer:returnMe];
	[returnMe setPreferDeletion:YES];
	[returnMe setSize:newAssetSize];
	[returnMe setSrcRect:NSMakeRect(0,0,newAssetSize.width,newAssetSize.height)];
	[returnMe setBackingSize:NSMakeSize(newAssetSize.width,newAssetSize.height)];
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
	NSRect				newRect = NSMakeRect([[components objectAtIndex:1] floatValue], [[components objectAtIndex:2] floatValue], [[components objectAtIndex:3] floatValue], [[components objectAtIndex:4] floatValue]);
	BOOL				newFlipped = ([[components objectAtIndex:5] integerValue]==0) ? FALSE : TRUE;
	VVBuffer			*returnMe = [self allocBufferForIOSurfaceID:newID];
	[returnMe setSrcRect:newRect];
	[returnMe setFlipped:newFlipped];
	return returnMe;
}
- (VVBuffer *) allocCubeMapTextureForImages:(NSArray *)n	{
	//	make sure that i was passed six images, and that all six images are the same size
	if (n==nil || [n count]!=6)	{
		NSLog(@"\t\terr: bailing, not passed 6 images, %s",__func__);
		return nil;
	}
	NSSize			imageSize = [[n objectAtIndex:0] size];
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
	
	VVBuffer		*returnMe = nil;
	
	//	set up the buffer descriptor that i'll be using to describe the texture i'm about to create
	VVBufferDescriptor		desc;
	desc.type = VVBufferType_Tex;
	desc.target = GL_TEXTURE_CUBE_MAP;
	desc.internalFormat = VVBufferIF_RGBA8;
	desc.pixelFormat = VVBufferPF_RGBA;
	desc.pixelType = VVBufferPT_U_Int_8888_Rev;
	desc.cpuBackingType = VVBufferCPUBack_None;
	desc.gpuBackingType = VVBufferGPUBack_Internal;
	desc.name = 0;
	desc.texRangeFlag = NO;
	desc.texClientStorageFlag = NO;
	desc.msAmount = 0;
	desc.localSurfaceID = 0;
	
	//	actually upload the bitmap data to the texture
	pthread_mutex_lock(&contextLock);
	
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	
	glEnable(desc.target);
	glGenTextures(1,&desc.name);
	glBindTexture(desc.target, desc.name);
	glPixelStorei(GL_UNPACK_SKIP_ROWS, GL_FALSE);
	glPixelStorei(GL_UNPACK_SKIP_PIXELS, GL_FALSE);
	glPixelStorei(GL_UNPACK_SWAP_BYTES, GL_FALSE);
	glTexParameteri(desc.target, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(desc.target, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(desc.target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(desc.target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glFlush();
	
	int				faceCount=0;
	unsigned long	bytesPerRow = 32 * imageSize.width / 8;
	void			*clipboardData = malloc(bytesPerRow * imageSize.height);
	//	run through all the images
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
	free(clipboardData);
	
	glBindTexture(desc.target, 0);
	glDisable(desc.target);
	
	pthread_mutex_unlock(&contextLock);
	
	//	finish creating the VVBuffer instance from stuff
	returnMe = [[VVBuffer alloc] initWithPool:self];
	[returnMe setDescriptorFromPtr:&desc];
	[returnMe setSize:imageSize];
	[returnMe setSrcRect:NSMakeRect(0,0,imageSize.width,imageSize.height)];
	[returnMe setBackingSize:imageSize];
	[returnMe setPreferDeletion:YES];
	[VVBufferPool timestampThisBuffer:returnMe];
	
	return returnMe;
}


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
	NSRect			tmpRect = NSMakeRect(0,0,0,0);
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
	//	don't bother setting the cvImgRef, cvTexRef, ffglImage, syphonImage, or externalBacking- buffers with those are never returned to the pool
	[newBuffer setLocalSurfaceRef:[b localSurfaceRef]];
	//	don't bother setting the remote surface- buffers with remote surfaces are never returned to the pool
	
	[freeBuffers lockAddObject:newBuffer];
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
		CGLContextObj		cgl_ctx = [context CGLContextObj];
		switch (desc->type)	{
			case VVBufferType_None:
			case VVBufferType_RB:
				glDeleteRenderbuffersEXT(1,&desc->name);
				break;
			case VVBufferType_FBO:
				glDeleteFramebuffersEXT(1,&desc->name);
				break;
			case VVBufferType_Tex:
				glDeleteTextures(1,&desc->name);
				break;
			case VVBufferType_PBO:
				glDeleteBuffersARB(1,&desc->name);
				break;
			case VVBufferType_VBO:
				glDeleteBuffers(1,&desc->name);
				break;
			case VVBufferType_DispList:
				glDeleteLists(desc->name,1);
				break;
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

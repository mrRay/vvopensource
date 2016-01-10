#import "CIGLScene.h"
#import "AvailabilityMacros.h"
#import "VVBufferPool.h"
#import "GLScene.h"




pthread_mutex_t			_globalCIContextLock;
#if !TARGET_OS_IPHONE
NSOpenGLContext			*_globalCIContextGLContext = nil;
NSOpenGLContext			*_globalCIContextSharedContext = nil;
NSOpenGLPixelFormat		*_globalCIContextPixelFormat = nil;
#else
EAGLContext			*_globalCIContextGLContext = nil;
#endif




@implementation CIGLScene


+ (void) load	{
	pthread_mutexattr_t		attr;
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
	pthread_mutex_init(&_globalCIContextLock, &attr);
	pthread_mutexattr_destroy(&attr);
}
#if !TARGET_OS_IPHONE
+ (void) prepCommonCIBackendToRenderOnContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p	{
	if (c==nil)	{
		NSLog(@"\t\tERR: context nil in %s",__func__);
		return;
	}
	pthread_mutex_lock(&_globalCIContextLock);
	
	VVRELEASE(_globalCIContextSharedContext);
	_globalCIContextSharedContext = [c retain];
	
	VVRELEASE(_globalCIContextPixelFormat);
	_globalCIContextPixelFormat = [p retain];
	
	VVRELEASE(_globalCIContextGLContext);
	_globalCIContextGLContext = [[NSOpenGLContext alloc] initWithFormat:p shareContext:c];
	
	pthread_mutex_unlock(&_globalCIContextLock);
}
#else
+ (void) prepCommonCIBackendToRenderOnContext:(EAGLContext *)c	{
	if (c==nil)	{
		NSLog(@"\t\tERR: context nil in %s",__func__);
		return;
	}
	pthread_mutex_lock(&_globalCIContextLock);
	
	VVRELEASE(_globalCIContextGLContext);
	_globalCIContextGLContext = [c retain];
	
	pthread_mutex_unlock(&_globalCIContextLock);
}
+ (void) prepCommonCIBackendToRenderOnSharegroup:(EAGLSharegroup *)s	{
	if (s == nil)	{
		NSLog(@"\t\tERR: sharegroup nil in %s",__func__);
		return;
	}
	NSLog(@"\t\tmaking an  EAGLContext in %s for %@",__func__,self);
	EAGLContext		*newCtx = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3 sharegroup:s];
	if (newCtx == nil)	{
		NSLog(@"\t\tERR: context nil in %s",__func__);
		return;
	}
	
	pthread_mutex_lock(&_globalCIContextLock);
	
	VVRELEASE(_globalCIContextGLContext);
	_globalCIContextGLContext = [newCtx retain];
	
	pthread_mutex_unlock(&_globalCIContextLock);
	
	[newCtx release];
}
#endif

#if !TARGET_OS_IPHONE
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
#else
- (id) initWithSharegroup:(EAGLSharegroup *)g sized:(VVSIZE)s	{
	return [super initWithSharegroup:g sized:s];
}
- (id) initWithSharegroup:(EAGLSharegroup *)g	{
	return [super initWithSharegroup:g];
}
- (id) initWithContext:(EAGLContext *)c	{
	return [super initWithContext:c];
}
- (id) initWithContext:(EAGLContext *)c sized:(VVSIZE)s	{
	return [super initWithContext:c sized:s];
}
#endif

- (id) initCommonBackendSceneSized:(VVSIZE)n	{
	self = [super init];
	if (self!=nil)	{
		size = n;
		pthread_mutex_lock(&_globalCIContextLock);
		context = (_globalCIContextGLContext==nil) ? nil : [_globalCIContextGLContext retain];
		if (context!=nil)	{
#if !TARGET_OS_IPHONE
			sharedContext = (_globalCIContextSharedContext==nil) ? nil : [_globalCIContextSharedContext retain];
			customPixelFormat = (_globalCIContextPixelFormat==nil) ? nil : [_globalCIContextPixelFormat retain];
#endif
		}
		pthread_mutex_unlock(&_globalCIContextLock);
		if (context==nil)	{
			NSLog(@"\t\terr: couldn't make context, call +[CIGLScene prepCommonCIBackendToRenderOnContext:pixelFormat:] before trying to init a QCGLScene");
			[self release];
			self = nil;
		}
	}
	return self;
}
- (void) generalInit	{
	[super generalInit];
	workingColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	outputColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	ciContext = nil;
	cleanupDelegate = nil;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	if (workingColorSpace != NULL)	{
		CGColorSpaceRelease(workingColorSpace);
		workingColorSpace = NULL;
	}
	if (outputColorSpace != NULL)	{
		CGColorSpaceRelease(outputColorSpace);
		outputColorSpace = NULL;
	}
	
	VVRELEASE(ciContext);	//	should have already been added to render thread's delete array & set to nil in prepareToBeDeleted!
	
	[super dealloc];
}
- (void) prepareToBeDeleted	{
	//NSLog(@"%s ... %p",__func__,self);
	renderTarget = nil;
	deleted = YES;
	
	if (ciContext != nil)	{
		BOOL			addedToRenderThread = NO;
		OSSpinLockLock(&renderThreadLock);
		if (renderThreadDeleteArray != nil)	{
			addedToRenderThread = YES;
			[renderThreadDeleteArray lockAddObject:ciContext];
		}
		OSSpinLockUnlock(&renderThreadLock);
		if (!addedToRenderThread)	{
#if !TARGET_OS_IPHONE
			if (context!=nil)	{
				CGLLockContext([context CGLContextObj]);
				//NSLog(@"\t\tlocked context %p on thread %p in %s",[context CGLContextObj],[NSThread currentThread],__func__);
			}
#endif
			
			[ciContext release];
			ciContext = nil;
			
#if !TARGET_OS_IPHONE
			if (context!=nil)	{
				//NSLog(@"\t\tunlocking context %p on thread %p in %s",[context CGLContextObj],[NSThread currentThread],__func__);
				CGLUnlockContext([context CGLContextObj]);
			}
#endif
		}
		else	{
			[ciContext release];
			ciContext = nil;
		}
	}
	
	[super prepareToBeDeleted];
}

- (void) _renderPrep	{
	if (context==_globalCIContextGLContext)
		needsReshape = YES;
	
	[super _renderPrep];
	
	if (deleted)
		return;
	if (context == nil)
		return;
#if !TARGET_OS_IPHONE
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	/*
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
	
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glMatrixMode(GL_TEXTURE);
	glPushMatrix();
	
	glMatrixMode(GL_COLOR_MATRIX_STACK_DEPTH);
	glPushMatrix();
	glMatrixMode(GL_MODELVIEW_STACK_DEPTH);
	glPushMatrix();
	glMatrixMode(GL_PROJECTION_STACK_DEPTH);
	glPushMatrix();
	glMatrixMode(GL_TEXTURE_STACK_DEPTH);
	glPushMatrix();
	glMatrixMode(GL_MAX_MODELVIEW_STACK_DEPTH);
	glPushMatrix();
	glMatrixMode(GL_MAX_PROJECTION_STACK_DEPTH);
	glPushMatrix();
	glMatrixMode(GL_MAX_TEXTURE_STACK_DEPTH);
	glPushMatrix();
	*/
	//glDisable(GL_TEXTURE_RECTANGLE_EXT);
#endif
	//glDisable(GL_TEXTURE_2D);
	//glEnable(GL_TEXTURE_2D);
}
- (void) _renderCleanup	{
	if (cleanupDelegate != nil)	{
		[cleanupDelegate cleanupCIGLScene:self];
	}
	
	[super _renderCleanup];
	
	if (deleted)
		return;
	if (context == nil)
		return;
	
#if !TARGET_OS_IPHONE
	//CGLContextObj		cgl_ctx = [context CGLContextObj];
	//glDisable(GL_TEXTURE_RECTANGLE_EXT);
#endif
	//glDisable(GL_TEXTURE_2D);
	/*
	glPopAttrib();
	glPopClientAttrib();
	
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	glMatrixMode(GL_TEXTURE);
	glPopMatrix();
	
	glMatrixMode(GL_COLOR_MATRIX_STACK_DEPTH);
	glPopMatrix();
	glMatrixMode(GL_MODELVIEW_STACK_DEPTH);
	glPopMatrix();
	glMatrixMode(GL_PROJECTION_STACK_DEPTH);
	glPopMatrix();
	glMatrixMode(GL_TEXTURE_STACK_DEPTH);
	glPopMatrix();
	glMatrixMode(GL_MAX_MODELVIEW_STACK_DEPTH);
	glPopMatrix();
	glMatrixMode(GL_MAX_PROJECTION_STACK_DEPTH);
	glPopMatrix();
	glMatrixMode(GL_MAX_TEXTURE_STACK_DEPTH);
	glPopMatrix();
	*/
}


- (VVBuffer *) allocAndRenderBufferFromImage:(CIImage *)i	{
	if (i==nil)
		return nil;
	//VVSIZE			imgSize = CGMAKENSSIZE([i extent].size);
	//[self setSize:imgSize];
#if !TARGET_OS_IPHONE
	VVBuffer		*returnMe = [_globalVVBufferPool allocBGRTexSized:size];
#else
	VVBuffer		*returnMe = [_globalVVBufferPool allocBGR2DTexSized:size];
#endif
	VVBuffer		*tmpFbo = [_globalVVBufferPool allocFBO];
	
	[self renderCIImage:i inFBO:[tmpFbo name] colorTex:[returnMe name] target:[returnMe target]];
	
	VVRELEASE(tmpFbo);
	return returnMe;
}
- (void) renderCIImage:(CIImage *)i	{
	//NSLog(@"%s ... %@",__func__,i);
	if (deleted)
		return;
	
	OSSpinLockLock(&renderThreadLock);
	if (renderThreadDeleteArray == nil)	{
		renderThreadDeleteArray = [[[NSThread currentThread] threadDictionary] objectForKey:@"deleteArray"];
	}
	OSSpinLockUnlock(&renderThreadLock);
	
	//	if i'm here and the context is nil, then i'm not sharing a single GL context for everything- i'm expected to create the GL context, which will be used exclusively by this CIContext
	if (context==nil)
		[self _renderPrep];
	
	if (context!=nil)	{
#if !TARGET_OS_IPHONE
		CGLLockContext([context CGLContextObj]);
#endif
		//NSLog(@"\t\tlocked context %p on thread %p in %s",[context CGLContextObj],[NSThread currentThread],__func__);
		@try	{
			//	make sure the context has been set up/reshaped, attaches the texture/depth buffer to the fbo
			[self _renderPrep];
			
			//	draw the image in the context
			if (i != nil)	{
				
				[ciContext
					drawImage:i
					inRect:CGRectMake(0,0,size.width,size.height)
					fromRect:CGRectMake(0,0,size.width,size.height)];
				
				/*
				[ciContext
					drawImage:i
					atPoint:CGPointMake(0,0)
					fromRect:CGRectMake(0,0,size.width,size.height)];
				*/
			}
			
			//	do any cleanup/flush my context
			[self _renderCleanup];
		}
		@catch (NSException *excErr)	{
			NSLog(@"\t\tERR: caught exception in %s",__func__);
			NSLog(@"\t\texception was %@",excErr);
		}
#if !TARGET_OS_IPHONE
		//NSLog(@"\t\tunlocking context %p on thread %p in %s",[context CGLContextObj],[NSThread currentThread],__func__);
		CGLUnlockContext([context CGLContextObj]);
#endif
	}
}
- (void) renderCIImage:(CIImage *)i inFBO:(GLuint)f colorTex:(GLuint)t	{
#if !TARGET_OS_IPHONE
	[self renderCIImage:i inFBO:f colorTex:t target:GL_TEXTURE_RECTANGLE_EXT];
#else
	[self renderCIImage:i inFBO:f colorTex:t target:GL_TEXTURE_2D];
#endif
}
- (void) renderCIImage:(CIImage *)i inFBO:(GLuint)f colorTex:(GLuint)t target:(GLuint)tt	{
	if (deleted)
		return;
	
	fbo = f;
	tex = t;
	texTarget = tt;
	depth = 0;
	
	OSSpinLockLock(&renderThreadLock);
	if (renderThreadDeleteArray == nil)	{
		renderThreadDeleteArray = [[[NSThread currentThread] threadDictionary] objectForKey:@"deleteArray"];
	}
	OSSpinLockUnlock(&renderThreadLock);
	
	//	if i'm here and the context is nil, then i'm not sharing a single GL context for everything- i'm expected to create the GL context, which will be used exclusively by this CIContext
	if (context==nil)
		[self _renderPrep];
	
	if (context!=nil)	{
#if !TARGET_OS_IPHONE
		CGLLockContext([context CGLContextObj]);
#endif
		//NSLog(@"\t\tlocked context %p on thread %p in %s",[context CGLContextObj],[NSThread currentThread],__func__);
		@try	{
			//	make sure the context has been set up/reshaped, attaches the texture/depth buffer to the fbo
			[self _renderPrep];
			
			//	make sure i have a context
			if (context!=nil && ciContext!=nil)	{
				//	draw the image in the context
				if (i != nil)	{
					[ciContext
						drawImage:i
						inRect:CGRectMake(0,0,size.width,size.height)
						fromRect:CGRectMake(0,0,size.width,size.height)];
					/*
					[ciContext
						drawImage:i
						atPoint:CGPointMake(0,0)
						fromRect:CGRectMake(0,0,size.width,size.height)];
					*/
				}
			}
			
			//	do any cleanup/flush my context
			[self _renderCleanup];
		}
		@catch (NSException *excErr)	{
			NSLog(@"\t\tERR: caught exception in %s",__func__);
			NSLog(@"\t\texception was %@",excErr);
		}
		
		fbo = 0;
		tex = 0;
		texTarget = 0;
		depth = 0;
#if !TARGET_OS_IPHONE
		//NSLog(@"\t\tunlocking context %p on thread %p in %s",[context CGLContextObj],[NSThread currentThread],__func__);
		CGLUnlockContext([context CGLContextObj]);
#endif
	}
}
- (void) _initialize	{
	//	tell the super to do its thing
	[super _initialize];
#if !TARGET_OS_IPHONE
	//	the only thing i want to change is the tex env mode
	CGLContextObj		cgl_ctx = [context CGLContextObj];
#endif
	
	//glEnable(GL_BLEND);
	glDisable(GL_BLEND);
#if !TARGET_OS_IPHONE
	//glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
#endif
}
- (void) _reshape	{
	//	release the CI context (i'll have to get another one)
	//VVRELEASE(ciContext);
	
	//	tell the super to do its reshape- this takes care of the actual GL stuff
	[super _reshape];
	
	//	CI renders upside down, so i invert the coords now!
#if !TARGET_OS_IPHONE
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	if (flipped)
		glOrtho(0, size.width, size.height, 0, 1.0, -1.0);
	else
		glOrtho(0, size.width, 0, size.height, 1.0, -1.0);
#endif
	glViewport(0,0,size.width,size.height);
	
	//	make a new CI context, retain it if successful
	
	if (ciContext == nil)	{
#if (defined(MAC_OS_X_VERSION_MIN_REQUIRED) && (MAC_OS_X_VERSION_MIN_REQUIRED >= 1060))
		ciContext = [CIContext
			contextWithCGLContext:[context CGLContextObj]
			pixelFormat:[customPixelFormat CGLPixelFormatObj]
			colorSpace:workingColorSpace
			options:[NSDictionary dictionaryWithObjectsAndKeys:
				(id)outputColorSpace, kCIContextOutputColorSpace,
				(id)workingColorSpace, kCIContextWorkingColorSpace, nil]	];
#elif !TARGET_OS_IPHONE
		//NSLog(@"\t\tcreating CIContext for CGLContextObj %p",[context CGLContextObj]);
		ciContext = [CIContext
			contextWithCGLContext:[context CGLContextObj]
			pixelFormat:[customPixelFormat CGLPixelFormatObj]
			options:[NSDictionary dictionaryWithObjectsAndKeys:
				(id)outputColorSpace, kCIContextOutputColorSpace,
				(id)workingColorSpace, kCIContextWorkingColorSpace, nil]	];
#else
		ciContext = [CIContext
			contextWithEAGLContext:context
			//options:nil];
			options:[NSDictionary dictionaryWithObjectsAndKeys:
				(id)outputColorSpace, kCIContextOutputColorSpace,
				(id)workingColorSpace, kCIContextWorkingColorSpace,
			//	/*(id)NUMINT(kCIFormatRGBAf), kCIContextWorkingFormat,*/
				nil]	];
#endif
	}
	if (ciContext != nil)
		[ciContext retain];
}


@synthesize workingColorSpace;
@synthesize outputColorSpace;
- (CIContext *) ciContext	{
	return [[ciContext retain] autorelease];
}
- (void) setCleanupDelegate:(id <CIGLSceneCleanup>)n	{
	//NSLog(@"%s ... %@",__func__,n);
	//NSLog(@"\t\tconforms is %d",[(NSObject *)n conformsToProtocol:@protocol(CIGLSceneCleanup)]);
	if (deleted)
		return;
	if (n==nil)
		cleanupDelegate = nil;
	else if (n!=nil && [(NSObject *)n conformsToProtocol:@protocol(CIGLSceneCleanup)])
		cleanupDelegate = n;
}
- (id <CIGLSceneCleanup>) cleanupDelegate	{
	return cleanupDelegate;
}


@end

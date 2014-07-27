#import "CIGLScene.h"
#import "AvailabilityMacros.h"
#import "VVBufferPool.h"
#import "GLScene.h"




@implementation CIGLScene


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
	if (self = [super initWithSharedContext:c pixelFormat:p sized:s])	{
		//workingColorSpace = CGColorSpaceCreateDeviceRGB();
		//outputColorSpace = CGColorSpaceCreateDeviceRGB();
		
		workingColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
		outputColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
		
		/*
#if (defined(MAC_OS_X_VERSION_MIN_REQUIRED) && (MAC_OS_X_VERSION_MIN_REQUIRED >= 1060))
		ciContext = [CIContext
			contextWithCGLContext:[context CGLContextObj]
			pixelFormat:[customPixelFormat CGLPixelFormatObj]
			colorSpace:workingColorSpace
			options:[NSDictionary dictionaryWithObjectsAndKeys:
				(id)outputColorSpace, kCIContextOutputColorSpace,
				(id)workingColorSpace, kCIContextWorkingColorSpace, nil]	];
#else
		ciContext = [CIContext
			contextWithCGLContext:[context CGLContextObj]
			pixelFormat:[customPixelFormat CGLPixelFormatObj]
			options:[NSDictionary dictionaryWithObjectsAndKeys:
				(id)outputColorSpace, kCIContextOutputColorSpace,
				(id)workingColorSpace, kCIContextWorkingColorSpace, nil]	];
#endif
			
		if (ciContext == nil)
			goto BAIL;
		[ciContext retain];
		*/
		ciContext = nil;
		cleanupDelegate = nil;
		return self;
	}
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	if (self != nil)
		[self release];
	return nil;
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
		OSSpinLockLock(&renderThreadLock);
		if (renderThreadDeleteArray != nil)
			[renderThreadDeleteArray lockAddObject:ciContext];
		OSSpinLockUnlock(&renderThreadLock);
		[ciContext release];
		ciContext = nil;
	}
	
	[super prepareToBeDeleted];
}

- (void) _renderPrep	{
	[super _renderPrep];
	
	if (deleted)
		return;
	if (context == nil)
		return;
	
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	glDisable(GL_TEXTURE_RECTANGLE_EXT);
	glDisable(GL_TEXTURE_2D);
	glEnable(GL_TEXTURE_2D);
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
	
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	glDisable(GL_TEXTURE_RECTANGLE_EXT);
	glDisable(GL_TEXTURE_2D);
}


- (VVBuffer *) allocAndRenderBufferFromImage:(CIImage *)i	{
	if (i==nil)
		return nil;
	//NSSize			imgSize = CGMAKENSSIZE([i extent].size);
	//[self setSize:imgSize];
	VVBuffer		*returnMe = [_globalVVBufferPool allocBGRTexSized:size];
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
	if (renderThreadDeleteArray == nil)
		renderThreadDeleteArray = [[[NSThread currentThread] threadDictionary] objectForKey:@"deleteArray"];
	OSSpinLockUnlock(&renderThreadLock);
	
	//	make sure the context has been set up/reshaped, attaches the texture/depth buffer to the fbo
	[self _renderPrep];
	
	//	make sure there's a context!
	if (context==nil || ciContext==nil)
		return;
	
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
- (void) renderCIImage:(CIImage *)i inFBO:(GLuint)f colorTex:(GLuint)t	{
	[self renderCIImage:i inFBO:f colorTex:t target:GL_TEXTURE_RECTANGLE_EXT];
}
- (void) renderCIImage:(CIImage *)i inFBO:(GLuint)f colorTex:(GLuint)t target:(GLuint)tt	{
	if (deleted)
		return;
	
	fbo = f;
	tex = t;
	texTarget = tt;
	depth = 0;
	
	OSSpinLockLock(&renderThreadLock);
	if (renderThreadDeleteArray == nil)
		renderThreadDeleteArray = [[[NSThread currentThread] threadDictionary] objectForKey:@"deleteArray"];
	OSSpinLockUnlock(&renderThreadLock);
	
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
	
	fbo = 0;
	tex = 0;
	texTarget = 0;
	depth = 0;
}
- (void) _initialize	{
	//	tell the super to do its thing
	[super _initialize];
	//	the only thing i want to change is the tex env mode
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	
	//glEnable(GL_BLEND);
	glDisable(GL_BLEND);
	//glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
}
- (void) _reshape	{
	//	release the CI context (i'll have to get another one)
	VVRELEASE(ciContext);
	//	tell the super to do its reshape- this takes care of the actual GL stuff
	[super _reshape];
	
	//	CI renders upside down, so i invert the coords now!
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	if (flipped)
		glOrtho(0, size.width, size.height, 0, 1.0, -1.0);
	else
		glOrtho(0, size.width, 0, size.height, 1.0, -1.0);
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
#else
	//NSLog(@"\t\tcreating CIContext for CGLContextObj %p",[context CGLContextObj]);
	ciContext = [CIContext
		contextWithCGLContext:[context CGLContextObj]
		pixelFormat:[customPixelFormat CGLPixelFormatObj]
		options:[NSDictionary dictionaryWithObjectsAndKeys:
			(id)outputColorSpace, kCIContextOutputColorSpace,
			(id)workingColorSpace, kCIContextWorkingColorSpace, nil]	];
#endif
	}
	if (ciContext != nil)
		[ciContext retain];
}


@synthesize workingColorSpace;
@synthesize outputColorSpace;
@synthesize ciContext;
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

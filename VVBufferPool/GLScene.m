#import "GLScene.h"
#if !TARGET_OS_IPHONE
#import <OpenGL/CGLMacro.h>
#endif
#import "RenderThread.h"
#import "VVBufferPool.h"
#if !TARGET_OS_IPHONE
#import <IOKit/IOKitLib.h>
#import <IOKit/IOKitKeys.h>
#endif



OSSpinLock		_glSceneStatLock;
NSMutableArray	*_glGPUVendorArray = nil;
NSMutableArray	*_hwGPUVendorArray = NULL;
BOOL			_integratedGPUFlag = NO;
BOOL			_nvidiaGPUFlag = NO;
BOOL			_hasIntegratedAndDiscreteGPUsFlag = NO;



@implementation GLScene


+ (void) load	{
	_glSceneStatLock = OS_SPINLOCK_INIT;
	_glGPUVendorArray = nil;
	_hwGPUVendorArray = nil;
	_integratedGPUFlag = NO;
}
+ (void) initialize	{
#if !TARGET_OS_IPHONE
	if (_glGPUVendorArray==nil)	{
		[self gpuVendorArray];
	}
#endif
}
#if !TARGET_OS_IPHONE
+ (NSMutableArray *) gpuVendorArray	{
	NSMutableArray		*returnMe = MUTARRAY;
	
	OSSpinLockLock(&_glSceneStatLock);
	//	if there's no global GPU vendor array, create it
	if (_glGPUVendorArray == nil)	{
		_glGPUVendorArray = [[NSMutableArray arrayWithCapacity:0] retain];
		CGDisplayCount			dCnt;
		CGLContextObj			curr_ctx = 0;
		CGDirectDisplayID		dspys[32];
		CGDisplayErr			theErr;
		short					i;
		NSString				*tmpString = nil;
		dCnt = 0;
		
		theErr = CGGetActiveDisplayList(32, dspys, &dCnt);
		if (theErr)
			NSLog(@"\t\terr: %d at CGGetACtiveDisplayList() in %s",theErr,__func__);
		else	{
			//	first we're going to run through the GPU vendors that will be used by GL when we render in the various output screens.  these are the names of the cards that will be used- offline cards aren't going to be visible in this approach.
			if (dCnt==0)
				NSLog(@"\t\terr: CGGetActiveDisplayList() said there are 0 displays in %s",__func__);
			else	{
				BOOL					tmpIntegratedFlag = NO;
				BOOL					tmpNVIDIAFlag = NO;
				for (i = 0; i < dCnt; i++) {
					CGOpenGLDisplayMask		cglDisplayMask; // CGL display mask
					
					cglDisplayMask = CGDisplayIDToOpenGLDisplayMask(dspys[i]);
					// build context and context specific info
					CGLPixelFormatAttribute		attribs[] = {
						kCGLPFADisplayMask,
						//dCaps[i].cglDisplayMask,
						cglDisplayMask,
						(CGLPixelFormatAttribute)0
					};
					CGLPixelFormatObj			pixelFormat = NULL;
					long						numPixelFormats = 0;
					CGLContextObj				cglContext;
					CGLContextObj				cgl_ctx;
					
					curr_ctx = CGLGetCurrentContext (); // get current CGL context
					CGLChoosePixelFormat (attribs, &pixelFormat, (GLint *)&numPixelFormats);
					if (pixelFormat) {
						CGLCreateContext(pixelFormat, NULL, &cglContext);
						CGLDestroyPixelFormat (pixelFormat);
						CGLSetCurrentContext (cglContext);
						if (cglContext) {
							const GLubyte				*strVend;
							
							cgl_ctx = cglContext;
							strVend = glGetString (GL_VENDOR);
							tmpString = [NSString stringWithCString:(const char *)strVend encoding:NSASCIIStringEncoding];
							[_glGPUVendorArray addObject:tmpString];
							//	calculate if this is an integrated GPU setup while i'm running through the vendor array!
							if (!tmpIntegratedFlag && ![tmpString containsString:@"ATI"] && ![tmpString containsString:@"AMD"] && ![tmpString containsString:@"NVIDIA"])
								tmpIntegratedFlag = YES;
							else if ([tmpString containsString:@"NVIDIA"])
								tmpNVIDIAFlag = YES;
							
							CGLDestroyContext (cglContext);
						}
					}
					CGLSetCurrentContext (curr_ctx); // reset current CGL context
					
				}
				//	update the integrated GPU flag!
				_integratedGPUFlag = tmpIntegratedFlag;
				//	update the nvidia GPU flag!
				_nvidiaGPUFlag = tmpNVIDIAFlag;
			}
		}
	}
	if (_hwGPUVendorArray==nil)	{
		_hwGPUVendorArray = [[NSMutableArray arrayWithCapacity:0] retain];
		//	this is the same technique used by "gfxCardStatus" by Cody Krieger to enumerate the available graphics cards
		CFMutableDictionaryRef		deviceDict = IOServiceMatching("IOPCIDevice");
		io_iterator_t				entryIterator;
		kern_return_t				kernErr = kIOReturnSuccess;
		BOOL						integratedGPUExists = NO;
		kernErr = IOServiceGetMatchingServices(kIOMasterPortDefault, deviceDict, &entryIterator);
		if (kernErr!=kIOReturnSuccess)
			NSLog(@"\t\terr %d at IOServiceGetMatchingServices() in %s",kernErr,__func__);
		else	{
			io_registry_entry_t			device = 0;
			while ((device=IOIteratorNext(entryIterator)))	{
				CFMutableDictionaryRef		serviceDict = NULL;
				kernErr = IORegistryEntryCreateCFProperties(device, &serviceDict, kCFAllocatorDefault, kNilOptions);
				if (kernErr!=kIOReturnSuccess)
					NSLog(@"\t\terr %d at IORegistryEntryCreateCFProperties() in %s",kernErr,__func__);
				else	{
					//NSLog(@"\t\tserviceDict is %@",serviceDict);
					NSString			*ioName = [(NSDictionary *)serviceDict objectForKey:@"IOName"];
					if (ioName!=nil && [ioName isEqualToString:@"display"])	{
						const void			*modelData = CFDictionaryGetValue(serviceDict, @"model");
						NSString			*hwName = (modelData==nil) ? nil : [[[NSString alloc] initWithData:modelData encoding:NSASCIIStringEncoding] autorelease];
						if (hwName!=nil)	{
							//NSLog(@"\t\tadding hardware string %@ to hw GPU vendor array",hwName);
							[_hwGPUVendorArray addObject:hwName];
							
							if ([hwName rangeOfString:@"intel" options:NSCaseInsensitiveSearch].location != NSNotFound)
								integratedGPUExists = YES;
						}
					}
					if (serviceDict!=NULL)	{
						CFRelease(serviceDict);
						serviceDict = NULL;
					}
				}
				
				IOObjectRelease(device);
			}
			
			//	if i'm not using an integrated GPU right now, but an integrated GPU exists, set this flag
			if (!_integratedGPUFlag && integratedGPUExists)
				_hasIntegratedAndDiscreteGPUsFlag = YES;
			else
				_hasIntegratedAndDiscreteGPUsFlag = NO;
		}
	}
	
	//	populate the array i'll be returning with the contents of the global GPU vendor array
	if (_glGPUVendorArray != nil)
		[returnMe addObjectsFromArray:_glGPUVendorArray];
	
	BAIL:
	
	OSSpinLockUnlock(&_glSceneStatLock);
	
	return returnMe;
}
+ (BOOL) integratedGPUFlag	{
	BOOL		returnMe = NO;
	
	OSSpinLockLock(&_glSceneStatLock);
	if (_glGPUVendorArray == nil)	{
		OSSpinLockUnlock(&_glSceneStatLock);
		
		[GLScene gpuVendorArray];
		
		OSSpinLockLock(&_glSceneStatLock);
	}
	returnMe = _integratedGPUFlag;
	OSSpinLockUnlock(&_glSceneStatLock);
	return returnMe;
}
+ (BOOL) nvidiaGPUFlag	{
	BOOL		returnMe = NO;
	
	OSSpinLockLock(&_glSceneStatLock);
	if (_glGPUVendorArray == nil)	{
		OSSpinLockUnlock(&_glSceneStatLock);
		
		[GLScene gpuVendorArray];
		
		OSSpinLockLock(&_glSceneStatLock);
	}
	returnMe = _nvidiaGPUFlag;
	OSSpinLockUnlock(&_glSceneStatLock);
	return returnMe;
}
+ (GLuint) glDisplayMaskForAllScreens	{
	CGError					err = kCGErrorSuccess;
	CGDirectDisplayID		dspys[10];
	CGDisplayCount			count = 0;
	GLuint					glDisplayMask = 0;
	err = CGGetActiveDisplayList(10,dspys,&count);
	if (err == kCGErrorSuccess)	{
		int					i;
		for (i=0;i<count;++i)
			glDisplayMask = glDisplayMask | CGDisplayIDToOpenGLDisplayMask(dspys[i]);
	}
	return glDisplayMask;
}
+ (NSOpenGLPixelFormat *) defaultPixelFormat	{
	NSOpenGLPixelFormat					*returnMe = nil;
	GLuint								glDisplayMask = [GLScene glDisplayMaskForAllScreens];
	NSOpenGLPixelFormatAttribute		attrs[] = {
		NSOpenGLPFAAccelerated,
		//NSOpenGLPFAAllRenderers,
		//NSOpenGLPFAScreenMask,CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),
		NSOpenGLPFAScreenMask,glDisplayMask,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAAllowOfflineRenderers,
		//NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
		//NSOpenGLPFAColorSize,24,
		//NSOpenGLPFAAlphaSize,8,
		//NSOpenGLPFADoubleBuffer,
		//NSOpenGLPFABackingStore,
		//NSOpenGLPFADepthSize,16,
		//NSOpenGLPFAMultisample,
		//NSOpenGLPFASampleBuffers,1,
		//NSOpenGLPFASamples,4,
		0};
	returnMe = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (NSOpenGLPixelFormat *) doubleBufferPixelFormat	{
	NSOpenGLPixelFormat					*returnMe = nil;
	GLuint								glDisplayMask = [GLScene glDisplayMaskForAllScreens];
	NSOpenGLPixelFormatAttribute		attrs[] = {
		NSOpenGLPFAAccelerated,
		//NSOpenGLPFAAllRenderers,
		//NSOpenGLPFAScreenMask,CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),
		NSOpenGLPFAScreenMask,glDisplayMask,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAAllowOfflineRenderers,
		//NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
		//NSOpenGLPFAColorSize,24,
		//NSOpenGLPFAAlphaSize,8,
		NSOpenGLPFADoubleBuffer,
		//NSOpenGLPFABackingStore,
		//NSOpenGLPFADepthSize,16,
		//NSOpenGLPFAMultisample,
		//NSOpenGLPFASampleBuffers,1,
		//NSOpenGLPFASamples,4,
		0};
	returnMe = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (NSOpenGLPixelFormat *) defaultQTPixelFormat	{
	NSOpenGLPixelFormat					*returnMe = nil;
	GLuint								glDisplayMask = [GLScene glDisplayMaskForAllScreens];
	NSOpenGLPixelFormatAttribute		attrs[] = {
		NSOpenGLPFAAccelerated,
		//NSOpenGLPFAPixelBuffer,
		//NSOpenGLPFAAllRenderers,
		//NSOpenGLPFAScreenMask,CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),
		NSOpenGLPFAScreenMask,glDisplayMask,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAAllowOfflineRenderers,
		//NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
		//NSOpenGLPFAColorSize,24,
		//NSOpenGLPFAAlphaSize,8,
		//NSOpenGLPFADoubleBuffer,
		//NSOpenGLPFADepthSize,16,
		//NSOpenGLPFAMultisample,
		//NSOpenGLPFASampleBuffers,1,
		//NSOpenGLPFASamples,4,
		0};
	returnMe = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (NSOpenGLPixelFormat *) fsaaPixelFormat	{
	NSOpenGLPixelFormat					*returnMe = nil;
	GLuint								glDisplayMask = [GLScene glDisplayMaskForAllScreens];
	NSOpenGLPixelFormatAttribute		attrs[] = {
		NSOpenGLPFAAccelerated,
		//NSOpenGLPFAAllRenderers,
		//NSOpenGLPFAScreenMask,CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),
		NSOpenGLPFAScreenMask,glDisplayMask,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAAllowOfflineRenderers,
		//NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
		//NSOpenGLPFAColorSize,24,
		//NSOpenGLPFAAlphaSize,8,
		//NSOpenGLPFADoubleBuffer,
		//NSOpenGLPFABackingStore,
		//NSOpenGLPFADepthSize,16,
		NSOpenGLPFAMultisample,
		NSOpenGLPFASampleBuffers,1,
		NSOpenGLPFASamples,4,
		0};
	returnMe = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (NSOpenGLPixelFormat *) doubleBufferFSAAPixelFormat	{
	NSOpenGLPixelFormat					*returnMe = nil;
	GLuint								glDisplayMask = [GLScene glDisplayMaskForAllScreens];
	NSOpenGLPixelFormatAttribute		attrs[] = {
		NSOpenGLPFAAccelerated,
		//NSOpenGLPFAAllRenderers,
		//NSOpenGLPFAScreenMask,CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),
		NSOpenGLPFAScreenMask,glDisplayMask,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAAllowOfflineRenderers,
		//NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
		//NSOpenGLPFAColorSize,24,
		//NSOpenGLPFAAlphaSize,8,
		NSOpenGLPFADoubleBuffer,
		//NSOpenGLPFABackingStore,
		//NSOpenGLPFADepthSize,16,
		NSOpenGLPFAMultisample,
		NSOpenGLPFASampleBuffers,1,
		NSOpenGLPFASamples,4,
		0};
	returnMe = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
#endif


/*===================================================================================*/
#pragma mark --------------------- create/destroy
/*------------------------------------*/


- (id) init	{
	self = [super init];
	if (self!=nil)	{
#if TARGET_OS_IPHONE
		//sharegroup = nil;
		context = nil;
#else
		context = nil;
		sharedContext = nil;
		customPixelFormat = nil;
#endif
		size = VVMAKESIZE(80,60);
		[self generalInit];
	}
	return self;
}
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
	if ((c==nil)||(p==nil)||(s.width<1)||(s.height<1))	{
		NSLog(@"\t\terr: %s - BAIL, %@",__func__,self);
		NSLog(@"\t\terr: %@",c);
		NSLog(@"\t\terr: %f x %f",s.width,s.height);
		[self release];
		return nil;
	}
	self = [super init];
	if (self!=nil)	{
		context = nil;
		sharedContext = c;
		customPixelFormat = [p retain];
		size = s;
		[self generalInit];
	}
	return self;
}
- (id) initWithContext:(NSOpenGLContext *)c	{
	return [self initWithContext:c sharedContext:nil sized:VVMAKESIZE(80,60)];
}
- (id) initWithContext:(NSOpenGLContext *)c sharedContext:(NSOpenGLContext *)sc	{
	return [self initWithContext:c sharedContext:sc sized:VVMAKESIZE(80,60)];
}
- (id) initWithContext:(NSOpenGLContext *)c sized:(VVSIZE)s	{
	return [self initWithContext:c sharedContext:nil sized:s];
}
- (id) initWithContext:(NSOpenGLContext *)c sharedContext:(NSOpenGLContext *)sc sized:(VVSIZE)s	{
	if (c==nil || (s.width<1) || (s.height<1))	{
		NSLog(@"\t\terr: %s - BAIL",__func__);
		NSLog(@"\t\terr: %@",c);
		NSLog(@"\t\terr: %f x %f",s.width,s.height);
		[self release];
		return nil;
	}
	self = [super init];
	if (self!=nil)	{
		context = (c==nil) ? nil : [c retain];
		sharedContext = sc;
		customPixelFormat = nil;
		size = s;
		[self generalInit];
	}
	return self;
}
#else
- (id) initWithSharegroup:(EAGLSharegroup *)g sized:(VVSIZE)s	{
	self = [super init];
	if (self != nil)	{
		NSLog(@"\t\tmaking an  EAGLContext in %s for %@",__func__,self);
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3 sharegroup:g];
		size = s;
		[self generalInit];
	}
	return self;
}
- (id) initWithSharegroup:(EAGLSharegroup *)g	{
	return [self initWithSharegroup:g sized:VVMAKESIZE(80,60)];
}
- (id) initWithContext:(EAGLContext *)c	{
	return [self initWithContext:c sized:VVMAKESIZE(80,60)];
}
- (id) initWithContext:(EAGLContext *)c sized:(VVSIZE)s	{
	self = [super init];
	if (self != nil)	{
		context = [c retain];
		size = s;
		[self generalInit];
	}
	return self;
}
#endif


- (void) generalInit	{
	//NSLog(@"%s",__func__);
	//context = [[NSOpenGLContext alloc] initWithFormat:customPixelFormat shareContext:sharedContext];
	//context = nil;
	//colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGBLinear);
	colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	//colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceAdobeRGB1998);
	//colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	renderTarget = nil;
	renderSelector = nil;
	renderBlockLock = OS_SPINLOCK_INIT;
	renderBlock = nil;
	fbo = 0;
	tex = 0;
	texTarget = 0;
	depth = 0;
	fboMSAA = 0;
	colorMSAA = 0;
	depthMSAA = 0;
	
	flipped = NO;
	projectionMatrixLock = OS_SPINLOCK_INIT;
	//projectionMatrix = GLKMatrix4Identity;
	//projectionMatrixNeedsUpdate = YES;
#if TARGET_OS_IPHONE
	projectionMatrixEffect = nil;
#endif
	initialized = NO;
	needsReshape = YES;
	deleted = NO;
	renderThreadLock = OS_SPINLOCK_INIT;
	renderThreadDeleteArray = nil;
	performClear = YES;
	for (int i=0;i<4;++i)
		clearColor[i] = 0.0;
	clearColorUpdated = YES;
	flushMode = VVGLFlushModeGL;
	swapInterval = 0;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(RTDeleteArrayNotification:) name:RTDeleteArrayDestroyNotification object:nil];
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (!deleted)
		[self prepareToBeDeleted];
#if !TARGET_OS_IPHONE
	sharedContext = nil;
	VVRELEASE(context);	//	should have already been added to render thread's delete array & set to nil in prepareToBeDeleted!
	VVRELEASE(customPixelFormat);
#else
	VVRELEASE(context);
#endif
	if (colorSpace != NULL)	{
		CGColorSpaceRelease(colorSpace);
		colorSpace = NULL;
	}
	OSSpinLockLock(&renderThreadLock);
	renderThreadDeleteArray = nil;
	OSSpinLockUnlock(&renderThreadLock);
	OSSpinLockLock(&renderBlockLock);
	if (renderBlock != nil)	{
		Block_release(renderBlock);
		renderBlock = nil;
	}
	OSSpinLockUnlock(&renderBlockLock);
#if TARGET_OS_IPHONE
	OSSpinLockLock(&projectionMatrixLock);
	VVRELEASE(projectionMatrixEffect);
	OSSpinLockUnlock(&projectionMatrixLock);
#endif
	[super dealloc];
	//NSLog(@"\t\t%s - FINISHED",__func__);
}
- (void) prepareToBeDeleted	{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	renderTarget = nil;
	deleted = YES;
	
	if (context != nil)	{
		OSSpinLockLock(&renderThreadLock);
		if (renderThreadDeleteArray != nil)	{
			[renderThreadDeleteArray lockAddObject:context];
		}
		OSSpinLockUnlock(&renderThreadLock);
		[context release];
		context = nil;
	}
}
- (void) RTDeleteArrayNotification:(NSNotification *)note	{
	//NSLog(@"%s ... %p",__func__,self);
	OSSpinLockLock(&renderThreadLock);
		if (renderThreadDeleteArray != nil)	{
			id			noteObj = [note object];
			if (noteObj!=nil && noteObj==renderThreadDeleteArray)
				renderThreadDeleteArray = nil;
		}
	OSSpinLockUnlock(&renderThreadLock);
}


/*===================================================================================*/
#pragma mark --------------------- render frontend
/*------------------------------------*/


- (VVBuffer *) allocAndRenderABuffer	{
	//NSLog(@"%s",__func__);
#if !TARGET_OS_IPHONE
	VVBuffer		*returnMe = [_globalVVBufferPool allocBGRTexSized:size];
	VVBuffer		*tmpDepth = [_globalVVBufferPool allocDepthSized:size];
	VVBuffer		*tmpFbo = [_globalVVBufferPool allocFBO];
	//NSLog(@"\t\treturnMe is %@, tmpDepth is %@, tmpFbo is %@",returnMe,tmpDepth,tmpFbo);
	if (returnMe!=nil && tmpDepth!=nil && tmpFbo!=nil)
	{
		[self renderInMSAAFBO:0 colorRB:0 depthRB:0 fbo:[tmpFbo name] colorTex:[returnMe name] depthTex:[tmpDepth name]];
	}
	
	VVRELEASE(tmpFbo);
	VVRELEASE(tmpDepth);
	return returnMe;
#else
	VVBuffer		*returnMe = [_globalVVBufferPool allocBGR2DTexSized:size];
	VVBuffer		*tmpFbo = [_globalVVBufferPool allocFBO];
	//NSLog(@"\t\treturnMe is %@, tmpFbo is %@",returnMe,tmpFbo);
	if (returnMe!=nil && tmpFbo!=nil)
	{
		[self renderInMSAAFBO:0 colorRB:0 depthRB:0 fbo:[tmpFbo name] colorTex:[returnMe name] depthTex:0];
	}
	
	VVRELEASE(tmpFbo);
	return returnMe;
#endif
}
- (void) render	{
#if !TARGET_OS_IPHONE
	[self renderInMSAAFBO:0 colorRB:0 depthRB:0 fbo:0 colorTex:0 depthTex:0 target:GL_TEXTURE_RECTANGLE_EXT];
#else
	[self renderInMSAAFBO:0 colorRB:0 depthRB:0 fbo:0 colorTex:0 depthTex:0 target:GL_TEXTURE_2D];
#endif
}
- (void) renderInFBO:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d	{
#if !TARGET_OS_IPHONE
	[self renderInMSAAFBO:0 colorRB:0 depthRB:0 fbo:f colorTex:t depthTex:d target:GL_TEXTURE_RECTANGLE_EXT];
#else
	[self renderInMSAAFBO:0 colorRB:0 depthRB:0 fbo:f colorTex:t depthTex:d target:GL_TEXTURE_2D];
#endif
}
- (void) renderInMSAAFBO:(GLuint)mf colorRB:(GLuint)mc depthRB:(GLuint)md fbo:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d	{
#if !TARGET_OS_IPHONE
	[self renderInMSAAFBO:mf colorRB:mc depthRB:md fbo:f colorTex:t depthTex:d target:GL_TEXTURE_RECTANGLE_EXT];
#else
	[self renderInMSAAFBO:mf colorRB:mc depthRB:md fbo:f colorTex:t depthTex:d target:GL_TEXTURE_2D];
#endif
}
- (void) renderInMSAAFBO:(GLuint)mf colorRB:(GLuint)mc depthRB:(GLuint)md fbo:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d target:(GLuint)tt	{
	if (deleted)
		return;
	
	OSSpinLockLock(&renderThreadLock);
	if (renderThreadDeleteArray == nil)
		renderThreadDeleteArray = [[[NSThread currentThread] threadDictionary] objectForKey:@"deleteArray"];
	OSSpinLockUnlock(&renderThreadLock);
	
	fbo = f;
	tex = t;
	texTarget = tt;
	depth = d;
	fboMSAA = mf;
	colorMSAA = mc;
	depthMSAA = md;
	
	//	make sure the context has been set up/reshaped, attaches the texture/depth buffer to the fbo
	[self _renderPrep];
	
	//	make sure there's a context!
	if (context != nil)	{
		//	if there's a render block, safely retain it, execute it, then release it
		OSSpinLockLock(&renderBlockLock);
		void			(^localRenderBlock)(void) = (renderBlock==nil) ? nil : Block_copy(renderBlock);
		OSSpinLockUnlock(&renderBlockLock);
		if (localRenderBlock != nil)	{
			localRenderBlock();
			Block_release(localRenderBlock);
		}
		//	if there's a render target/selector, call them
		if ((renderTarget!=nil) && (renderSelector!=nil) && ([renderTarget respondsToSelector:renderSelector]))
			[renderTarget performSelector:renderSelector withObject:self];
		
		//	do any cleanup/flush my context
		[self _renderCleanup];
	}
	
	fbo = 0;
	tex = 0;
	texTarget = 0;
	depth = 0;
	fboMSAA = 0;
	colorMSAA = 0;
	depthMSAA = 0;
}
- (void) renderBlackFrameInFBO:(GLuint)f colorTex:(GLuint)t target:(GLuint)tt	{
	if (deleted)
		return;
	
	OSSpinLockLock(&renderThreadLock);
	if (renderThreadDeleteArray == nil)
		renderThreadDeleteArray = [[[NSThread currentThread] threadDictionary] objectForKey:@"deleteArray"];
	OSSpinLockUnlock(&renderThreadLock);
	
	fbo = f;
	tex = t;
	texTarget = tt;
	depth = 0;
	fboMSAA = 0;
	colorMSAA = 0;
	depthMSAA = 0;
	
	//	make sure the context has been set up/reshaped, attaches the texture/depth buffer to the fbo
	[self _renderPrep];
	
#if !TARGET_OS_IPHONE
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	if (cgl_ctx != NULL)	{
		glClearColor(0., 0., 0., 0.);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		clearColorUpdated = YES;
		
		//	do any cleanup/flush my context
		[self _renderCleanup];
	}
#else
	if (context != nil)	{
		[EAGLContext setCurrentContext:context];
		glClearColor(0., 0., 0., 0.);
		glClear(GL_COLOR_BUFFER_BIT);
		clearColorUpdated = YES;
		
		//	do any cleanup/flush my context
		[self _renderCleanup];
	}
#endif
	
	fbo = 0;
	tex = 0;
	texTarget = 0;
	depth = 0;
	fboMSAA = 0;
	colorMSAA = 0;
	depthMSAA = 0;
}
- (void) renderOpaqueBlackFrameInFBO:(GLuint)f colorTex:(GLuint)t target:(GLuint)tt	{
	if (deleted)
		return;
	
	OSSpinLockLock(&renderThreadLock);
	if (renderThreadDeleteArray == nil)
		renderThreadDeleteArray = [[[NSThread currentThread] threadDictionary] objectForKey:@"deleteArray"];
	OSSpinLockUnlock(&renderThreadLock);
	
	fbo = f;
	tex = t;
	texTarget = tt;
	depth = 0;
	fboMSAA = 0;
	colorMSAA = 0;
	depthMSAA = 0;
	
	//	make sure the context has been set up/reshaped, attaches the texture/depth buffer to the fbo
	[self _renderPrep];
	
#if !TARGET_OS_IPHONE
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	if (cgl_ctx != NULL)	{
		//NSLog(@"\t\tsetting clear color to opaque black");
		glClearColor(0., 0., 0., 1.);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		clearColorUpdated = YES;
		
		//	do any cleanup/flush my context
		[self _renderCleanup];
	}
#else
	if (context != nil)	{
		[EAGLContext setCurrentContext:context];
		//NSLog(@"\t\tsetting clear color to opaque black");
		glClearColor(0., 0., 0., 1.);
		glClear(GL_COLOR_BUFFER_BIT);
		clearColorUpdated = YES;
		
		//	do any cleanup/flush my context
		[self _renderCleanup];
	}
#endif
	
	fbo = 0;
	tex = 0;
	texTarget = 0;
	depth = 0;
	fboMSAA = 0;
	colorMSAA = 0;
	depthMSAA = 0;
}
- (void) renderRedFrameInFBO:(GLuint)f colorTex:(GLuint)t target:(GLuint)tt	{
	if (deleted)
		return;
	
	OSSpinLockLock(&renderThreadLock);
	if (renderThreadDeleteArray == nil)
		renderThreadDeleteArray = [[[NSThread currentThread] threadDictionary] objectForKey:@"deleteArray"];
	OSSpinLockUnlock(&renderThreadLock);
	
	fbo = f;
	tex = t;
	texTarget = tt;
	depth = 0;
	fboMSAA = 0;
	colorMSAA = 0;
	depthMSAA = 0;
	
	//	make sure the context has been set up/reshaped, attaches the texture/depth buffer to the fbo
	[self _renderPrep];
	
#if !TARGET_OS_IPHONE
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	if (cgl_ctx != NULL)	{
		glClearColor(1,0,0,1);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		clearColorUpdated = YES;
		
		//	do any cleanup/flush my context
		[self _renderCleanup];
	}
#else
	if (context != nil)	{
		[EAGLContext setCurrentContext:context];
		glClearColor(1,0,0,1);
		glClear(GL_COLOR_BUFFER_BIT);
		clearColorUpdated = YES;
		
		//	do any cleanup/flush my context
		[self _renderCleanup];
	}
#endif
	
	fbo = 0;
	tex = 0;
	texTarget = 0;
	depth = 0;
	fboMSAA = 0;
	colorMSAA = 0;
	depthMSAA = 0;
}


/*===================================================================================*/
#pragma mark --------------------- render backend
/*------------------------------------*/


- (void) _renderPrep	{
	if (deleted)
		return;
	if (context == nil)	{
#if !TARGET_OS_IPHONE
		context = [[NSOpenGLContext alloc] initWithFormat:customPixelFormat shareContext:sharedContext];
#else
		NSLog(@"\t\terr: no context, %s",__func__);
#endif
	}
	if (context == nil)	{
		NSLog(@"\terr: context was nil %s",__func__);
		return;
	}
	
#if !TARGET_OS_IPHONE
	CGLContextObj		cgl_ctx = [context CGLContextObj];
#else
	[EAGLContext setCurrentContext:context];
#endif
	
	//	if the context hasn't been initialized yet, do so now
	if (!initialized)
		[self _initialize];
	//	if the context needs to be reshaped, do so now
	if (needsReshape)
		[self _reshape];
	
	//	if i'm doing multisampling, set it up
	if (fboMSAA > 0)	{
		//	bind the msaa fbo
		glBindFramebuffer(GL_FRAMEBUFFER,fboMSAA);
		//	attach the depth & render buffers (if they exist)
		if (depthMSAA > 0)
			glFramebufferRenderbuffer(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,GL_RENDERBUFFER,depthMSAA);
		if (colorMSAA > 0)
			glFramebufferRenderbuffer(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_RENDERBUFFER,colorMSAA);
		
		//	if the clear color was updated, set it again
		if (clearColorUpdated)	{
			glClearColor(clearColor[0],clearColor[1],clearColor[2],clearColor[3]);
			clearColorUpdated = NO;
		}
		//	glear the texture/renderbuffer
		if (performClear)	{
#if !TARGET_OS_IPHONE
			glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
#else
			glClear(GL_COLOR_BUFFER_BIT);
#endif
		}
	}
	//	else if i'm not doing multisampling, but i'm still rendering
	else if (fbo > 0)	{
		
		//	bind the fbo
		glBindFramebuffer(GL_FRAMEBUFFER,fbo);
#if !TARGET_OS_IPHONE
		//	attach the depth & texture/color buffers if they exist
		if (depth > 0)
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_RECTANGLE_EXT, depth, 0);
		else
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_RECTANGLE_EXT, 0, 0);
#else
		//	attach the depth & texture/color buffers if they exist
		if (depth > 0)
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, depth, 0);
		else
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, 0, 0);
#endif
		//	bind the texture
		if (tex > 0)
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, texTarget, tex, 0);
		else
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, texTarget, 0, 0);
		
		//	if the clear color was updated, set it again
		if (clearColorUpdated)	{
			glClearColor(clearColor[0],clearColor[1],clearColor[2],clearColor[3]);
			clearColorUpdated = NO;
		}
		//	glear the texture/renderbuffer
		if (performClear)
			glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	}
}
- (void) _initialize	{
#if !TARGET_OS_IPHONE
	CGLContextObj		cgl_ctx = [context CGLContextObj];
#endif
	
	//glEnable(GL_TEXTURE_RECTANGLE_EXT);
	//glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glEnable(GL_BLEND);
	//glDisable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

#if !TARGET_OS_IPHONE
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);

	const GLint			swap = swapInterval;
	CGLSetParameter(cgl_ctx,kCGLCPSwapInterval,&swap);
#endif	
	//glHint(GL_CLIP_VOLUME_CLIPPING_HINT_EXT, GL_FASTEST);
	//glHint(GL_PERSPECTIVE_CORRECTION_HINT,GL_NICEST);
	//glDisable(GL_DEPTH_TEST);
	
	//glClearColor(0.0, 0.0, 0.0, 0.0);
	
	initialized = YES;
	clearColorUpdated = YES;
}
- (void) _reshape	{
	//	lock and update a matrix we keep handy for doing projection transforms to an orthogonal view
	OSSpinLockLock(&projectionMatrixLock);
	
	double			left = 0.0;
	double			right = size.width;
	double			top = size.height;
	double			bottom = 0.0;
	double			far = 1.0;
	double			near = -1.0;
	if (flipped)	{
		top = 0.0;
		bottom = size.height;
	}
	projectionMatrix[0] = 2.0/(right-left);
	projectionMatrix[4] = 0.0;
	projectionMatrix[8] = 0.0;
	projectionMatrix[12] = -1.0*(right + left) / (right - left);
	
	projectionMatrix[1] = 0.0;
	projectionMatrix[5] = 2.0/(top-bottom);
	projectionMatrix[9] = 0.0;
	projectionMatrix[13] = -1.0*(top + bottom) / (top - bottom);
	
	projectionMatrix[2] = 0.0;
	projectionMatrix[6] = 0.0;
	projectionMatrix[10] = -2.0 / (far - near);
	projectionMatrix[14] = -1.0*(far + near) / (far - near);
	
	projectionMatrix[3] = 0.0;
	projectionMatrix[7] = 0.0;
	projectionMatrix[11] = 0.0;
	projectionMatrix[15] = 1.0;
	//projectionMatrix = ([self flipped])
	//	?	GLKMatrix4MakeOrtho(0.0, size.width, size.height, 0.0, 1.0, -1.0)
	//	:	GLKMatrix4MakeOrtho(0.0, size.width, 0.0, size.height, 1.0, -1.0);
#if TARGET_OS_IPHONE
	if (projectionMatrixEffect == nil)
		projectionMatrixEffect = [[GLKBaseEffect alloc] init];
	GLKEffectPropertyTransform		*trans = [projectionMatrixEffect transform];
	if (trans != nil)	{
		[trans setModelviewMatrix:GLKMatrix4Identity];
		//[trans setProjectionMatrix:projectionMatrix];
		GLKMatrix4		tmpMatrix = GLKMatrix4Make(
			projectionMatrix[0],projectionMatrix[1],projectionMatrix[2],projectionMatrix[3],
			projectionMatrix[4],projectionMatrix[5],projectionMatrix[6],projectionMatrix[7],
			projectionMatrix[8],projectionMatrix[9],projectionMatrix[10],projectionMatrix[11],
			projectionMatrix[12],projectionMatrix[13],projectionMatrix[14],projectionMatrix[15]);
		[trans setProjectionMatrix:tmpMatrix];
	}
#endif
	//projectionMatrixNeedsUpdate = NO;
	OSSpinLockUnlock(&projectionMatrixLock);
	
	
#if !TARGET_OS_IPHONE
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	if (!flipped)
		glOrtho(0, size.width, 0, size.height, 1.0, -1.0);
	else
		glOrtho(0, size.width, size.height, 0, 1.0, -1.0);
#else
	//	nothing to do here, if we want orthogonal projection in iOS we have to pass the projection matrix to a program before drawing
#endif
	glViewport(0,0,size.width,size.height);
	needsReshape = NO;
}
- (void) _renderCleanup	{
	if (deleted)
		return;
	if (context == nil)	{
		NSLog(@"\terr: context was nil %s",__func__);
		return;
	}
	
#if !TARGET_OS_IPHONE
	CGLContextObj		cgl_ctx = [context CGLContextObj];
#endif
	
	//	flush the buffer before i unbind the framebuffer (thanks, lili!)
	switch (flushMode)	{
		case VVGLFlushModeGL:
			glFlush();
			break;
#if !TARGET_OS_IPHONE
		case VVGLFlushModeCGL:
			CGLFlushDrawable(cgl_ctx);
			break;
		case VVGLFlushModeNS:
			[context flushBuffer];
			break;
		case VVGLFlushModeApple:
			glFlushRenderAPPLE();
			break;
#endif
		case VVGLFlushModeFinish:
			glFinish();
			break;
	}
	
	//	if i'm doing multisampling, i have to blit from the msaa fbo to the normal fbo!
	if (fboMSAA > 0)	{
		//	if there's an fbo, i have to blit from the msaa fbo to the normal fbo!
		if (fbo > 0)	{
			//	bind the non-msaa fbo
			glBindFramebuffer(GL_FRAMEBUFFER,fbo);
			//	attach the texture to it!
			if (tex > 0)
				glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, texTarget, tex, 0);
			//	set up the fbos for a blit!
			glBindFramebuffer(GL_READ_FRAMEBUFFER, fboMSAA);
			glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fbo);
			//	blit it
			glBlitFramebuffer(0,0,size.width,size.height,0,0,size.width,size.height,GL_COLOR_BUFFER_BIT, GL_NEAREST);
			
			//	this flush is definitely necessary here
			glFlush();
			
			//	bind the normal fbo, detach the depth & tex attachments from it
			glBindFramebuffer(GL_FRAMEBUFFER,fbo);
			if (depth > 0)
				glFramebufferTexture2D(GL_FRAMEBUFFER,GL_DEPTH_ATTACHMENT,0,0,0);
			if (tex > 0)
				glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,0,0,0);
		}
		//	bind the msaa fbo, detach the depth & color attachments from it
		glBindFramebuffer(GL_FRAMEBUFFER,fboMSAA);
		if (depthMSAA > 0)
			glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,0,0);
		if (colorMSAA > 0)
			glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,0,0);
		
		//	unbind any framebuffers!
		glBindFramebuffer(GL_FRAMEBUFFER,0);
	}
	//	else i'm not doing multisampling- i may still have to do cleanup for non-msaa rendering!
	else	{
		if (fbo > 0)	{
			if (depth > 0)
				glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, 0, 0, 0);
			if (tex > 0)
				glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, 0, 0, 0);
			
			//	unbind the framebuffer
			glBindFramebuffer(GL_FRAMEBUFFER,0);
		}
	}
}


/*===================================================================================*/
#pragma mark --------------------- key-value
/*------------------------------------*/


#if !TARGET_OS_IPHONE
- (NSOpenGLContext *) sharedContext	{
	return sharedContext;
}
- (NSOpenGLContext *) context	{
	return context;
}
- (CGLContextObj) CGLContextObj	{
	if (context != nil)
		return [context CGLContextObj];
	return NULL;
}
- (NSOpenGLPixelFormat *) customPixelFormat	{
	return customPixelFormat;
}
#else
- (EAGLSharegroup *) sharegroup	{
	return [context sharegroup];
}
- (EAGLContext *) context	{
	return context;
}
#endif
- (CGColorSpaceRef) colorSpace	{
	return colorSpace;
}
- (void) setSize:(VVSIZE)s	{
	//NSLog(@"%s ... %f x %f",__func__,s.width,s.height);
	if ((size.width != s.width) || (size.height != s.height))	{
		size = s;
		needsReshape = YES;
	}
}
- (VVSIZE) size	{
	return size;
}
- (void) setFlipped:(BOOL)n	{
	flipped = n;
}
- (BOOL) flipped	{
	return flipped;
}


- (void) setInitialized:(BOOL)n	{
	initialized = n;
	if (n)
		needsReshape = YES;
}
- (BOOL) initialized	{
	return initialized;
}
@synthesize renderTarget;
@synthesize renderSelector;
- (void) setRenderBlock:(void (^)(void))n	{
	OSSpinLockLock(&renderBlockLock);
	if (renderBlock != nil)	{
		Block_release(renderBlock);
		renderBlock = nil;
	}
	if (n != nil)	{
		renderBlock = Block_copy(n);
	}
	OSSpinLockUnlock(&renderBlockLock);
}
@synthesize flushMode;
@synthesize swapInterval;


- (void) setPerformClear:(BOOL)n	{
	performClear = n;
}
#if !TARGET_OS_IPHONE
- (void) setClearNSColor:(NSColor *)c	{
	if (deleted || c==nil)
		return;
	CGFloat			comps[4];
	[c getComponents:comps];
	for (int i=0;i<4;++i)
		clearColor[i] = comps[i];
	clearColorUpdated = YES;
}
#endif
- (void) setClearColor:(GLfloat *)c	{
	if (deleted || c==nil)
		return;
	for (int i=0;i<4;++i)	{
		clearColor[i] = c[i];
	}
	clearColorUpdated = YES;
}
- (void) setClearColors:(GLfloat)r :(GLfloat)g :(GLfloat)b :(GLfloat)a	{
	clearColor[0]=r;
	clearColor[1]=g;
	clearColor[2]=b;
	clearColor[3]=a;
	clearColorUpdated = YES;
}


@end

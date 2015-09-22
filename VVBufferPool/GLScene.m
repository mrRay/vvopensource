#import "GLScene.h"
#import <OpenGL/CGLMacro.h>
#import "RenderThread.h"
#import "VVBufferPool.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/IOKitKeys.h>




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
	if (_glGPUVendorArray==nil)	{
		[self gpuVendorArray];
	}
}
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


/*===================================================================================*/
#pragma mark --------------------- create/destroy
/*------------------------------------*/


- (id) init	{
	self = [super init];
	if (self!=nil)	{
		context = nil;
		sharedContext = nil;
		customPixelFormat = nil;
		size = NSMakeSize(80,60);
		[self generalInit];
	}
	return self;
}
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
	return [self initWithContext:c sharedContext:nil sized:NSMakeSize(80,60)];
}
- (id) initWithContext:(NSOpenGLContext *)c sharedContext:(NSOpenGLContext *)sc	{
	return [self initWithContext:c sharedContext:sc sized:NSMakeSize(80,60)];
}
- (id) initWithContext:(NSOpenGLContext *)c sized:(NSSize)s	{
	return [self initWithContext:c sharedContext:nil sized:s];
}
- (id) initWithContext:(NSOpenGLContext *)c sharedContext:(NSOpenGLContext *)sc sized:(NSSize)s	{
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
		size = s;
		[self generalInit];
	}
	return self;
}
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
	sharedContext = nil;
	VVRELEASE(context);	//	should have already been added to render thread's delete array & set to nil in prepareToBeDeleted!
	VVRELEASE(customPixelFormat);
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
	VVBuffer		*returnMe = [_globalVVBufferPool allocBGRTexSized:size];
	VVBuffer		*tmpDepth = [_globalVVBufferPool allocDepthSized:size];
	VVBuffer		*tmpFbo = [_globalVVBufferPool allocFBO];
	
	if (returnMe!=nil && tmpDepth!=nil && tmpFbo!=nil)	{
		[self renderInMSAAFBO:0 colorRB:0 depthRB:0 fbo:[tmpFbo name] colorTex:[returnMe name] depthTex:[tmpDepth name]];
	}
	
	VVRELEASE(tmpFbo);
	VVRELEASE(tmpDepth);
	return returnMe;
}
- (void) render	{
	[self renderInMSAAFBO:0 colorRB:0 depthRB:0 fbo:0 colorTex:0 depthTex:0 target:GL_TEXTURE_RECTANGLE_EXT];
}
- (void) renderInFBO:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d	{
	[self renderInMSAAFBO:0 colorRB:0 depthRB:0 fbo:f colorTex:t depthTex:d target:GL_TEXTURE_RECTANGLE_EXT];
}
- (void) renderInMSAAFBO:(GLuint)mf colorRB:(GLuint)mc depthRB:(GLuint)md fbo:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d	{
	[self renderInMSAAFBO:mf colorRB:mc depthRB:md fbo:f colorTex:t depthTex:d target:GL_TEXTURE_RECTANGLE_EXT];
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
	
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	if (cgl_ctx != NULL)	{
		glClearColor(0., 0., 0., 0.);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		clearColorUpdated = YES;
		
		//	make sure there's a context!
		//if (context != nil)	{
			//	don't do anything!
			
			//	do any cleanup/flush my context
			[self _renderCleanup];
		//}
	}
	
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
	
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	if (cgl_ctx != NULL)	{
		//NSLog(@"\t\tsetting clear color to opaque black");
		glClearColor(0., 0., 0., 1.);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		clearColorUpdated = YES;
		
		//	make sure there's a context!
		//if (context != nil)	{
			//	don't do anything!
			
			//	do any cleanup/flush my context
			[self _renderCleanup];
		//}
	}
	
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
	
	CGLContextObj		cgl_ctx = [context CGLContextObj];
		if (cgl_ctx != NULL)	{
		glClearColor(1,0,0,1);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		clearColorUpdated = YES;
		
		//	make sure there's a context!
		//if (context != nil)	{
			//	don't do anything!
			
			//	do any cleanup/flush my context
			[self _renderCleanup];
		//}
	}
	
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
	if (context == nil)
		context = [[NSOpenGLContext alloc] initWithFormat:customPixelFormat shareContext:sharedContext];
	if (context == nil)	{
		NSLog(@"\terr: context was nil %s",__func__);
		return;
	}
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	
	//	if the context hasn't been initialized yet, do so now
	if (!initialized)
		[self _initialize];
	//	if the context needs to be reshaped, do so now
	if (needsReshape)
		[self _reshape];
	
	//	if i'm doing multisampling, set it up
	if (fboMSAA > 0)	{
		//	bind the msaa fbo
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,fboMSAA);
		//	attach the depth & render buffers (if they exist)
		if (depthMSAA > 0)
			glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT,GL_DEPTH_ATTACHMENT_EXT,GL_RENDERBUFFER_EXT,depthMSAA);
		if (colorMSAA > 0)
			glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT,GL_COLOR_ATTACHMENT0_EXT,GL_RENDERBUFFER_EXT,colorMSAA);
		
		//	if the clear color was updated, set it again
		if (clearColorUpdated)	{
			glClearColor(clearColor[0],clearColor[1],clearColor[2],clearColor[3]);
			clearColorUpdated = NO;
		}
		//	glear the texture/renderbuffer
		if (performClear)
			glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	}
	//	else if i'm not doing multisampling, but i'm still rendering
	else if (fbo > 0)	{
		//	bind the fbo
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,fbo);
		//	attach the depth & texture/color buffers if they exist
		if (depth > 0)
			glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_TEXTURE_RECTANGLE_EXT, depth, 0);
		else
			glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_TEXTURE_RECTANGLE_EXT, 0, 0);
		
		if (tex > 0)
			glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, texTarget, tex, 0);
		else
			glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, texTarget, 0, 0);
		
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
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	
	//glEnable(GL_TEXTURE_RECTANGLE_EXT);
	//glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glEnable(GL_BLEND);
	//glDisable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
	
	const GLint			swap = swapInterval;
	CGLSetParameter(cgl_ctx,kCGLCPSwapInterval,&swap);
	
	//glHint(GL_CLIP_VOLUME_CLIPPING_HINT_EXT, GL_FASTEST);
	//glHint(GL_PERSPECTIVE_CORRECTION_HINT,GL_NICEST);
	//glDisable(GL_DEPTH_TEST);
	
	//glClearColor(0.0, 0.0, 0.0, 0.0);
	
	initialized = YES;
	clearColorUpdated = YES;
}
- (void) _reshape	{
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	if (!flipped)
		glOrtho(0, size.width, 0, size.height, 1.0, -1.0);
	else
		glOrtho(0, size.width, size.height, 0, 1.0, -1.0);
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
	
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	
	//	flush the buffer before i unbind the framebuffer (thanks, lili!)
	switch (flushMode)	{
		case VVGLFlushModeGL:
			glFlush();
			break;
		case VVGLFlushModeCGL:
			CGLFlushDrawable(cgl_ctx);
			break;
		case VVGLFlushModeNS:
			[context flushBuffer];
			break;
		case VVGLFlushModeApple:
			glFlushRenderAPPLE();
			break;
		case VVGLFlushModeFinish:
			glFinish();
			break;
	}
	
	//	if i'm doing multisampling, i have to blit from the msaa fbo to the normal fbo!
	if (fboMSAA > 0)	{
		//	if there's an fbo, i have to blit from the msaa fbo to the normal fbo!
		if (fbo > 0)	{
			//	bind the non-msaa fbo
			glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,fbo);
			//	attach the texture to it!
			if (tex > 0)
				glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, texTarget, tex, 0);
			//	set up the fbos for a blit!
			glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, fboMSAA);
			glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, fbo);
			//	blit that sum'bitch
			glBlitFramebufferEXT(0,0,size.width,size.height,0,0,size.width,size.height,GL_COLOR_BUFFER_BIT, GL_NEAREST);
			
			//	this flush is definitely necessary here
			glFlush();
			
			//	bind the normal fbo, detach the depth & tex attachments from it
			glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,fbo);
			if (depth > 0)
				glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT,GL_DEPTH_ATTACHMENT_EXT,0,0,0);
			if (tex > 0)
				glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT,GL_COLOR_ATTACHMENT0_EXT,0,0,0);
		}
		//	bind the msaa fbo, detach the depth & color attachments from it
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,fboMSAA);
		if (depthMSAA > 0)
			glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT,0,0);
		if (colorMSAA > 0)
			glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT,0,0);
		
		//	unbind any framebuffers!
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,0);
	}
	//	else i'm not doing multisampling- i may still have to do cleanup for non-msaa rendering!
	else	{
		if (fbo > 0)	{
			if (depth > 0)
				glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, 0, 0, 0);
			if (tex > 0)
				glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, 0, 0, 0);
			
			//	unbind the framebuffer
			glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,0);
		}
	}
}


/*===================================================================================*/
#pragma mark --------------------- key-value
/*------------------------------------*/


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
- (CGColorSpaceRef) colorSpace	{
	return colorSpace;
}
- (void) setSize:(NSSize)s	{
	//NSLog(@"%s ... %f x %f",__func__,s.width,s.height);
	if ((size.width != s.width) || (size.height != s.height))	{
		size = s;
		needsReshape = YES;
	}
}
- (NSSize) size	{
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
- (void) setClearNSColor:(NSColor *)c	{
	if (deleted || c==nil)
		return;
	CGFloat			comps[4];
	[c getComponents:comps];
	for (int i=0;i<4;++i)
		clearColor[i] = comps[i];
	clearColorUpdated = YES;
}
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

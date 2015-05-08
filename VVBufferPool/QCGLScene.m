#import "QCGLScene.h"
#import "VVQCComposition.h"




BOOL					_QCGLSceneInitialized = NO;
pthread_mutex_t			universalInitializeLock;
BOOL					_safeQCRenderFlag = NO;

NSOpenGLContext			*_globalQCContextGLContext = nil;
NSOpenGLContext			*_globalQCContextSharedContext = nil;
NSOpenGLPixelFormat		*_globalQCContextPixelFormat = nil;
pthread_mutex_t			_globalQCContextLock;




@implementation QCGLScene


+ (void) load	{
	_QCGLSceneInitialized = NO;
	
	pthread_mutexattr_t		attr;
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
	pthread_mutex_init(&_globalQCContextLock, &attr);
	pthread_mutexattr_destroy(&attr);
}
+ (void) initialize	{
	if (_QCGLSceneInitialized)
		return;
	
	_QCGLSceneInitialized = YES;
	pthread_mutexattr_t		attr;
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
	pthread_mutex_init(&universalInitializeLock, &attr);
	pthread_mutexattr_destroy(&attr);
	
	NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
	NSNumber			*tmpNum = (def==nil)?nil:[def objectForKey:@"safeQCRenderFlag"];
	_safeQCRenderFlag = (tmpNum==nil)?YES:[tmpNum boolValue];
}
+ (void) prepCommonQCBackendToRenderOnContext:(NSOpenGLContext *)c pixelFormat:(NSOpenGLPixelFormat *)p	{
	if (c==nil)	{
		NSLog(@"\t\tERR: context nil in %s",__func__);
		return;
	}
	pthread_mutex_lock(&_globalQCContextLock);
	VVRELEASE(_globalQCContextSharedContext);
	_globalQCContextSharedContext = [c retain];
	VVRELEASE(_globalQCContextPixelFormat);
	_globalQCContextPixelFormat = [p retain];
	VVRELEASE(_globalQCContextGLContext);
	_globalQCContextGLContext = [[NSOpenGLContext alloc] initWithFormat:p shareContext:c];
	pthread_mutex_unlock(&_globalQCContextLock);
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
	self = [super initWithSharedContext:c pixelFormat:p sized:s];
	if (self!=nil)	{
	}
	return self;
}
- (id) initCommonBackendSceneSized:(NSSize)n	{
	self = [super init];
	if (self!=nil)	{
		size = n;
		pthread_mutex_lock(&_globalQCContextLock);
		context = (_globalQCContextGLContext==nil) ? nil : [_globalQCContextGLContext retain];
		if (context!=nil)	{
			sharedContext = (_globalQCContextSharedContext==nil) ? nil : [_globalQCContextSharedContext retain];
			customPixelFormat = (_globalQCContextPixelFormat==nil) ? nil : [_globalQCContextPixelFormat retain];
		}
		pthread_mutex_unlock(&_globalQCContextLock);
		if (context==nil)	{
			NSLog(@"\t\terr: couldn't make context, call +[QCGLScene prepCommonQCBackendToRenderOnContext:pixelFormat:] before trying to init a QCGLScene");
			[self release];
			self = nil;
		}
	}
	return self;
}
- (void) generalInit	{
	[super generalInit];
	pthread_mutexattr_t		attr;
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
	pthread_mutex_init(&renderLock, &attr);
	pthread_mutexattr_destroy(&attr);
	//renderThread = nil;
	filePath = nil;
	comp = nil;
	renderer = nil;
	stopwatch = [[VVStopwatch alloc] init];
	//mouseEventDict = [[MutLockDict alloc] init];
	mouseEventArray = [[MutLockArray alloc] init];
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	//pthread_mutex_lock(&renderLock);
		if (!deleted)
			[self prepareToBeDeleted];
		VVRELEASE(renderer);	//	should have already been added to render thread's delete array & set to nil in prepareToBeDeleted!
		VVRELEASE(filePath);
		VVRELEASE(comp);
		VVRELEASE(stopwatch);
		//VVRELEASE(mouseEventDict);
		VVRELEASE(mouseEventArray);
		[super dealloc];
	//pthread_mutex_unlock(&renderLock);
	pthread_mutex_destroy(&renderLock);
	//NSLog(@"\t\t%s - FINISHED",__func__);
}
- (void) prepareToBeDeleted	{
	//	test a simple lock around here to prevent basic actions from colliding with rendering
	//@synchronized (self)	{
		renderTarget = nil;
		deleted = YES;
		
		pthread_mutex_lock(&renderLock);
			if (renderer != nil)	{
				//NSLog(@"\t\tdeleteArray is %p",renderThreadDeleteArray);
				OSSpinLockLock(&renderThreadLock);
				if (renderThreadDeleteArray != nil)
					[renderThreadDeleteArray lockAddObject:renderer];
				OSSpinLockUnlock(&renderThreadLock);
				[renderer release];
				renderer = nil;
			}
		pthread_mutex_lock(&renderLock);
		
		[super prepareToBeDeleted];
	//}
}


- (void) useFile:(NSString *)p	{
	[self useFile:p resetTimer:YES];
}
- (void) useFile:(NSString *)p resetTimer:(BOOL)t	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	//	testing a simple lock around myself to prevent basic actions from colliding with rendering
	pthread_mutex_lock(&renderLock);
		if (!deleted)	{
			//	release the various relevant instances
			VVRELEASE(filePath);
			VVRELEASE(comp);
			//	the renderer must be created, rendered, and released all on the same thread!
			if (renderer != nil)	{
				BOOL			addedToRenderThread = NO;
				OSSpinLockLock(&renderThreadLock);
				if (renderThreadDeleteArray != nil)	{
					addedToRenderThread = YES;
					[renderThreadDeleteArray lockAddObject:renderer];
				}
				OSSpinLockUnlock(&renderThreadLock);
				if (!addedToRenderThread)	{
					if (context!=nil)	{
						CGLLockContext([context CGLContextObj]);
						//NSLog(@"\t\tlocked context %p on thread %p in %s on %p",[context CGLContextObj],[NSThread currentThread],__func__,self);
					}
					
					[renderer release];
					renderer = nil;
					
					if (context!=nil)	{
						//NSLog(@"\t\tunlocking context %p on thread %p in %s on %p",[context CGLContextObj],[NSThread currentThread],__func__,self);
						CGLUnlockContext([context CGLContextObj]);
					}
				}
				else	{
					[renderer release];
					renderer = nil;
				}
			}
			//	retain the passed path
			if (p != nil)
				filePath = [p retain];
			//	if i was actually passed a path, try to make a comp for it
			if (filePath != nil)	{
				comp = [VVQCComposition compositionWithFile:filePath];
				//	if i could make a comp, make sure it doesn't have a live input- bail if it does!
				if (comp != nil)	{
					if ([comp hasLiveInput])	{
						//[QCGLScene displayVidInAlertForFile:filePath];
						[self
							performSelectorOnMainThread:@selector(_actuallyDisplayVidInAlertForFile:)
							withObject:filePath
							waitUntilDone:NO];
						comp = nil;
					}
					else
						[comp retain];
				}
				else
					NSLog(@"\t\terr: composition was nil");
				//	if i'm using a comp, flag me as needing to be re-initialized to create the QCRenderer
				initialized = NO;
			}
		}
	pthread_mutex_unlock(&renderLock);
	if (t)
		[stopwatch start];
}
- (void) _actuallyDisplayVidInAlertForFile:(NSString *)p	{
	VVRunAlertPanel(@"Problem loading composition",
		VVFMTSTRING(@"The QC composition you are trying to load (%@) contains a Video Input patch- please delete this object and then re-load the composition.",p),
		@"I'll do that!",nil,nil);
}


- (void) prepareRendererIfNeeded	{
	if (deleted)
		return;
	pthread_mutex_lock(&renderLock);
		if (context == nil)	{
			pthread_mutex_lock(&_globalQCContextLock);
			context = (_globalQCContextGLContext==nil) ? nil : [_globalQCContextGLContext retain];
			if (context!=nil)	{
				VVRELEASE(sharedContext);
				sharedContext = (_globalQCContextSharedContext==nil) ? nil : [_globalQCContextSharedContext retain];
				VVRELEASE(customPixelFormat);
				customPixelFormat = (_globalQCContextPixelFormat==nil) ? nil : [_globalQCContextPixelFormat retain];
			}
			pthread_mutex_unlock(&_globalQCContextLock);
		}
		if (context == nil)
			NSLog(@"\t\terr: couldn't create GL context %s",__func__);
		else	{
			CGLLockContext([context CGLContextObj]);
			//NSLog(@"\t\tlocked context %p on thread %p in %s on %p",[context CGLContextObj],[NSThread currentThread],__func__,self);
			[self _initialize];
			//NSLog(@"\t\tunlocking context %p on thread %p in %s on %p",[context CGLContextObj],[NSThread currentThread],__func__,self);
			CGLUnlockContext([context CGLContextObj]);
		}
	pthread_mutex_unlock(&renderLock);
}


- (void) renderInMSAAFBO:(GLuint)mf colorRB:(GLuint)mc depthRB:(GLuint)md fbo:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d target:(GLuint)tt	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	
	OSSpinLockLock(&renderThreadLock);
	if (renderThreadDeleteArray == nil)	{
		renderThreadDeleteArray = [[[NSThread currentThread] threadDictionary] objectForKey:@"deleteArray"];
	}
	OSSpinLockUnlock(&renderThreadLock);
	
	BOOL		mouseEventsRequireAdditionalPass = NO;
	
	//	trying a simple lock around myself to prevent basic actions from colliding with rendering
	pthread_mutex_lock(&renderLock);
		if (!deleted)	{
			//	if i'm here and the context is nil, then i'm not sharing a single GL context for everything- i'm expected to create the GL context, which will be used exclusively by this CIContext
			if (context==nil)
				[self _renderPrep];
			
			if (context!=nil)	{
				@try	{
					CGLLockContext([context CGLContextObj]);
					//NSLog(@"\t\tlocked context %p on thread %p in %s on %p",[context CGLContextObj],[NSThread currentThread],__func__,self);
					fbo = f;
					tex = t;
					texTarget = tt;
					depth = d;
					fboMSAA = mf;
					colorMSAA = mc;
					depthMSAA = md;
					
					//	we need to reshape (reset the viewport) every frame if we're using a single GL context to back all QCRenderers...
					needsReshape = YES;
					
					//	make sure the context has been set up/reshaped appropriately
					[self _renderPrep];
					
					NSMutableDictionary		*args = nil;
					
					//	tell the QCRenderer to render
					if (renderer != nil)	{
						//	if there are too many mouse events, throw them all out
						[mouseEventArray wrlock];
						if ([mouseEventArray count]>20)
							[mouseEventArray removeAllObjects];
						if ([mouseEventArray count]>0)	{
							args = [[mouseEventArray objectAtIndex:0] retain];
							[mouseEventArray removeObjectAtIndex:0];
						}
						if ([mouseEventArray count]>0)
							mouseEventsRequireAdditionalPass = YES;
						[mouseEventArray unlock];
						
						/*
						if ([mouseEventArray count]>20)	{
							[mouseEventArray lockRemoveAllObjects];
						}
						//	if there are mouse events that need to be passed on, do so now
						if ([mouseEventArray count]>0)	{
							[mouseEventArray wrlock];
							args = [[mouseEventArray objectAtIndex:0] retain];
							[mouseEventArray removeObjectAtIndex:0];
							[mouseEventArray unlock];
						}
						*/
						
						double		timeSinceStart = [stopwatch timeSinceStart];
						[renderer renderAtTime:(timeSinceStart<=0.0)?1.0/70.0:timeSinceStart arguments:args];
					}
					if (args != nil)
						[args release];
					
					//	do any cleanup/flush
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
				fboMSAA = 0;
				colorMSAA = 0;
				depthMSAA = 0;
				//NSLog(@"\t\tunlocking context %p on thread %p in %s on %p",[context CGLContextObj],[NSThread currentThread],__func__,self);
				CGLUnlockContext([context CGLContextObj]);
			}
		}
	pthread_mutex_unlock(&renderLock);
	
	if (mouseEventsRequireAdditionalPass)	{
		[self renderInMSAAFBO:mf colorRB:mc depthRB:md fbo:f colorTex:t depthTex:d];
	}
	/*
	//	if there are more mouse events i need to process, i need to do additional render passes : (
	if ([mouseEventArray count]>0)	{
		//NSLog(@"\t\tmouseEventArray has %ld items",[mouseEventArray count]);
		//[self renderInFBO:f colorTex:t depthTex:d];
		[self renderInMSAAFBO:mf colorRB:mc depthRB:md fbo:f colorTex:t depthTex:d];
		//[mouseEventArray lockRemoveAllObjects];
	}
	*/
}
- (void) _renderPrep	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	//	now that i've made a renderer, do the render prep associated with its context
	[super _renderPrep];
	
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
}
- (void) _initialize	{
	//NSLog(@"%s",__func__);
	if (context == nil)
		NSLog(@"\t\terr: context nil, %s",__func__);
	//	if there's no renderer, make one
	if (renderer == nil)	{
		//NSLog(@"\t\tshould be making a renderer");
		//	only make the renderer if there's a VVQCComposition (if this doesn't exist, something went wrong)
		if (comp != nil)	{
			QCComposition		*composition = [QCComposition compositionWithFile:filePath];
			if (composition == nil)
				NSLog(@"\terr: QCComposition was nil %s",__func__);
			else	{
				pthread_mutex_lock(&universalInitializeLock);
				renderer = [[QCRenderer alloc]
					initWithCGLContext:[context CGLContextObj]
					pixelFormat:[customPixelFormat CGLPixelFormatObj]
					colorSpace:colorSpace
					composition:composition];
				if (renderer == nil)
					NSLog(@"\t\terr: couldn't create QCRenderer, %s",__func__);
				pthread_mutex_unlock(&universalInitializeLock);
				[stopwatch start];
			}
		}
	}
	
	initialized = YES;
	clearColorUpdated = YES;
}
- (void) _reshape	{
	[super _reshape];
	
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	if (flipped)
		glOrtho(-1.0, 1.0, 1.0, -1.0, 1.0, -1.0);
	else
		glOrtho(-1.0, 1.0, -1.0, 1.0, 1.0, -1.0);
}
- (void) _renderCleanup	{
	
	CGLContextObj		cgl_ctx = [context CGLContextObj];

	[super _renderCleanup];
	
	glPopAttrib();
	glPopClientAttrib();
}


- (NSString *) filePath	{
	return [[filePath retain] autorelease];
}
- (VVQCComposition *) comp	{
	return [[comp retain] autorelease];
}
- (QCRenderer *) renderer	{
	return [[renderer retain] autorelease];
}
- (MutLockArray *) mouseEventArray	{
	return [[mouseEventArray retain] autorelease];
}


- (void) _renderLock	{
	pthread_mutex_lock(&renderLock);
	CGLLockContext([context CGLContextObj]);
	//NSLog(@"\t\tlocked context %p on thread %p in %s on %p",[context CGLContextObj],[NSThread currentThread],__func__,self);
}
- (void) _renderUnlock	{
	//NSLog(@"\t\tunlocking context %p on thread %p in %s on %p",[context CGLContextObj],[NSThread currentThread],__func__,self);
	CGLUnlockContext([context CGLContextObj]);
	pthread_mutex_unlock(&renderLock);
}


@end

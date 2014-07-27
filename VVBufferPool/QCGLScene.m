#import "QCGLScene.h"
#import "VVQCComposition.h"




BOOL					_QCGLSceneInitialized;
pthread_mutex_t			universalInitializeLock;
BOOL					_safeQCRenderFlag;




@implementation QCGLScene


+ (void) load	{
	_QCGLSceneInitialized = NO;
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
	if ((c==nil)||(s.width<1)||(s.height<1))
		goto BAIL;
	if (self = [super initWithSharedContext:c pixelFormat:p sized:s])	{
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
		return self;
	}
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	if (self != nil)
		[self release];
	return nil;
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
				OSSpinLockLock(&renderThreadLock);
				if (renderThreadDeleteArray != nil)
					[renderThreadDeleteArray lockAddObject:renderer];
				OSSpinLockUnlock(&renderThreadLock);
				[renderer release];
				renderer = nil;
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
		if (context == nil)
			context = [[NSOpenGLContext alloc] initWithFormat:customPixelFormat shareContext:sharedContext];
		if (context == nil)
			NSLog(@"\t\terr: couldn't create GL context %s",__func__);
		[self _initialize];
	pthread_mutex_unlock(&renderLock);
}


- (void) renderInMSAAFBO:(GLuint)mf colorRB:(GLuint)mc depthRB:(GLuint)md fbo:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d target:(GLuint)tt	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	
	OSSpinLockLock(&renderThreadLock);
	if (renderThreadDeleteArray == nil)
		renderThreadDeleteArray = [[[NSThread currentThread] threadDictionary] objectForKey:@"deleteArray"];
	OSSpinLockUnlock(&renderThreadLock);
	
	BOOL		mouseEventsRequireAdditionalPass = NO;
	
	//	trying a simple lock around myself to prevent basic actions from colliding with rendering
	pthread_mutex_lock(&renderLock);
		if (!deleted)	{
			fbo = f;
			tex = t;
			texTarget = tt;
			depth = d;
			fboMSAA = mf;
			colorMSAA = mc;
			depthMSAA = md;
			
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
				
				if (_safeQCRenderFlag)	{
					@try	{
						[renderer renderAtTime:(timeSinceStart<=0.0)?1.0/70.0:timeSinceStart arguments:args];
					}
					@catch (NSException *err)	{
						NSLog(@"\t\tsafe QC rendering enabled, caught exception %@ with filePath %@",err,filePath);
					}
					@finally	{
					
					}
				}
				else	{
					[renderer renderAtTime:(timeSinceStart<=0.0)?1.0/70.0:timeSinceStart arguments:args];
				}
			}
			if (args != nil)
				[args release];
			
			//	do any cleanup/flush
			[self _renderCleanup];
			
			fbo = 0;
			tex = 0;
			texTarget = 0;
			depth = 0;
			fboMSAA = 0;
			colorMSAA = 0;
			depthMSAA = 0;
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
}
- (void) _initialize	{
	//NSLog(@"%s",__func__);
	if (context == nil)
		context = [[NSOpenGLContext alloc] initWithFormat:customPixelFormat shareContext:sharedContext];
	if (context == nil)
		NSLog(@"\t\terr: couldn't create GL context, %s",__func__);
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


- (NSString *) filePath	{
	return filePath;
}
- (VVQCComposition *) comp	{
	return comp;
}
- (QCRenderer *) renderer	{
	return renderer;
}
- (MutLockArray *) mouseEventArray	{
	return mouseEventArray;
}


- (void) _renderLock	{
	pthread_mutex_lock(&renderLock);
}
- (void) _renderUnlock	{
	pthread_mutex_unlock(&renderLock);
}


@end

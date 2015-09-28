#import "VVBufferCopier.h"




id _globalVVBufferCopier = nil;




@implementation VVBufferCopier


+ (void) createGlobalVVBufferCopierWithSharedContext:(NSOpenGLContext *)c	{
	if (c == nil)
		return;
	if (_globalVVBufferCopier != nil)	{
		[_globalVVBufferCopier prepareToBeDeleted];
		[_globalVVBufferCopier release];
		_globalVVBufferCopier = nil;
	}
	_globalVVBufferCopier = [[VVBufferCopier alloc] initWithSharedContext:c sized:NSMakeSize(4,3)];
	[_globalVVBufferCopier setCopyToIOSurface:NO];
}
+ (VVBufferCopier *) globalBufferCopier	{
	return _globalVVBufferCopier;
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
- (void) generalInit	{
	[super generalInit];
	pthread_mutexattr_t		attr;
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
	pthread_mutex_init(&renderLock, &attr);
	pthread_mutexattr_destroy(&attr);
	copyToIOSurface = NO;
	copyPixFormat = VVBufferPF_BGRA;
	copyAndResize = NO;
	copySize = NSMakeSize(320,240);
	copySizingMode = VVSizingModeStretch;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	//pthread_mutex_lock(&renderLock);
		if (!deleted)
			[self prepareToBeDeleted];
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
		/*
		pthread_mutex_lock(&renderLock);
			
			if (renderer != nil)	{
				if (renderThreadDeleteArray != nil)
					[renderThreadDeleteArray lockAddObject:renderer];
				[renderer release];
				renderer = nil;
			}
		pthread_mutex_lock(&renderLock);
		*/
		[super prepareToBeDeleted];
	//}
}



- (void) render	{
	NSLog(@"\t\tERRR: should be overridden! %s",__func__);
}
- (void) renderInFBO:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d	{
	NSLog(@"\t\tERRR: should be overridden! %s",__func__);
}
- (void) renderInMSAAFBO:(GLuint)mf colorRB:(GLuint)mc depthRB:(GLuint)md fbo:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d	{
	NSLog(@"\t\tERRR: should be overridden! %s",__func__);
}
- (void) renderInMSAAFBO:(GLuint)mf colorRB:(GLuint)mc depthRB:(GLuint)md fbo:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d target:(GLuint)tt	{
	NSLog(@"\t\tERRR: should be overridden! %s",__func__);
}
- (void) _initialize	{
	[super _initialize];
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glHint(GL_CLIP_VOLUME_CLIPPING_HINT_EXT, GL_FASTEST);
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_BLEND);
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
}
- (VVBuffer *) copyToNewBuffer:(VVBuffer *)n	{
	//NSLog(@"%s ... %ld",__func__,[n name]);
	if (deleted || n==nil)
		return nil;
	
	if (copyAndResize)
		[self setSize:copySize];
	else
		[self setSize:[n srcRect].size];
	
	pthread_mutex_lock(&renderLock);
	
	VVBuffer				*tmpFBO = [_globalVVBufferPool allocFBO];
	VVBuffer				*tmpTex = [n retain];
	VVBuffer				*returnMe = nil;
	
	returnMe = (copyToIOSurface) ? [_globalVVBufferPool allocBufferForTexBackedIOSurfaceSized:size] : [_globalVVBufferPool allocBGRTexSized:size];
	
	if (tmpFBO!=nil && returnMe!=nil)	{
		fbo = (tmpFBO==nil)?0:[tmpFBO name];
		tex = (returnMe==nil)?0:[returnMe name];
		texTarget = [returnMe target];
		depth = 0;
		fboMSAA = 0;
		colorMSAA = 0;
		depthMSAA = 0;
		
		//	make sure the context has been set up/reshaped, attaches the texture/depth buffer to the fbo
		[self _renderPrep];
		//	make sure there's a context!
		if (context!=nil)	{
			CGLContextObj		cgl_ctx = [context CGLContextObj];
			glEnable([tmpTex target]);
			//GLDRAWTEXQUADMACRO([tmpTex name],[tmpTex target],[tmpTex flipped],[tmpTex glReadySrcRect],NSMakeRect(0,0,size.width,size.height));
			NSRect				dstRect = [VVSizingTool rectThatFitsRect:[tmpTex glReadySrcRect] inRect:NSMakeRect(0,0,size.width,size.height) sizingMode:[self copySizingMode]];
			GLDRAWTEXQUADMACRO([tmpTex name],[tmpTex target],[tmpTex flipped],[tmpTex glReadySrcRect],dstRect);
			glDisable([tmpTex target]);
			//NSLog(@"\t\tjust copied %ld to %ld",[n name],[returnMe name]);
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
	else
		NSLog(@"\t\terr: required resource nil in %s",__func__);
	
	VVRELEASE(tmpFBO);
	VVRELEASE(tmpTex);
	
	pthread_mutex_unlock(&renderLock);
	
	return returnMe;
}
- (BOOL) copyThisBuffer:(VVBuffer *)a toThisBuffer:(VVBuffer *)b	{
	if (deleted || a==nil || b==nil)
		return NO;
	NSSize			aSize = [a size];
	NSSize			bSize = [b size];
	if ((!NSEqualSizes(aSize,bSize) && !copyAndResize) || (copyAndResize && !NSEqualSizes(bSize,copySize)))
		return NO;
	[a retain];
	[b retain];
	
	BOOL			returnMe = NO;
	[self setSize:(copyAndResize) ? copySize : bSize];
	
	pthread_mutex_lock(&renderLock);
	
	VVBuffer				*tmpFBO = [_globalVVBufferPool allocFBO];
	
	if (tmpFBO!=nil)	{
		fbo = (tmpFBO==nil)?0:[tmpFBO name];
		tex = (b==nil)?0:[b name];
		texTarget = [b target];
		depth = 0;
		fboMSAA = 0;
		colorMSAA = 0;
		depthMSAA = 0;
		
		//	make sure the context has been set up/reshaped, attaches the texture/depth buffer to the fbo
		[self _renderPrep];
		//	make sure there's a context!
		if (context!=nil)	{
			CGLContextObj		cgl_ctx = [context CGLContextObj];
			glEnable([a target]);
			GLDRAWTEXQUADMACRO([a name],[a target],[a flipped],[a glReadySrcRect],NSMakeRect(0,0,bSize.width,bSize.height));
			glDisable([a target]);
			//NSLog(@"\t\tjust copied %ld to %ld",[n name],[returnMe name]);
			//	do any cleanup/flush my context
			[self _renderCleanup];
			returnMe = YES;
		}
	}
	else
		NSLog(@"\t\terr: required resource nil in %s",__func__);
	
	VVRELEASE(tmpFBO);
	
	pthread_mutex_unlock(&renderLock);
	
	[a release];
	[b release];
	
	return returnMe;
}
- (void) sizeVariantCopyThisBuffer:(VVBuffer *)a toThisBuffer:(VVBuffer *)b	{
	//NSLog(@"%s ... %@ -> %@",__func__,a,b);
	if (deleted || a==nil || b==nil)
		return;
	//NSSize			aSize = [a size];
	NSSize			bSize = [b size];
	[a retain];
	[b retain];
	
	//BOOL			returnMe = NO;
	[self setSize:bSize];
	
	pthread_mutex_lock(&renderLock);
	
	VVBuffer				*tmpFBO = [_globalVVBufferPool allocFBO];
	
	if (tmpFBO!=nil)	{
		fbo = (tmpFBO==nil)?0:[tmpFBO name];
		tex = (b==nil)?0:[b name];
		texTarget = [b target];
		depth = 0;
		fboMSAA = 0;
		colorMSAA = 0;
		depthMSAA = 0;
		
		//	make sure the context has been set up/reshaped, attaches the texture/depth buffer to the fbo
		[self _renderPrep];
		//	make sure there's a context!
		if (context!=nil)	{
			CGLContextObj		cgl_ctx = [context CGLContextObj];
			glEnable([a target]);
			//GLDRAWTEXQUADMACRO([a name],[a target],[a flipped],[a glReadySrcRect],NSMakeRect(0,0,bSize.width,bSize.height));
			NSRect				dstRect = [VVSizingTool rectThatFitsRect:[a glReadySrcRect] inRect:NSMakeRect(0,0,bSize.width,bSize.height) sizingMode:[self copySizingMode]];
			GLDRAWTEXQUADMACRO([a name],[a target],[a flipped],[a glReadySrcRect],dstRect);
			glDisable([a target]);
			//NSLog(@"\t\tjust copied %ld to %ld",[n name],[returnMe name]);
			//	do any cleanup/flush my context
			[self _renderCleanup];
			//returnMe = YES;
		}
	}
	else
		NSLog(@"\t\terr: required resource nil in %s",__func__);
	
	VVRELEASE(tmpFBO);
	
	pthread_mutex_unlock(&renderLock);
	
	[a release];
	[b release];
}
- (void) ignoreSizeCopyThisBuffer:(VVBuffer *)a toThisBuffer:(VVBuffer *)b	{
	//NSLog(@"%s ... %@ -> %@",__func__,a,b);
	if (deleted || a==nil || b==nil)
		return;
	//NSSize			aSize = [a size];
	NSSize			bSize = [b size];
	[a retain];
	[b retain];
	
	//BOOL			returnMe = NO;
	[self setSize:bSize];
	
	pthread_mutex_lock(&renderLock);
	
	VVBuffer				*tmpFBO = [_globalVVBufferPool allocFBO];
	
	if (tmpFBO!=nil)	{
		fbo = (tmpFBO==nil)?0:[tmpFBO name];
		tex = (b==nil)?0:[b name];
		texTarget = [b target];
		depth = 0;
		fboMSAA = 0;
		colorMSAA = 0;
		depthMSAA = 0;
		
		//	make sure the context has been set up/reshaped, attaches the texture/depth buffer to the fbo
		[self _renderPrep];
		//	make sure there's a context!
		if (context!=nil)	{
			CGLContextObj		cgl_ctx = [context CGLContextObj];
			glEnable([a target]);
			//GLDRAWTEXQUADMACRO([a name],[a target],[a flipped],[a glReadySrcRect],NSMakeRect(0,0,aSize.width,aSize.height));
			NSRect				dstRect = [VVSizingTool rectThatFitsRect:[a srcRect] inRect:NSMakeRect(0,0,bSize.width,bSize.height) sizingMode:VVSizingModeCopy];
			GLDRAWTEXQUADMACRO([a name],[a target],[a flipped],[a glReadySrcRect],dstRect);
			glDisable([a target]);
			//NSLog(@"\t\tjust copied %d to %d",[a name],[b name]);
			//glColor4f(1,0,0,1);
			//GLDRAWRECT(NSMakeRect(0,0,100,100));
			//	do any cleanup/flush my context
			[self _renderCleanup];
			//returnMe = YES;
		}
	}
	else
		NSLog(@"\t\terr: required resource nil in %s",__func__);
	
	VVRELEASE(tmpFBO);
	
	pthread_mutex_unlock(&renderLock);
	
	[a release];
	[b release];
}
- (void) copyBlackFrameToThisBuffer:(VVBuffer *)b	{
	if (deleted || b==nil)
		return;
	VVBufferType	bType = [b descriptorPtr]->type;
	if (bType!=VVBufferType_RB && bType!=VVBufferType_Tex)
		return;
	[b retain];
	NSSize			bSize = [b size];
	[self setSize:bSize];
	
	pthread_mutex_lock(&renderLock);
		VVBuffer				*tmpFBO = [_globalVVBufferPool allocFBO];
		if (tmpFBO!=nil)	{
			[self renderBlackFrameInFBO:[tmpFBO name] colorTex:[b name] target:[b target]];
		}
		else
			NSLog(@"\t\terr: required resource nil in %s",__func__);
		
		VVRELEASE(tmpFBO);
	pthread_mutex_unlock(&renderLock);
	
	[b release];
}
- (void) copyOpaqueBlackFrameToThisBuffer:(VVBuffer *)b	{
	if (deleted || b==nil)
		return;
	VVBufferType	bType = [b descriptorPtr]->type;
	if (bType!=VVBufferType_RB && bType!=VVBufferType_Tex)
		return;
	[b retain];
	NSSize			bSize = [b size];
	[self setSize:bSize];
	
	pthread_mutex_lock(&renderLock);
		VVBuffer				*tmpFBO = [_globalVVBufferPool allocFBO];
		if (tmpFBO!=nil)	{
			[self renderOpaqueBlackFrameInFBO:[tmpFBO name] colorTex:[b name] target:[b target]];
		}
		else
			NSLog(@"\t\terr: required resource nil in %s",__func__);
		
		VVRELEASE(tmpFBO);
	pthread_mutex_unlock(&renderLock);
	
	[b release];
}
- (void) copyRedFrameToThisBuffer:(VVBuffer *)b	{
	if (deleted || b==nil)
		return;
	VVBufferType	bType = [b descriptorPtr]->type;
	if (bType!=VVBufferType_RB && bType!=VVBufferType_Tex)
		return;
	[b retain];
	NSSize			bSize = [b size];
	[self setSize:bSize];
	
	pthread_mutex_lock(&renderLock);
		VVBuffer				*tmpFBO = [_globalVVBufferPool allocFBO];
		if (tmpFBO!=nil)	{
			[self renderRedFrameInFBO:[tmpFBO name] colorTex:[b name] target:[b target]];
		}
		else
			NSLog(@"\t\terr: required resource nil in %s",__func__);
		
		VVRELEASE(tmpFBO);
	pthread_mutex_unlock(&renderLock);
	
	[b release];
}


@synthesize copyToIOSurface;
@synthesize copyPixFormat;
@synthesize copyAndResize;
@synthesize copySize;
@synthesize copySizingMode;


@end

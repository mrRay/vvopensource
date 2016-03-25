#import "VVBufferCopier.h"




id _globalVVBufferCopier = nil;




@implementation VVBufferCopier


#if !TARGET_OS_IPHONE
+ (void) createGlobalVVBufferCopierWithSharedContext:(NSOpenGLContext *)c	{
	if (c == nil)
		return;
	if (_globalVVBufferCopier != nil)	{
		[_globalVVBufferCopier prepareToBeDeleted];
		[_globalVVBufferCopier release];
		_globalVVBufferCopier = nil;
	}
	_globalVVBufferCopier = [[VVBufferCopier alloc] initWithSharedContext:c sized:VVMAKESIZE(4,3)];
	[_globalVVBufferCopier setCopyToIOSurface:NO];
}
#else
+ (void) createGlobalVVBufferCopierWithSharegroup:(EAGLSharegroup *)s	{
	if (s==nil)
		return;
	if (_globalVVBufferCopier != nil)	{
		[_globalVVBufferCopier prepareToBeDeleted];
		[_globalVVBufferCopier release];
		_globalVVBufferCopier = nil;
	}
	_globalVVBufferCopier = [[VVBufferCopier alloc] initWithSharegroup:s sized:VVMAKESIZE(4,3)];
	[_globalVVBufferCopier setCopyToIOSurface:NO];
}
#endif
+ (VVBufferCopier *) globalBufferCopier	{
	return _globalVVBufferCopier;
}
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
	[super generalInit];
	pthread_mutexattr_t		attr;
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
	pthread_mutex_init(&renderLock, &attr);
	pthread_mutexattr_destroy(&attr);
	copyToIOSurface = NO;
	copyPixFormat = VVBufferPF_BGRA;
	copyAndResize = NO;
	copySize = VVMAKESIZE(320,240);
	copySizingMode = VVSizingModeStretch;
	geoXYVBO = nil;
	geoSTVBO = nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	//pthread_mutex_lock(&renderLock);
		if (!deleted)
			[self prepareToBeDeleted];
		[super dealloc];
	//pthread_mutex_unlock(&renderLock);
	pthread_mutex_destroy(&renderLock);
	VVRELEASE(geoXYVBO);
	VVRELEASE(geoSTVBO);
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
	
#if !TARGET_OS_IPHONE
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glHint(GL_CLIP_VOLUME_CLIPPING_HINT_EXT, GL_FASTEST);
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
#endif
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_BLEND);
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
	
#if !TARGET_OS_IPHONE
	returnMe = (copyToIOSurface) ? [_globalVVBufferPool allocBufferForTexBackedIOSurfaceSized:size] : [_globalVVBufferPool allocBGRTexSized:size];
#else
	returnMe = [_globalVVBufferPool allocBGR2DTexSized:size];
#endif
	
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
#if !TARGET_OS_IPHONE
			CGLContextObj		cgl_ctx = [context CGLContextObj];
			VVRECT				bounds = VVMAKERECT(0,0,size.width,size.height);
			VVRECT				glSrcRect = [tmpTex glReadySrcRect];
			VVRECT				dstRect = [VVSizingTool rectThatFitsRect:glSrcRect inRect:bounds sizingMode:[self copySizingMode]];
			glEnable([tmpTex target]);
			//GLDRAWTEXQUADMACRO([tmpTex name],[tmpTex target],[tmpTex flipped],[tmpTex glReadySrcRect],VVMAKERECT(0,0,size.width,size.height));
			GLDRAWTEXQUADMACRO([tmpTex name],[tmpTex target],[tmpTex flipped],glSrcRect,dstRect);
			glDisable([tmpTex target]);
#else
			VVRECT				bounds = VVMAKERECT(0,0,size.width,size.height);
			VVRECT				glSrcRect = [tmpTex glReadySrcRect];
			VVRECT				dstRect = [VVSizingTool rectThatFitsRect:glSrcRect inRect:bounds sizingMode:[self copySizingMode]];
			
			//	populate my built-in projection effect with the texture data i want to draw
			GLKEffectPropertyTexture	*effectTex = [projectionMatrixEffect texture2d0];
			[effectTex setEnabled:YES];
			[effectTex setName:[tmpTex name]];
			//	tell the built-in projection effect to prepare to draw
			[projectionMatrixEffect prepareToDraw];
			
			GLfloat				geoCoords[] = {
				VVMINX(dstRect), VVMINY(dstRect),
				VVMAXX(dstRect), VVMINY(dstRect),
				VVMINX(dstRect), VVMAXY(dstRect),
				VVMAXX(dstRect), VVMAXY(dstRect)
			};
			GLfloat				texCoords[] = {
				VVMINX(glSrcRect), VVMINY(glSrcRect),
				VVMAXX(glSrcRect), VVMINY(glSrcRect),
				VVMINX(glSrcRect), VVMAXY(glSrcRect),
				VVMAXX(glSrcRect), VVMAXY(glSrcRect)
			};
			//	if i don't have a VBO containing geometry for a quad, make one now
			if (geoXYVBO == nil)	{
				geoXYVBO = [_globalVVBufferPool
					allocVBOInCurrentContextWithBytes:geoCoords
					byteSize:8*sizeof(GLfloat)
					usage:GL_DYNAMIC_DRAW];
			}
			if (geoSTVBO == nil)	{
				geoSTVBO = [_globalVVBufferPool
					allocVBOInCurrentContextWithBytes:texCoords
					byteSize:8*sizeof(GLfloat)
					usage:GL_DYNAMIC_DRAW];
			}
			
			glBindBuffer(GL_ARRAY_BUFFER, [geoXYVBO name]);
			glBufferData(GL_ARRAY_BUFFER, 8*(sizeof(GLfloat)), geoCoords, GL_DYNAMIC_DRAW);
			glEnableVertexAttribArray(GLKVertexAttribPosition);
			glVertexAttribPointer(GLKVertexAttribPosition,
				2,
				GL_FLOAT,
				GL_FALSE,
				0,
				NULL);
			
			glBindBuffer(GL_ARRAY_BUFFER, [geoSTVBO name]);
			glBufferData(GL_ARRAY_BUFFER, 8*(sizeof(GLfloat)), texCoords, GL_DYNAMIC_DRAW);
			glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
			glVertexAttribPointer(GLKVertexAttribTexCoord0,
				2,
				GL_FLOAT,
				GL_FALSE,
				0,
				NULL);
			glBindBuffer(GL_ARRAY_BUFFER, 0);
			//	draw!
			glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
#endif
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
	VVSIZE			aSize = [a size];
	VVSIZE			bSize = [b size];
	if ((!VVEQUALSIZES(aSize,bSize) && !copyAndResize) || (copyAndResize && !VVEQUALSIZES(bSize,copySize)))
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
#if !TARGET_OS_IPHONE
			CGLContextObj		cgl_ctx = [context CGLContextObj];
			glEnable([a target]);
			GLDRAWTEXQUADMACRO([a name],[a target],[a flipped],[a glReadySrcRect],VVMAKERECT(0,0,bSize.width,bSize.height));
			glDisable([a target]);
#else
			//VVRECT				bounds = VVMAKERECT(0,0,size.width,size.height);
			VVRECT				glSrcRect = [a glReadySrcRect];
			VVRECT				dstRect = VVMAKERECT(0,0,bSize.width,bSize.height);
			
			//	populate my built-in projection effect with the texture data i want to draw
			GLKEffectPropertyTexture	*effectTex = [projectionMatrixEffect texture2d0];
			[effectTex setEnabled:YES];
			[effectTex setName:[a name]];
			//	tell the built-in projection effect to prepare to draw
			[projectionMatrixEffect prepareToDraw];
			
			//	these are the geometry & texture coord values we want to pass to the program
			GLfloat			geoCoords[] = {
				VVMINX(dstRect), VVMINY(dstRect),
				VVMAXX(dstRect), VVMINY(dstRect),
				VVMINX(dstRect), VVMAXY(dstRect),
				VVMAXX(dstRect), VVMAXY(dstRect)
			};
			GLfloat				texCoords[] = {
				VVMINX(glSrcRect), VVMINY(glSrcRect),
				VVMAXX(glSrcRect), VVMINY(glSrcRect),
				VVMINX(glSrcRect), VVMAXY(glSrcRect),
				VVMAXX(glSrcRect), VVMAXY(glSrcRect)
			};
			//	if i don't have a VBO containing geometry for a quad, make one now
			if (geoXYVBO == nil)	{
				geoXYVBO = [_globalVVBufferPool
					allocVBOInCurrentContextWithBytes:geoCoords
					byteSize:8*sizeof(GLfloat)
					usage:GL_DYNAMIC_DRAW];
			}
			if (geoSTVBO == nil)	{
				geoSTVBO = [_globalVVBufferPool
					allocVBOInCurrentContextWithBytes:texCoords
					byteSize:8*sizeof(GLfloat)
					usage:GL_DYNAMIC_DRAW];
			}
			
			glBindBuffer(GL_ARRAY_BUFFER, [geoXYVBO name]);
			glBufferData(GL_ARRAY_BUFFER, 8*(sizeof(GLfloat)), geoCoords, GL_DYNAMIC_DRAW);
			glEnableVertexAttribArray(GLKVertexAttribPosition);
			glVertexAttribPointer(GLKVertexAttribPosition,
				2,
				GL_FLOAT,
				GL_FALSE,
				0,
				NULL);
			
			glBindBuffer(GL_ARRAY_BUFFER, [geoSTVBO name]);
			glBufferData(GL_ARRAY_BUFFER, 8*(sizeof(GLfloat)), texCoords, GL_DYNAMIC_DRAW);
			glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
			glVertexAttribPointer(GLKVertexAttribTexCoord0,
				2,
				GL_FLOAT,
				GL_FALSE,
				0,
				NULL);
			glBindBuffer(GL_ARRAY_BUFFER, 0);
			//	draw!
			glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
#endif
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
	//VVSIZE			aSize = [a size];
	VVSIZE			bSize = [b size];
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
#if !TARGET_OS_IPHONE
			CGLContextObj		cgl_ctx = [context CGLContextObj];
			glEnable([a target]);
			VVRECT				dstRect = [VVSizingTool rectThatFitsRect:[a glReadySrcRect] inRect:VVMAKERECT(0,0,bSize.width,bSize.height) sizingMode:[self copySizingMode]];
			GLDRAWTEXQUADMACRO([a name],[a target],[a flipped],[a glReadySrcRect],dstRect);
			glDisable([a target]);
#else
			//VVRECT				bounds = VVMAKERECT(0,0,size.width,size.height);
			VVRECT				glSrcRect = [a glReadySrcRect];
			VVRECT				dstRect = [VVSizingTool rectThatFitsRect:[a glReadySrcRect] inRect:VVMAKERECT(0,0,bSize.width,bSize.height) sizingMode:[self copySizingMode]];
			//	populate my built-in projection effect with the texture data i want to draw
			GLKEffectPropertyTexture	*effectTex = [projectionMatrixEffect texture2d0];
			[effectTex setEnabled:YES];
			[effectTex setName:[a name]];
			//	tell the built-in projection effect to prepare to draw
			[projectionMatrixEffect prepareToDraw];
			
			GLfloat			geoCoords[] = {
				VVMINX(dstRect), VVMINY(dstRect),
				VVMAXX(dstRect), VVMINY(dstRect),
				VVMINX(dstRect), VVMAXY(dstRect),
				VVMAXX(dstRect), VVMAXY(dstRect)
			};
			GLfloat				texCoords[] = {
				VVMINX(glSrcRect), VVMINY(glSrcRect),
				VVMAXX(glSrcRect), VVMINY(glSrcRect),
				VVMINX(glSrcRect), VVMAXY(glSrcRect),
				VVMAXX(glSrcRect), VVMAXY(glSrcRect)
			};
			//	if i don't have a VBO containing geometry for a quad, make one now
			if (geoXYVBO == nil)	{
				geoXYVBO = [_globalVVBufferPool
					allocVBOInCurrentContextWithBytes:geoCoords
					byteSize:8*sizeof(GLfloat)
					usage:GL_DYNAMIC_DRAW];
			}
			if (geoSTVBO == nil)	{
				geoSTVBO = [_globalVVBufferPool
					allocVBOInCurrentContextWithBytes:texCoords
					byteSize:8*sizeof(GLfloat)
					usage:GL_DYNAMIC_DRAW];
			}
			
			glBindBuffer(GL_ARRAY_BUFFER, [geoXYVBO name]);
			glBufferData(GL_ARRAY_BUFFER, 8*(sizeof(GLfloat)), geoCoords, GL_DYNAMIC_DRAW);
			glEnableVertexAttribArray(GLKVertexAttribPosition);
			glVertexAttribPointer(GLKVertexAttribPosition,
				2,
				GL_FLOAT,
				GL_FALSE,
				0,
				NULL);
			
			glBindBuffer(GL_ARRAY_BUFFER, [geoSTVBO name]);
			glBufferData(GL_ARRAY_BUFFER, 8*(sizeof(GLfloat)), texCoords, GL_DYNAMIC_DRAW);
			glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
			glVertexAttribPointer(GLKVertexAttribTexCoord0,
				2,
				GL_FLOAT,
				GL_FALSE,
				0,
				NULL);
			glBindBuffer(GL_ARRAY_BUFFER, 0);
			//	draw!
			glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
#endif
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
	//VVSIZE			aSize = [a size];
	VVSIZE			bSize = [b size];
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
#if !TARGET_OS_IPHONE
			CGLContextObj		cgl_ctx = [context CGLContextObj];
			glEnable([a target]);
			//GLDRAWTEXQUADMACRO([a name],[a target],[a flipped],[a glReadySrcRect],VVMAKERECT(0,0,aSize.width,aSize.height));
			VVRECT				dstRect = [VVSizingTool rectThatFitsRect:[a srcRect] inRect:VVMAKERECT(0,0,bSize.width,bSize.height) sizingMode:VVSizingModeCopy];
			dstRect.origin = NSMakePoint(0,0);
			GLDRAWTEXQUADMACRO([a name],[a target],[a flipped],[a glReadySrcRect],dstRect);
			glDisable([a target]);
#else
			//VVRECT				bounds = VVMAKERECT(0,0,size.width,size.height);
			VVRECT				glSrcRect = [a glReadySrcRect];
			VVRECT				dstRect = [VVSizingTool rectThatFitsRect:[a srcRect] inRect:VVMAKERECT(0,0,bSize.width,bSize.height) sizingMode:VVSizingModeCopy];
			dstRect.origin = VVMAKEPOINT(0,0);
			//	populate my built-in projection effect with the texture data i want to draw
			GLKEffectPropertyTexture	*effectTex = [projectionMatrixEffect texture2d0];
			[effectTex setEnabled:YES];
			[effectTex setName:[a name]];
			//	tell the built-in projection effect to prepare to draw
			[projectionMatrixEffect prepareToDraw];
			
			GLfloat			geoCoords[] = {
				VVMINX(dstRect), VVMINY(dstRect),
				VVMAXX(dstRect), VVMINY(dstRect),
				VVMINX(dstRect), VVMAXY(dstRect),
				VVMAXX(dstRect), VVMAXY(dstRect)
			};
			GLfloat				texCoords[] = {
				VVMINX(glSrcRect), VVMINY(glSrcRect),
				VVMAXX(glSrcRect), VVMINY(glSrcRect),
				VVMINX(glSrcRect), VVMAXY(glSrcRect),
				VVMAXX(glSrcRect), VVMAXY(glSrcRect)
			};
			//	if i don't have a VBO containing geometry for a quad, make one now
			if (geoXYVBO == nil)	{
				geoXYVBO = [_globalVVBufferPool
					allocVBOInCurrentContextWithBytes:geoCoords
					byteSize:8*sizeof(GLfloat)
					usage:GL_DYNAMIC_DRAW];
			}
			if (geoSTVBO == nil)	{
				geoSTVBO = [_globalVVBufferPool
					allocVBOInCurrentContextWithBytes:texCoords
					byteSize:8*sizeof(GLfloat)
					usage:GL_DYNAMIC_DRAW];
			}
			
			glBindBuffer(GL_ARRAY_BUFFER, [geoXYVBO name]);
			glBufferData(GL_ARRAY_BUFFER, 8*(sizeof(GLfloat)), geoCoords, GL_DYNAMIC_DRAW);
			glEnableVertexAttribArray(GLKVertexAttribPosition);
			glVertexAttribPointer(GLKVertexAttribPosition,
				2,
				GL_FLOAT,
				GL_FALSE,
				0,
				NULL);
			
			glBindBuffer(GL_ARRAY_BUFFER, [geoSTVBO name]);
			glBufferData(GL_ARRAY_BUFFER, 8*(sizeof(GLfloat)), texCoords, GL_DYNAMIC_DRAW);
			glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
			glVertexAttribPointer(GLKVertexAttribTexCoord0,
				2,
				GL_FLOAT,
				GL_FALSE,
				0,
				NULL);
			glBindBuffer(GL_ARRAY_BUFFER, 0);
			//	draw!
			glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
#endif
			//NSLog(@"\t\tjust copied %d to %d",[a name],[b name]);
			//glColor4f(1,0,0,1);
			//GLDRAWRECT(VVMAKERECT(0,0,100,100));
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
	VVSIZE			bSize = [b size];
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
	VVSIZE			bSize = [b size];
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
	VVSIZE			bSize = [b size];
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

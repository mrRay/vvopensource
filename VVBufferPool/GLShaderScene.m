#import "GLShaderScene.h"
#if !TARGET_OS_IPHONE
#import <OpenGL/CGLMacro.h>
#endif
//#import "Macros.h"




@implementation GLShaderScene


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
- (id) initWithContext:(NSOpenGLContext *)c	{
	return [self initWithContext:c sized:VVMAKESIZE(80,60)];
}
- (id) initWithContext:(NSOpenGLContext *)c sharedContext:(NSOpenGLContext *)sc	{
	return [self initWithContext:c sharedContext:sc sized:VVMAKESIZE(80,60)];
}
- (id) initWithContext:(NSOpenGLContext *)c sized:(VVSIZE)s	{
	return [self initWithContext:c sharedContext:nil sized:s];
}
- (id) initWithContext:(NSOpenGLContext *)c sharedContext:(NSOpenGLContext *)sc sized:(VVSIZE)s	{
	self = [super initWithContext:c sharedContext:sc sized:s];
	if (self!=nil)	{
	}
	return self;
}
#else
#endif
- (void) generalInit	{
	[super generalInit];
#if !TARGET_OS_IPHONE
	if (context==nil)
		context = [[NSOpenGLContext alloc] initWithFormat:customPixelFormat shareContext:sharedContext];
#endif
	pthread_mutexattr_t		attr;
	pthread_mutexattr_init(&attr);
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
	pthread_mutex_init(&renderLock, &attr);
	pthread_mutexattr_destroy(&attr);
	vertexShaderUpdated = NO;
	fragmentShaderUpdated = NO;
	program = 0;
	vertexShader = 0;
	fragmentShader = 0;
	vertexShaderString = nil;
	fragmentShaderString = nil;
	//samplerTarget = nil;
	//samplerSelector = nil;
	errDictLock = OS_SPINLOCK_INIT;
	errDict = nil;
}
- (void) prepareToBeDeleted	{
	pthread_mutex_lock(&renderLock);
		if (context != nil)	{
#if !TARGET_OS_IPHONE
			CGLContextObj		cgl_ctx = [context CGLContextObj];
#else
			[EAGLContext setCurrentContext:[self context]];
#endif
			if (program > 0)
				glDeleteProgram(program);
			if (vertexShader > 0)
				glDeleteShader(vertexShader);
			if (fragmentShader > 0)
				glDeleteShader(fragmentShader);
		}
		VVRELEASE(vertexShaderString);
		VVRELEASE(fragmentShaderString);
	pthread_mutex_unlock(&renderLock);
	
	[super prepareToBeDeleted];
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	pthread_mutex_destroy(&renderLock);
	if (errDict != nil)	{
		OSSpinLockLock(&errDictLock);
		VVRELEASE(errDict);
		OSSpinLockUnlock(&errDictLock);
	}
	[super dealloc];
}


- (void) setVertexShaderString:(NSString *)n	{
	if (n == nil)	{
		NSLog(@"************ ERR: tried to set nil string! %s",__func__);
		NSException		*exc = [NSException
			exceptionWithName:@"NilVSStringException"
			reason:@"tried to set a nil vertex shader"
			userInfo:nil];
		[exc raise];
		return;
	}
	pthread_mutex_lock(&renderLock);
		VVRELEASE(vertexShaderString);
		if (n != nil)
			vertexShaderString = [n retain];
		vertexShaderUpdated = YES;
	pthread_mutex_unlock(&renderLock);
}
- (NSString *) vertexShaderString	{
	NSString		*returnMe = nil;
	pthread_mutex_lock(&renderLock);
	returnMe = (vertexShaderString==nil) ? nil : [[vertexShaderString retain] autorelease];
	pthread_mutex_unlock(&renderLock);
	return returnMe;
}
- (void) setFragmentShaderString:(NSString *)n	{
	if (n == nil)	{
		NSLog(@"************ ERR: tried to set nil string! %s",__func__);
		NSException		*exc = [NSException
			exceptionWithName:@"NilFSStringException"
			reason:@"tried to set a nil frag shader"
			userInfo:nil];
		[exc raise];
		return;
	}
	pthread_mutex_lock(&renderLock);
		VVRELEASE(fragmentShaderString);
		if (n != nil)
			fragmentShaderString = [n retain];
		fragmentShaderUpdated = YES;
	pthread_mutex_unlock(&renderLock);
}
- (NSString *) fragmentShaderString	{
	NSString		*returnMe = nil;
	pthread_mutex_lock(&renderLock);
	returnMe = (fragmentShaderString==nil) ? nil : [[fragmentShaderString retain] autorelease];
	pthread_mutex_unlock(&renderLock);
	return returnMe;
}


- (void) renderInMSAAFBO:(GLuint)mf colorRB:(GLuint)mc depthRB:(GLuint)md fbo:(GLuint)f colorTex:(GLuint)t depthTex:(GLuint)d target:(GLuint)tt	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	pthread_mutex_lock(&renderLock);
	[super renderInMSAAFBO:mf colorRB:mc depthRB:md fbo:f colorTex:t depthTex:d target:tt];
	pthread_mutex_unlock(&renderLock);
}


- (void) _initialize	{
	[super _initialize];
#if !TARGET_OS_IPHONE
	CGLContextObj		cgl_ctx = [context CGLContextObj];
#endif
	glDisable(GL_BLEND);
}
- (void) _renderPrep	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	
	//	have the super do its render prep (initializes, reshapes, binds fbo/depth/textures, clears
	[super _renderPrep];
	
	if (context == nil)
		return;
	
#if !TARGET_OS_IPHONE
	CGLContextObj		cgl_ctx = [context CGLContextObj];
#endif
	
	if (vertexShaderUpdated || fragmentShaderUpdated)	{
		glUseProgram(0);
		
		if (program > 0)	{
			glDeleteProgram(program);
			program = 0;
		}
		if (vertexShader > 0)	{
			glDeleteShader(vertexShader);
			vertexShader = 0;
		}
		if (fragmentShader > 0)	{
			glDeleteShader(fragmentShader);
			fragmentShader = 0;
		}
		
		OSSpinLockLock(&errDictLock);
		VVRELEASE(errDict);
		OSSpinLockUnlock(&errDictLock);
		
		BOOL			encounteredError = NO;
		if (vertexShaderString != nil)	{
			vertexShader = glCreateShader(GL_VERTEX_SHADER);
			const char		*shaderSrc = [vertexShaderString UTF8String];
			glShaderSource(vertexShader,1,&shaderSrc,NULL);
			glCompileShader(vertexShader);
			GLint			compiled;
			glGetShaderiv(vertexShader,GL_COMPILE_STATUS,&compiled);
			if (!compiled)	{
				GLint			length;
				GLchar			*log;
				glGetShaderiv(vertexShader,GL_INFO_LOG_LENGTH,&length);
				log = (GLchar *) malloc(sizeof(GLchar)*length);
				glGetShaderInfoLog(vertexShader,length,&length,log);
				NSLog(@"\t\terror compiling vertex shader:");
				NSLog(@"\t\terr: %s",log);
				//NSLog(@"\t\tshader was %s",shaderSrc);
				encounteredError = YES;
				
				OSSpinLockLock(&errDictLock);
				if (errDict == nil)
					errDict = [MUTDICT retain];
				[errDict setObject:[NSString stringWithUTF8String:log] forKey:@"vertErrLog"];
				[errDict setObject:vertexShaderString forKey:@"vertSrc"];
				OSSpinLockUnlock(&errDictLock);
				
				free(log);
				glDeleteShader(vertexShader);
				vertexShader = 0;
			}
		}
		if (fragmentShaderString != nil)	{
			fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
			const char		*shaderSrc = [fragmentShaderString UTF8String];
			glShaderSource(fragmentShader,1,&shaderSrc,NULL);
			glCompileShader(fragmentShader);
			GLint			compiled;
			glGetShaderiv(fragmentShader,GL_COMPILE_STATUS,&compiled);
			if (!compiled)	{
				GLint			length;
				GLchar			*log;
				glGetShaderiv(fragmentShader,GL_INFO_LOG_LENGTH,&length);
				log = (GLchar *) malloc(sizeof(GLchar)*length);
				glGetShaderInfoLog(fragmentShader,length,&length,log);
				NSLog(@"\t\terror compiling fragment shader:");
				NSLog(@"\t\terr: %s",log);
				//NSLog(@"\t\tshader was %s",shaderSrc);
				
				OSSpinLockLock(&errDictLock);
				if (errDict == nil)
					errDict = [MUTDICT retain];
				[errDict setObject:[NSString stringWithUTF8String:log] forKey:@"fragErrLog"];
				[errDict setObject:fragmentShaderString forKey:@"fragSrc"];
				OSSpinLockUnlock(&errDictLock);
				
				free(log);
				glDeleteShader(fragmentShader);
				fragmentShader = 0;
			}
		}
		if (((vertexShader>0) || (fragmentShader>0)) && !encounteredError)	{
			program = glCreateProgram();
			if (vertexShader > 0)
				glAttachShader(program,vertexShader);
			if (fragmentShader > 0)
				glAttachShader(program,fragmentShader);
			glLinkProgram(program);
			
			GLint			linked;
			glGetProgramiv(program,GL_LINK_STATUS,&linked);
			if (!linked)	{
				GLint			length;
				GLchar			*log;
				glGetProgramiv(program,GL_INFO_LOG_LENGTH,&length);
				log = (GLchar *)malloc(sizeof(GLchar)*length);
				glGetProgramInfoLog(program,length,&length,log);
				NSLog(@"\t\terror linking program:");
				NSLog(@"\t\terr: %s",log);
				//NSLog(@"\t\tvert shader is:");
				//NSLog(@"%@",vertexShaderString);
				//NSLog(@"\t\tfrag shader is:");
				//NSLog(@"%@",fragmentShaderString);
				
				OSSpinLockLock(&errDictLock);
				if (errDict == nil)
					errDict = [MUTDICT retain];
				[errDict setObject:[NSString stringWithUTF8String:log] forKey:@"linkErrLog"];
				OSSpinLockUnlock(&errDictLock);
				
				free(log);
				glDeleteProgram(program);
				program = 0;
			}
		}
		
		vertexShaderUpdated = NO;
		fragmentShaderUpdated = NO;
	}
	
	//if ((samplerTarget!=nil)&&(samplerSelector!=nil)&&([samplerTarget respondsToSelector:samplerSelector]))
	//	[samplerTarget performSelector:samplerSelector withObject:self];
	
	if (program > 0)
		glUseProgram(program);
}


- (void) _renderCleanup	{
	if (deleted || context==nil)
		return;
	if (program > 0)	{
#if !TARGET_OS_IPHONE
		CGLContextObj		cgl_ctx = [context CGLContextObj];
		glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
#endif
		glBindTexture(GL_TEXTURE_2D, 0);
		glUseProgram(0);
	}
	[super _renderCleanup];
	
}


@synthesize vertexShaderUpdated;
@synthesize fragmentShaderUpdated;
@synthesize program;
@synthesize vertexShader;
@synthesize fragmentShader;
//@synthesize samplerTarget;
//@synthesize samplerSelector;
@synthesize vertexShaderString;
@synthesize fragmentShaderString;


@end

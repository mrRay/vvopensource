#import "VVBufferGLKView.h"
#import "GLScene.h"
#import "VVSizingTool.h"
//#import "Canvas.h"
#import "VVBufferPool.h"




@implementation VVBufferGLKView


- (id) initWithFrame:(VVRECT)f	{
	if (self = [super initWithFrame:f])	{
		pthread_mutexattr_t		attr;
		pthread_mutexattr_init(&attr);
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
		pthread_mutex_init(&renderLock, &attr);
		pthread_mutexattr_destroy(&attr);
		initialized = NO;
		orthoEffect = nil;
		sizingMode = VVSizingModeFit;
		retainDraw = NO;
		retainDrawLock = OS_SPINLOCK_INIT;
		retainDrawBuffer = nil;
		onlyDrawNewStuff = NO;
		onlyDrawNewStuffLock = OS_SPINLOCK_INIT;
		onlyDrawNewStuffTimestamp.tv_sec = 0;
		onlyDrawNewStuffTimestamp.tv_usec = 0;
		geoXYVBO = nil;
		geoSTVBO = nil;
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (id) initWithCoder:(NSCoder *)c	{
	if (self = [super initWithCoder:c])	{
		pthread_mutexattr_t		attr;
		pthread_mutexattr_init(&attr);
		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
		pthread_mutex_init(&renderLock, &attr);
		pthread_mutexattr_destroy(&attr);
		initialized = NO;
		orthoEffect = nil;
		sizingMode = VVSizingModeFit;
		retainDraw = NO;
		retainDrawLock = OS_SPINLOCK_INIT;
		retainDrawBuffer = nil;
		onlyDrawNewStuff = NO;
		onlyDrawNewStuffLock = OS_SPINLOCK_INIT;
		onlyDrawNewStuffTimestamp.tv_sec = 0;
		onlyDrawNewStuffTimestamp.tv_usec = 0;
		geoXYVBO = nil;
		geoSTVBO = nil;
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (void) awakeFromNib	{
	NSLog(@"%s",__func__);
	initialized = NO;
}
- (void) dealloc	{
	pthread_mutex_lock(&renderLock);
	VVRELEASE(orthoEffect);
	pthread_mutex_unlock(&renderLock);
	
	pthread_mutex_destroy(&renderLock);
	OSSpinLockLock(&retainDrawLock);
	VVRELEASE(retainDrawBuffer);
	OSSpinLockUnlock(&retainDrawLock);
	VVRELEASE(geoXYVBO);
	VVRELEASE(geoSTVBO);
	[super dealloc];
}
- (void) redraw	{
	VVBuffer		*lastBuffer = nil;
	OSSpinLockLock(&retainDrawLock);
	lastBuffer = (!retainDraw || retainDrawBuffer==nil) ? nil : [retainDrawBuffer retain];
	OSSpinLockUnlock(&retainDrawLock);
	
	[self drawBuffer:lastBuffer];
	
	[lastBuffer release];
	lastBuffer = nil;
}
- (void) drawRect:(VVRECT)r	{
	//NSLog(@"%s",__func__);
	//NSRectLog(@"\t\trect is",r);
	//glClearColor(1., 0., 0., 1.);
	//glClear(GL_COLOR_BUFFER_BIT);
	
	OSSpinLockLock(&retainDrawLock);
	VVBuffer			*bufferToDraw = (retainDrawBuffer==nil) ? nil : [retainDrawBuffer retain];
	OSSpinLockUnlock(&retainDrawLock);
	
	if (bufferToDraw != nil)	{
		VVRECT				bounds = VVMAKERECT(0,0,[self drawableWidth],[self drawableHeight]);
		//NSRectLog(@"\t\tbounds are",bounds);
		VVRECT				bufferSrcRect = [bufferToDraw srcRect];
		VVRECT				bufferFrame = [VVSizingTool rectThatFitsRect:bufferSrcRect inRect:bounds sizingMode:VVSizingModeFit];
		//	calculate an orthogonal projection matrix
		GLKMatrix4			newOrthoMat = ([bufferToDraw flipped])
			?	GLKMatrix4MakeOrtho(bounds.origin.x, bounds.origin.x+bounds.size.width, bounds.origin.y+bounds.size.height, bounds.origin.y, 1.0, -1.0)
			:	GLKMatrix4MakeOrtho(bounds.origin.x, bounds.origin.x+bounds.size.width, bounds.origin.y, bounds.origin.y+bounds.size.height, 1.0, -1.0);
		//	make the effect (if necessary)
		if (orthoEffect == nil)
			orthoEffect = [[GLKBaseEffect alloc] init];
		glPushGroupMarkerEXT(0, "Working with orthoEffect");
		[orthoEffect setUseConstantColor:GL_TRUE];
		[orthoEffect setConstantColor:GLKVector4Make(1., 1., 1., 1.)];
		
		//	populate the effect with the new orthogonal projection matrix
		GLKEffectPropertyTransform		*trans = [orthoEffect transform];
		if (trans == nil)
			NSLog(@"\t\terr: transform nil in %s",__func__);
		else	{
			[trans setModelviewMatrix:GLKMatrix4Identity];
			[trans setProjectionMatrix:newOrthoMat];
		}
		
		//	populate the effect with the geometry data i wish to draw
		GLKEffectPropertyTexture	*tmpTex = [orthoEffect texture2d0];
		[tmpTex setEnabled:YES];
		[tmpTex setName:[bufferToDraw name]];
		
		//	apply the effect
		[orthoEffect prepareToDraw];
		glPopGroupMarkerEXT();
		
		
		
		
		
		GLfloat			geoCoords[] = {
			VVMINX(bufferFrame), VVMINY(bufferFrame),
			VVMAXX(bufferFrame), VVMINY(bufferFrame),
			VVMINX(bufferFrame), VVMAXY(bufferFrame),
			VVMAXX(bufferFrame), VVMAXY(bufferFrame)
		};
		GLfloat				texCoords[] = {
			0.,0.,
			1.,0.,
			0.,1.,
			1.,1.
		};
		glPushGroupMarkerEXT(0, "allocating VBOs");
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
		glPopGroupMarkerEXT();
		
		glPushGroupMarkerEXT(0, "Drawing VBOs");
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
		glPopGroupMarkerEXT();
		/*
		//glBindTexture([bufferToDraw target],[bufferToDraw name]);
		
		//	i need to pass vertex & texture info to the effect (which is just a program/set of shaders)
		glEnableVertexAttribArray(GLKVertexAttribPosition);
		glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
		
		
		GLfloat				geo[] = {
			VVMINX(bufferFrame), VVMINY(bufferFrame),
			VVMAXX(bufferFrame), VVMINY(bufferFrame),
			VVMINX(bufferFrame), VVMAXY(bufferFrame),
			VVMAXX(bufferFrame), VVMAXY(bufferFrame)
		};
		GLfloat				tex[] = {
			0.,0.,
			1.,0.,
			0.,1.,
			1.,1.};
		glVertexAttribPointer(GLKVertexAttribPosition,
			2,
			GL_FLOAT,
			GL_FALSE,
			0,
			geo);
		glVertexAttribPointer(GLKVertexAttribTexCoord0,
			2,
			GL_FLOAT,
			GL_FALSE,
			0,
			tex);
		*/
		
		
		
		/*
		VVBufferQuad		tmpQuad;
		VVBufferQuadPopulate(&tmpQuad, bufferFrame, VVMAKERECT(0,0,1,1));
		VVBufferQuad		*tmpQuadPtr = &tmpQuad;
		//	pass the vertex & texture coords to GL
		glVertexAttribPointer(GLKVertexAttribPosition,
			2,
			GL_FLOAT,
			GL_FALSE,
			sizeof(VVBufferVertex),
			tmpQuadPtr);
		glVertexAttribPointer(GLKVertexAttribTexCoord0,
			2,
			GL_FLOAT,
			GL_FALSE,
			sizeof(VVBufferVertex),
			tmpQuadPtr + 3);
		*/
		//	draw!
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		
	}
	
	//glFlush();
	
	if (bufferToDraw!=nil)
		glBindTexture([bufferToDraw target], 0);
	
	//[super drawRect:r];
	VVRELEASE(bufferToDraw);
	
	
	//	if i'm not retaining the draw buffer, nil it out now
	OSSpinLockLock(&retainDrawLock);
	if (!retainDraw)
		VVRELEASE(retainDrawBuffer);
	OSSpinLockUnlock(&retainDrawLock);
}

- (void) drawBuffer:(VVBuffer *)b	{
	//NSLog(@"%s ... %@",__func__,b);
	BOOL			bail = NO;
	pthread_mutex_lock(&renderLock);
	if (!initialized)	{
		if (_globalVVBufferPool != nil)	{
			/*
			[self setContext:[_globalVVBufferPool context]];
			initialized = YES;
			*/
			EAGLSharegroup		*sg = [_globalVVBufferPool sharegroup];
			if (sg != nil)	{
				[self setSharegroup:sg];
				initialized = YES;
			}
			
		}
		if (!initialized)	{
			bail = YES;
			NSLog(@"\t\tbailing, view not initialized, %s",__func__);
		}
	}
	pthread_mutex_unlock(&renderLock);
	if (bail)
		return;
	
	OSSpinLockLock(&retainDrawLock);
	//if (retainDraw)	{
	//	if (retainDrawBuffer != b)	{
			VVRELEASE(retainDrawBuffer);
			retainDrawBuffer = [b retain];
	//	}
	//}
	OSSpinLockUnlock(&retainDrawLock);
	
	OSSpinLockLock(&onlyDrawNewStuffLock);
	if (onlyDrawNewStuff)	{
		struct timeval		bufferTimestamp;
		[b getContentTimestamp:&bufferTimestamp];
		if (onlyDrawNewStuffTimestamp.tv_sec==bufferTimestamp.tv_sec && onlyDrawNewStuffTimestamp.tv_usec==bufferTimestamp.tv_usec)
			bail = YES;
	}
	OSSpinLockUnlock(&onlyDrawNewStuffLock);
	if (bail)
		return;
	
	
	BOOL			shouldDisplay = NO;
	pthread_mutex_lock(&renderLock);
	if (initialized)
		shouldDisplay = YES;
	pthread_mutex_unlock(&renderLock);
	
	//	tell the super to display- this actually draws stuff in the view
	if (shouldDisplay)	{
		[self display];
	}
	
	
}
- (void) setSharegroup:(EAGLSharegroup *)g	{
	if (g == nil)
		return;
	pthread_mutex_lock(&renderLock);
		NSLog(@"\t\tmaking an  EAGLContext in %s for %@",__func__,self);
		EAGLContext		*newContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3 sharegroup:g];
		[self setContext:newContext];
		[newContext release];
		//long				swap = 1;
		//[[self context] setValues:(GLint *)&swap forParameter:NSOpenGLCPSwapInterval];
		initialized = YES;
	pthread_mutex_unlock(&renderLock);
}
- (void) setContext:(EAGLContext *)c	{
	//NSLog(@"%s",__func__);
	pthread_mutex_lock(&renderLock);
		[super setContext:c];
		initialized = NO;
	pthread_mutex_unlock(&renderLock);
	//needsReshape = YES;
}


@synthesize initialized;
@synthesize sizingMode;
- (void) setOnlyDrawNewStuff:(BOOL)n	{
	OSSpinLockLock(&onlyDrawNewStuffLock);
	onlyDrawNewStuff = n;
	onlyDrawNewStuffTimestamp.tv_sec = 0;
	onlyDrawNewStuffTimestamp.tv_usec = 0;
	OSSpinLockUnlock(&onlyDrawNewStuffLock);
}
- (void) setRetainDraw:(BOOL)n	{
	OSSpinLockLock(&retainDrawLock);
	retainDraw = n;
	OSSpinLockUnlock(&retainDrawLock);
}
- (void) setRetainDrawBuffer:(VVBuffer *)n	{
	OSSpinLockLock(&retainDrawLock);
	VVRELEASE(retainDrawBuffer);
	retainDrawBuffer = (n==nil) ? nil : [n retain];
	OSSpinLockUnlock(&retainDrawLock);
}
- (BOOL) onlyDrawNewStuff	{
	BOOL		returnMe = NO;
	OSSpinLockLock(&onlyDrawNewStuffLock);
	returnMe = onlyDrawNewStuff;
	OSSpinLockUnlock(&onlyDrawNewStuffLock);
	return returnMe;
}


@end

#import "TexRangeGLCPUStreamer.h"
#import "VVBufferPool.h"
#import <OpenGL/CGLMacro.h>




@implementation TexRangeGLCPUStreamer


- (id) init	{
	if (self = [super init])	{
		copyObj = nil;
		copyAndResize = NO;
		copySize = NSMakeSize(4,3);
		ctxArray = [[MutLockArray alloc] init];
		return self;
	}
	[self release];
	return nil;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	
	VVRELEASE(copyObj);
	VVRELEASE(ctxArray);
	
	[super dealloc];
}


- (void) setNextTexBufferForStream:(VVBuffer *)n	{
	//NSLog(@"%s",__func__);
	//NSLog(@"\t\tpassed buffer is %@",n);
	//NSLog(@"\t\tuserInfo of passed buffer is %@",[n userInfo]);
	if (deleted || n==nil)
		return;
	[self setNextObjForStream:n];
}
- (VVBuffer *) copyAndGetCPUBackedBufferForStream	{
	if (deleted)
		return nil;
	//	this class returns a CPU-backed VVBuffer of the appropriate type
	return [self copyAndPullObjThroughStream];
}


- (void) startProcessingThisDict:(NSMutableDictionary *)d	{
	//NSLog(@"%s",__func__);
	//NSLog(@"\t\tpassed dict is %@",d);
	if (deleted || d==nil)
		return;
	//	get the passed texture, bail if i can't find one
	VVBuffer				*passedTex = [d objectForKey:@"passed"];
	if (passedTex == nil)
		return;
	//	get or create a GL context to be used to download the texture to CPU memory- bail if i can't
	NSOpenGLContext			*ctx = nil;
	if (ctxArray!=nil && [ctxArray count]>0)	{
		[ctxArray wrlock];
			ctx = [ctxArray objectAtIndex:0];
			if (ctx != nil)	{
				[ctx retain];
				[ctxArray removeObjectAtIndex:0];
			}
		[ctxArray unlock];
	}
	else	{
		//NSLog(@"\t\tcreating GL context in %s",__func__);
		ctx = [[NSOpenGLContext alloc] initWithFormat:[_globalVVBufferPool customPixelFormat] shareContext:[_globalVVBufferPool sharedContext]];
		[ctx setCurrentVirtualScreen:[_globalVVBufferPool currentVirtualScreen]];
	}
	if (ctx==nil)
		return;
	//	store the GL context in the passed dict so i can retrieve it later!
	[d setObject:ctx forKey:@"ctx"];
	[ctx release];
	
	
	VVBuffer				*destTex = nil;
	if (passedTex == nil)
		return;
	NSSize					imageSize = [passedTex srcRect].size;
	NSSize					targetSize = (copyAndResize) ? copySize : imageSize;
	BOOL					sizeIsAProblem = (!NSEqualSizes(targetSize,imageSize)) ? YES : NO;
	VVBufferDescriptor		*passedDesc = [passedTex descriptorPtr];
	/*
	VVBufferDescriptor		tmpDesc;
	tmpDesc.type = VVBufferType_Tex;
	tmpDesc.target = 0;
	tmpDesc.internalFormat = VVBufferIF_RGBA8;
	tmpDesc.pixelFormat = VVBufferPF_BGRA;
	tmpDesc.pixelType = VVBufferPT_U_Int_8888_Rev;
	tmpDesc.backingType = VVBufferBack_Pixels;
	tmpDesc.name = 0;
	tmpDesc.texRangeFlag = YES;
	tmpDesc.texClientStorageFlag = YES;
	tmpDesc.msAmount = 0;
	tmpDesc.localSurfaceID = 0;
	*/
	//	if the passed buffer is NOT the appropriate type or it needs to be resized, copy it into a buffer of the appropriate type (CPU-backed GL tex range) now
	if (!passedDesc->texRangeFlag || sizeIsAProblem)	{
		//NSLog(@"\t\tnot a tex range or size is a problem, have to copy to a new buffer...");
		destTex = [_globalVVBufferPool allocBGRACPUBackedTexRangeSized:targetSize];
		//NSLog(@"\t\t...copying to new buffer, %@",destTex);
		//NSSizeLog(@"\t\ttargetSize is",targetSize);
		//NSSizeLog(@"\t\tpassed image size is",imageSize);
		[d setObject:destTex forKey:@"pullThisBack"];
		[destTex release];
		if (copyObj == nil)	{
			copyObj = [[VVBufferCopier alloc] initWithSharedContext:[_globalVVBufferPool sharedContext] sized:NSMakeSize(4,3)];
			[copyObj setCurrentVirtualScreen:[_globalVVBufferPool currentVirtualScreen]];
			[copyObj setCopySize:copySize];
			[copyObj setCopyAndResize:copyAndResize];
			[copyObj setCopyToIOSurface:NO];
		}
		if (copyObj != nil)
			[copyObj copyThisBuffer:passedTex toThisBuffer:destTex];
	}
	//	...else the passed buffer is the approrpiate type
	else	{
		destTex = passedTex;
		[d setObject:destTex forKey:@"pullThisBack"];
	}
	
	VVBuffer			*tmpFBO = [_globalVVBufferPool allocFBO];
	//VVBuffer			*tmpTex = [_globalVVBufferPool allocDepthSized:NSMakeSize(1,1)];
	if (tmpFBO==nil /*|| tmpTex==nil*/)	{
		VVRELEASE(tmpFBO);
		//VVRELEASE(tmpTex);
		return;
	}
	
	//	...at this point, "destTex" has a GL texture with the appropriate texture range CPU backing- start pulling it back now!
	CGLContextObj		cgl_ctx = [ctx CGLContextObj];
	
	if (tmpFBO != nil)	{
		/*		okay, so this is a minor controversy: right now, this code generates a GL error (because 
		there's no FBO bound when i flush- these are texture ranges, i'm not actually drawing anything, 
		i just need to bind the texture and flush the context- i don't need or want an FBO).  obviously, 
		i don't want to have a GL error.  but there's a catch...
		
		if i un-comment out this code- if i bind an FBO to eliminate the GL error, then i have to 
		attach something to the FBO as a color attachment or i'll still get a GL error.  when i do 
		this, graphical corruption in the texture i'm downloading appears- whether the texture bound 
		as an attachment is 1x1 or full-frame, where there's overlap, there's going to be some level 
		of graphical corruption.  there's also a proportional slowdown...so eliminating the GL error 
		actually causes more problems than ignoring it?		*/
		
		/*
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,[tmpFBO name]);
		if (destTex != nil)	{
			glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, [destTex target], [destTex name], 0);
			//glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, [tmpTex target], [tmpTex name], 0);
			GLenum			status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
			if (status != GL_FRAMEBUFFER_COMPLETE_EXT)
				NSLog(@"\t\terr: GL %04X in %s", status,__func__);
		}
		*/
	}
	
	[destTex setUserInfo:[passedTex userInfo]];
	[destTex setContentTimestampFromPtr:[passedTex contentTimestampPtr]];
	
	//GLenum			status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
	//if (status != GL_FRAMEBUFFER_COMPLETE_EXT)
	//	NSLog(@"err (%04X) %s",status,__func__);
	GLuint				destTexTarget = [destTex target];
	glEnable(destTexTarget);
	glBindTexture(destTexTarget,[destTex name]);
	glTexParameteri(destTexTarget,GL_TEXTURE_STORAGE_HINT_APPLE,GL_STORAGE_SHARED_APPLE);
	//glTexParameteri(destTexTarget,GL_TEXTURE_STORAGE_HINT_APPLE,GL_STORAGE_CACHED_APPLE);
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
	//	this method initiates an async. DMA transfer to system memory next time you call a flush routine
	//if (!integratedGPUFlag)	{
		//NSLog(@"\t\t***** check this on integrated GPUs! %s",__func__);
		glCopyTexSubImage2D(destTexTarget,0,0,0,0,0,targetSize.width,targetSize.height);
	//}
	//	flush- start the DMA transfer.  the CPU doesn't wait for this to complete- so program 
	//	execution continues right now, while the transfer is running in the background...
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE);
	glFlush();
	//	right now, the texture is being pulled back from memory- so i should do some other stuff to 
	//	waste some time while i'm waiting for it to finish...
	
	if (tmpFBO != nil)	{
		/*
		if (destTex != nil)	{
			glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, [destTex target], 0, 0);
		}
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,0);
		*/
	}
	//VVRELEASE(tmpTex);
	VVRELEASE(tmpFBO);
	
}
//	returns a RETAINED (must be freed by caller) instance of something!  called by this obj when it finishes processing one of the passed objects.  returns the object to be returned by the subclass.  YOU MUST RETAIN THE OBJECT BEING RETURNED HERE!
- (id) copyAndFinishProcessingThisDict:(NSMutableDictionary *)d	{
	//NSLog(@"%s ... %@",__func__,n);
	if (deleted || d==nil)
		return nil;
	NSOpenGLContext			*ctx = [d objectForKey:@"ctx"];
	VVBuffer				*destTex = [d objectForKey:@"pullThisBack"];
	if (ctx==nil || destTex==nil)	{
		if (ctx != nil)
			[ctxArray lockAddObject:ctx];
		[d removeAllObjects];
		return nil;
	}
	
	//NSLog(@"%s ... %@",__func__,n);
	//NSLog(@"\t\tdest pixels are %p",[destTex pixels]);
	id					returnMe = [destTex retain];
	CGLContextObj		cgl_ctx = [ctx CGLContextObj];
	//GLenum			status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
	//if (status != GL_FRAMEBUFFER_COMPLETE_EXT)
	//	NSLog(@"err (%04X) %s",status,__func__);
	VVBufferDescriptor	*desc = [destTex descriptorPtr];
	void				*wPtr = [destTex cpuBackingPtr];
	//NSLog(@"\t\tcalling glGetTexImage()");
	if (wPtr==nil)
		NSLog(@"\t\terr: can't download, cpuBackingPtr nil in %s",__func__);
	else	{
		//NSLog(@"\t\t%s, currentVirtualScreen is %d",__func__,[ctx currentVirtualScreen]);
		glGetTexImage(desc->target,
			0,
			desc->pixelFormat,
			desc->pixelType,
			wPtr);
		glFlush();
	}
	
	[ctxArray lockAddObject:ctx];
	
	return returnMe;
}

- (void) setCopyAndResize:(BOOL)n	{
	if (deleted)
		return;
	copyAndResize = n;
	[copyObj setCopyAndResize:n];
	[copyObj setCopySize:copySize];
}
- (BOOL) copyAndResize	{
	return copyAndResize;
}
- (void) setCopySize:(NSSize)n	{
	if (deleted)
		return;
	copySize = n;
	[copyObj setCopySize:n];
}
- (NSSize) copySize	{
	return copySize;
}


@end

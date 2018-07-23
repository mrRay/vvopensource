#import "PBOGLCPUStreamer.h"
#import "VVBufferPool.h"
#import <OpenGL/CGLMacro.h>




@implementation PBOGLCPUStreamer


- (id) init	{
	if (self = [super init])	{
		ctxArray = [[MutLockArray alloc] init];
		return self;
	}
	[self release];
	return nil;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(ctxArray);
	[super dealloc];
}
- (void) setNextTexBufferForStream:(VVBuffer *)n	{
	[self setNextObjForStream:n];
}
- (VVBuffer *) allocCPUBufferForTexBuffer:(VVBuffer *)b	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return nil;
	[self setNextObjForStream:b];
	VVBuffer	*returnMe = [self copyAndPullObjThroughStream];	//	actually a dict, but i'm just pulling through & releasing the dict to push the passed buffer halfway through the double-buffer process
	//NSLog(@"\t\thalfway item is %@",returnMe);
	VVRELEASE(returnMe);
	returnMe = [self copyAndGetCPUBufferForStream];
	return returnMe;
}
- (VVBuffer *) copyAndGetPBOBufferForStream	{
	if (deleted)
		return nil;
	//	pull an obj through the stream, get its PBO and GL context
	NSMutableDictionary		*streamDict = [self copyAndPullObjThroughStream];
	VVBuffer				*streamPBO = nil;
	NSOpenGLContext			*streamCtx = nil;
	if (streamDict != nil)	{
		streamPBO = [streamDict objectForKey:@"pbo"];
		streamCtx = [streamDict objectForKey:@"ctx"];
	}
	if (streamCtx != nil)
		[ctxArray lockAddObject:streamCtx];
	if (streamPBO != nil)
		[streamPBO retain];
	[streamDict release];
	return streamPBO;
}
- (VVBuffer *) copyAndGetCPUBufferForStream	{
	//NSLog(@"%s",__func__);
	if (deleted)	{
		//NSLog(@"\t\terr: bailing, deleted %s",__func__);
		return nil;
	}
	//	pull an obj through the stream, get its PBO and GL context
	NSMutableDictionary		*streamDict = [self copyAndPullObjThroughStream];
	//NSLog(@"\t\tstreamDict i just pulled through the stream is %@",streamDict);
	VVBuffer				*streamPBO = nil;
	NSOpenGLContext			*streamCtx = nil;
	if (streamDict != nil)	{
		streamPBO = [streamDict objectForKey:@"pbo"];
		streamCtx = [streamDict objectForKey:@"ctx"];
	}
	if (streamCtx == nil)	{
		//NSLog(@"\t\terr: bailing, stream ctx nil, %s",__func__);
		[streamDict release];
		return nil;
	}
	if (streamPBO == nil)	{
		//NSLog(@"\t\terr: bailing, stream pbo nil, %s",__func__);
		[ctxArray lockAddObject:streamCtx];
		[streamDict release];
		return nil;
	}
	VVBufferDescriptor		*pboDesc = [streamPBO descriptorPtr];
	//	make the CPU buffer i'll be returning, copy the PBO into it
	NSSize				bufferSize = [streamPBO size];
	VVBuffer			*returnMe = nil;
	if (pboDesc->internalFormat == VVBufferIF_RGBA32F)
		returnMe = [_globalVVBufferPool allocRGBAFloatCPUBufferSized:bufferSize];
	else
		returnMe = [_globalVVBufferPool allocRGBACPUBufferSized:bufferSize];
	if (returnMe != nil)	{
		void		*wPtr = (void *)[returnMe pixels];
		if (wPtr != nil)
			[self _copyPBOBuffer:streamPBO toRawDataBuffer:wPtr usingContext:[streamCtx CGLContextObj]];
	}
	//	release the stream dict so it doesn't leak, put the GL context in the ctxArray
	[ctxArray lockAddObject:streamCtx];
	[streamDict release];
	
	return returnMe;
}
- (BOOL) copyPBOFromStreamToRawDataBuffer:(void *)b sized:(NSSize)dataBufferSize	{
	//NSLog(@"%s",__func__);
	if (deleted || b==nil)
		return NO;
	//	pull an obj through the stream, get its PBO and GL context
	NSMutableDictionary		*streamDict = [self copyAndPullObjThroughStream];
	//NSLog(@"\t\tstreamDict is %@",streamDict);
	VVBuffer				*streamPBO = nil;
	NSOpenGLContext			*streamCtx = nil;
	if (streamDict != nil)	{
		streamPBO = [streamDict objectForKey:@"pbo"];
		streamCtx = [streamDict objectForKey:@"ctx"];
	}
	if (streamCtx == nil)	{
		//NSLog(@"\t\tbailing A %s",__func__);
		[streamDict release];
		return NO;
	}
	if (streamPBO == nil)	{
		//NSLog(@"\t\tbailing B %s",__func__);
		[ctxArray lockAddObject:streamCtx];
		[streamDict release];
		return NO;
	}
	if (!NSEqualSizes(dataBufferSize, [streamPBO size]))	{
		[ctxArray lockAddObject:streamCtx];
		[streamDict release];
		return NO;
	}
	//	copy the PBO into the passed buffer
	[self _copyPBOBuffer:streamPBO toRawDataBuffer:b usingContext:[streamCtx CGLContextObj]];
	//	release the stream dict so it doesn't leak, put the GL context in the ctxArray
	[ctxArray lockAddObject:streamCtx];
	[streamDict release];
	return YES;
}
/*		NOT SAFE!  DOESN'T CHECK THE SIZE OF THE PBO WITH THE SIZE OF 'w', JUST ASSUMES EVERYTHING'S CORRECTLY-SIZED!		*/
- (void) _copyPBOBuffer:(VVBuffer *)pbo toRawDataBuffer:(void *)w usingContext:(CGLContextObj)cgl_ctx	{
	//NSLog(@"%s ... %@",__func__,pbo);
	if (deleted || pbo==nil || w==nil)
		return;
    NSSize			bufferSize = [pbo size];
    VVBufferDescriptor	*texDesc = [pbo descriptorPtr];
	glBindBufferARB(GL_PIXEL_PACK_BUFFER_ARB,[pbo name]);
	unsigned char		*rPtr = (GLubyte *)glMapBufferARB(GL_PIXEL_PACK_BUFFER_ARB,GL_READ_ONLY_ARB);
	unsigned char		*wPtr = w;
	if (rPtr != nil)	{
		if (texDesc!=nil && texDesc->internalFormat==VVBufferIF_RGBA32F)	{
			memcpy(wPtr, rPtr, bufferSize.width*bufferSize.height*16);
		}
		else	{
			//NSLog(@"\t\tcopying %ld bytes",(NSUInteger)(bufferSize.width*bufferSize.height*32.0/8.0));
			memcpy(wPtr, rPtr, (NSUInteger)(bufferSize.width*bufferSize.height*32.0/8.0));
		}
		/*
		for (int row=0; row<bufferSize.height; ++row)	{
			for (int col=0; col<bufferSize.width; ++col)	{
				for (int channel=0; channel<4; ++channel)	{
					//if (row==0 && col==0)
						//NSLog(@"\t\t%ld",*rPtr);
					//fprintf(stderr," %d",*rPtr);
					*wPtr = *rPtr;
					
					++wPtr;
					++rPtr;
					
				}
			}
		}
		*/
		glUnmapBufferARB(GL_PIXEL_PACK_BUFFER_ARB);
	}
	glBindBufferARB(GL_PIXEL_PACK_BUFFER_ARB,0);
	glFlush();
}
/*		NOT SAFE!  DOESN'T CHECK THE SIZE OF THE PBO WITH THE SIZE OF 'w', JUST ASSUMES EVERYTHING'S CORRECTLY-SIZED!		*/
//	this method exists because i'm working with textures that have padding- i don't want to read all the bytes for every row, just most of them
- (void) _copyBytesPerRow:(NSUInteger)bpr ofPBOBuffer:(VVBuffer *)pbo toRawDataBuffer:(void *)w usingContext:(CGLContextObj)cgl_ctx	{
	//NSLog(@"%s ... %ld, %@",__func__,bpr,pbo);
	if (deleted || pbo==nil || w==nil)
		return;
    NSSize			bufferSize = [pbo size];
    VVBufferDescriptor	*texDesc = [pbo descriptorPtr];
	glBindBufferARB(GL_PIXEL_PACK_BUFFER_ARB,[pbo name]);
	unsigned char		*rPtr = (GLubyte *)glMapBufferARB(GL_PIXEL_PACK_BUFFER_ARB,GL_READ_ONLY_ARB);
	unsigned char		*wPtr = w;
	//	calculate the number of bytes per row in the actual pbo
	NSUInteger			bufferBPR = bufferSize.width*32.0/8.0;
	//	i don't want to copy "too much" memory...
	NSUInteger			bytesPerRowToCopy = fminl(bpr,bufferBPR);
	//NSLog(@"\t\tbufferBPR is %ld",bufferBPR);
	if (texDesc!=nil && texDesc->internalFormat==VVBufferIF_RGBA32F)
		bufferBPR = bufferSize.width*(32.0*4.0)/8.0;
	//	begin reading back "bpr" bytes per row for each of the rows in the pbo...
	if (rPtr != nil)	{
		//NSLog(@"\t\tcopying %ld bytes per row for %ld rows",bpr,(NSUInteger)(bufferSize.height));
		for (int i=0; i<bufferSize.height; ++i)	{
			memcpy(wPtr, rPtr, bytesPerRowToCopy);
			rPtr += (bufferBPR);
			wPtr += bpr;
		}
		glUnmapBufferARB(GL_PIXEL_PACK_BUFFER_ARB);
	}
	glBindBufferARB(GL_PIXEL_PACK_BUFFER_ARB,0);
	glFlush();
}


- (void) startProcessingThisDict:(NSMutableDictionary *)d	{
	//NSLog(@"%s",__func__);
	//NSLog(@"\t\tdict is %@",d);
	if (deleted || d==nil)
		return;
	VVBuffer		*tex = [d objectForKey:@"passed"];
	if (tex == nil)	{
		//NSLog(@"\t\terr: bailing, passed tex is nil, %s",__func__);
		return;
	}
	VVBufferDescriptor		*texDesc = [tex descriptorPtr];
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
	if (ctx==nil)	{
		//NSLog(@"\t\terr: bailing, ctx nil, %s",__func__);
		return;
	}
	//	store the GL context in the passed dict so i can retrieve it later!
	[d setObject:ctx forKey:@"ctx"];
	[ctx release];
	
	
	
	NSSize			bufferSize = [tex size];
	VVBuffer		*pbo = nil;
	if (texDesc->internalFormat == VVBufferIF_RGBA32F)	{
		pbo = [_globalVVBufferPool
			allocRGBAFloatPBOForTarget:GL_PIXEL_PACK_BUFFER
			usage:GL_DYNAMIC_READ
			sized:bufferSize
			data:nil];
	}
	else	{
		pbo = [_globalVVBufferPool
			allocRGBAPBOForTarget:GL_PIXEL_PACK_BUFFER
			usage:GL_DYNAMIC_READ
			sized:bufferSize
			data:nil];
	}
	[pbo setUserInfo:[tex userInfo]];
	[d setObject:pbo forKey:@"pbo"];
	[pbo release];
	
	CGLContextObj		cgl_ctx = [ctx CGLContextObj];
	//	set up the context, bind the appropriate texture & buffer
	glBindBufferARB(GL_PIXEL_PACK_BUFFER,[pbo name]);
	glEnable([tex target]);
	glBindTexture([tex target],[tex name]);
	glPixelStorei(GL_PACK_ROW_LENGTH,bufferSize.width);
	
	//	start pulling the texture back to the newly-created PBO- this starts async. DMA transfer to system memory next time flush is called
	glGetTexImage([tex target], 0, texDesc->pixelFormat, texDesc->pixelType, (GLvoid *)0);
	
	glBindTexture([tex target],0);
	glDisable([tex target]);
	glBindBufferARB(GL_PIXEL_PACK_BUFFER_ARB,0);
	//	flush- start the DMA transfer.  the CPU doesn't wait for this to complete, and returns immediately!
	glFlush();
}
//	returns a RETAINED (must be freed by caller) instance of something!  called by this obj when it finishes processing one of the passed objects.  returns the object to be returned by the subclass.  YOU MUST RETAIN THE OBJECT BEING RETURNED HERE!
- (id) copyAndFinishProcessingThisDict:(NSMutableDictionary *)d	{
	//NSLog(@"%s",__func__);
	//NSLog(@"\t\tdict is %@",d);
	if (deleted || d==nil)	{
		NSLog(@"\t\terr: bailing, initial nil, %s",__func__);
		return nil;
	}
	//	timestamp the pbo in the dict!
	VVBuffer		*pbo = [d objectForKey:@"pbo"];
	if (pbo != nil)
		[VVBufferPool timestampThisBuffer:pbo];
	//	i want to return the dict i'm being passed- but dicts are part of the StreamProcessor backend, and may be emptied (to ensure release as opposed to autorelease), so i can't just retain it: i have to copy it!
	//[d retain];
	//return d;
	return [d copy];
}


- (MutLockArray *) ctxArray	{
	return ctxArray;
}


@end

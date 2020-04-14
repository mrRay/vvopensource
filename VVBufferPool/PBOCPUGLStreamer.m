#import "PBOCPUGLStreamer.h"
#import "GLScene.h"
#import "VVBufferPool.h"
#import <OpenGL/CGLMacro.h>




@implementation PBOCPUGLStreamer


- (id) init	{
	if (self = [super init])	{
		ctxArray = [[MutLockArray alloc] init];
		return self;
	}
	VVRELEASE(self);
	return self;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(ctxArray);
	
}


- (void) setNextPBOForStream:(VVBuffer *)n	{
	if (deleted)
		return;
	[self setNextObjForStream:n];
}
- (VVBuffer *) copyAndGetTexBufferForStream	{
	if (deleted)
		return nil;
	return [self copyAndPullObjThroughStream];
}


- (void) startProcessingThisDict:(NSMutableDictionary *)d	{
	if (deleted || d==nil)
		return;
	//	get the PBO
	VVBuffer			*newPBO = [d objectForKey:@"passed"];
	if (newPBO == nil)
		return;
	//	get or create a GL context to be used to download the texture to CPU memory- bail if i can't
	NSOpenGLContext			*ctx = nil;
	if (ctxArray!=nil && [ctxArray count]>0)	{
		[ctxArray wrlock];
			ctx = [ctxArray objectAtIndex:0];
			if (ctx != nil)	{
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
	[d setObject:ctx forKey:@"ctx"];
	
	
	NSSize				bufferSize = [newPBO size];
	VVBufferPixFormat	pixFormat = [newPBO descriptorPtr]->pixelFormat;
	VVBuffer			*newTex = nil;
	switch (pixFormat)	{
		case VVBufferPF_RGBA:
			newTex = [_globalVVBufferPool allocRGBTexSized:bufferSize];
			break;
		case VVBufferPF_BGRA:
			//NSLog(@"\t\tRGB PBO");
			newTex = [_globalVVBufferPool allocBGRTexSized:bufferSize];
			break;
		case VVBufferPF_YCBCR_422:
			//NSLog(@"\t\tYUV PBO");
			newTex = [_globalVVBufferPool allocYCbCrTexSized:bufferSize];
			break;
		default:
			NSLog(@"\t\terr: unrecognized pixel format A, %s",__func__);
			break;
	}
	if (newTex != nil)	{
		[d setObject:newTex forKey:@"destTex"];
		
		[newTex setFlipped:[newPBO flipped]];
		
		CGLContextObj		cgl_ctx = [ctx CGLContextObj];
		
		//	set up the context, bind the appropriate texture & buffer
		glBindBufferARB(GL_PIXEL_UNPACK_BUFFER, [newPBO name]);
		glEnable([newTex target]);
		glBindTexture([newTex target], [newTex name]);
		glPixelStorei(GL_PACK_ROW_LENGTH, bufferSize.width);
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
		
		//	start copying the buffer data to the newly-created PBO- this starts async. DMA transfer from system memory next time flush is called
		switch (pixFormat)	{
			case VVBufferPF_RGBA:
				glTexSubImage2D([newTex target], 0, 0, 0, bufferSize.width, bufferSize.height, GL_RGBA, GL_UNSIGNED_INT_8_8_8_8_REV, 0);
				break;
			case VVBufferPF_BGRA:
				glTexSubImage2D([newTex target], 0, 0, 0, bufferSize.width, bufferSize.height, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, 0);
				break;
			case VVBufferPF_YCBCR_422:
				glTexSubImage2D([newTex target], 0, 0, 0, bufferSize.width, bufferSize.height, GL_YCBCR_422_APPLE, GL_UNSIGNED_SHORT_8_8_APPLE, 0);
				break;
			default:
				NSLog(@"\t\terr: unrecognized pixel format B, %s",__func__);
				break;
		}
		
		glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE);
		
		glBindTexture([newTex target],0);
		glDisable([newTex target]);
		glBindBufferARB(GL_PIXEL_UNPACK_BUFFER_ARB,0);
		//	flush- start the DMA transfer.  the CPU doesn't wait for this to complete, and returns immediately!
		glFlush();
		
	}
	else
		NSLog(@"\t\terr: newTex was nil in %s",__func__);
}
//	returns a RETAINED (must be freed by caller) instance of something!  called by this obj when it finishes processing one of the passed objects.  returns the object to be returned by the subclass.  YOU MUST RETAIN THE OBJECT BEING RETURNED HERE!
- (id) copyAndFinishProcessingThisDict:(NSMutableDictionary *)d	{
	if (deleted || d==nil)
		return nil;
	//	i store the tex in "extraObj", return it
	id			returnMe = [d objectForKey:@"destTex"];
	//	don't forget to timestamp it!
	[VVBufferPool timestampThisBuffer:returnMe];
	
	NSOpenGLContext		*ctx = [d objectForKey:@"ctx"];
	if (ctx != nil)	{
		[ctxArray lockAddObject:ctx];
		[d removeObjectForKey:@"ctx"];
	}
	return returnMe;
}


@end

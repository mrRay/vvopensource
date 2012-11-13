//
//  TestGLView.m
//  VVOpenSource
//
//  Created by bagheera on 11/12/12.
//
//

#import "TestGLView.h"




@implementation TestGLView


- (void) initializeGL	{
	//NSLog(@"%s",__func__);
	//[self setPixelFormat:[TestGLView defaultQTPixelFormat]];
	NSOpenGLContext		*newContext = [[NSOpenGLContext alloc] initWithFormat:[TestGLView defaultPixelFormat] shareContext:nil];
	[self setOpenGLContext:newContext];
	[newContext setView:self];
	[newContext release];
	
	[super initializeGL];
	/*
	CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
	//glEnable(GL_TEXTURE_RECTANGLE_EXT);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	//glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	//glEnable(GL_BLEND);
	glDisable(GL_BLEND);
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
	*/
}


+ (NSOpenGLPixelFormat *) defaultPixelFormat	{
	NSOpenGLPixelFormat					*returnMe = nil;
	GLuint								glDisplayMask = [TestGLView glDisplayMaskForAllScreens];
	NSOpenGLPixelFormatAttribute		attrs[] = {
		NSOpenGLPFAAccelerated,
		//NSOpenGLPFAAllRenderers,
		//NSOpenGLPFAScreenMask,CGDisplayIDToOpenGLDisplayMask(kCGDirectMainDisplay),
		NSOpenGLPFAScreenMask,glDisplayMask,
		NSOpenGLPFANoRecovery,
		NSOpenGLPFAAllowOfflineRenderers,
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


@end

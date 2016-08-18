#import "ISFVVBufferGLView.h"




@implementation ISFVVBufferGLView


/*===================================================================================*/
#pragma mark --------------------- init/setup/destroy
/*------------------------------------*/


- (void) generalInit	{
	//NSLog(@"%s",__func__);
	[super generalInit];
	localISFSceneLock = OS_SPINLOCK_INIT;
	localISFScene = nil;
	bgSprite = [spriteManager makeNewSpriteAtBottomForRect:NSMakeRect(0,0,1,1)];
	[bgSprite setDelegate:self];
	[bgSprite setActionCallback:@selector(actionBgSprite:)];
	[bgSprite setDrawCallback:@selector(drawBGSprite:)];
	spritesNeedUpdate = YES;
	bufferLock = OS_SPINLOCK_INIT;
	buffer = nil;
	bufferArray = [MUTARRAY retain];
}
- (void) awakeFromNib	{
	[super awakeFromNib];
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (!deleted)
		[self prepareToBeDeleted];
	OSSpinLockLock(&localISFSceneLock);
	VVRELEASE(localISFScene);
	OSSpinLockUnlock(&localISFSceneLock);
	
	OSSpinLockLock(&bufferLock);
	VVRELEASE(buffer);
	VVRELEASE(bufferArray);
	OSSpinLockUnlock(&bufferLock);
	
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- main interaction
/*------------------------------------*/


- (void) drawBuffer:(VVBuffer *)n	{
	//NSLog(@"%s",__func__);
	//if (n==nil)
	//	return;
	
	//	i have to retain the buffer locally (a sprite needs to draw this in a delegate method)
	OSSpinLockLock(&bufferLock);
	VVRELEASE(buffer);
	buffer = (n==nil) ? nil : [n retain];
	OSSpinLockUnlock(&bufferLock);
	
	//	this causes my super to draw immediately
	[self performDrawing:[self bounds]];
	
	//	since i just drew, i don't need to retain the buffer any more!
	//OSSpinLockLock(&bufferLock);
	//VVRELEASE(buffer);
	//OSSpinLockUnlock(&bufferLock);
}
- (void) setSharedGLContext:(NSOpenGLContext *)c	{
	NSOpenGLContext		*newCtx = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:c];
	[self setOpenGLContext:newCtx];
	[newCtx setView:self];
	[newCtx release];
	newCtx = nil;
}
- (void) useFile:(NSString *)n	{
	OSSpinLockLock(&localISFSceneLock);
	if (localISFScene==nil)
		NSLog(@"\t\terr: trying to load file %@, but ISF scene is nil!  %s",n,__func__);
	else	{
		[localISFScene useFile:n];
	}
	OSSpinLockUnlock(&localISFSceneLock);
}


/*===================================================================================*/
#pragma mark --------------------- drawing/sprites
/*------------------------------------*/


- (void) initializeGL	{
	//NSLog(@"%s",__func__);
	//[self setPixelFormat:[GLScene defaultQTPixelFormat]];
	
	OSSpinLockLock(&localISFSceneLock);
	if (localISFScene==nil)	{
		NSOpenGLContext		*currentCtx = [self openGLContext];
		if (currentCtx!=nil)	{
			localISFScene = [[ISFGLScene alloc] initWithContext:currentCtx sharedContext:[_globalVVBufferPool sharedContext]];
			[localISFScene useFile:[[NSBundle mainBundle] pathForResource:@"AlphaOverCheckerboard" ofType:@"fs"]];
		}
	}
	OSSpinLockUnlock(&localISFSceneLock);
	
	//[self setOpenGLContext:[localISFScene context]];
	//[[localISFScene context] setView:self];
	[localISFScene setSize:[self backingBounds].size];
	
	[super initializeGL];
	
	CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
	//glEnable(GL_TEXTURE_RECTANGLE_EXT);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	//glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	//glEnable(GL_BLEND);
	glDisable(GL_BLEND);
	glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
}
- (void) updateSprites	{
	//NSLog(@"%s",__func__);
	[super updateSprites];
	if (bgSprite != nil)	{
		[bgSprite setRect:[self backingBounds]];
		//NSRectLog(@"\t\tbgSprite's rect is",[bgSprite rect]);
	}
}


- (void) drawBGSprite:(VVSprite *)s	{
	//NSLog(@"%s",__func__);
	if (deleted || localISFScene==nil)
		return;
	
	CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
	glDisable(GL_BLEND);
	
	OSSpinLockLock(&bufferLock);
	VVBuffer		*bufferToDraw = buffer;
	if (bufferToDraw!=nil)
		[bufferArray addObject:bufferToDraw];
	OSSpinLockUnlock(&bufferLock);
	
	//NSLog(@"\t\tbufferToDraw is %@",bufferToDraw);
	if (bufferToDraw!=nil)	{
		[localISFScene setFilterInputImageBuffer:bufferToDraw];
		[localISFScene render];
	}
	else	{
		//- (void) renderBlackFrameInFBO:(GLuint)f colorTex:(GLuint)t target:(GLuint)tt
		[localISFScene renderBlackFrameInFBO:0 colorTex:0 target:GL_TEXTURE_RECTANGLE_EXT];
		//[localISFScene renderToBuffer:nil sized:size renderTime:[swatch timeSinceStart] passDict:nil];
		
	}
	
}
- (void) actionBgSprite:(VVSprite *)s	{

}


/*===================================================================================*/
#pragma mark --------------------- superclass overrides
/*------------------------------------*/


- (void) finishedDrawing	{
	if (deleted)
		return;
	
	OSSpinLockLock(&bufferLock);
	if (bufferArray != nil)	{
		//	clear out any buffers already in the array from the last render 
		[bufferArray removeAllObjects];
	}
	OSSpinLockUnlock(&bufferLock);
	
	[super finishedDrawing];
}
- (void) setOpenGLContext:(NSOpenGLContext *)c	{
	//	tell the super to set the GL context, which will handle all the context/view setup
	[super setOpenGLContext:c];
	
	//	now i have to reload the ISF scene to use the passed context (which means reloading the file as well)
	OSSpinLockLock(&localISFSceneLock);
	NSString		*currentISFPath = nil;
	if (localISFScene!=nil)	{
		currentISFPath = [[[localISFScene filePath] retain] autorelease];
		VVRELEASE(localISFScene);
	}
	localISFScene = [[ISFGLScene alloc] initWithContext:c sized:[self backingBounds].size];
	if (currentISFPath!=nil)
		[localISFScene useFile:currentISFPath];
	OSSpinLockUnlock(&localISFSceneLock);
}


/*===================================================================================*/
#pragma mark --------------------- key-val
/*------------------------------------*/


@synthesize localISFScene;


@end

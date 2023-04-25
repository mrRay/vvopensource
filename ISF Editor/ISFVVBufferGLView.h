#import <Cocoa/Cocoa.h>
#import <VVBufferPool/VVBufferPool.h>
#import <VVUIToolbox/VVUIToolbox.h>
#import <VVISFKit/VVISFKit.h>




@interface ISFVVBufferGLView : VVSpriteGLView	{
	VVLock				localISFSceneLock;
	ISFGLScene			*localISFScene;	//	instead of rendering to a texture, this draws in my GL view.  built from the same GL context used to draw me (i'm a GL view)
	VVSprite			*bgSprite;
	
	VVLock				bufferLock;
	VVBuffer			*buffer;	//	this is the buffer that needs to be drawn
	NSMutableArray		*bufferArray;	//	used to store the buffer being drawn 'til after my superclass flushes!
}

- (void) drawBGSprite:(VVSprite *)s;

- (void) drawBuffer:(VVBuffer *)n;
- (void) setSharedGLContext:(NSOpenGLContext *)c;
- (void) useFile:(NSString *)n;

@property (readonly) ISFGLScene *localISFScene;

@end

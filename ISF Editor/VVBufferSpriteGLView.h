#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>
#import <VVUIToolbox/VVUIToolbox.h>




@interface VVBufferSpriteGLView : VVSpriteGLView	{
	VVSizingMode	sizingMode;
	
	VVSprite		*bgSprite;
	
	OSSpinLock		retainDrawLock;
	VVBuffer		*retainDrawBuffer;
}

- (void) redraw;
///	Draws the passd buffer
- (void) drawBuffer:(VVBuffer *)b;
///	Sets the GL context to share- this is generally done automatically (using the global buffer pool's shared context), but if you want to override it and use a different context...this is how.
- (void) setSharedGLContext:(NSOpenGLContext *)c;

@property (assign,readwrite) VVSizingMode sizingMode;

@end

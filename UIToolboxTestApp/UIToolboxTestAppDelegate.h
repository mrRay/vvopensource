//
//  UIToolboxTestAppDelegate.h
//  UIToolboxTestApp
//
//  Created by testadmin on 4/27/23.
//

#import <Cocoa/Cocoa.h>
#import <VVUIToolbox/VVUIToolbox.h>
#import <VVBufferPool/VVBufferPool.h>




@interface UIToolboxTestAppDelegate : NSObject <NSApplicationDelegate>	{
	CVDisplayLinkRef			displayLink;
	NSOpenGLContext				*sharedContext;
	
	id<MTLDevice>				device;
	id<MTLCommandQueue>			cmdQueue;
}

@property (weak,readwrite) IBOutlet VVSpriteView * spriteView;
@property (weak,readwrite) IBOutlet VVSpriteGLView * spriteGLView;
@property (weak,readwrite) IBOutlet VVSpriteMTLView * spriteMTLView;

- (void) renderCallback;

@end








CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);


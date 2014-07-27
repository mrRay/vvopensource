#import <Cocoa/Cocoa.h>
#import <VVBufferPool/VVBufferPool.h>
#import <CoreVideo/CoreVideo.h>
#import "QTVideoSource.h"




@interface AppDelegate : NSObject <NSApplicationDelegate>	{
	IBOutlet VVBufferGLView		*glView;
	NSOpenGLContext				*sharedContext;
	CVDisplayLinkRef			displayLink;
	
	QTVideoSource		*videoSource;
}

- (void) renderCallback;

@end



CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);

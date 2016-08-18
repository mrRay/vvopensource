#import <Foundation/Foundation.h>
#import <VVBufferPool/VVBufferPool.h>
#import "VideoSource.h"




@interface QCVideoSource : VideoSource	{
	NSString		*propPath;	//	have to load the comp on the render thread...
	QCGLScene		*propScene;
}

- (void) loadFileAtPath:(NSString *)p;

@end

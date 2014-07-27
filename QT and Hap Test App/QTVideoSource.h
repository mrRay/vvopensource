#import <Foundation/Foundation.h>
#import <VVBufferPool/VVBufferPool.h>
#import <QuickTime/QuickTime.h>
#import <VVISFKit/VVISFKit.h>
#import <QTKit/QTKit.h>




@interface QTVideoSource : NSObject	{
	QTMovie				*movie;
	NSOpenGLContext		*glContext;
	QTVisualContextRef	visualContext;
	ISFGLScene			*hapQSwizzler;
}

- (void) loadFileAtPath:(NSString *)p;
- (VVBuffer *) allocNewFrame;

@end

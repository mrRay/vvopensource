#import <Foundation/Foundation.h>
#import "VideoSource.h"




@interface IMGVideoSource : VideoSource	{
	VVBuffer					*propLastBuffer;
}

- (void) loadFileAtPath:(NSString *)p;

@end

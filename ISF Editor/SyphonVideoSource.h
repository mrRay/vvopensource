#import <Cocoa/Cocoa.h>
#import "VideoSource.h"
#import <Syphon/Syphon.h>




@interface SyphonVideoSource : VideoSource	{
	SyphonClient		*propClient;
}

- (void) loadServerWithServerDescription:(NSDictionary *)n;

@end

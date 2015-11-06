#import "VVBufferSyphonAdditions.h"




@implementation VVBuffer (VVBufferAdditions)
- (SyphonImage *) syphonImage	{
	SyphonImage		*syphonImage = ((long)backingID==VVBufferBackID_Syphon) ? [[(id)backingReleaseCallbackContext retain] autorelease] : nil;
	return syphonImage;
}
@end


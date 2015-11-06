#import <Foundation/Foundation.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>
#import <Syphon/Syphon.h>




/*	the 'VVBufferBackID' typedef is used purely for identification of the source of a VVBuffer (as 
buffers are frequently wrappers for resources created by or underlying other graphics APIs).  these 
values are purely referential- they aren't functional at all, and are mainly used so you can 
avoid ping-ponging between graphics formats.  since these are purely a reference, you can define 
your own values- just start at 100 or whatever, and make sure that these values are unique within 
all the code you're compiling.		*/
#define VVBufferBackID_Syphon 100




/*	this class addition retrieves the SyphonImage underlying a VVBuffer (if there is one).  just 
checks the buffer's VVBufferBackID, returns the callback context- which was set to a SyphonImage 
when we created the buffer- if the VVBufferBackID is VVBufferBackID_Syphon		*/

@interface VVBuffer (VVBufferAdditions)
- (SyphonImage *) syphonImage;
@end

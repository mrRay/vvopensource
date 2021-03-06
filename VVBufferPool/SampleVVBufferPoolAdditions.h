/*		this is sample code demonstrating how to use the VVBufferPool framework to "wrap" 
graphic/image resources generated by other APIs.  in these examples (Syphon and VVFFGL), this is 
very nearly a zero-cost operation: VVBuffer is basically just retaining the underlying graphic 
resource, and is merely populated with its properties.		*/
#import <Cocoa/Cocoa.h>
#import <VVBufferPool/VVBufferPool.h>
#import <Syphon/Syphon.h>
#ifndef __LP64__
#import <VVFFGL/VVFFGL.h>
#endif




/*	the 'VVBufferBackID' typedef is used purely for identification of the source of a VVBuffer (as 
buffers are frequently wrappers for resources created by or underlying other graphics APIs).  these 
values are purely referential- they aren't functional at all, and are mainly used so you can 
avoid ping-ponging between graphics formats.  since these are purely a reference, you can define 
your own values- just start at 100 or whatever, and make sure that these values are unique within 
all the code you're compiling.		*/
#define VVBufferBackID_Syphon 100
#define VVBufferBackID_VVFFGL 101




/*	these are class additions to VVBuffer- we're adding methods to VVBufferPool to create VVBuffer 
instances from syphon resources, here are some methods to retrieve the underlying syphon resources 
from VVBuffers (where appropriate)		*/
@interface VVBuffer (VVBufferAdditions)

- (SyphonImage *) syphonImage;
#ifndef __LP64__	//	FFGL is a 32-bit API/VVFFGL is a 32-bit-only framework
- (FFGLImage *) ffglImage;
#endif


@end




/*	these are callbacks we're defining; they're called when a VVBuffer wrapping a syphon or ffgl 
resource is freed (the point of the callback is to release the underlying syphon/ffgl resource)		*/
void VVBuffer_ReleaseSyphonImage(id b, void *c);
#ifndef __LP64__	//	FFGL is a 32-bit API/VVFFGL is a 32-bit-only framework
void VVBuffer_ReleaseFFGLImage(id b, void *c);
#endif




/*	these are class additions to VVBufferPool- these are how you create VVBuffer resources from 
Syphon or VVFFGL resources.  going the "other way"- creating syphon/VVFFGL image resources from 
VVBuffer instances- is beyond the scope of this example, but quite painless since VVBuffer is just a 
wrapper around GL resources.  wrap the VVBuffer with your image format of choice, and when you're 
done, free the VVBuffer instance- the underlying resources will be pooled or freed by the buffer pool.		*/
@interface VVBufferPool (VVBufferPoolAdditions)

- (VVBuffer *) allocBufferForSyphonClient:(SyphonClient *)c;
#ifndef __LP64__	//	FFGL is a 32-bit API/VVFFGL is a 32-bit-only framework
- (VVBuffer *) allocBufferForFFGLImage:(FFGLImage *)i;
#endif
- (VVBuffer *) allocBufferForPlane:(int)pi inHapDecoderFrame:(HapDecoderFrame *)n;
- (NSArray *) createBuffersForHapDecoderFrame:(HapDecoderFrame *)n;

@end

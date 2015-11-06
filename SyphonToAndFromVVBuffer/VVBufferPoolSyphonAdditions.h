#import <Foundation/Foundation.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>
#import <Syphon/Syphon.h>




/*	this class addition gets a SyphonImage from a SyphonClient, and then creates a VVBuffer from 
from the SyphonImage (the VVBuffer will retain the SyphonImage, to ensure that the resource backing 
the VVBuffer is valid for the VVBuffer's lifetime).

this demonstrates how to populate all the relevant properties of a VVBuffer from a GL resource 
contained by another object-oriented instance, and how to use the VVBuffer's callback to release the 
underlying instance when the VVBuffer is freed- the same technique can be used to create a VVBuffer 
from other APIs that vend GL resources.		*/

@interface VVBufferPool (VVBufferPoolAdditions)
- (VVBuffer *) allocBufferForSyphonClient:(SyphonClient *)c;
@end




/*	this is the callback function we define- this function will get called when the VVBuffer we 
create is released.  this is where we release the SyphonImage that we created the VVBuffer from		*/

void VVBuffer_ReleaseSyphonImage(id b, void *c);

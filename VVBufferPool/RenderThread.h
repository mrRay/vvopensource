#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>




#define RTDeleteArrayDestroyNotification @"RTDeleteArrayDestroyNotification"




///	Subclass of VVThreadLoop from VVBasics, provides a simple interface for dealing with GL resources that aren't threadsafe, and need to be created, rendered, and deleted all on the same thread.
/*
\ingroup VVBufferPool
this class exists because some APIs require that resources must be CREATED, RENDERED, and DELETED all on the same thread- if you don't deal with them explicitly on the same thread, they leak!  as such, this class maintains an array of items which are released on the render thread.

that's it, really- this class exists solely to provide an empty mutable array that other objects add stuff to; the array is emptied only on the thread callback.

if you're doing simple stuff with QC then you probably won't need to use this class- but if you're building something big that frees QCRenderers then you want to use this.
*/
@interface RenderThread : VVThreadLoop {
	MutLockArray		*deleteArray;
}

@end

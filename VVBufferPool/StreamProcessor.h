#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>




/*
	this is a general-use class for doing asynchronous stream processing on objects.  the interface 
	for this class is extremely easy to use, and it's easy to subclass so i can use it to quickly 
	assemble asynchronous processing classes.
	
	pass it an object, the object gets stored in a dict.  this dict is passed to subclasses of this 
	class (startProcessingThisDict: and copyAndFinishProcessingThisDict:) for custom behaviors.
*/




@interface StreamProcessor : NSObject	{
	BOOL					deleted;
	
	NSMutableDictionary		*objNext;	//	when you set a next object for the stream, it's stored here until you pull something out of the stream (at which point this gets moved to 'objArray')
	OSSpinLock				objLock;
	
	MutLockArray			*objArray;	//	dictionaries are created for objects and added here when you pull on the stream
	int						objMaxCount;	//	initially 2 (double-buffering)
}

- (void) prepareToBeDeleted;

- (void) setNextObjForStream:(id)n;
//	returns a RETAINED (caller is responsible for releasing) instance of something (what is returned is subclass-specific)
- (id) copyAndPullObjThroughStream;

- (void) clearStream;
- (NSUInteger) streamCount;
- (int) objMaxCount;
- (void) setObjMaxCount:(int)n;


/*				SUBCLASSES **MUST** OVERRIDE THESE METHODS!				*/

//	called by this obj when it starts processing one of the passed objects
- (void) startProcessingThisDict:(NSMutableDictionary *)d;
//	returns a RETAINED (must be freed by caller) instance of something!  called by this obj when it finishes processing one of the passed objects.  returns the object to be returned by the subclass.  YOU MUST RETAIN THE OBJECT BEING RETURNED HERE!
- (id) copyAndFinishProcessingThisDict:(NSMutableDictionary *)d;

@end

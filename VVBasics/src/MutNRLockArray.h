
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "MutLockArray.h"
#import "ObjectHolder.h"



///	Subclass of MutLockArray; this class does NOT retain the objects in its array!
/**
\ingroup VVBasics
this class exists because i frequently find myself in situations where i want to add an instance of an object to an array/dict/[any class which retains the passed instance], but i don't actually want the item to be retained.

Instead of adding (and therefore retaining) objects to an array like my superclass, this class makes an ObjectHolder for objects which are added to it (so they don't get retained), and adds the ObjectHolder to me.  when other classes ask me for the index of an object, or ask for the object at a particular index, i'll find the relevant ObjectHolder and then return the object it's storing.
*/

@interface MutNRLockArray : MutLockArray {
	BOOL		zwrFlag;	//	NO by default. if YES, uses mike ash's zeroing weak reference object instead of just storing a simple weak reference!
}

+ (id) arrayWithCapacity:(NSInteger)c;

- (NSMutableArray *) createArrayCopy;
- (NSMutableArray *) lockCreateArrayCopyFromObjects;
- (NSMutableArray *) createArrayCopyFromObjects;
- (void) addObject:(id)o;
- (void) addObjectsFromArray:(id)a;
- (void) replaceWithObjectsFromArray:(id)a;
- (BOOL) insertObject:(id)o atIndex:(NSInteger)i;
- (id) lastObject;
- (void) removeObject:(id)o;
- (BOOL) containsObject:(id)o;
- (id) objectAtIndex:(NSInteger)i;
- (NSArray *) objectsAtIndexes:(NSIndexSet *)indexes;
- (NSInteger) indexOfObject:(id)o;
- (BOOL) containsIdenticalPtr:(id)o;
- (long) indexOfIdenticalPtr:(id)o;
- (void) removeIdenticalPtr:(id)o;

///	NO by default.  if YES, the ObjectHolder instances created by this class will use Mike Ash's zeroing weak reference object instead of just storing a simple weak reference.  this is generally safer, and isn't really much slower.
@property (assign,readwrite) BOOL zwrFlag;

//	these methods exist because the lookup cost for an ObjectHolder can be significant for high-performance applications- these methods get the object from the ObjectHolder and call the method directly on it!
- (void) bruteForceMakeObjectsPerformSelector:(SEL)s;
- (void) lockBruteForceMakeObjectsPerformSelector:(SEL)s;
- (void) bruteForceMakeObjectsPerformSelector:(SEL)s withObject:(id)o;
- (void) lockBruteForceMakeObjectsPerformSelector:(SEL)s withObject:(id)o;

- (void) lockPurgeEmptyHolders;
- (void) purgeEmptyHolders;


@end

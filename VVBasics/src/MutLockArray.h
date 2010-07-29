
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <pthread.h>



///	Similar to NSMutableArray, but thread-safe.  Internally, uses an NSMutableArray and a rwlock.
/*
This class exists because NSMutableArray is not thread-safe by default: if you call methods on it from two different threads at the same time, it will try to execute both, often crashing in the process.  I found myself writing a lot of lock/array pairs, so simplified everything by combining them into a single class.  MutLockArray has methods which allow you to work with a mutable array in a transparent and thread-safe manner- it will automatically establish the read-/write-locks necessary to perform the relevant task.  By avoiding the "lock" methods, you can also work with the array without performing any locking- so you can get a read-/write-lock, perform a number of actions, and then unlock.

It is important to remember, when working with it, that MutLockArray is NOT a subclass of NSMutableArray; rather, it is a subclass of NSObject with an instance of an NSMutableArray and a rwlock for working with it safely.  This means that you can't pass an instance of MutLockArray to anything which is expecting to be passed an NSMutableArray- internally, apple's frameworks will probably be doing some dark voodoo bullshit which will result in a spectacular failure.  If you want to work with an actual NSMutableArray, check out the "array", "createArrayCopy", and "lockCreateArrayCopy" methods below.

...and remember- when looking for stuff in an NSMutableArray, the array will use the "isEqualTo:" comparator method, which is slower than comparing the address of two pointers.  if you know the pointer address hasn't changed (if you're *not* working with NSStrings), use the "indexOfIdenticalPtr", "removeIdenticalPtr", etc. methods to work with the array.
*/

@interface MutLockArray : NSObject {
	NSMutableArray			*array;
	pthread_rwlock_t		arrayLock;
}

///	Creates and returns an auto-released MutLockArray with a given capacity.  The capacity may be 0.
+ (id) arrayWithCapacity:(NSUInteger)c;
///	Inits and returns a MutLockArray with a given capacity; the capacity may be 0.
- (id) initWithCapacity:(NSUInteger)c;
- (id) init;

///	Establishes a read-lock for the array; multiple read locks may exist simultaneously (if it's not changing, anything can look at the contents of the array).  This method does not return until it has been able to get the lock.
- (void) rdlock;
///	Establishes a write-lock for the array.  Only one write-lock may exist at any given time, and all read-locks must be relinquished before the write-lock may be established (if you're going to change the array, nothing else can be changing or observing it).
- (void) wrlock;
///	Unlocks the array.
- (void) unlock;

///	Returns the NSMutableArray with everything in it.  This returns the actual array, so be careful- it's possible to do something which ISN'T threadsafe with this...
- (NSMutableArray *) array;
///	Returns an NSMutableArray which was created by calling "mutableCopy" on my array.  Again, it's possible to do something which ISN'T threadsafe by calling this...
- (NSMutableArray *) createArrayCopy;
///	Returns an NSMutableArray which was created while a read-lock was established; this is threadsafe.
- (NSMutableArray *) lockCreateArrayCopy;

///	Calls "addObject" on my array; not threadsafe.
- (void) addObject:(id)o;
///	Establishes a write-lock, then calls "addObject" on self; threadsafe.
- (void) lockAddObject:(id)o;
///	Calls "addObjectsFromArray" on my array; not threadsafe.
- (void) addObjectsFromArray:(id)a;
///	Establishes a write-lock, then calls "addObjectsFromArray" on self; threadsafe.
- (void) lockAddObjectsFromArray:(id)a;
///	Calls "addObjectsFromArray" on my array; not threadsafe.
- (void) replaceWithObjectsFromArray:(id)a;
///	Establishes a write-lock, then calls "replaceWithObjectsFromArray" on self; threadsafe.
- (void) lockReplaceWithObjectsFromArray:(id)a;
///	Calls "insertObject:atIndex:" on my array; not threadsafe.
- (void) insertObject:(id)o atIndex:(NSUInteger)i;
///	Establishes a write-lock, then calls "insertObject:atIndex:" on self; threadsafe.
- (void) lockInsertObject:(id)o atIndex:(NSUInteger)i;
///	Calls "removeAllObjects" on my array; not threadsafe.
- (void) removeAllObjects;
///	Establishes a write-lock, then calls "removeAllObjects" on self; threadsafe.
- (void) lockRemoveAllObjects;
///	Calls "objectAtIndex:0" on my array; not threadsafe.
- (id) firstObject;
///	Establishes a read-lock, then calls "firstObject" on self; threadsafe
- (id) lockFirstObject;
///	Calls "removeObjectAtIndex:0" on my array; not threadsafe
- (void) removeFirstObject;
///	Establishes a write-lock, then calls "removeFirstObject" on self; threadsafe.
- (void) lockRemoveFirstObject;
///	Calls "lastObject" on my array; not threadsafe.
- (id) lastObject;
///	Establishes a read-lock, then calls "lastObject" on self; threadsafe.
- (id) lockLastObject;
///	Calls "removeLastObject" on my array; not threadsafe.
- (void) removeLastObject;
///	Establishes a write-lock, then calls "removeLastObject" on self; threadsafe.
- (void) lockRemoveLastObject;
///	Calls "removeObject:" on my array; not threadsafe.
- (void) removeObject:(id)o;
///	Establishes a write-lock, then calls "removeObject:" on self; threadsafe.
- (void) lockRemoveObject:(id)o;
///	Calls "removeObjectAtIndex:" on my array; not threadsafe.
- (void) removeObjectAtIndex:(NSUInteger)i;
///	Establishes a write-lock, then calls "removeObjectAtIndex:" on self; threadsafe.
- (void) lockRemoveObjectAtIndex:(NSUInteger)i;
///	Calls "removeObjectsAtIndexes:" on my array; not threadsafe.
- (void) removeObjectsAtIndexes:(NSIndexSet *)i;
///	Establishes a write-lock, then calls "removeObjectsAtIndexes:" on self; threadsafe.
- (void) lockRemoveObjectsAtIndexes:(NSIndexSet *)i;
///	Calls "removeObjectsInArray:" on my array; not threadsafe.
- (void) removeObjectsInArray:(NSArray *)otherArray;
///	Establishes a write-lock, then calls "removeObjectsInArray:" on self; threadsafe.
- (void) lockRemoveObjectsInArray:(NSArray *)otherArray;
///	Calls "removeIdenticalPtrsInArray:" on my array; not threadsafe
- (void) removeIdenticalPtrsInArray:(NSArray *)a;
///	Establishes a write-lock, then calls "removeIdenticalPtrsInArray:" on self; threadsafe.
- (void) lockRemoveIdenticalPtrsInArray:(NSArray *)a;

///	Calls "replaceObjectsAtIndexes:withObjects" on my array; not threadsafe.
- (void) replaceObjectsAtIndexes:(NSIndexSet *)indexes withObjects:(NSArray *)objects;
//	Establishes a write-lock, then calls "replaceObjectsAtIndexes:withObjects on self; threadsafe
- (void) lockReplaceObjectsAtIndexes:(NSIndexSet *)indexes withObjects:(NSArray *)objects;

///	Calls "valueForKey:" on my array; not threadsafe.
- (id) valueForKey:(NSString *)key;
///	Establishes a read-lock, then calls "valueForKey:" on self; threadsafe.
- (id) lockValueForKey:(NSString *)key;


///	Calls "containsObject:" on my array; not threadsafe.
- (BOOL) containsObject:(id)o;
///	Establishes a read-lock, then calls "containsObject:" on self; threadsafe.
- (BOOL) lockContainsObject:(id)o;
///	Calls "objectAtIndex:" on my array; not threadsafe.
- (id) objectAtIndex:(NSUInteger)i;
///	Establishes a read-lock, then calls "objectAtIndex:" on self; threadsafe.
- (id) lockObjectAtIndex:(NSUInteger)i;
///	Calls "objectsAtIndexes:" on my array; not threadsafe.
- (NSArray *) objectsAtIndexes:(NSIndexSet *)indexes;
///	Establishes a read-lock, then calls "objectsAtIndexes:" on self; threadsafe.
- (NSArray *) lockObjectsAtIndexes:(NSIndexSet *)indexes;
///	Calls "indexOfObject:" on my array; not threadsafe.
- (NSUInteger) indexOfObject:(id)o;
///	Establishes a read-lock, then calls "indexOfObject:" on self; threadsafe.
- (NSUInteger) lockIndexOfObject:(id)o;


///	Enumerates through my array- compares the address of each item in the array to the passed pointer.  Unlike NSMutableArray, this method does NOT call isEqualTo:, it's just a simple == operator.
- (BOOL) containsIdenticalPtr:(id)o;
///	Establishes a read-lock, then calls "containsIdenticalPtr:" on self; threadsafe.
- (BOOL) lockContainsIdenticalPtr:(id)o;
///	Enumerates through my array- compares the address of each item in the array to the passed pointer.  Unlike NSMutableArray, this method does NOT call isEqualTo:, it's just a simple == operator.
- (int) indexOfIdenticalPtr:(id)o;
///	Establishes a read-lock, then calls "indexOfIdenticalPtr:" on self; threadsafe.
- (int) lockIndexOfIdenticalPtr:(id)o;
///	Locates an item in my array by enumerating through it and comparing the address of each item in the array to the passed ptr, and then deletes the matching item from the array; not threadsafe.
- (void) removeIdenticalPtr:(id)o;
///	Establishes a write-lock, then calls "removeIdenticalPtr:" on self; threadsafe.
- (void) lockRemoveIdenticalPtr:(id)o;

//	Calls "filteredArrayUsingPredicate:" on my array; not threadsafe
- (NSArray *)filteredArrayUsingPredicate:(NSPredicate *)predicate;
//	Establishes a read-lock, then calls "filteredArrayUsingPredicate:" on self; threadsafe
- (NSArray *) lockFilteredArrayUsingPredicate:(NSPredicate *)predicate;

///	Calls "makeObjectsPerformSelector:" on my array; not threadsafe.
- (void) makeObjectsPerformSelector:(SEL)s;
///	Establishes a read-lock, then calls "makeObjectsPerformSelector:" on self; threadsafe.
- (void) lockMakeObjectsPerformSelector:(SEL)s;
///	Calls "makeObjectsPerformSelector:withObject:" on my array; not threadsafe.
- (void) makeObjectsPerformSelector:(SEL)s withObject:(id)o;
///	Establishes a read-lock, then calls "makeObjectsPerformSelector:withObject:" on self; threadsafe.
- (void) lockMakeObjectsPerformSelector:(SEL)s withObject:(id)o;



/*
- (void) makeCopyPerformSelector:(SEL)s;
- (void) lockMakeCopyPerformSelector:(SEL)s;
- (void) makeCopyPerformSelector:(SEL)s withObject:(id)o;
- (void) lockMakeCopyPerformSelector:(SEL)s withObject:(id)o;
*/



///	Calls "sortUsingSelector:" on my array; not threadsafe.
- (void) sortUsingSelector:(SEL)s;
///	Establishes a write-lock, then calls "sortUsingSelector:" on self; threadsafe.
- (void) lockSortUsingSelector:(SEL)s;

///	Calls "sortUsingDescriptors:" on my array; not threadsafe.
- (void) sortUsingDescriptors:(NSArray *)descriptors;
///	Establishes a write-lock, then calls "sortUsingDescriptors:" on self; threadsafe.
- (void) lockSortUsingDescriptors:(NSArray *)descriptors;

- (NSEnumerator *) objectEnumerator;
- (NSEnumerator *) reverseObjectEnumerator;
- (NSUInteger) count;
- (NSUInteger) lockCount;

@end

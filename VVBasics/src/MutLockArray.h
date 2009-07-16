
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <pthread.h>




@interface MutLockArray : NSObject {
	NSMutableArray			*array;
	pthread_rwlock_t		arrayLock;
}

+ (id) arrayWithCapacity:(NSUInteger)c;
- (id) initWithCapacity:(NSUInteger)c;
- (id) init;

- (void) rdlock;
- (void) wrlock;
- (void) unlock;

- (NSMutableArray *) array;
- (NSMutableArray *) createArrayCopy;
- (NSMutableArray *) lockCreateArrayCopy;

- (void) addObject:(id)o;
- (void) lockAddObject:(id)o;
- (void) addObjectsFromArray:(id)a;
- (void) lockAddObjectsFromArray:(id)a;
- (void) replaceWithObjectsFromArray:(id)a;
- (void) lockReplaceWithObjectsFromArray:(id)a;
- (void) insertObject:(id)o atIndex:(NSUInteger)i;
- (void) lockInsertObject:(id)o atIndex:(NSUInteger)i;
- (void) removeAllObjects;
- (void) lockRemoveAllObjects;
- (id) lastObject;
- (id) lockLastObject;
- (void) removeLastObject;
- (void) lockRemoveLastObject;
- (void) removeObject:(id)o;
- (void) lockRemoveObject:(id)o;
- (void) removeObjectAtIndex:(NSUInteger)i;
- (void) lockRemoveObjectAtIndex:(NSUInteger)i;
- (void) removeObjectsAtIndexes:(NSIndexSet *)i;
- (void) lockRemoveObjectsAtIndexes:(NSIndexSet *)i;
- (void) removeObjectsInArray:(NSArray *)otherArray;
- (void) lockRemoveObjectsInArray:(NSArray *)otherArray;
- (id) valueForKey:(NSString *)key;
- (id) lockValueForKey:(NSString *)key;

- (BOOL) containsObject:(id)o;
- (BOOL) lockContainsObject:(id)o;

- (id) objectAtIndex:(NSUInteger)i;
- (id) lockObjectAtIndex:(NSUInteger)i;

- (NSArray *) objectsAtIndexes:(NSIndexSet *)indexes;
- (NSArray *) lockObjectsAtIndexes:(NSIndexSet *)indexes;

- (NSUInteger) indexOfObject:(id)o;
- (NSUInteger) lockIndexOfObject:(id)o;

- (BOOL) containsIdenticalPtr:(id)o;
- (BOOL) lockContainsIdenticalPtr:(id)o;
- (int) indexOfIdenticalPtr:(id)o;
- (int) lockIndexOfIdenticalPtr:(id)o;
- (void) removeIdenticalPtr:(id)o;
- (void) lockRemoveIdenticalPtr:(id)o;

- (void) makeObjectsPerformSelector:(SEL)s;
- (void) lockMakeObjectsPerformSelector:(SEL)s;
- (void) makeObjectsPerformSelector:(SEL)s withObject:(id)o;
- (void) lockMakeObjectsPerformSelector:(SEL)s withObject:(id)o;

- (void) makeCopyPerformSelector:(SEL)s;
- (void) lockMakeCopyPerformSelector:(SEL)s;
- (void) makeCopyPerformSelector:(SEL)s withObject:(id)o;
- (void) lockMakeCopyPerformSelector:(SEL)s withObject:(id)o;

- (void) sortUsingSelector:(SEL)s;
- (void) lockSortUsingSelector:(SEL)s;

- (NSEnumerator *) objectEnumerator;
- (NSEnumerator *) reverseObjectEnumerator;
- (NSUInteger) count;
- (NSUInteger) lockCount;

@end

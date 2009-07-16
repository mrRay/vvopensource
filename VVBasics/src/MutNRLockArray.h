
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "MutLockArray.h"
#import "ObjectHolder.h"




/*
	instead of adding (and therefore retaining) objects to an array
	like my superclass, this class makes an ObjectHolder for objects
	which are added to it (so they don't get retained), and adds the
	ObjectHolder to me
*/




@interface MutNRLockArray : MutLockArray {

}

+ (id) arrayWithCapacity:(NSUInteger)c;

- (void) addObject:(id)o;
- (void) addObjectsFromArray:(id)a;
- (void) replaceWithObjectsFromArray:(id)a;
- (void) insertObject:(id)o atIndex:(NSUInteger)i;
- (id) lastObject;
- (void) removeObject:(id)o;
- (BOOL) containsObject:(id)o;
- (id) objectAtIndex:(NSUInteger)i;
- (NSArray *) objectsAtIndexes:(NSIndexSet *)indexes;
- (NSUInteger) indexOfObject:(id)o;
- (BOOL) containsIdenticalPtr:(id)o;
- (int) indexOfIdenticalPtr:(id)o;
- (void) removeIdenticalPtr:(id)o;

@end

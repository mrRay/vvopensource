
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <pthread.h>



///	MutLockDict is a thread-safe version of NSMutableDictionary.
/*!
\ingroup VVBasics
This class exists because NSMutableDictionary is not thread-safe by default: if you call methods on it from two different threads at the same time, it will try to execute both, often crashing in the process.  This class has methods which allow you to work with a mutable dictionary in a transparent and thread-safe manner.
*/

@interface MutLockDict : NSObject {
	NSMutableDictionary		*dict;
	pthread_rwlock_t		dictLock;
}

///	functions similarly to the NSDictionary method
+ (id) dictionaryWithCapacity:(NSInteger)c;
///	functions similarly to the NSDictionary method- creates and returns an auto-released instance of MutLockDict populated with the contents of the passed dictionary
+ (id) dictionaryWithDict:(NSDictionary *)d;
///	functions similarly to the NSDictionary method- inits a MutLockDict with the supplied capacity
- (id) initWithCapacity:(NSInteger)c;

///	blocks until it can establish a read-lock on the array, and then returns.  try to avoid calling this- using the built-in methods (which unlock before they return) is generally preferable/safer!
- (void) rdlock;
///	blocks until it can establish a write-lock on the array, and then returns.  try to avoid calling this- using the built-in methods (which unlock before they return) is generally preferable/safer!
- (void) wrlock;
///	unlocks and returns immediately
- (void) unlock;

///	returns the NSMutableDictionary used as the basis for this class- useful if you want to use fast iteration/that sort of thing
- (NSMutableDictionary *) dict;
///	creates a mutable, autoreleased copy of the dict and returns it.  be careful, this method isn't threadsafe!
- (NSMutableDictionary *) createDictCopy;
///	creates a mutable, autoreleased copy of the dict and returns it.  this method is threadsafe.
- (NSMutableDictionary *) lockCreateDictCopy;

///	functions similar to the NSDictionary method, but checks to make sure you aren't trying to insert a nil value or use a nil key.  not threadsafe!
- (void) setObject:(id)o forKey:(NSString *)s;
///	establishes a write-lock, then calls setObject:forKey:.  threadsafe.
- (void) lockSetObject:(id)o forKey:(NSString *)s;
///	functions similar to the NSDictionary method- not threadsafe
- (void) setValue:(id)v forKey:(NSString *)s;
///	establishes a write-lock, then calls setValue:forKey:.  threadsafe.
- (void) lockSetValue:(id)v forKey:(NSString *)s;
///	removes all objects from the underlying dict- not threadsafe
- (void) removeAllObjects;
///	establishes a write-lock, then removes all objects from the underlying dict.  threadsafe.
- (void) lockRemoveAllObjects;
///	returns the object stored in the underlying dict at the passed key- not threadsafe
- (id) objectForKey:(NSString *)k;
///	establihes a read-lock, then returns the object stored in the underlying dict at the passed key.  threadsafe.
- (id) lockObjectForKey:(NSString *)k;
///	attempts to remove any object stored in the underlying dict at the passed key- not threadsafe.
- (void) removeObjectForKey:(NSString *)k;
///	establishes a write-lock, then removes any object stored in the underlying dict at the passed key.  threadsafe.
- (void) lockRemoveObjectForKey:(NSString *)k;
///	adds all entries from the passed dict to the receiver's underlying dictionary- not threadsafe.
- (void) addEntriesFromDictionary:(NSDictionary *)otherDictionary;
///	establishes a write-lock, then calls "addEntriesFromDictionary:".  threadsafe.
- (void) lockAddEntriesFromDictionary:(NSDictionary *)otherDictionary;
///	returns an array with all the keys from the underlying dictionary- not threadsafe
- (NSArray *) allKeys;
///	establishes a read-lock, then calls "allKeys".  threadsafe.
- (NSArray *) lockAllKeys;
///	returns an array with all the values from the underlying dictionary- not threadsafe.
- (NSArray *) allValues;
///	establishes a read-lock, then calls "allValues".  threadsafe.
- (NSArray *) lockAllValues;

///	calls "makeObjectsPerformSelector" on the array of values returned by the underlying dictionary- not threadsafe.
- (void) makeObjectsPerformSelector:(SEL)s;
///	establishes a read-lock, then calls "makeObjectsPerformSelector:".  threadsafe.
- (void) lockMakeObjectsPerformSelector:(SEL)s;

///	returns the number of objects in the underlying dictionary- not threadsafe.
- (NSInteger) count;
///	establishes a read-lock, then returns the number of objects in the underlying dictionary.  threadsafe.
- (NSInteger) lockCount;

@end

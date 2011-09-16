
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <pthread.h>



///	MutLockDict is a thread-safe version of NSMutableDictionary.
/*!
This class exists because NSMutableDictionary is not thread-safe by default: if you call methods on it from two different threads at the same time, it will try to execute both, often crashing in the process.  This class has methods which allow you to work with a mutable dictionary in a transparent and thread-safe manner.
*/

@interface MutLockDict : NSObject {
	NSMutableDictionary		*dict;
	pthread_rwlock_t		dictLock;
}

+ (id) dictionaryWithCapacity:(NSUInteger)c;
- (id) initWithCapacity:(NSUInteger)c;

- (void) rdlock;
- (void) wrlock;
- (void) unlock;

- (NSMutableDictionary *) dict;
- (NSMutableDictionary *) createDictCopy;
- (NSMutableDictionary *) lockCreateDictCopy;

- (void) setObject:(id)o forKey:(NSString *)s;
- (void) lockSetObject:(id)o forKey:(NSString *)s;
- (void) setValue:(id)v forKey:(NSString *)s;
- (void) lockSetValue:(id)v forKey:(NSString *)s;
- (void) removeAllObjects;
- (void) lockRemoveAllObjects;
- (id) objectForKey:(NSString *)k;
- (id) lockObjectForKey:(NSString *)k;
- (void) removeObjectForKey:(NSString *)k;
- (void) lockRemoveObjectForKey:(NSString *)k;
- (void) addEntriesFromDictionary:(NSDictionary *)otherDictionary;
- (void) lockAddEntriesFromDictionary:(NSDictionary *)otherDictionary;
- (NSArray *) allKeys;
- (NSArray *) lockAllKeys;
- (NSArray *) allValues;
- (NSArray *) lockAllValues;

- (void) lockMakeObjectsPerformSelector:(SEL)s;
- (void) makeObjectsPerformSelector:(SEL)s;

- (NSUInteger) count;
- (NSUInteger) lockCount;

@end

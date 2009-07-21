
#import <Cocoa/Cocoa.h>
#import <pthread.h>




/*
	this class exists because NSMutableDictionary is not thread-safe by default: if you 
	call methods on it from two different threads at the same time, it will try to 
	execute both, often crashing in the process.  this class has methods which 
	allow you to work with a mutable dictionary in a transparent and thread-safe manner.
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
- (NSArray *) allKeys;
- (NSArray *) lockAllKeys;

@end

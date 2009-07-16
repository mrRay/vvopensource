
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <pthread.h>




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

#import <Foundation/Foundation.h>
#import <VVBasics/VVBasics.h>
#import <sys/types.h>
#import <sys/event.h>
#import <pthread.h>




/*

let's give credit where credit's due:

i learned how kqueues work by reading stuff online and looking at other
peoples' uses of kqueues.  this class (and my understanding of kqueues)
was shaped significantly by the "UKKQueue" class, by M. Uli Kusterer.

if you don't want to write your own cocoa implementation of kqueues, you
should really look for this class- it's well-written, does much more than
this paltry, bare-bones implementation, and is highly functional.

thanks, Uli!

*/




@protocol VVKQueueCenterDelegate
- (void) file:(NSString *)p changed:(u_int)fflag;
@end




extern id			_mainVVKQueueCenter;




@interface VVKQueueCenter : NSObject	{
	int				kqueueFD;
	
	MutLockArray	*entries;	//	stores the entries that the center is currently observing
	MutLockArray	*entryChanges;	//	stores changes to the entries (changes are accumulated here and then applied on a specific thread)
	
	BOOL			threadHaltFlag;
	BOOL			currentlyProcessing;
}

+ (id) mainCenter;

+ (void) addObserver:(id)o forPath:(NSString *)p;
+ (void) removeObserver:(id)o;
+ (void) removeObserver:(id)o forPath:(NSString *)p;

- (void) addObserver:(id)o forPath:(NSString *)p;
- (void) removeObserver:(id)o;
- (void) removeObserver:(id)o forPath:(NSString *)p;

@end






@interface VVKQueueEntry : NSObject	{
	NSString		*path;
	NSNumber		*fd;
	OSSpinLock		delegateLock;
	ObjectHolder	*delegate;
	
	BOOL			addFlag;	//	used to indicate if we want to add or remove this entry- ignored once the entry is stored in the 'entries' array in the center
}

+ (id) createWithDelegate:(id<VVKQueueCenterDelegate>)d path:(NSString *)p;
- (id) initWithDelegate:(id<VVKQueueCenterDelegate>)d path:(NSString *)p;

@property (retain,readwrite) NSString *path;
@property (retain,readwrite,setter=setFD:) NSNumber *fd;
@property (assign,readwrite) id<VVKQueueCenterDelegate> delegate;
@property (assign,readwrite) BOOL addFlag;

@end


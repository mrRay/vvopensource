#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import <VVBasics/VVBasics.h>
#import <VVOSC/OSCZeroConfDomain.h>
#import <pthread.h>




#if TARGET_OS_IPHONE
@interface OSCZeroConfManager : NSObject <NSNetServiceBrowserDelegate> {
#else
@interface OSCZeroConfManager : NSObject {
#endif
	NSNetServiceBrowser		*domainBrowser;
	
	NSMutableDictionary		*domainDict;
	pthread_rwlock_t		domainLock;
	
	id						oscManager;
    
    NSString                *serviceTypeString;
}

- (instancetype) initWithOSCManager:(id)m serviceType:(NSString *)t;

- (void) serviceRemoved:(NSNetService *)s;
- (void) serviceResolved:(NSNetService *)s;

//	NSNetServiceBrowser delegate methods
- (void)netServiceBrowser:(NSNetServiceBrowser *)n didFindDomain:(NSString *)d moreComing:(BOOL)m;
- (void)netServiceBrowser:(NSNetServiceBrowser *)n didNotSearch:(NSDictionary *)err;

@end

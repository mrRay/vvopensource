//
//  OSCZeroConfDomain.m
//  VVOSC
//
//  Created by bagheera on 12/9/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCZeroConfDomain.h"
#import "OSCZeroConfManager.h"




@implementation OSCZeroConfDomain


+ (id) createWithDomain:(NSString *)d andDomainManager:(id)m	{
	if ((d == nil) || (m == nil))
		return nil;
	OSCZeroConfDomain		*returnMe = nil;
	returnMe = [[OSCZeroConfDomain alloc] initWithDomain:d andDomainManager:m];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithDomain:(NSString *)d andDomainManager:(id)m	{
	if ((d == nil) || (m == nil))
		goto BAIL;
	
	//pthread_rwlockattr_t		attr;
	
	if (self = [super init])	{
		domainString = [d copy];
		
		servicesArray = [[MutLockArray arrayWithCapacity:0] retain];
		domainManager = nil;
		
		//pthread_rwlockattr_init(&attr);
		//pthread_rwlockattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
		//pthread_rwlock_init(&servicesLock, &attr);
		
		domainManager = m;
		
		serviceBrowser = [[NSNetServiceBrowser alloc] init];
		[serviceBrowser setDelegate:self];
		[serviceBrowser searchForServicesOfType:@"_osc._udp" inDomain:domainString];
		
		return self;
	}
	
	BAIL:
	[self release];
	return nil;
}

- (void) dealloc	{
	domainManager = nil;
	//pthread_rwlock_destroy(&servicesLock);
	if (domainString != nil)	{
		[domainString release];
		domainString = nil;
	}
	if (serviceBrowser != nil)	{
		[serviceBrowser stop];
		[serviceBrowser release];
		serviceBrowser = nil;
	}
	if (servicesArray != nil)	{
		[servicesArray release];
		servicesArray = nil;
	}
	[super dealloc];
}




//	NSNetServiceBrowser delegate methods
- (void)netServiceBrowser:(NSNetServiceBrowser *)n didFindService:(NSNetService *)x moreComing:(BOOL)m	{
	//NSLog(@"%s",__func__);
	if (x != nil)	{
		//pthread_rwlock_wrlock(&servicesLock);
			[servicesArray lockAddObject:x];
			[x setDelegate:self];
			[x resolveWithTimeout:10];
		//pthread_rwlock_wrlock(&servicesLock);
	}
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)n didNotSearch:(NSDictionary *)err	{
	//NSLog(@"%s ... %@",__func__,err);
	NSLog(@"\t\terr, didn't search: %@",err);
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)n didRemoveService:(NSNetService *)s moreComing:(BOOL)m	{
	//NSLog(@"%s",__func__);
	//	tell the domainManager the service is being removed
	if (domainManager != nil)	{
		[domainManager serviceRemoved:s];
	}
	//	remove the object from the array
	//pthread_rwlock_wrlock(&servicesLock);
		[servicesArray lockRemoveObject:n];
	//pthread_rwlock_unlock(&servicesLock);
}




//	NSNetService delegate methods
- (void)netService:(NSNetService *)n didNotResolve:(NSDictionary *)err	{
	//NSLog(@"%s",__func__);
	NSLog(@"\t\terr resolving domain: %@",err);
	//	tell the net service to stop
	[n stop];
	//	remove the service from the array
	//pthread_rwlock_wrlock(&servicesLock);
		[servicesArray lockRemoveObject:n];
	//pthread_rwlock_unlock(&servicesLock);
}
- (void)netServiceDidResolveAddress:(NSNetService *)n	{
	//NSLog(@"%s",__func__);
	//	tell the net service to stop, since it's resolved the address
	[n stop];
	//	tell the domainManager about the resolved service
	if (domainManager!=nil)	{
		[domainManager serviceResolved:n];
	}
}


@end

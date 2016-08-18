#import "SyphonVideoSource.h"
#import "SyphonVVBufferPoolAdditions.h"




@implementation SyphonVideoSource


/*===================================================================================*/
#pragma mark --------------------- init/dealloc
/*------------------------------------*/


- (id) init	{
	if (self = [super init])	{
		//	register for notifications when syphon servers change
		for (NSString *notificationName in [NSArray arrayWithObjects:SyphonServerAnnounceNotification, SyphonServerUpdateNotification, SyphonServerRetireNotification,nil]) {
			[[NSNotificationCenter defaultCenter]
				addObserver:self
				selector:@selector(syphonServerChangeNotification:)
				name:notificationName
				object:nil];
		}
		return self;
	}
	[self release];
	return nil;
}
- (void) prepareToBeDeleted	{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super prepareToBeDeleted];
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- superclass overrides
/*------------------------------------*/


- (NSArray *) arrayOfSourceMenuItems	{
	NSMutableArray				*returnMe = nil;
	SyphonServerDirectory		*sd = [SyphonServerDirectory sharedDirectory];
	NSArray						*servers = (sd==nil) ? nil : [sd servers];
	if (servers != nil)	{
		for (NSDictionary *serverDict in servers)	{
			if (returnMe == nil)
				returnMe = MUTARRAY;
			NSString		*serverName = [NSString stringWithFormat:@"%@-%@",[serverDict objectForKey:SyphonServerDescriptionAppNameKey],[serverDict objectForKey:SyphonServerDescriptionNameKey]];
			NSMenuItem		*tmpItem = [[NSMenuItem alloc] initWithTitle:serverName action:nil keyEquivalent:@""];
			[tmpItem setRepresentedObject:serverDict];
			[returnMe addObject:tmpItem];
			[tmpItem release];
		}
	}
	return returnMe;
}
- (void) _stop	{
	VVRELEASE(propClient);
}
- (VVBuffer *) allocBuffer	{
	VVBuffer		*newBuffer = nil;
	
	OSSpinLockLock(&propLock);
	if (propClient!=nil && [propClient hasNewFrame])	{
		newBuffer = [_globalVVBufferPool allocBufferForSyphonClient:propClient];
	}
	OSSpinLockUnlock(&propLock);
	
	return newBuffer;
}


/*===================================================================================*/
#pragma mark --------------------- misc
/*------------------------------------*/


- (void) loadServerWithServerDescription:(NSDictionary *)n	{
	if ([self propRunning])
		[self stop];
	if (n==nil)
		return;
	
	OSSpinLockLock(&propLock);
	propClient = [[SyphonClient alloc]
		initWithServerDescription:n
		options:nil
		newFrameHandler:nil];
	OSSpinLockUnlock(&propLock);
	
	[self start];
}
- (void) syphonServerChangeNotification:(NSNotification *)note	{
	//NSLog(@"%s",__func__);
	id			localDelegate = nil;
	OSSpinLockLock(&propLock);
	localDelegate = (propDelegate==nil) ? nil : [(id)propDelegate retain];
	OSSpinLockUnlock(&propLock);
	
	if (localDelegate != nil)	{
		[localDelegate listOfStaticSourcesUpdated:self];
		[localDelegate release];
		localDelegate = nil;
	}
}


@end

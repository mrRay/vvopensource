#import "QCVideoSource.h"




@implementation QCVideoSource


/*===================================================================================*/
#pragma mark --------------------- init/dealloc
/*------------------------------------*/


- (id) init	{
	if (self = [super init])	{
		propScene = nil;
		return self;
	}
	[self release];
	return nil;
}
- (void) prepareToBeDeleted	{
	[super prepareToBeDeleted];
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	VVLockLock(&propLock);
	VVRELEASE(propScene);
	VVLockUnlock(&propLock);
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- superclass overrides
/*------------------------------------*/


- (void) loadFileAtPath:(NSString *)p	{
	NSFileManager	*fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:p])
		return;
	[self stop];
	
	VVLockLock(&propLock);
	VVRELEASE(propPath);
	propPath = [p retain];
	VVLockUnlock(&propLock);
	
	[self start];
}
- (void) _stop	{
	VVRELEASE(propScene);
}
- (VVBuffer *) allocBuffer	{
	VVBuffer		*returnMe = nil;
	VVLockLock(&propLock);
	if (propPath != nil)	{
		VVRELEASE(propScene);
		//propScene = [[QCGLScene alloc] initWithSharedContext:[_globalVVBufferPool sharedContext] sized:NSMakeSize(1920,1080)];
		propScene = [[QCGLScene alloc] initCommonBackendSceneSized:NSMakeSize(1920,1080)];
		[propScene useFile:propPath];
		VVRELEASE(propPath);
	}
	returnMe = (propScene==nil) ? nil : [propScene allocAndRenderABuffer];
	VVLockUnlock(&propLock);
	return returnMe;
}
- (NSArray *) arrayOfSourceMenuItems	{
	NSMutableArray		*returnMe = MUTARRAY;
	NSArray				*fileNames = @[@"Cube Array", @"Blue"];
	NSBundle			*mb = [NSBundle mainBundle];
	for (NSString *fileName in fileNames)	{
		NSMenuItem		*newItem = [[NSMenuItem alloc] initWithTitle:fileName action:nil keyEquivalent:@""];
		NSString		*filePath = [mb pathForResource:fileName ofType:@"qtz"];
		NSURL			*fileURL = [NSURL fileURLWithPath:filePath];
		[newItem setRepresentedObject:fileURL];
		[returnMe addObject:newItem];
		[newItem release];
	}
	return returnMe;
}


@end

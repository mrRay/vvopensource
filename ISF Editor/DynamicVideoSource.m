#import "DynamicVideoSource.h"




@implementation DynamicVideoSource


/*===================================================================================*/
#pragma mark --------------------- init/dealloc
/*------------------------------------*/


- (id) init	{
	if (self = [super init])	{
		deleted = NO;
		srcLock = OS_SPINLOCK_INIT;
		srcMode = SrcMode_None;
		lastBufferLock = OS_SPINLOCK_INIT;
		lastBuffer = nil;
		
		vidInSrc = [[AVCaptureVideoSource alloc] init];
		movSrc = [[MovieFileVideoSource alloc] init];
		qcSrc = [[QCVideoSource alloc] init];
		imgSrc = [[IMGVideoSource alloc] init];
		syphonSrc = [[SyphonVideoSource alloc] init];
		
		[vidInSrc setPropDelegate:self];
		[movSrc setPropDelegate:self];
		[qcSrc setPropDelegate:self];
		[imgSrc setPropDelegate:self];
		[syphonSrc setPropDelegate:self];
		
		NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(reloadCaptureSourcesNotification:) name:AVCaptureDeviceWasConnectedNotification object:nil];
		[nc addObserver:self selector:@selector(reloadCaptureSourcesNotification:) name:AVCaptureDeviceWasDisconnectedNotification object:nil];
		return self;
	}
	[self release];
	return nil;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(vidInSrc);
	VVRELEASE(movSrc);
	VVRELEASE(qcSrc);
	VVRELEASE(imgSrc);
	VVRELEASE(syphonSrc);
	[super dealloc];
}
- (void) prepareToBeDeleted	{
	[vidInSrc prepareToBeDeleted];
	[movSrc prepareToBeDeleted];
	[qcSrc prepareToBeDeleted];
	[imgSrc prepareToBeDeleted];
	[syphonSrc prepareToBeDeleted];
	deleted = YES;
}


/*===================================================================================*/
#pragma mark --------------------- frontend methods
/*------------------------------------*/


- (void) loadVidInWithUniqueID:(NSString *)u	{
	//NSLog(@"%s ... %@",__func__,u);
	if ([self srcMode]!=SrcMode_VidIn)
		[self _useMode:SrcMode_VidIn];
	[vidInSrc loadDeviceWithUniqueID:u];
}
- (void) loadMovieAtPath:(NSString *)p	{
	//NSLog(@"%s ... %@",__func__,p);
	if ([self srcMode]!=SrcMode_AVFMov)
		[self _useMode:SrcMode_AVFMov];
	[movSrc loadFileAtPath:p];
}
- (void) loadQCCompAtPath:(NSString *)p	{
	//NSLog(@"%s ... %@",__func__,p);
	if ([self srcMode]!=SrcMode_QC)
		[self _useMode:SrcMode_QC];
	[qcSrc loadFileAtPath:p];
}
- (void) loadImgAtPath:(NSString *)p	{
	//NSLog(@"%s ... %@",__func__,p);
	if ([self srcMode]!=SrcMode_IMG)
		[self _useMode:SrcMode_IMG];
	[imgSrc loadFileAtPath:p];
}
- (void) loadSyphonServerWithDescription:(NSDictionary *)d	{
	//NSLog(@"%s",__func__);
	//NSLog(@"\t\tdict is %@",d);
	if ([self srcMode]!=SrcMode_Syphon)
		[self _useMode:SrcMode_Syphon];
	[syphonSrc loadServerWithServerDescription:d];
}
- (void) eject	{
	[self _useMode:SrcMode_None];
}


- (NSMenu *) allocStaticSourcesMenu	{
	NSMenu		*returnMe = [[NSMenu alloc] initWithTitle:@""];
	[returnMe setAutoenablesItems:NO];
	NSArray		*tmpArray = nil;
	
	tmpArray = [qcSrc arrayOfSourceMenuItems];
	if (tmpArray!=nil)	{
		NSMenuItem		*catItem = [[NSMenuItem alloc] initWithTitle:@"    Built-In QC Sources" action:nil keyEquivalent:@""];
		[catItem setEnabled:NO];
		[returnMe addItem:catItem];
		[catItem release];
		
		for (NSMenuItem *itemPtr in tmpArray)
			[returnMe addItem:itemPtr];
	}
	
	tmpArray = [vidInSrc arrayOfSourceMenuItems];
	if (tmpArray!=nil)	{
		NSMenuItem		*catItem = [[NSMenuItem alloc] initWithTitle:@"    Live Inputs" action:nil keyEquivalent:@""];
		[catItem setEnabled:NO];
		[returnMe addItem:catItem];
		[catItem release];
		
		for (NSMenuItem *itemPtr in tmpArray)
			[returnMe addItem:itemPtr];
	}
	
	tmpArray = [syphonSrc arrayOfSourceMenuItems];
	if (tmpArray!=nil)	{
		NSMenuItem		*catItem = [[NSMenuItem alloc] initWithTitle:@"    Syphon Sources" action:nil keyEquivalent:@""];
		[catItem setEnabled:NO];
		[returnMe addItem:catItem];
		[catItem release];
		
		for (NSMenuItem *itemPtr in tmpArray)
			[returnMe addItem:itemPtr];
	}
	return returnMe;
}
- (VVBuffer *) allocBuffer	{
	//NSLog(@"%s",__func__);
	VVBuffer		*returnMe = nil;
	VVBuffer		*newBuffer = nil;
	VideoSource		*src = nil;
	OSSpinLockLock(&srcLock);
	switch (srcMode)	{
		case SrcMode_None:
			break;
		case SrcMode_VidIn:
			src = vidInSrc;
			break;
		case SrcMode_AVFMov:
			src = movSrc;
			break;
		case SrcMode_QC:
			src = qcSrc;
			break;
		case SrcMode_IMG:
			src = imgSrc;
			break;
		case SrcMode_Syphon:
			src = syphonSrc;
			break;
	}
	if (src!=nil)	{
		//[src _render];
		newBuffer = [src allocBuffer];
	}
	OSSpinLockUnlock(&srcLock);
	
	OSSpinLockLock(&lastBufferLock);
	if (newBuffer != nil)	{
		VVRELEASE(lastBuffer);
		lastBuffer = newBuffer;
		returnMe = [newBuffer retain];
	}
	else	{
		returnMe = (lastBuffer==nil) ? nil : [lastBuffer retain];
	}
	OSSpinLockUnlock(&lastBufferLock);
	
	return returnMe;
}


/*===================================================================================*/
#pragma mark --------------------- backend methods
/*------------------------------------*/


- (void) _useMode:(SrcMode)n	{
	//NSLog(@"%s ... %d",__func__,n);
	SrcMode		oldMode;
	OSSpinLockLock(&srcLock);
	oldMode = srcMode;
	if (oldMode != n)	{
		switch (oldMode)	{
			case SrcMode_None:
				break;
			case SrcMode_VidIn:
				[vidInSrc stop];
				break;
			case SrcMode_AVFMov:
				[movSrc stop];
				break;
			case SrcMode_QC:
				[qcSrc stop];
				break;
			case SrcMode_IMG:
				[imgSrc stop];
				break;
			case SrcMode_Syphon:
				[syphonSrc stop];
				break;
		}
		switch (n)	{
			case SrcMode_None:
				break;
			case SrcMode_VidIn:
				[vidInSrc start];
				break;
			case SrcMode_AVFMov:
				[movSrc start];
				break;
			case SrcMode_QC:
				[qcSrc start];
				break;
			case SrcMode_IMG:
				[imgSrc start];
				break;
			case SrcMode_Syphon:
				[syphonSrc start];
				break;
		}
		srcMode = n;
	}
	OSSpinLockUnlock(&srcLock);
}

- (SrcMode) srcMode	{
	SrcMode		returnMe;
	OSSpinLockLock(&srcLock);
	returnMe = srcMode;
	OSSpinLockUnlock(&srcLock);
	return returnMe;
}


- (void) setDelegate:(id<DynamicVideoSourceDelegate>)n	{
	OSSpinLockLock(&delegateLock);
	delegate = n;
	OSSpinLockUnlock(&delegateLock);
}


- (void) reloadCaptureSourcesNotification:(NSNotification *)note	{
	//NSLog(@"%s",__func__);
	[self listOfStaticSourcesUpdated:nil];
}


/*===================================================================================*/
#pragma mark --------------------- VideoSourceDelegate protocol
/*------------------------------------*/


- (void) listOfStaticSourcesUpdated:(id)ds	{
	//NSLog(@"%s",__func__);
	id			localDelegate = nil;
	OSSpinLockLock(&delegateLock);
	localDelegate = (delegate==nil) ? nil : [delegate retain];
	OSSpinLockUnlock(&delegateLock);
	
	if (localDelegate != nil)	{
		[localDelegate listOfStaticSourcesUpdated:self];
		[localDelegate release];
	}
}


@end

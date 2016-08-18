#import "IMGVideoSource.h"




@implementation IMGVideoSource


/*===================================================================================*/
#pragma mark --------------------- init/dealloc
/*------------------------------------*/


- (id) init	{
	if (self = [super init])	{
		propLastBuffer = nil;
		//lastBufferLock = OS_SPINLOCK_INIT;
		//lastBuffer = nil;
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
	OSSpinLockLock(&propLock);
	VVRELEASE(propLastBuffer);
	OSSpinLockUnlock(&propLock);
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- superclass overrides
/*------------------------------------*/


- (void) loadFileAtPath:(NSString *)p	{
	NSLog(@"%s ... %@",__func__,p);
	if (p==nil)
		return;
	NSImage		*img = [[NSImage alloc] initWithContentsOfFile:p];
	if (img==nil)	{
		NSLog(@"\t\terr: couldn't make NSImage from path \"%@\"",p);
		return;
	}
	
	VVBuffer		*newBuffer = [_globalVVBufferPool allocBufferForNSImage:img];
	if (newBuffer==nil)	{
		NSLog(@"\t\terr: couldn't make VVBuffer from NSImage in %s",__func__);
	}
	else	{
		[newBuffer setFlipped:YES];
		
		OSSpinLockLock(&propLock);
		VVRELEASE(propLastBuffer);
		propLastBuffer = newBuffer;
		OSSpinLockUnlock(&propLock);
	}
	
	[img release];
	img = nil;
}
- (void) _stop	{
	VVRELEASE(propLastBuffer);
}
- (VVBuffer *) allocBuffer	{
	VVBuffer		*returnMe = nil;
	OSSpinLockLock(&propLock);
	returnMe = (propLastBuffer==nil) ? nil : [propLastBuffer retain];
	OSSpinLockUnlock(&propLock);
	return returnMe;
}


@end

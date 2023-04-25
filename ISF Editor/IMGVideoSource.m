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
	VVLockLock(&propLock);
	VVRELEASE(propLastBuffer);
	VVLockUnlock(&propLock);
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
		
		VVLockLock(&propLock);
		VVRELEASE(propLastBuffer);
		propLastBuffer = newBuffer;
		VVLockUnlock(&propLock);
	}
	
	[img release];
	img = nil;
}
- (void) _stop	{
	VVRELEASE(propLastBuffer);
}
- (VVBuffer *) allocBuffer	{
	VVBuffer		*returnMe = nil;
	VVLockLock(&propLock);
	returnMe = (propLastBuffer==nil) ? nil : [propLastBuffer retain];
	VVLockUnlock(&propLock);
	return returnMe;
}


@end

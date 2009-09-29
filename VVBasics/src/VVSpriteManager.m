
#import "VVSpriteManager.h"
#import "VVBasicMacros.h"




@implementation VVSpriteManager


/*===================================================================================*/
#pragma mark --------------------- create/destroy
/*------------------------------------*/
- (id) init	{
	if (self = [super init])	{
		deleted = NO;
		zoneArray = [[MutLockArray alloc] initWithCapacity:0];
		zoneInUse = nil;
		zoneIndexCount = 1;
		return self;
	}
	[self release];
	return nil;
}
- (void) prepareToBeDeleted	{
	//NSLog(@"%s",__func__);
	[self removeAllZones];
	deleted = YES;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(zoneArray);
	zoneInUse = nil;
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- action and draw
/*------------------------------------*/


//	returns YES if the mousedown was on a zone
- (BOOL) localMouseDown:(NSPoint)p	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(zoneArray==nil)||([zoneArray count]<1))
		return NO;
	//	determine if there's a zone which intersects the mousedown coords
	NSEnumerator		*it;
	VVSprite		*zonePtr;
	VVSprite		*foundZone = nil;
	[zoneArray rdlock];
		it = [zoneArray objectEnumerator];
		while ((zonePtr = [it nextObject]) && (foundZone==nil))	{
			if ((![zonePtr locked]) && ([zonePtr checkPoint:p]))
				foundZone = zonePtr;
		}
	[zoneArray unlock];
	//	if i found a zone which contains the mousedown loc
	if (foundZone!=nil)	{
		zoneInUse = foundZone;
		[foundZone mouseDown:p];
		return YES;
	}
	//	if i'm here, i didn't find a zone- return NO
	return NO;
}
- (void) localMouseDragged:(NSPoint)p	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(zoneInUse==nil))
		return;
	[zoneInUse mouseDragged:p];
}
- (void) localMouseUp:(NSPoint)p	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(zoneInUse==nil))
		return;
	[zoneInUse mouseUp:p];
	zoneInUse = nil;
}

/*===================================================================================*/
#pragma mark --------------------- management
/*------------------------------------*/

- (VVSprite *) zoneAtPoint:(NSPoint)p	{
	//NSLog(@"%s ... (%f, %f)",__func__,p.x,p.y);
	if (deleted)
		return nil;
		
	id	returnMe = nil;
	
	[zoneArray rdlock];
	
		for (VVSprite *tmpZone in [zoneArray objectEnumerator])	{
			if ((![tmpZone locked]) && ([tmpZone checkPoint:p]))	{
				returnMe = tmpZone;		
				break;
			}
		}
	
	[zoneArray unlock];
	
	return returnMe;
}
- (id) newZoneAtBottomForRect:(NSRect)r	{
	id			returnMe = nil;
	returnMe = [VVSprite createWithRect:r inManager:self];
	[zoneArray lockAddObject:returnMe];
	return returnMe;
}
- (id) newZoneAtTopForRect:(NSRect)r	{
	id			returnMe = nil;
	returnMe = [VVSprite createWithRect:r inManager:self];
	[zoneArray lockInsertObject:returnMe atIndex:0];
	return returnMe;
}
- (long) getUniqueZoneIndex	{
	long		returnMe = zoneIndexCount;
	++zoneIndexCount;
	if (zoneIndexCount >= 0x7FFFFFFF)
		zoneIndexCount = 1;
	return returnMe;
}

- (VVSprite *) zoneForIndex:(long)i	{
	NSEnumerator		*it;
	VVSprite		*zonePtr = nil;
	VVSprite		*returnMe = nil;
	
	[zoneArray rdlock];
	it = [zoneArray objectEnumerator];
	while ((zonePtr = [it nextObject]) && (returnMe == nil))	{
		if ([zonePtr zoneIndex] == i)
			returnMe = zonePtr;
	}
	[zoneArray unlock];
	return returnMe;
}
- (void) removeZoneForIndex:(long)i	{
	NSEnumerator		*it;
	VVSprite		*zonePtr;
	VVSprite		*foundZone = nil;
	
	//	find & remove zone in zones array
	[zoneArray wrlock];
	it = [zoneArray objectEnumerator];
	while ((zonePtr=[it nextObject])&&(foundZone==nil))	{
		if ([zonePtr zoneIndex]==i)
			foundZone = zonePtr;
	}
	if (foundZone!=nil)
		[zoneArray removeObject:foundZone];
	[zoneArray unlock];
	//	find & remove zone in zones in use array
	if (zoneInUse == foundZone)
		zoneInUse = nil;
}
- (void) removeZone:(id)z	{
	if (z == nil)
		return;
	if ((zoneArray!=nil)&&([zoneArray count]>0))	{
		//[zoneArray lockRemoveObject:z];
		[zoneArray lockRemoveIdenticalPtr:z];
	}
	if (zoneInUse == z)
		zoneInUse = nil;
}
- (void) removeAllZones	{
	//	remove everything from the tracker array
	zoneInUse = nil;
	//	remove everything from the zones in use array
	if (zoneArray != nil)
		[zoneArray lockRemoveAllObjects];
}

- (void) draw	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(zoneArray==nil)||([zoneArray count]<1))
		return;
	[zoneArray rdlock];
		NSEnumerator	*it = [zoneArray reverseObjectEnumerator];
		VVSprite	*zonePtr;
		while (zonePtr = [it nextObject])	{
			[zonePtr draw];
		}
	[zoneArray unlock];
}
- (void) drawRect:(NSRect)r	{
	if ((deleted)||(zoneArray==nil)||([zoneArray count]<1))
		return;
	[zoneArray rdlock];
		NSEnumerator	*it = [zoneArray reverseObjectEnumerator];
		VVSprite	*zonePtr;
		while (zonePtr = [it nextObject])	{
			if (NSIntersectsRect([zonePtr rect],r))
				[zonePtr draw];
		}
	[zoneArray unlock];
}

- (VVSprite *) zoneInUse	{
	return zoneInUse;
}
- (void) setZoneInUse:(VVSprite *)z	{
	zoneInUse = z;
}
- (MutLockArray *) zoneArray	{
	return zoneArray;
}


@end

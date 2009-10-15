
#import "VVSpriteManager.h"
#import "VVBasicMacros.h"




@implementation VVSpriteManager


/*===================================================================================*/
#pragma mark --------------------- create/destroy
/*------------------------------------*/
- (id) init	{
	if (self = [super init])	{
		deleted = NO;
		spriteArray = [[MutLockArray alloc] initWithCapacity:0];
		spriteInUse = nil;
		spriteIndexCount = 1;
		return self;
	}
	[self release];
	return nil;
}
- (void) prepareToBeDeleted	{
	//NSLog(@"%s",__func__);
	[self removeAllSprites];
	deleted = YES;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(spriteArray);
	spriteInUse = nil;
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- action and draw
/*------------------------------------*/


//	returns YES if the mousedown was on a sprite
- (BOOL) localMouseDown:(NSPoint)p	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return NO;
	//	determine if there's a sprite which intersects the mousedown coords
	NSEnumerator		*it;
	VVSprite		*spritePtr;
	VVSprite		*foundSprite = nil;
	[spriteArray rdlock];
		it = [spriteArray objectEnumerator];
		while ((spritePtr = [it nextObject]) && (foundSprite==nil))	{
			if ((![spritePtr locked]) && ([spritePtr checkPoint:p]))
				foundSprite = spritePtr;
		}
	[spriteArray unlock];
	//	if i found a sprite which contains the mousedown loc
	if (foundSprite!=nil)	{
		spriteInUse = foundSprite;
		[foundSprite mouseDown:p];
		return YES;
	}
	//	if i'm here, i didn't find a sprite- return NO
	return NO;
}
- (void) localMouseDragged:(NSPoint)p	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(spriteInUse==nil))
		return;
	[spriteInUse mouseDragged:p];
}
- (void) localMouseUp:(NSPoint)p	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(spriteInUse==nil))
		return;
	[spriteInUse mouseUp:p];
	spriteInUse = nil;
}

/*===================================================================================*/
#pragma mark --------------------- management
/*------------------------------------*/

- (VVSprite *) spriteAtPoint:(NSPoint)p	{
	//NSLog(@"%s ... (%f, %f)",__func__,p.x,p.y);
	if (deleted)
		return nil;
		
	id	returnMe = nil;
	
	[spriteArray rdlock];
	
		for (VVSprite *tmpSprite in [spriteArray objectEnumerator])	{
			if ((![tmpSprite locked]) && ([tmpSprite checkPoint:p]))	{
				returnMe = tmpSprite;		
				break;
			}
		}
	
	[spriteArray unlock];
	
	return returnMe;
}
- (id) newSpriteAtBottomForRect:(NSRect)r	{
	id			returnMe = nil;
	returnMe = [VVSprite createWithRect:r inManager:self];
	[spriteArray lockAddObject:returnMe];
	return returnMe;
}
- (id) newSpriteAtTopForRect:(NSRect)r	{
	id			returnMe = nil;
	returnMe = [VVSprite createWithRect:r inManager:self];
	[spriteArray lockInsertObject:returnMe atIndex:0];
	return returnMe;
}
- (long) getUniqueSpriteIndex	{
	long		returnMe = spriteIndexCount;
	++spriteIndexCount;
	if (spriteIndexCount >= 0x7FFFFFFF)
		spriteIndexCount = 1;
	return returnMe;
}

- (VVSprite *) spriteForIndex:(long)i	{
	NSEnumerator		*it;
	VVSprite		*spritePtr = nil;
	VVSprite		*returnMe = nil;
	
	[spriteArray rdlock];
	it = [spriteArray objectEnumerator];
	while ((spritePtr = [it nextObject]) && (returnMe == nil))	{
		if ([spritePtr spriteIndex] == i)
			returnMe = spritePtr;
	}
	[spriteArray unlock];
	return returnMe;
}
- (void) removeSpriteForIndex:(long)i	{
	NSEnumerator		*it;
	VVSprite		*spritePtr;
	VVSprite		*foundSprite = nil;
	
	//	find & remove sprite in sprites array
	[spriteArray wrlock];
	it = [spriteArray objectEnumerator];
	while ((spritePtr=[it nextObject])&&(foundSprite==nil))	{
		if ([spritePtr spriteIndex]==i)
			foundSprite = spritePtr;
	}
	if (foundSprite!=nil)
		[spriteArray removeObject:foundSprite];
	[spriteArray unlock];
	//	find & remove sprite in sprites in use array
	if (spriteInUse == foundSprite)
		spriteInUse = nil;
}
- (void) removeSprite:(id)z	{
	if (z == nil)
		return;
	if ((spriteArray!=nil)&&([spriteArray count]>0))	{
		//[spriteArray lockRemoveObject:z];
		[spriteArray lockRemoveIdenticalPtr:z];
	}
	if (spriteInUse == z)
		spriteInUse = nil;
}
- (void) removeAllSprites	{
	//	remove everything from the tracker array
	spriteInUse = nil;
	//	remove everything from the sprites in use array
	if (spriteArray != nil)
		[spriteArray lockRemoveAllObjects];
}

- (void) draw	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return;
	[spriteArray rdlock];
		NSEnumerator	*it = [spriteArray reverseObjectEnumerator];
		VVSprite	*spritePtr;
		while (spritePtr = [it nextObject])	{
			[spritePtr draw];
		}
	[spriteArray unlock];
}
- (void) drawRect:(NSRect)r	{
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return;
	[spriteArray rdlock];
		NSEnumerator	*it = [spriteArray reverseObjectEnumerator];
		VVSprite	*spritePtr;
		while (spritePtr = [it nextObject])	{
			if (NSIntersectsRect([spritePtr rect],r))
				[spritePtr draw];
		}
	[spriteArray unlock];
}

- (VVSprite *) spriteInUse	{
	return spriteInUse;
}
- (void) setSpriteInUse:(VVSprite *)z	{
	spriteInUse = z;
}
- (MutLockArray *) spriteArray	{
	return spriteArray;
}


@end

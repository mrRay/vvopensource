
#import "VVSpriteManager.h"
#import "VVBasicMacros.h"




@implementation VVSpriteManager


/*===================================================================================*/
#pragma mark --------------------- create/destroy
/*------------------------------------*/
- (id) init	{
	//NSLog(@"%s",__func__);
	if (self = [super init])	{
		deleted = NO;
		allowMultiSpriteInteraction = NO;
		spriteArray = [[MutLockArray alloc] initWithCapacity:0];
		spriteInUse = nil;
		spritesInUse = nil;
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
	VVRELEASE(spritesInUse);
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
	BOOL			returnMe = NO;
	//	if i'm doing multi-sprite interaction
	if (allowMultiSpriteInteraction)	{
		[spritesInUse lockRemoveAllObjects];
		[spriteArray rdlock];
		for (VVSprite *spritePtr in [spriteArray array])	{
			if ((![spritePtr locked]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
				[spritesInUse lockAddObject:spritePtr];
				returnMe = YES;
			}
		}
		[spriteArray unlock];
		
		//	if 'spritesInUse' has more than one item, i may have to ignore some of them (because 'dropFromMultipleSpriteActions' may be YES)
		if ([spritesInUse count]>1)	{
			//	run through 'spritesInUse'- do mousedowns, and remove any sprites that have 'dropFromMultiSpriteActions' set to YES
			[spritesInUse wrlock];
			NSMutableIndexSet	*indicesToRemove = nil;
			int					tmpIndex = 0;
			for (VVSprite *spritePtr in [spritesInUse array])	{
				if ([spritePtr dropFromMultiSpriteActions])	{
					if (indicesToRemove==nil)
						indicesToRemove = [[NSMutableIndexSet alloc] init];
					[indicesToRemove addIndex:tmpIndex];
				}
				else
					[spritePtr mouseDown:p];
				++tmpIndex;
			}
			if (indicesToRemove != nil)	{
				//	if all the sprites in use are 'dropFromMultiSpriteActions', i need to "save" one and tell it to do the relevant action
				if ([indicesToRemove count] == [spritesInUse count])	{
					long			firstIndex = [indicesToRemove firstIndex];
					if (firstIndex != NSNotFound)	{
						[indicesToRemove removeIndex:firstIndex];
						VVSprite	*firstSprite = [spritesInUse objectAtIndex:firstIndex];
						if (firstSprite != nil)
							[firstSprite mouseDown:p];
					}
				}
				//	remove the dropped sprites
				[spritesInUse removeObjectsAtIndexes:indicesToRemove];
			}
			[spritesInUse unlock];
		}
		//	else 'spritesInuse' only has 0 or 1 items in it- i can just down the mousedown.
		else	{
			[spritesInUse rdlock];
			for (VVSprite *spritePtr in [spritesInUse array])	{
				[spritePtr mouseDown:p];
			}
			[spritesInUse unlock];
		}
	}
	//	else this is a single-sprite interaction
	else	{
		VVSprite		*foundSprite = nil;
		[spriteArray rdlock];
			for (VVSprite *spritePtr in [spriteArray array])	{
				if ((![spritePtr locked]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
					foundSprite = spritePtr;
					break;
				}
			}
		[spriteArray unlock];
		if (foundSprite!=nil)	{
			spriteInUse = foundSprite;
			[foundSprite mouseDown:p];
			returnMe = YES;
		}
	}
	return returnMe;
	/*
	VVSprite		*spritePtr = nil;
	VVSprite		*foundSprite = nil;
	[spriteArray rdlock];
		for (spritePtr in [spriteArray array])	{
			if ((![spritePtr locked]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
				foundSprite = spritePtr;
				break;
			}
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
	*/
}
- (BOOL) localVisibleMouseDown:(NSPoint)p	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return NO;
	BOOL			returnMe = NO;
	//	if i'm doing multi-sprite interaction
	if (allowMultiSpriteInteraction)	{
		[spritesInUse lockRemoveAllObjects];
		[spriteArray rdlock];
		for (VVSprite *spritePtr in [spriteArray array])	{
			if ((![spritePtr locked]) && (![spritePtr hidden]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
				[spritesInUse lockAddObject:spritePtr];
				returnMe = YES;
			}
		}
		[spriteArray unlock];
		
		//	if 'spritesInUse' has more than one item, i may have to ignore some of them (because 'dropFromMultipleSpriteActions' may be YES)
		if ([spritesInUse count]>1)	{
			//	run through 'spritesInUse'- do mousedowns, and remove any sprites that have 'dropFromMultiSpriteActions' set to YES
			[spritesInUse wrlock];
			NSMutableIndexSet	*indicesToRemove = nil;
			int					tmpIndex = 0;
			for (VVSprite *spritePtr in [spritesInUse array])	{
				if ([spritePtr dropFromMultiSpriteActions])	{
					if (indicesToRemove==nil)
						indicesToRemove = [[NSMutableIndexSet alloc] init];
					[indicesToRemove addIndex:tmpIndex];
				}
				else
					[spritePtr mouseDown:p];
				++tmpIndex;
			}
			if (indicesToRemove != nil)	{
				//	if all the sprites in use are 'dropFromMultiSpriteActions', i need to "save" one and tell it to do the relevant action
				if ([indicesToRemove count] == [spritesInUse count])	{
					long			firstIndex = [indicesToRemove firstIndex];
					if (firstIndex != NSNotFound)	{
						[indicesToRemove removeIndex:firstIndex];
						VVSprite	*firstSprite = [spritesInUse objectAtIndex:firstIndex];
						if (firstSprite != nil)
							[firstSprite mouseDown:p];
					}
				}
				//	remove the dropped sprites
				[spritesInUse removeObjectsAtIndexes:indicesToRemove];
			}
			[spritesInUse unlock];
		}
		//	else 'spritesInuse' only has 0 or 1 items in it- i can just down the mousedown.
		else	{
			[spritesInUse rdlock];
			for (VVSprite *spritePtr in [spritesInUse array])	{
				[spritePtr mouseDown:p];
			}
			[spritesInUse unlock];
		}
	}
	//	else this is a single-sprite interaction
	else	{
		VVSprite		*foundSprite = nil;
		[spriteArray rdlock];
			for (VVSprite *spritePtr in [spriteArray array])	{
				if ((![spritePtr locked]) && (![spritePtr hidden]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
					foundSprite = spritePtr;
					break;
				}
			}
		[spriteArray unlock];
		if (foundSprite!=nil)	{
			spriteInUse = foundSprite;
			[foundSprite mouseDown:p];
			returnMe = YES;
		}
	}
	return returnMe;
	/*
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return NO;
	//	determine if there's a sprite which intersects the mousedown coords
	//NSEnumerator		*it;
	VVSprite		*spritePtr = nil;
	VVSprite		*foundSprite = nil;
	[spriteArray rdlock];
		for (spritePtr in [spriteArray array])	{
			if ((![spritePtr locked]) && (![spritePtr hidden]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
				foundSprite = spritePtr;
				break;
			}
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
	*/
}
- (BOOL) localRightMouseDown:(NSPoint)p	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return NO;
	BOOL			returnMe = NO;
	//	if i'm doing multi-sprite interaction
	if (allowMultiSpriteInteraction)	{
		[spritesInUse lockRemoveAllObjects];
		[spriteArray rdlock];
		for (VVSprite *spritePtr in [spriteArray array])	{
			if ((![spritePtr locked]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
				[spritesInUse lockAddObject:spritePtr];
				returnMe = YES;
			}
		}
		[spriteArray unlock];
		
		//	if 'spritesInUse' has more than one item, i may have to ignore some of them (because 'dropFromMultipleSpriteActions' may be YES)
		if ([spritesInUse count]>1)	{
			//	run through 'spritesInUse'- do mousedowns, and remove any sprites that have 'dropFromMultiSpriteActions' set to YES
			[spritesInUse wrlock];
			NSMutableIndexSet	*indicesToRemove = nil;
			int					tmpIndex = 0;
			for (VVSprite *spritePtr in [spritesInUse array])	{
				if ([spritePtr dropFromMultiSpriteActions])	{
					if (indicesToRemove==nil)
						indicesToRemove = [[NSMutableIndexSet alloc] init];
					[indicesToRemove addIndex:tmpIndex];
				}
				else
					[spritePtr rightMouseDown:p];
				++tmpIndex;
			}
			if (indicesToRemove != nil)	{
				//	if all the sprites in use are 'dropFromMultiSpriteActions', i need to "save" one and tell it to do the relevant action
				if ([indicesToRemove count] == [spritesInUse count])	{
					long			firstIndex = [indicesToRemove firstIndex];
					if (firstIndex != NSNotFound)	{
						[indicesToRemove removeIndex:firstIndex];
						VVSprite	*firstSprite = [spritesInUse objectAtIndex:firstIndex];
						if (firstSprite != nil)
							[firstSprite rightMouseDown:p];
					}
				}
				//	remove the dropped sprites
				[spritesInUse removeObjectsAtIndexes:indicesToRemove];
			}
			[spritesInUse unlock];
		}
		//	else 'spritesInuse' only has 0 or 1 items in it- i can just down the mousedown.
		else	{
			[spritesInUse rdlock];
			for (VVSprite *spritePtr in [spritesInUse array])	{
				[spritePtr rightMouseDown:p];
			}
			[spritesInUse unlock];
		}
	}
	//	else this is a single-sprite interaction
	else	{
		VVSprite		*foundSprite = nil;
		[spriteArray rdlock];
			for (VVSprite *spritePtr in [spriteArray array])	{
				if ((![spritePtr locked]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
					foundSprite = spritePtr;
					break;
				}
			}
		[spriteArray unlock];
		if (foundSprite!=nil)	{
			spriteInUse = foundSprite;
			[foundSprite rightMouseDown:p];
			returnMe = YES;
		}
	}
	return returnMe;
	/*
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return NO;
	//	determine if there's a sprite which intersects the mousedown coords
	//NSEnumerator		*it;
	VVSprite		*spritePtr = nil;
	VVSprite		*foundSprite = nil;
	[spriteArray rdlock];
		for (spritePtr in [spriteArray array])	{
			if ((![spritePtr locked]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
				foundSprite = spritePtr;
				break;
			}
		}
	[spriteArray unlock];
	//	if i found a sprite which contains the mousedown loc
	if (foundSprite!=nil)	{
		spriteInUse = foundSprite;
		[foundSprite rightMouseDown:p];
		return YES;
	}
	//	if i'm here, i didn't find a sprite- return NO
	return NO;
	*/
}
- (BOOL) localVisibleRightMouseDown:(NSPoint)p	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return NO;
	BOOL			returnMe = NO;
	//	if i'm doing multi-sprite interaction
	if (allowMultiSpriteInteraction)	{
		[spritesInUse lockRemoveAllObjects];
		[spriteArray rdlock];
		for (VVSprite *spritePtr in [spriteArray array])	{
			if ((![spritePtr locked]) && (![spritePtr hidden]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
				[spritesInUse lockAddObject:spritePtr];
				returnMe = YES;
			}
		}
		[spriteArray unlock];
		
		//	if 'spritesInUse' has more than one item, i may have to ignore some of them (because 'dropFromMultipleSpriteActions' may be YES)
		if ([spritesInUse count]>1)	{
			//	run through 'spritesInUse'- do mousedowns, and remove any sprites that have 'dropFromMultiSpriteActions' set to YES
			[spritesInUse wrlock];
			NSMutableIndexSet	*indicesToRemove = nil;
			int					tmpIndex = 0;
			for (VVSprite *spritePtr in [spritesInUse array])	{
				if ([spritePtr dropFromMultiSpriteActions])	{
					if (indicesToRemove==nil)
						indicesToRemove = [[NSMutableIndexSet alloc] init];
					[indicesToRemove addIndex:tmpIndex];
				}
				else
					[spritePtr rightMouseDown:p];
				++tmpIndex;
			}
			if (indicesToRemove != nil)	{
				//	if all the sprites in use are 'dropFromMultiSpriteActions', i need to "save" one and tell it to do the relevant action
				if ([indicesToRemove count] == [spritesInUse count])	{
					long			firstIndex = [indicesToRemove firstIndex];
					if (firstIndex != NSNotFound)	{
						[indicesToRemove removeIndex:firstIndex];
						VVSprite	*firstSprite = [spritesInUse objectAtIndex:firstIndex];
						if (firstSprite != nil)
							[firstSprite rightMouseDown:p];
					}
				}
				//	remove the dropped sprites
				[spritesInUse removeObjectsAtIndexes:indicesToRemove];
			}
			[spritesInUse unlock];
		}
		//	else 'spritesInuse' only has 0 or 1 items in it- i can just down the mousedown.
		else	{
			[spritesInUse rdlock];
			for (VVSprite *spritePtr in [spritesInUse array])	{
				[spritePtr rightMouseDown:p];
			}
			[spritesInUse unlock];
		}
	}
	//	else this is a single-sprite interaction
	else	{
		VVSprite		*foundSprite = nil;
		[spriteArray rdlock];
			for (VVSprite *spritePtr in [spriteArray array])	{
				if ((![spritePtr locked]) && (![spritePtr hidden]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
					foundSprite = spritePtr;
					break;
				}
			}
		[spriteArray unlock];
		if (foundSprite!=nil)	{
			spriteInUse = foundSprite;
			[foundSprite rightMouseDown:p];
			returnMe = YES;
		}
	}
	return returnMe;
	/*
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return NO;
	//	determine if there's a sprite which intersects the mousedown coords
	//NSEnumerator		*it;
	VVSprite		*spritePtr = nil;
	VVSprite		*foundSprite = nil;
	[spriteArray rdlock];
		for (spritePtr in [spriteArray array])	{
			if ((![spritePtr locked]) && (![spritePtr hidden]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
				foundSprite = spritePtr;
				break;
			}
		}
	[spriteArray unlock];
	//	if i found a sprite which contains the mousedown loc
	if (foundSprite!=nil)	{
		spriteInUse = foundSprite;
		[foundSprite rightMouseDown:p];
		return YES;
	}
	//	if i'm here, i didn't find a sprite- return NO
	return NO;
	*/
}
- (void) localRightMouseUp:(NSPoint)p	{
	if (deleted || spriteArray==nil || [spriteArray count]<1)
		return;
	if (allowMultiSpriteInteraction)	{
		if (spritesInUse != nil)	{
			[spritesInUse rdlock];
			for (VVSprite *spritePtr in [spritesInUse array])	{
				[spritePtr rightMouseUp:p];
			}
			[spritesInUse unlock];
			[spritesInUse lockRemoveAllObjects];
		}
	}
	else	{
		if (spriteInUse != nil)	{
			[spriteInUse rightMouseUp:p];
			spriteInUse = nil;
		}
	}
	/*
	if ((deleted)||(spriteInUse==nil))
		return;
	[spriteInUse rightMouseUp:p];
	spriteInUse = nil;
	*/
}
- (void) localMouseDragged:(NSPoint)p	{
	//NSLog(@"%s",__func__);
	if (deleted || spriteArray==nil || [spriteArray count]<1)
		return;
	if (allowMultiSpriteInteraction)	{
		if (spritesInUse != nil)	{
			[spritesInUse rdlock];
			for (VVSprite *spritePtr in [spritesInUse array])	{
				[spritePtr mouseDragged:p];
			}
			[spritesInUse unlock];
		}
	}
	else	{
		if (spriteInUse != nil)
			[spriteInUse mouseDragged:p];
	}
	/*
	if ((deleted)||(spriteInUse==nil))
		return;
	[spriteInUse mouseDragged:p];
	*/
}
- (void) localMouseUp:(NSPoint)p	{
	//NSLog(@"%s",__func__);
	if (deleted || spriteArray==nil || [spriteArray count]<1)
		return;
	if (allowMultiSpriteInteraction)	{
		if (spritesInUse != nil)	{
			[spritesInUse rdlock];
			for (VVSprite *spritePtr in [spritesInUse array])	{
				[spritePtr mouseUp:p];
			}
			[spritesInUse unlock];
		}
	}
	else	{
		if (spriteInUse != nil)
			[spriteInUse mouseUp:p];
	}
	/*
	if ((deleted)||(spriteInUse==nil))
		return;
	[spriteInUse mouseUp:p];
	spriteInUse = nil;
	*/
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
	
		for (VVSprite *tmpSprite in [spriteArray array])	{
			if ((![tmpSprite locked]) && ([tmpSprite checkPoint:p]))	{
				returnMe = tmpSprite;		
				break;
			}
		}
	
	[spriteArray unlock];
	
	return returnMe;
}
- (VVSprite *) visibleSpriteAtPoint:(NSPoint)p	{
	//NSLog(@"%s ... (%f, %f)",__func__,p.x,p.y);
	if (deleted)
		return nil;
		
	id	returnMe = nil;
	
	[spriteArray rdlock];
	
		for (VVSprite *tmpSprite in [spriteArray array])	{
			if ((![tmpSprite locked]) && (![tmpSprite hidden]) && ([tmpSprite checkPoint:p]))	{
				returnMe = tmpSprite;		
				break;
			}
		}
	
	[spriteArray unlock];
	
	return returnMe;
}
- (id) newSpriteAtBottomForRect:(NSRect)r	{
	if (deleted)
		return nil;
	id			returnMe = nil;
	returnMe = [VVSprite createWithRect:r inManager:self];
	[spriteArray lockAddObject:returnMe];
	return returnMe;
}
- (id) newSpriteAtTopForRect:(NSRect)r	{
	if (deleted)
		return nil;
	id			returnMe = nil;
	returnMe = [VVSprite createWithRect:r inManager:self];
	[spriteArray lockInsertObject:returnMe atIndex:0];
	return returnMe;
}
- (long) getUniqueSpriteIndex	{
	if (deleted)
		return -1;
	long		returnMe = spriteIndexCount;
	++spriteIndexCount;
	if (spriteIndexCount >= 0x7FFFFFFF)
		spriteIndexCount = 1;
	return returnMe;
}

- (VVSprite *) spriteForIndex:(long)i	{
	if (deleted)
		return nil;
	//NSEnumerator		*it;
	VVSprite		*spritePtr = nil;
	VVSprite		*returnMe = nil;
	
	[spriteArray rdlock];
	for (spritePtr in [spriteArray array])	{
		if ([spritePtr spriteIndex] == i)	{
			returnMe = spritePtr;
			break;
		}
	}
	[spriteArray unlock];
	return returnMe;
}
- (void) removeSpriteForIndex:(long)i	{
	if (deleted)
		return;
	int				tmpIndex = 0;
	VVSprite		*spritePtr;
	VVSprite		*foundSprite = nil;
	
	//	find & remove sprite in sprites array
	[spriteArray wrlock];
	for (spritePtr in [spriteArray array])	{
		if ([spritePtr spriteIndex] == i)	{
			foundSprite = spritePtr;
			break;
		}
		++tmpIndex;
	}
	if (foundSprite != nil)	{
		if (allowMultiSpriteInteraction)	{
			[spritesInUse lockRemoveIdenticalPtr:foundSprite];
		}
		else	{
			if (spriteInUse == foundSprite)
				spriteInUse = nil;
		}
		[spriteArray removeObjectAtIndex:tmpIndex];
	}
	[spriteArray unlock];
}
- (void) removeSprite:(id)z	{
	if (deleted || z==nil)
		return;
	if ((spriteArray!=nil)&&([spriteArray count]>0))	{
		[spriteArray lockRemoveIdenticalPtr:z];
	}
	if (allowMultiSpriteInteraction)	{
		[spritesInUse lockRemoveIdenticalPtr:z];
	}
	else	{
		if (spriteInUse == z)
			spriteInUse = nil;
	}
}
- (void) removeSpritesFromArray:(NSArray *)array	{
	if (deleted || array==nil)
		return;
	for (id sprite in array)	{
		[self removeSprite:sprite];
	}
}
- (void) removeAllSprites	{
	if (deleted)
		return;
	//	remove everything from the tracker array
	spriteInUse = nil;
	//	remove everything from the sprites in use array
	if (spriteArray != nil)
		[spriteArray lockRemoveAllObjects];
	if (spritesInUse != nil)
		[spritesInUse lockRemoveAllObjects];
}
/*
- (void) moveSpriteToFront:(VVSprite *)z	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return;
	[spriteArray wrlock];
		
		[spriteArray removeObject:z];
		[spriteArray insertObject:z atIndex:0];
		
	[spriteArray unlock];
}
*/
- (void) draw	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return;
	[spriteArray rdlock];
		NSEnumerator	*it = [[spriteArray array] reverseObjectEnumerator];
		VVSprite	*spritePtr;
		while (spritePtr = [it nextObject])	{
			//if (![spritePtr hidden])
				[spritePtr draw];
		}
	[spriteArray unlock];
}
- (void) drawRect:(NSRect)r	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return;
	[spriteArray rdlock];
		NSEnumerator	*it = [[spriteArray array] reverseObjectEnumerator];
		VVSprite	*spritePtr;
		while (spritePtr = [it nextObject])	{
			//NSRect		tmp = [spritePtr rect];
			//NSLog(@"\t\tsprite %@ is (%f, %f) %f x %f",[spritePtr userInfo],tmp.origin.x,tmp.origin.y,tmp.size.width,tmp.size.height);
			//if (![spritePtr hidden])	{
				if (NSIntersectsRect([spritePtr rect],r))
					[spritePtr draw];
			//}
		}
	[spriteArray unlock];
}

- (VVSprite *) spriteInUse	{
	if (deleted)
		return nil;
	if (allowMultiSpriteInteraction)
		return nil;
	else
		return spriteInUse;
}
- (void) setSpriteInUse:(VVSprite *)z	{
	if (deleted)
		return;
	spriteInUse = z;
}
- (void) setAllowMultiSpriteInteraction:(BOOL)n	{
	if (n && spritesInUse==nil)
		spritesInUse = [[MutLockArray alloc] init];
	else if (!n && spritesInUse!=nil)
		VVRELEASE(spritesInUse);
	allowMultiSpriteInteraction = n;
}
- (BOOL) allowMultiSpriteInteraction	{
	return allowMultiSpriteInteraction;
}
- (MutLockArray *) spriteArray	{
	return spriteArray;
}


@end

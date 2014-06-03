
#import "VVSpriteManager.h"
#import "VVBasicMacros.h"
#if !IPHONE
#import <OpenGL/CGLMacro.h>
#endif



BOOL			_spriteManagerInitialized;
MutLockArray		*_spriteManagerArray;




@implementation VVSpriteManager


+ (void) load	{
	//_spriteManagerInitialized = YES;
	_spriteManagerInitialized = YES;
}
+ (void) initialize	{
	if (_spriteManagerInitialized)
		return;
	_spriteManagerInitialized = YES;
	_spriteManagerArray = [[MutLockArray alloc] init];
}


/*===================================================================================*/
#pragma mark --------------------- create/destroy
/*------------------------------------*/


- (id) init	{
	//NSLog(@"%s",__func__);
	if (self = [super init])	{
		deleted = !_spriteManagerInitialized;
		allowMultiSpriteInteraction = NO;
		multiSpriteExecutesOnMultipleSprites = NO;
		spriteArray = [[MutLockArray alloc] initWithCapacity:0];
#if IPHONE
		perTouchSpritesInUse = [[MutNRLockDict alloc] init];
		perTouchMultiSpritesInUse = [[MutLockDict alloc] init];
#else
		spriteInUse = nil;
		spritesInUse = nil;
#endif
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
#if IPHONE
	VVRELEASE(perTouchSpritesInUse);
	VVRELEASE(perTouchMultiSpritesInUse);
#else
	spriteInUse = nil;
	VVRELEASE(spritesInUse);
#endif
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- action and draw
/*------------------------------------*/


#if IPHONE
- (BOOL) receivedDownEvent:(VVSpriteEventType)e forTouch:(UITouch *)t atPoint:(VVPOINT)p visibleOnly:(BOOL)v	{
	//NSLog(@"%s ... (%0.2f, %0.2f)",__func__,p.x,p.y);
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1)||(!_spriteManagerInitialized)||(t==nil))
		return NO;
	BOOL			returnMe = NO;
	//	if i'm doing multi-sprite interaction
	if (allowMultiSpriteInteraction)	{
		NSLog(@"\t\tmulti-sprite interaction isn't supported on iOS yet! %s",__func__);
	}
	//	else this is a single-sprite interaction
	else	{
		[perTouchSpritesInUse rdlock];
		[spriteArray rdlock];
		
		__block VVSprite		*foundSprite = nil;
		for (VVSprite *spritePtr in [spriteArray array])	{
			if ((![spritePtr locked]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
				if ((v && ![spritePtr hidden]) || (!v))	{
					//	if everything checks out, set the foundSprite to this sprite
					foundSprite = spritePtr;
					//	run through the sprites that are already in use, making sure that the sprite i found isn't already being used by another touch
					[[perTouchSpritesInUse dict] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)	{
						if ([(ObjectHolder *)obj object] == foundSprite)	{
							foundSprite = nil;
							*stop = YES;
						}
					}];
					//	if i found a sprite, break out of the for loop and start working with it
					if (foundSprite != nil)
						break;
				}
			}
		}
		
		[spriteArray unlock];
		[perTouchSpritesInUse unlock];
		
		//	if "foundSprite" is non-nil, i'm good to go and can start working with it...
		if (foundSprite!=nil)	{
			ObjectHolder	*tmpHolder = [ObjectHolder createWithZWRObject:foundSprite];
			//	cast the UITouch pointer as a 64-bit int representing the address of the UITouch's pointer
			[perTouchSpritesInUse lockSetObject:tmpHolder forKey:(id)NUMU64((unsigned long long)t)];
			[foundSprite receivedEvent:e atPoint:p withModifierFlag:0];
			returnMe = YES;
		}
	}
	return returnMe;
}
- (void) receivedOtherEvent:(VVSpriteEventType)e forTouch:(UITouch *)t atPoint:(VVPOINT)p	{
	//NSLog(@"%s ... %0.2f, %0.2f",__func__,p.x,p.y);
	if (deleted || spriteArray==nil || [spriteArray count]<1 || !_spriteManagerInitialized || t==nil)
		return;
	if (allowMultiSpriteInteraction)	{
		NSLog(@"\t\tmulti-sprite interaction isn't supported on iOS yet! %s",__func__);
	}
	else	{
		//	cast the UITouch pointer as a 64-bit int representing the address of the UITouch's pointer
		VVSprite		*spriteInUse = [perTouchSpritesInUse lockObjectForKey:(id)NUMU64((unsigned long long)t)];
		if (spriteInUse != nil)	{
			//[spriteInUse rightMouseUp:p];
			[spriteInUse receivedEvent:e atPoint:p withModifierFlag:0];
			//	if this is a mouseup, empty spritesInUse- but i don't want to empty it during a drag!
			if (e==VVSpriteEventUp || e==VVSpriteEventRightUp)	{
				//	cast the UITouch pointer as a 64-bit int representing the address of the UITouch's pointer
				[perTouchSpritesInUse lockRemoveObjectForKey:(id)NUMU64((unsigned long long)t)];
			}
		}
	}
}
- (BOOL) localTouch:(UITouch *)t downAtPoint:(VVPOINT)p	{
	//NSLog(@"%s ... %p, (%0.2f, %0.2f)",__func__,self,p.x,p.y);
	return [self receivedDownEvent:VVSpriteEventDown forTouch:t atPoint:p visibleOnly:NO];
}
- (BOOL) localTouch:(UITouch *)t visibleDownAtPoint:(VVPOINT)p	{
	//NSLog(@"%s ... %p, (%0.2f, %0.2f)",__func__,self,p.x,p.y);
	return [self receivedDownEvent:VVSpriteEventDown forTouch:t atPoint:p visibleOnly:YES];
}
- (void) localTouch:(UITouch *)t draggedAtPoint:(VVPOINT)p	{
	//NSLog(@"%s ... %p, (%0.2f, %0.2f)",__func__,self,p.x,p.y);
	[self receivedOtherEvent:VVSpriteEventDrag forTouch:t atPoint:p];
}
- (void) localTouch:(UITouch *)t upAtPoint:(VVPOINT)p	{
	//NSLog(@"%s ... %p, (%0.2f, %0.2f)",__func__,self,p.x,p.y);
	[self receivedOtherEvent:VVSpriteEventUp forTouch:t atPoint:p];
}
- (void) terminateTouch:(UITouch *)t	{
	//NSLog(@"%s ... %p",__func__,self);
	if (t != nil)	{
		//	cast the UITouch pointer as a 64-bit int representing the address of the UITouch's pointer
		NSNumber		*ptrAsNum = NUMU64((unsigned long long)t);
		[perTouchSpritesInUse lockRemoveObjectForKey:(id)ptrAsNum];
		[perTouchMultiSpritesInUse lockRemoveObjectForKey:(id)ptrAsNum];
	}
}
#else
- (BOOL) receivedMouseDownEvent:(VVSpriteEventType)e atPoint:(VVPOINT)p withModifierFlag:(long)m visibleOnly:(BOOL)v	{
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1)||(!_spriteManagerInitialized))
		return NO;
	BOOL			returnMe = NO;
	//	if i'm doing multi-sprite interaction
	if (allowMultiSpriteInteraction)	{
		[spritesInUse lockRemoveAllObjects];
		[spriteArray rdlock];
		for (VVSprite *spritePtr in [spriteArray array])	{
			if ((![spritePtr locked]) && ([spritePtr checkPoint:p]) && ([spritePtr actionCallback]!=nil) && ([spritePtr delegate]!=nil))	{
				if ((v && ![spritePtr hidden]) || (!v))	{
					[spritesInUse lockAddObject:spritePtr];
					returnMe = YES;
				}
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
				else	{
					//[spritePtr mouseDown:p modifierFlag:m];
					[spritePtr receivedEvent:e atPoint:p withModifierFlag:m];
				}
				++tmpIndex;
			}
			if (indicesToRemove != nil)	{
				//	if all the sprites in use are 'dropFromMultiSpriteActions', i need to "save" one and tell it to do the relevant action
				if ([indicesToRemove count] == [spritesInUse count])	{
					long			firstIndex = [indicesToRemove firstIndex];
					if (firstIndex != NSNotFound)	{
						[indicesToRemove removeIndex:firstIndex];
						VVSprite	*firstSprite = [spritesInUse objectAtIndex:firstIndex];
						if (firstSprite != nil)	{
							//[firstSprite mouseDown:p modifierFlag:m];
							[firstSprite receivedEvent:e atPoint:p withModifierFlag:m];
						}
					}
				}
				//	remove the dropped sprites
				[spritesInUse removeObjectsAtIndexes:indicesToRemove];
			}
			[spritesInUse unlock];
			VVRELEASE(indicesToRemove);
		}
		//	else 'spritesInuse' only has 0 or 1 items in it- i can just down the mousedown.
		else	{
			[spritesInUse rdlock];
			for (VVSprite *spritePtr in [spritesInUse array])	{
				//[spritePtr mouseDown:p modifierFlag:m];
				[spritePtr receivedEvent:e atPoint:p withModifierFlag:m];
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
					if ((v && ![spritePtr hidden]) || (!v))	{
						foundSprite = spritePtr;
						break;
					}
				}
			}
		[spriteArray unlock];
		if (foundSprite!=nil)	{
			spriteInUse = foundSprite;
			//[foundSprite mouseDown:p modifierFlag:m];
			[foundSprite receivedEvent:e atPoint:p withModifierFlag:m];
			returnMe = YES;
		}
	}
	return returnMe;
}
- (void) receivedOtherEvent:(VVSpriteEventType)e atPoint:(VVPOINT)p withModifierFlag:(long)m	{
	//NSLog(@"%s ... %0.2f, %0.2f",__func__,p.x,p.y);
	if (deleted || spriteArray==nil || [spriteArray count]<1 || !_spriteManagerInitialized)
		return;
	if (allowMultiSpriteInteraction)	{
		if (spritesInUse != nil)	{
			[spritesInUse rdlock];
			for (VVSprite *spritePtr in [spritesInUse array])	{
				//[spritePtr rightMouseUp:p];
				[spritePtr receivedEvent:e atPoint:p withModifierFlag:0];
			}
			[spritesInUse unlock];
			//	if this is a mouseup, empty spritesInUse- but i don't want to empty it during a drag!
			if (e==VVSpriteEventUp || e==VVSpriteEventRightUp)
				[spritesInUse lockRemoveAllObjects];
		}
	}
	else	{
		if (spriteInUse != nil)	{
			//[spriteInUse rightMouseUp:p];
			[spriteInUse receivedEvent:e atPoint:p withModifierFlag:0];
			//	if this is a mouseup, empty spritesInUse- but i don't want to empty it during a drag!
			if (e==VVSpriteEventUp || e==VVSpriteEventRightUp)
				spriteInUse = nil;
		}
	}
}

- (BOOL) localMouseDown:(VVPOINT)p modifierFlag:(long)m	{
	return [self receivedMouseDownEvent:VVSpriteEventDown atPoint:p withModifierFlag:m visibleOnly:NO];
}
- (BOOL) localVisibleMouseDown:(VVPOINT)p modifierFlag:(long)m	{
	return [self receivedMouseDownEvent:VVSpriteEventDown atPoint:p withModifierFlag:m visibleOnly:YES];
}
- (BOOL) localRightMouseDown:(VVPOINT)p modifierFlag:(long)m	{
	return [self receivedMouseDownEvent:VVSpriteEventRightDown atPoint:p withModifierFlag:m visibleOnly:NO];
}
- (BOOL) localVisibleRightMouseDown:(VVPOINT)p modifierFlag:(long)m	{
	return [self receivedMouseDownEvent:VVSpriteEventRightDown atPoint:p withModifierFlag:m visibleOnly:YES];
}
- (void) localRightMouseUp:(VVPOINT)p	{
	[self receivedOtherEvent:VVSpriteEventRightUp atPoint:p withModifierFlag:0];
}
- (void) localMouseDragged:(VVPOINT)p	{
	[self receivedOtherEvent:VVSpriteEventDrag atPoint:p withModifierFlag:0];
}
- (void) localMouseUp:(VVPOINT)p	{
	[self receivedOtherEvent:VVSpriteEventUp atPoint:p withModifierFlag:0];
}
- (void) terminatePresentMouseSession	{
	spriteInUse = nil;
	[spritesInUse lockRemoveAllObjects];
}
#endif


/*===================================================================================*/
#pragma mark --------------------- management
/*------------------------------------*/

- (VVSprite *) spriteAtPoint:(VVPOINT)p	{
	//NSLog(@"%s ... (%f, %f)",__func__,p.x,p.y);
	if (deleted || !_spriteManagerInitialized)
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
- (NSMutableArray *) spritesAtPoint:(VVPOINT)p	{
	if (deleted || !_spriteManagerInitialized)
		return nil;
	NSMutableArray		*returnMe = nil;
	[spriteArray rdlock];
	for (VVSprite *tmpSprite in [spriteArray array])	{
		if ((![tmpSprite locked]) && ([tmpSprite checkPoint:p]))	{
			if (returnMe == nil)
				returnMe = MUTARRAY;
			[returnMe addObject:tmpSprite];
		}
	}
	[spriteArray unlock];
	return returnMe;
}
- (VVSprite *) visibleSpriteAtPoint:(VVPOINT)p	{
	//NSLog(@"%s ... (%f, %f)",__func__,p.x,p.y);
	if (deleted || !_spriteManagerInitialized)
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
- (id) makeNewSpriteAtBottomForRect:(VVRECT)r	{
	if (deleted)
		return nil;
	id			returnMe = nil;
	returnMe = [VVSprite createWithRect:r inManager:self];
	[spriteArray lockAddObject:returnMe];
	return returnMe;
}
- (id) makeNewSpriteAtTopForRect:(VVRECT)r	{
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
#if IPHONE
	if (foundSprite != nil)	{
		if (allowMultiSpriteInteraction)	{
			//	run through the key/val dict of UITouch/MutLockArrays, delete the ObjectHolder containing the found sprite from each array!
			[perTouchMultiSpritesInUse rdlock];
			[[perTouchMultiSpritesInUse dict] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)	{
				[(MutLockArray *)obj lockRemoveIdenticalPtr:foundSprite];
			}];
			[perTouchMultiSpritesInUse unlock];
		}
		else	{
			//	run through the key/val dict of UITouch/ObjectHolders, determining which keys (which UITouches) to delete
			[perTouchSpritesInUse wrlock];
			__block NSMutableArray		*keysToRemove = nil;
			[[perTouchSpritesInUse dict] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)	{
				VVSprite		*objSprite = [(ObjectHolder *)obj object];
				if (objSprite == foundSprite)	{
					if (keysToRemove == nil)
						keysToRemove = MUTARRAY;
					[keysToRemove addObject:key];
				}
			}];
			if (keysToRemove != nil)	{
				for (id keyToRemove in keysToRemove)
					[perTouchSpritesInUse removeObjectForKey:keyToRemove];
			}
			[perTouchSpritesInUse unlock];
		}
		[spriteArray removeObjectAtIndex:tmpIndex];
	}
#else
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
#endif
	[spriteArray unlock];
}
- (void) removeSprite:(id)z	{
	if (deleted || z==nil)
		return;
	if ((spriteArray!=nil)&&([spriteArray count]>0))	{
		[spriteArray lockRemoveIdenticalPtr:z];
	}
	VVSprite		*foundSprite = z;
#if IPHONE
	if (foundSprite != nil)	{
		if (allowMultiSpriteInteraction)	{
			//	run through the key/val dict of UITouch/MutLockArrays, delete the ObjectHolder containing the found sprite from each array!
			[perTouchMultiSpritesInUse rdlock];
			[[perTouchMultiSpritesInUse dict] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)	{
				[(MutLockArray *)obj lockRemoveIdenticalPtr:foundSprite];
			}];
			[perTouchMultiSpritesInUse unlock];
		}
		else	{
			//	run through the key/val dict of UITouch/ObjectHolders, determining which keys (which UITouches) to delete
			[perTouchSpritesInUse wrlock];
			__block NSMutableArray		*keysToRemove = nil;
			[[perTouchSpritesInUse dict] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop)	{
				VVSprite		*objSprite = [(ObjectHolder *)obj object];
				if (objSprite == foundSprite)	{
					if (keysToRemove == nil)
						keysToRemove = MUTARRAY;
					[keysToRemove addObject:key];
				}
			}];
			if (keysToRemove != nil)	{
				for (id keyToRemove in keysToRemove)
					[perTouchSpritesInUse removeObjectForKey:keyToRemove];
			}
			[perTouchSpritesInUse unlock];
		}
	}
#else
	if (foundSprite != nil)	{
		if (allowMultiSpriteInteraction)	{
			[spritesInUse lockRemoveIdenticalPtr:foundSprite];
		}
		else	{
			if (spriteInUse == foundSprite)
				spriteInUse = nil;
		}
	}
#endif
	[spriteArray lockRemoveIdenticalPtr:z];
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
#if IPHONE
	[perTouchSpritesInUse lockRemoveAllObjects];
	[perTouchMultiSpritesInUse lockRemoveAllObjects];
#else
	//	remove everything from the tracker array
	spriteInUse = nil;
	if (spritesInUse != nil)
		[spritesInUse lockRemoveAllObjects];
#endif
	//	remove everything from the sprites in use array
	if (spriteArray != nil)
		[spriteArray lockRemoveAllObjects];
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
- (void) drawRect:(VVRECT)r	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return;
	[spriteArray rdlock];
		NSEnumerator	*it = [[spriteArray array] reverseObjectEnumerator];
		VVSprite	*spritePtr;
		while (spritePtr = [it nextObject])	{
			if ([spritePtr checkRect:r])
				[spritePtr draw];
			/*
			//VVRECT		tmp = [spritePtr rect];
			//NSLog(@"\t\tsprite %@ is (%f, %f) %f x %f",[spritePtr userInfo],tmp.origin.x,tmp.origin.y,tmp.size.width,tmp.size.height);
			//if (![spritePtr hidden])	{
				if (VVINTERSECTSRECT([spritePtr rect],r))
					[spritePtr draw];
			//}
			*/
		}
	[spriteArray unlock];
}
#if !IPHONE
- (void) drawInContext:(CGLContextObj)cgl_ctx	{
	//NSLog(@"%s",__func__);
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return;
	[spriteArray rdlock];
		NSEnumerator	*it = [[spriteArray array] reverseObjectEnumerator];
		VVSprite	*spritePtr;
		while (spritePtr = [it nextObject])	{
			[spritePtr drawInContext:cgl_ctx];
		}
	[spriteArray unlock];
}
#endif
#if !IPHONE
- (void) drawRect:(VVRECT)r inContext:(CGLContextObj)cgl_ctx	{
	//NSLog(@"%s",__func__);
	//VVRectLog(@"\t\tpassed rect is",r);
	if ((deleted)||(spriteArray==nil)||([spriteArray count]<1))
		return;
	[spriteArray rdlock];
		NSEnumerator	*it = [[spriteArray array] reverseObjectEnumerator];
		VVSprite	*spritePtr;
		while (spritePtr = [it nextObject])	{
			if ([spritePtr checkRect:r])
				[spritePtr drawInContext:cgl_ctx];
			/*
			//VVRECT		tmp = [spritePtr rect];
			//NSLog(@"\t\tsprite %@ is (%f, %f) %f x %f",[spritePtr userInfo],tmp.origin.x,tmp.origin.y,tmp.size.width,tmp.size.height);
			//if (![spritePtr hidden])	{
				if (VVINTERSECTSRECT([spritePtr rect],r))
					[spritePtr draw];
			//}
			*/
		}
	[spriteArray unlock];
}
#endif
#if !IPHONE
- (VVSprite *) spriteInUse	{
	if (deleted)
		return nil;
	if (allowMultiSpriteInteraction)
		return nil;
	else
		return spriteInUse;
}
#endif
#if !IPHONE
- (void) setSpriteInUse:(VVSprite *)z	{
	if (deleted)
		return;
	spriteInUse = z;
}
#endif
- (void) setAllowMultiSpriteInteraction:(BOOL)n	{
#if IPHONE
	
#else
	if (n && spritesInUse==nil)
		spritesInUse = [[MutLockArray alloc] init];
	else if (!n && spritesInUse!=nil)
		VVRELEASE(spritesInUse);
#endif
	allowMultiSpriteInteraction = n;
}
- (BOOL) allowMultiSpriteInteraction	{
	return allowMultiSpriteInteraction;
}
@synthesize multiSpriteExecutesOnMultipleSprites;
- (MutLockArray *) spriteArray	{
	if (deleted)
		return nil;
	return spriteArray;
}
#if !IPHONE
- (MutLockArray *) spritesInUse	{
	if (deleted)
		return nil;
	return spritesInUse;
}
#endif


@end

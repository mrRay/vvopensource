
#import "MutNRLockArray.h"




@implementation MutNRLockArray


- (NSString *) description	{
	return [NSString stringWithFormat:@"<MutNRLockArray: %@>",array];
}
+ (id) arrayWithCapacity:(NSUInteger)c	{
	MutNRLockArray	*returnMe = [[MutNRLockArray alloc] initWithCapacity:0];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (void) addObject:(id)o	{
	ObjectHolder		*holder = [ObjectHolder createWithObject:o];
	[super addObject:holder];
}
- (void) addObjectsFromArray:(id)a	{
	if ((array!=nil) && (a!=nil) && ([a count]>0))	{
		//	if the array's another MutNRLockArray, i can simply use its items
		if ([a isKindOfClass:[MutNRLockArray class]])	{
			[array addObjectsFromArray:[a lockCreateArrayCopy]];
		}
		//	else if it's an MutLockArray
		else if ([a isKindOfClass:[MutLockArray class]])	{
			//	lock & get a copy of the array
			NSMutableArray		*copy = [a lockCreateArrayCopy];
			ObjectHolder		*tmpHolder = nil;
			if (copy!=nil)	{
				//	run through the copy, creating ObjectHolders for each item & adding them to me
				for (id anObj in copy)	{
					tmpHolder = [ObjectHolder createWithObject:anObj];
					if (tmpHolder != nil)
						[array addObject:tmpHolder];
				}
			}
		}
		//	else it's some other kind of generic array
		else	{
			//	run through the array, creating ObjectHolders for each itme & adding them to me
			ObjectHolder		*tmpHolder = nil;
			for (id anObj in a)	{
				tmpHolder = [ObjectHolder createWithObject:anObj];
				if (tmpHolder != nil)
					[array addObject:tmpHolder];
			}
		}
	}
}
- (void) replaceWithObjectsFromArray:(id)a	{
	if ((array!=nil) && (a!=nil))	{
		@try	{
			[array removeAllObjects];
			[self addObjectsFromArray:a];
		}
		@catch (NSException *err)	{
			NSLog(@"%\t\t%s - %@",__func__,err);
		}
	}
}
- (void) insertObject:(id)o atIndex:(NSUInteger)i	{
	ObjectHolder		*tmpHolder = [ObjectHolder createWithObject:o];
	[super insertObject:tmpHolder atIndex:i];
}
- (id) lastObject	{
	ObjectHolder		*objHolder = [super lastObject];
	return [objHolder object];
}
- (void) removeObject:(id)o	{
	int			indexOfObject = [self indexOfObject:o];
	if ((indexOfObject!=NSNotFound) && (indexOfObject>=0))
		[self removeObjectAtIndex:indexOfObject];
}
- (BOOL) containsObject:(id)o	{
	int		foundIndex = [self indexOfObject:o];
	if (foundIndex == NSNotFound)
		return NO;
	return YES;
}
- (id) objectAtIndex:(NSUInteger)i	{
	ObjectHolder	*returnMe = [super objectAtIndex:i];
	if (returnMe == nil)
		return nil;
	return [returnMe object];
}
- (NSArray *) objectsAtIndexes:(NSIndexSet *)indexes	{
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	NSArray				*tmpArray = nil;
	
	if ((array!=nil) && (indexes!=nil))	{
		tmpArray = [array objectsAtIndexes:indexes];
		if (tmpArray != nil)	{
			for (ObjectHolder *objPtr in tmpArray)	{
				[returnMe addObject:[objPtr object]];
			}
		}
	}
	return returnMe;
}
- (NSUInteger) indexOfObject:(id)o	{
	if (o == nil)
		return NSNotFound;
	int				tmpIndex = 0;
	int				foundIndex = -1;
	NSEnumerator	*objIt;
	ObjectHolder	*objPtr;
	id				anObj;
	
	objIt = [array objectEnumerator];
	//	run through the array object holders while i haven't found the object i'm looking for
	while ((objPtr=[objIt nextObject]) && (foundIndex<0))	{
		//	get the object stored by the object holder
		anObj = [objPtr object];
		//	if the object in the object holder matches the passed object using isEqual:, i'm going to return it
		if ((anObj != nil) && ([o isEqual:anObj]))
			foundIndex = tmpIndex;
		++tmpIndex;
	}
	//	make sure i return NSNotFound instead of -1
	if (foundIndex < 0)
		foundIndex = NSNotFound;
	return foundIndex;
}
- (BOOL) containsIdenticalPtr:(id)o	{
	int		foundIndex = [self indexOfIdenticalPtr:o];
	if (foundIndex == NSNotFound)
		return NO;
	return YES;
}
- (int) indexOfIdenticalPtr:(id)o	{
	if (o == nil)
		return NSNotFound;
	int				tmpIndex = 0;
	int				foundIndex = -1;
	NSEnumerator	*objIt;
	ObjectHolder	*objPtr;
	id				anObj;
	
	objIt = [array objectEnumerator];
	//	run through the array object holders while i haven't found the object i'm looking for
	while ((objPtr=[objIt nextObject]) && (foundIndex<0))	{
		//	get the object stored by the object holder
		anObj = [objPtr object];
		//	if the object in the object holder matches the passed object using isEqual:, i'm going to return it
		if ((anObj != nil) && (o  == anObj))
			foundIndex = tmpIndex;
		++tmpIndex;
	}
	//	make sure i return NSNotFound instead of -1
	if (foundIndex < 0)
		foundIndex = NSNotFound;
	return foundIndex;
}
- (void) removeIdenticalPtr:(id)o	{
	int		foundIndex = [self indexOfIdenticalPtr:o];
	if (foundIndex == NSNotFound)
		return;
	[self removeObjectAtIndex:foundIndex];
}


@end

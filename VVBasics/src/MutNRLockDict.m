//
//  MutNRLockDict.m
//  VVOpenSource
//
//  Created by David Lublin on 12/22/09.
//  Copyright 2009 Vidvox. All rights reserved.
//

#import "MutNRLockDict.h"


@implementation MutNRLockDict


- (NSString *) description	{
	return [NSString stringWithFormat:@"<MutNRLockDict: %@>",dict];
}
+ (id) dictionaryWithCapacity:(NSInteger)c	{
	MutNRLockDict	*returnMe = [[MutNRLockDict alloc] initWithCapacity:0];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (NSMutableDictionary *) createDictCopy	{
	NSMutableDictionary		*returnMe = [NSMutableDictionary dictionaryWithCapacity:0];
	for (NSString *keyPtr in [dict allKeys])	{
		ObjectHolder *objPtr = [dict objectForKey:keyPtr];
		[returnMe setObject:objPtr forKey:keyPtr];	//	THIS RETAINS THE OBJECT! HAVE TO RETURN A MUTABLE DICTIONARY!
	}
	return returnMe;
}
- (void) setObject:(id)o forKey:(NSString *)s	{
	if (s == nil)
		return;
	if ([o isKindOfClass:[ObjectHolder class]])	{
		[super setObject:o forKey:s];
		return;
	}
	ObjectHolder		*holder = [ObjectHolder createWithObject:o];
	[super setObject:holder forKey:s];
}
- (void) setValue:(id)v forKey:(NSString *)s	{
	if (s == nil)
		return;
	if ([v isKindOfClass:[ObjectHolder class]])	{
		[super setObject:v forKey:s];
		return;
	}
	ObjectHolder		*holder = [ObjectHolder createWithObject:v];
	[super setObject:holder forKey:s];
}
- (id) objectForKey:(NSString *)k	{
	ObjectHolder	*returnMe = [super objectForKey:k];
	if (returnMe == nil)
		return nil;
	return [returnMe object];
}
- (void) addEntriesFromDictionary:(id)otherDictionary	{
	if ((dict!=nil) && (otherDictionary!=nil) && ([otherDictionary count]>0))	{
		//	if the array's another MutNRLockDict, i can simply use its items
		if ([otherDictionary isKindOfClass:[MutNRLockDict class]])	{
			[dict addEntriesFromDictionary:[otherDictionary lockCreateDictCopy]];
		}
		//	else if it's an MutLockDict
		else if ([otherDictionary isKindOfClass:[MutLockDict class]])	{
			//	lock & get a copy of the dict
			NSMutableDictionary		*copy = [otherDictionary lockCreateDictCopy];
			if (copy!=nil)	{
				for (NSString *keyPtr in [otherDictionary allKeys])	{
					id anObj = [otherDictionary objectForKey:keyPtr];
					ObjectHolder *objPtr = [ObjectHolder createWithObject:anObj];
					
					[dict setObject:objPtr forKey:keyPtr];	
				}
			}
		}
		//	else it's some other kind of generic array
		else	{
			//	run through the dict, creating ObjectHolders for each itme & adding them to me
			for (NSString *keyPtr in [otherDictionary allKeys])	{
				id anObj = [otherDictionary objectForKey:keyPtr];
				ObjectHolder *objPtr = [ObjectHolder createWithObject:anObj];
				
				[dict setObject:objPtr forKey:keyPtr];	
			}
		}
	}
}
- (NSArray *) allValues	{
	if (dict==nil)
		return nil;
		
	NSArray	*returnMe = [[dict allValues] valueForKey:@"object"];
	
	return returnMe;
}
@end

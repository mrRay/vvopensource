
#import "MutLockDict.h"




@implementation MutLockDict


- (NSString *) description	{
	return [NSString stringWithFormat:@"<MutLockDict: %@>",dict];
}
+ (id) dictionaryWithCapacity:(NSInteger)c	{
	MutLockDict		*returnMe = [[MutLockDict alloc] initWithCapacity:0];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) dictionaryWithDict:(NSDictionary *)d	{
	id			returnMe = [[MutLockDict alloc] initWithCapacity:0];
	if (returnMe == nil)
		return nil;
	if (d != nil)
		[[returnMe dict] addEntriesFromDictionary:d];
	return [returnMe autorelease];
}
- (id) initWithCapacity:(NSInteger)c	{
	if (c < 0)	{
		[self release];
		return nil;
	}
	
	pthread_rwlockattr_t		attr;
	
	if (self = [super init])	{
		dict = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
		if (dict == nil)	{
			[self release];
			return nil;
		}
		pthread_rwlockattr_init(&attr);
		//pthread_rwlockattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
		pthread_rwlockattr_setpshared(&attr, PTHREAD_PROCESS_PRIVATE);
		pthread_rwlock_init(&dictLock, &attr);
		pthread_rwlockattr_destroy(&attr);
		
		return self;
	}
	[self release];
	return nil;
}
- (id) init	{
	return [self initWithCapacity:0];
}
- (void) dealloc	{
	[self lockRemoveAllObjects];
	pthread_rwlock_destroy(&dictLock);
	if (dict != nil)
		[dict release];
	dict = nil;
	[super dealloc];
}


- (void) rdlock	{
	pthread_rwlock_rdlock(&dictLock);
}
- (void) wrlock	{
	pthread_rwlock_wrlock(&dictLock);
}
- (void) unlock	{
	pthread_rwlock_unlock(&dictLock);
}


- (NSMutableDictionary *) dict	{
	return dict;
}
- (NSMutableDictionary *) createDictCopy	{
	NSMutableDictionary		*returnMe = [dict mutableCopy];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (NSMutableDictionary *) lockCreateDictCopy	{
	NSMutableDictionary		*returnMe = nil;
	pthread_rwlock_rdlock(&dictLock);
		returnMe = [self createDictCopy];
	pthread_rwlock_unlock(&dictLock);
	return returnMe;
}


- (void) setObject:(id)o forKey:(NSString *)s	{
	if ((dict != nil) && (o != nil) && (s != nil))	{
		//@try	{
			[dict setObject:o forKey:s];
		//}
		//@catch (NSException *err)	{
		//	NSLog(@"\t\t%s - %@",__func__,err);
		//}
	}
}
- (void) lockSetObject:(id)o forKey:(NSString *)s	{
	pthread_rwlock_wrlock(&dictLock);
		[self setObject:o forKey:s];
	pthread_rwlock_unlock(&dictLock);
}


- (void) setValue:(id)v forKey:(NSString *)s	{
	if ((dict != nil) && (v != nil) && (s != nil))	{
		//@try	{
			[dict setValue:v forKey:s];
		//}
		//@catch (NSException *err)	{
		//	NSLog(@"\t\t%s - %@",__func__,err);
		//}
	}
}
- (void) lockSetValue:(id)v forKey:(NSString *)s	{
	pthread_rwlock_wrlock(&dictLock);
		[self setValue:v forKey:s];
	pthread_rwlock_unlock(&dictLock);
}


- (void) removeAllObjects	{
	if (dict != nil)	{
		//@try	{
			[dict removeAllObjects];
		//}
		//@catch (NSException *err)	{
		//	NSLog(@"\t\t%s - %@",__func__,err);
		//}
	}
}
- (void) lockRemoveAllObjects	{
	pthread_rwlock_wrlock(&dictLock);
		[self removeAllObjects];
	pthread_rwlock_unlock(&dictLock);
}


- (id) objectForKey:(NSString *)k	{
	if ((dict!=nil) && (k!=nil))	{
		id				returnMe = nil;
		//@try	{
			returnMe = [dict objectForKey:k];
		//}
		//@catch (NSException *err)	{
		//	NSLog(@"\t\t%s - %@",__func__,err);
		//}
		return returnMe;
	}
	return nil;
}
- (id) lockObjectForKey:(NSString *)k	{
	id		returnMe = nil;
	pthread_rwlock_rdlock(&dictLock);
		returnMe = [self objectForKey:k];
	pthread_rwlock_unlock(&dictLock);
	return returnMe;
}
- (void) removeObjectForKey:(NSString *)k	{
	if ((k==nil)||(dict==nil))	{
		return;
	}
	[dict removeObjectForKey:k];
}
- (void) lockRemoveObjectForKey:(NSString *)k	{
	if ((k==nil)||(dict==nil))	{
		return;
	}
	pthread_rwlock_wrlock(&dictLock);
		[self removeObjectForKey:k];
	pthread_rwlock_unlock(&dictLock);
}
- (NSArray *) allKeys	{
	if ((dict!=nil)&&([dict count]>0))	{
		id			returnMe = nil;
		returnMe = [dict allKeys];
		return returnMe;
	}
	return nil;
}
- (NSArray *) lockAllKeys	{
	id		returnMe = nil;
	pthread_rwlock_rdlock(&dictLock);
		returnMe = [self allKeys];
	pthread_rwlock_unlock(&dictLock);
	return returnMe;
}
- (NSArray *) allValues	{
	if ((dict!=nil)&&([dict count]>0))	{
		id			returnMe = nil;
		returnMe = [dict allValues];
		return returnMe;
	}
	return nil;
}
- (NSArray *) lockAllValues	{
	id		returnMe = nil;
	pthread_rwlock_rdlock(&dictLock);
		returnMe = [dict allValues];
	pthread_rwlock_unlock(&dictLock);
	return returnMe;
}


- (void) lockMakeObjectsPerformSelector:(SEL)s	{
	if (dict==nil)
		return;
	pthread_rwlock_rdlock(&dictLock);
		[self makeObjectsPerformSelector:s];
	pthread_rwlock_unlock(&dictLock);
}
- (void) makeObjectsPerformSelector:(SEL)s	{
	if (dict == nil)
		return;
	NSArray			*valArray = [dict allValues];
	if (valArray != nil)
		[valArray makeObjectsPerformSelector:s];
}


- (void) addEntriesFromDictionary:(NSDictionary *)otherDictionary	{
	if ((dict!=nil)&&(otherDictionary!=nil)&&([otherDictionary count]))	{
		[dict addEntriesFromDictionary:otherDictionary];
	}
}
- (void) lockAddEntriesFromDictionary:(NSDictionary *)otherDictionary	{
	if ((dict==nil)||(otherDictionary==nil)||([otherDictionary count]==0))
		return;
	pthread_rwlock_wrlock(&dictLock);
		[self addEntriesFromDictionary:otherDictionary];
	pthread_rwlock_unlock(&dictLock);	
}
- (NSInteger) count	{
	if (dict!=nil)
		return [dict count];
	return 0;
}
- (NSInteger) lockCount	{
	NSInteger	returnMe = 0;
	pthread_rwlock_rdlock(&dictLock);
		returnMe = [self count];
	pthread_rwlock_unlock(&dictLock);
	return returnMe;
}

@end

#import "VVKQueueCenter.h"




id			_mainVVKQueueCenter = nil;




@interface VVKQueueCenter ()
- (void) updateEntries;
- (BOOL) startConnectionForPathIfNeeded:(NSString *)p fileDescriptor:(int)fd;
- (void) closeConnectionForPathIfNeeded:(NSString *)p fileDescriptor:(int)fd;
@end




@implementation VVKQueueCenter


+ (void) initialize	{
	_mainVVKQueueCenter = [[VVKQueueCenter alloc] init];
}
+ (id) mainCenter	{
	return _mainVVKQueueCenter;
}
+ (void) addObserver:(id)o forPath:(NSString *)p	{
	[_mainVVKQueueCenter addObserver:o forPath:p];
}
+ (void) removeObserver:(id)o	{
	[_mainVVKQueueCenter removeObserver:o];
}
+ (void) removeObserver:(id)o forPath:(NSString *)p	{
	[_mainVVKQueueCenter removeObserver:o forPath:p];
}
- (id) init	{
	self = [super init];
	if (self != nil)	{
		kqueueFD = -1;
		entries = [[MutLockArray alloc] init];
		entryChanges = [[MutLockArray alloc] init];
		threadHaltFlag = NO;
		currentlyProcessing = NO;
		
		kqueueFD = kqueue();
		if (kqueueFD == -1)	{
			NSLog(@"\t\terr: couldn't create kqueueFD: %d",kqueueFD);
			goto BAIL;
		}
		
		[NSThread detachNewThreadSelector:@selector(threadLaunch:) toTarget:self withObject:nil];
	}
	return self;
	BAIL:
	[self release];
	return nil;
}
- (void) dealloc	{
	threadHaltFlag = YES;
	while (currentlyProcessing)
		pthread_yield_np();
	if (kqueueFD != -1)
		close(kqueueFD);
	VVRELEASE(entries);
	VVRELEASE(entryChanges);
	[super dealloc];
}


- (void) threadLaunch:(id)sender	{
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	
	USE_CUSTOM_ASSERTION_HANDLER
	
	int						poolCount = 0;
	int						fileDescriptor = kqueueFD;
	
	//if ([VVStatChecker maxFileHandlerCount]==0)
	//	[VVStatChecker computeMaxFileHandlerCount];
	
	currentlyProcessing = YES;
	while (!threadHaltFlag)	{
		int						n;
		struct kevent			event;
		struct timespec			timeout = {1,0};
		
		[self updateEntries];
		
		n = kevent(kqueueFD, NULL, 0, &event, 1, &timeout);
		
		if ([entryChanges count]>0)
			[self updateEntries];
		
		if (n > 0)	{
			//NSLog(@"\t\tfound event");
			if (event.filter == EVFILT_VNODE)	{
				if (event.fflags)	{
					NSString		*path = [[(NSString *)event.udata retain] autorelease];
					//	find all the entries matching the path
					NSMutableArray	*entriesToPing = nil;
					[entries rdlock];
					for (VVKQueueEntry *entry in [entries array])	{
						NSString		*entryPath = [entry path];
						if (entryPath!=nil && [entryPath isEqualToString:path])	{
							if (entriesToPing == nil)
								entriesToPing = MUTARRAY;
							[entriesToPing addObject:entry];
						}
					}
					[entries unlock];
					//	if there are entries to ping- do so now!
					for (VVKQueueEntry *entry in entriesToPing)	{
						[[entry delegate] file:path changed:event.fflags];
					}
				}
			}
		}
		
		//	purge an entries with nil delegates (which will happen if the delegate was freed but not remvoed as an observer)
		NSMutableIndexSet	*indexesToDelete = nil;
		[entries wrlock];
		NSInteger			tmpIndex = 0;
		for (VVKQueueEntry *entry in [entries array])	{
			if ([entry delegate]==nil)	{
				if (indexesToDelete == nil)
					indexesToDelete = [[[NSMutableIndexSet alloc] init] autorelease];
				[indexesToDelete addIndex:tmpIndex];
			}
			++tmpIndex;
		}
		if (indexesToDelete != nil)
			[entries removeObjectsAtIndexes:indexesToDelete];
		[entries unlock];
		
		
		++poolCount;
		if (poolCount > 1)	{
			[pool release];
			pool = [[NSAutoreleasePool alloc] init];
			poolCount = 0;
		}
	}
	
	close(fileDescriptor);
	currentlyProcessing = NO;
	
	[pool release];
}


- (void) addObserver:(id)o forPath:(NSString *)p	{
	//	make an entry
	VVKQueueEntry		*newEntry = [VVKQueueEntry createWithDelegate:o path:p];
	if (newEntry == nil)
		return;
	//	we want this entry to be an "add"
	[newEntry setAddFlag:YES];
	//	add it to the array of changes
	[entryChanges lockAddObject:newEntry];
}
- (void) removeObserver:(id)o	{
	//	make an entry
	VVKQueueEntry		*newEntry = [VVKQueueEntry createWithDelegate:o path:nil];
	if (newEntry == nil)
		return;
	//	we want this entry to be an "remove"
	[newEntry setAddFlag:NO];
	//	add it to the array of changes
	[entryChanges lockAddObject:newEntry];
}
- (void) removeObserver:(id)o forPath:(NSString *)p	{
	//	make an entry
	VVKQueueEntry		*newEntry = [VVKQueueEntry createWithDelegate:o path:p];
	if (newEntry == nil)
		return;
	//	we want this entry to be an "remove"
	[newEntry setAddFlag:NO];
	//	add it to the array of changes
	[entryChanges lockAddObject:newEntry];
}


- (void) updateEntries	{
	//	copy the contents of 'entryChanges', then clear it out
	[entryChanges wrlock];
	NSMutableArray		*tmpChanges = [entryChanges createArrayCopy];
	[entryChanges removeAllObjects];
	[entryChanges unlock];
	
	//	run through the copied entries, applying their changes
	for (VVKQueueEntry *tmpEntry in tmpChanges)	{
		NSString	*tmpPath = [tmpEntry path];
		id			tmpDelegate = [tmpEntry delegate];
		//	if we're supposed to be adding this entry...
		if ([tmpEntry addFlag])	{
			//	calculate and set the entry's file descriptor...
			int			fileDescriptor = open([tmpPath fileSystemRepresentation], O_EVTONLY, 0);
			if (fileDescriptor < 0)	{
				NSLog(@"error: entries count %ld on failure to opening rep. for path to watch, %s : %@",[entries lockCount],__func__,tmpPath);
				continue;
			}
			[tmpEntry setFD:NUMINT(fileDescriptor)];
			
			//	start the connection
			[self startConnectionForPathIfNeeded:tmpPath fileDescriptor:fileDescriptor];
			
			//	add the entry to the array of entries AFTER STARTING THE CONNECTION (order is important)
			[entries lockAddObject:tmpEntry];
		}
		else	{
			//	remove the entry (or entries!) from the array of entries BEFORE CLOSING THE CONNECTION (order is important)
			
			NSMutableIndexSet		*indexesToRemove = nil;
			NSArray					*entriesToRemove = nil;
			NSInteger				tmpIndex = 0;
			[entries wrlock];
			//	if there's no "path", then we want to remove all existing entries that match the tmp entry's delegate
			if (tmpPath == nil)	{
				for (VVKQueueEntry *existingEntry in [entries array])	{
					if ([existingEntry delegate] == tmpDelegate)	{
						if (indexesToRemove == nil)
							indexesToRemove = [[[NSMutableIndexSet alloc] init] autorelease];
						[indexesToRemove addIndex:tmpIndex];
					}
					++tmpIndex;
				}
			}
			//	else there's a "path"- we want to remove only the entries that are an exact match to the tmp entry's delegate/path
			else	{
				for (VVKQueueEntry *existingEntry in [entries array])	{
					id<VVKQueueCenterDelegate>	existingDelegate = [existingEntry delegate];
					NSString		*existingPath = [existingEntry path];
					if (existingDelegate==tmpDelegate && existingPath!=nil && [existingPath isEqualToString:tmpPath])	{
						if (indexesToRemove == nil)
							indexesToRemove = [[[NSMutableIndexSet alloc] init] autorelease];
						[indexesToRemove addIndex:tmpIndex];
					}
					++tmpIndex;
				}
			}
			//	copy the entries we're about to remove (we want their FDs), then remove them from the array of entries
			if (indexesToRemove != nil)	{
				entriesToRemove = [entries objectsAtIndexes:indexesToRemove];
				[entries removeObjectsAtIndexes:indexesToRemove];
			}
			[entries unlock];
			
			//	run through the array of entries we just removed from the array, closing the connection for each
			for (VVKQueueEntry *entryToRemove in entriesToRemove)	{
				//	close the connection AFTER REMOVING THE ENTRIES FROM THE ARRAY (order is important)
				[self closeConnectionForPathIfNeeded:[entryToRemove path] fileDescriptor:[[entryToRemove fd] intValue]];
			}
		}
	}
}
- (BOOL) startConnectionForPathIfNeeded:(NSString *)p fileDescriptor:(int)fd	{
	//NSLog(@"%s",__func__);
	if (p == nil)
		return NO;
		
	BOOL	needsStart = YES;
	//	Go through the paths array
	//	If a match is found, BAIL
	[entries rdlock];
	for (VVKQueueEntry *entry in [entries array])	{
		NSString		*entryPath = [entry path];
		if (entryPath!=nil && [entryPath isEqualToString:p])	{
			needsStart = NO;
			break;
		}
	}
	[entries unlock];
	
	if (needsStart)	{
		//NSLog(@"\t\t %@ with fd %ld", p, fd);
		struct kevent		event;
		struct timespec		tmpTime = {0,0};
		EV_SET(&event,
			fd,
			EVFILT_VNODE,
			EV_ADD | EV_ENABLE | EV_CLEAR,
			NOTE_RENAME | NOTE_WRITE | NOTE_DELETE | NOTE_ATTRIB,
			0,
			[p copy]);
			
		kevent(kqueueFD, &event, 1, NULL, 0, &tmpTime);
	}
	
	return needsStart;
}
- (void) closeConnectionForPathIfNeeded:(NSString *)p fileDescriptor:(int)fd	{
	//NSLog(@"%s",__func__);
	if (p == nil)
		return;
		
	BOOL	needsClose = YES;
	//	Go through the paths array
	//	If a match is found, BAIL
	[entries rdlock];
	for (VVKQueueEntry *entry in [entries array])	{
		NSString		*entryPath = [entry path];
		if (entryPath!=nil && [entryPath isEqualToString:p])	{
			needsClose = NO;
			break;
		}
	}
	[entries unlock];
	
	if (needsClose)	{
		//NSLog(@"\t\tclosing %@ with fd %ld", p, fd);
		close(fd);
	}
}


@end



#pragma mark -
#pragma mark -



@implementation VVKQueueEntry


+ (id) createWithDelegate:(id<VVKQueueCenterDelegate>)d path:(NSString *)p	{
	return [[[VVKQueueEntry alloc] initWithDelegate:d path:p] autorelease];
}
- (id) initWithDelegate:(id<VVKQueueCenterDelegate>)d path:(NSString *)p	{
	self = [super init];
	if (self != nil)	{
		path = nil;
		fd = nil;
		delegateLock = OS_SPINLOCK_INIT;
		delegate = nil;
		[self setDelegate:d];
		[self setPath:p];
	}
	return self;
}
- (void) dealloc	{
	[self setPath:nil];
	[self setFD:nil];
	[self setDelegate:nil];
	[super dealloc];
}
@synthesize path;
@synthesize fd;
- (void) setDelegate:(id<VVKQueueCenterDelegate>)n	{
	OSSpinLockLock(&delegateLock);
	VVRELEASE(delegate);
	if (n!=nil && [(id)n respondsToSelector:@selector(file:changed:)])
		delegate = [[ObjectHolder alloc] initWithZWRObject:n];
	OSSpinLockUnlock(&delegateLock);
}
- (id<VVKQueueCenterDelegate>) delegate	{
	OSSpinLockLock(&delegateLock);
	id<VVKQueueCenterDelegate>		returnMe = [delegate object];
	OSSpinLockUnlock(&delegateLock);
	return returnMe;
}
@synthesize addFlag;


@end
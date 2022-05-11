#import "VVLogger.h"

#import "VVBasicMacros.h"

#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#include <assert.h>




//	uncomment the following and manually specify the following vals if you pull this class out of this framework...
/*
#define USING_MRC 0
#define USING_ARC 1

// Sanity checks
#if USING_GC
#   if USING_ARC || USING_MRC
#      error "Cannot specify GC and RC memory management"
#   endif
#elif USING_ARC
#   if USING_MRC
#      error "Cannot specify ARC and MRC memory management"
#   endif
#elif !USING_MRC
#   error "Must specify GC, ARC or MRC memory management"
#endif
#if USING_ARC
#   if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_6
#      error "ARC requires at least 10.6"
#   endif
#endif

//	macros for checking to see if something is nil, and if it's not releasing and setting it to nil
#if USING_MRC
#define VVRELEASE(item) {if (item != nil)	{			\
	[item release];										\
	item = nil;											\
}}
#define VVAUTORELEASE(item) {if (item != nil)	{		\
	[item autorelease];									\
	item = nil;											\
}}
#elif USING_ARC
#define VVRELEASE(item) {if (item != nil)	{			\
	item = nil;											\
}}
#define VVAUTORELEASE(item) {if (item != nil)	{		\
	item = nil;											\
}}
#endif
*/



static VVLogger		*_globalVVLogger = nil;




NSString * VVLoggerRealHomeDirectory(void);




@interface VVLogFile ()
+ (id) createWithPath:(NSString *)p openDate:(NSDate *)od closeDate:(NSDate *)cd;
- (id) initWithPath:(NSString *)p openDate:(NSDate *)od closeDate:(NSDate *)cd;
@property (retain,readwrite) NSString *path;
@property (retain,readwrite) NSDate *openDate;
@property (retain,readwrite) NSDate *closeDate;
- (BOOL) encompassesDate:(NSDate *)n;
@end

@implementation VVLogFile
+ (id) createWithPath:(NSString *)p openDate:(NSDate *)od closeDate:(NSDate *)cd	{
#if USING_MRC
	return [[[VVLogFile alloc] initWithPath:p openDate:od closeDate:cd] autorelease];
#elif USING_ARC
	return [[VVLogFile alloc] initWithPath:p openDate:od closeDate:cd];
#endif
}
- (id) initWithPath:(NSString *)p openDate:(NSDate *)od closeDate:(NSDate *)cd	{
	self = [super init];
	if (self != nil)	{
		[self setPath:nil];
		[self setOpenDate:nil];
		[self setCloseDate:nil];
		
		if (p==nil || od==nil || cd==nil)	{
#if USING_MRC
			[self release];
#endif
			self = nil;
			return self;
		}
		
		[self setPath:p];
		[self setOpenDate:od];
		[self setCloseDate:cd];
	}
	return self;
}
- (void) dealloc	{
	[self setPath:nil];
	[self setOpenDate:nil];
	[self setCloseDate:nil];
#if USING_MRC
	[super dealloc];
#endif
}
- (NSString *) description	{
	return [NSString stringWithFormat:@"<VVLogFile %@>",[self path]];
}
- (BOOL) encompassesDate:(NSDate *)n	{
	if (n==nil)
		return NO;
	NSDate		*tmpOpenDate = [self openDate];
	NSDate		*tmpCloseDate = [self closeDate];
	if ([tmpOpenDate timeIntervalSinceDate:n]<0. && [tmpCloseDate timeIntervalSinceDate:n]>0.)
		return YES;
	return NO;
}
@end




@interface VVLogger ()
- (void) _cleanUpExistingLogs;
- (NSString *) _formatterString;
- (NSString *) logDir;
- (NSArray<VVLogFile*> *) sortedLogFiles;	//	return array of VVLogFile instances, not safe outside this class
@end




@implementation VVLogger

+ (id) globalLogger	{
	return _globalVVLogger;
}
- (id) initWithFolderName:(NSString *)fn maxNumLogs:(int)ml	{
	self = [super init];
	if (self != nil)	{
		logFolderName = nil;
		currentLogPath = nil;
		maxNumLogs = fmax(ml,0);
		
		if (fn != nil)	{
#if USING_MRC
			logFolderName = [fn retain];
#elif USING_ARC
			logFolderName = fn;
#endif
		}
		else	{
			NSBundle		*mainBundle = [NSBundle mainBundle];
			NSDictionary	*infoDict = (mainBundle==nil) ? nil : [mainBundle infoDictionary];
			NSString		*appName = (infoDict==nil) ? nil : [infoDict objectForKey:@"CFBundleName"];
			if (appName != nil)	{
#if USING_MRC
				logFolderName = [appName retain];
#elif USING_ARC
				logFolderName = appName;
#endif
			}
		}
		
		//	if we don't have a log folder name then we can't start redirecting- we need to kick up a fuss
		if (logFolderName == nil)	{
			NSLog(@"\t\tERR: logFolderName nil, cannot proceed, %s",__func__);
#if USING_MRC
			[self release];
#endif
			self = nil;
			return nil;
		}
		
		if (_globalVVLogger == nil)
			_globalVVLogger = self;
		
		//	clean up the existing log files
		[self _cleanUpExistingLogs];
		//	start redirecting logs
		//[self redirectLogs];
	}
	return self;
}
- (void) dealloc	{
	VVRELEASE(logFolderName);
	VVRELEASE(currentLogPath);
	
	if (_globalVVLogger == self)
		_globalVVLogger = nil;
	
#if USING_MRC
	[super dealloc];
#endif
}

- (void) _cleanUpExistingLogs	{
	//NSLog(@"%s",__func__);
	//	get the log directory- if it doesn't exist, we're done and can bail
	NSString			*logDir = [self logDir];
	NSFileManager		*fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:logDir])
		return;
	
	NSArray			*sortedLogFiles = [self sortedLogFiles];
	//NSLog(@"\t\tsortedLogFiles are %@",sortedLogFiles);
	if ([sortedLogFiles count]>maxNumLogs)	{
		int			deleteCount = (int)[sortedLogFiles count] - maxNumLogs;
		for (int i=0; i<deleteCount; ++i)	{
			NSString		*filePath = [[sortedLogFiles objectAtIndex:i] path];
			if (filePath != nil)	{
				//NSLog(@"\t\tcleaning up log at path %@",filePath);
				[fm removeItemAtURL:[NSURL fileURLWithPath:filePath] error:nil];
			}
		}
	}
}
- (void) redirectLogs	{
	//NSLog(@"%s",__func__);
	
	NSString			*logDir = [self logDir];
	NSFileManager		*fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:logDir])
		[fm createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:nil];
	
	NSDateFormatter		*fmt = [[NSDateFormatter alloc] init];
	[fmt setFormatterBehavior:NSDateFormatterBehavior10_4];
	[fmt setDateFormat:[self _formatterString]];
	NSString			*fileName = [fmt stringFromDate:[NSDate date]];
	NSString			*fullPath = [NSString stringWithFormat:@"%@/%@",logDir,fileName];
	VVRELEASE(currentLogPath);
#if USING_MRC
	currentLogPath = (fullPath==nil) ? nil : [fullPath retain];
#elif USING_ARC
	currentLogPath = fullPath;
#endif
	
	freopen([fullPath fileSystemRepresentation], "a+", stderr);
	
	VVRELEASE(fmt);
}
- (NSString *) _formatterString	{
	return [NSString stringWithFormat:@"yyyy.MM.dd-HH.mm.ss'-%@.log'",logFolderName];
}
- (NSString *) logDir	{
	//return [[NSString stringWithFormat:@"~/Library/Logs/%@",logFolderName] stringByExpandingTildeInPath];
	return [VVLoggerRealHomeDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"Library/Logs/%@",logFolderName]];
}
- (NSArray<VVLogFile*> *) sortedLogFiles	{
	//NSLog(@"%s",__func__);
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	NSString			*logDir = [self logDir];
	NSFileManager		*fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:logDir])
		return returnMe;
	
	NSDateFormatter		*fmt = [[NSDateFormatter alloc] init];
	[fmt setFormatterBehavior:NSDateFormatterBehavior10_4];
	[fmt setDateFormat:[self _formatterString]];
	
	//	run through every file in the log directory
	for (NSString *filename in [fm contentsOfDirectoryAtPath:logDir error:nil])	{
		//	parse the open date from the filename
		NSDate			*tmpOpenDate = [fmt dateFromString:filename];
		
		//	get the close date from the filesystem
		NSString		*fullPath = [NSString stringWithFormat:@"%@/%@",logDir,filename];
		NSDictionary	*attrs = [fm attributesOfItemAtPath:fullPath error:nil];
		NSDate			*tmpCloseDate = (attrs==nil) ? nil : [attrs objectForKey:NSFileModificationDate];
		
		//	make a log file object
		VVLogFile		*tmpFile = [VVLogFile createWithPath:fullPath openDate:tmpOpenDate closeDate:tmpCloseDate];
		if (tmpFile == nil)
			continue;
		[returnMe addObject:tmpFile];
	}
	
	//	sort the array of log file objects
	[returnMe sortUsingComparator:^(VVLogFile *file1, VVLogFile *file2)	{
		return [[file1 openDate] compare:[file2 openDate]];
	}];
	
	VVRELEASE(fmt);
	
	return returnMe;
}


- (NSString *) pathForLogEncompassingDate:(NSDate *)n	{
	if (n == nil)
		return nil;
	
	NSArray		*logs = [self sortedLogFiles];
	for (VVLogFile *log in logs)	{
		if ([log encompassesDate:n])
			return [log path];
	}
	
	return nil;
}
- (NSString *) pathForLogRightBeforeDate:(NSDate *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	if (n == nil)
		return nil;
	
	NSArray		*logs = [self sortedLogFiles];
	/*
	for (VVLogFile *log in logs)	{
		NSLog(@"\t\tlog %@ time interval since passed date is %f",log,[[log openDate] timeIntervalSinceDate:n]);
	}
	*/
	NSString	*lastLogPath = nil;
	for (VVLogFile *log in logs)	{
		if ([[log openDate] timeIntervalSinceDate:n] > 0.)	{
			return lastLogPath;
			break;
		}
		
		lastLogPath = [log path];
	}
	
	return lastLogPath;
}
- (NSString *) pathForCurrentLogFile	{
#if USING_MRC
	return [[currentLogPath copy] autorelease];
#elif USING_ARC
	return currentLogPath;
#endif
}
- (NSArray<NSURL*> *) sortedLogURLs	{
	NSMutableArray		*returnMe = nil;
#if USING_MRC
	returnMe = [NSMutableArray arrayWithCapacity:0];
#elif USING_ARC
	returnMe = [[NSMutableArray alloc] init];
#endif
	
	NSArray			*sortedLogFiles = [self sortedLogFiles];
	for (VVLogFile * file in sortedLogFiles)	{
		NSURL			*url = (file.path==nil) ? nil : [NSURL fileURLWithPath:file.path];
		if (url != nil)
			[returnMe addObject:url];
	}
	
	if (returnMe.count < 1)
		return nil;
	return [NSArray arrayWithArray:returnMe];
}

@end




NSString * VVLoggerRealHomeDirectory() {
    struct passwd *pw = getpwuid(getuid());
    assert(pw);
    return [NSString stringWithUTF8String:pw->pw_dir];
}

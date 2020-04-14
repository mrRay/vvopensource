#import <Cocoa/Cocoa.h>




@interface VVLogger : NSObject	{
	NSString		*logFolderName;
	NSString		*currentLogPath;	//	path to the current log file
	int				maxNumLogs;
}

+ (id) globalLogger;

//	if fn is nil, uses the bundle info dict's CFBundleName- if this is also nil, returns nil and does nothing.
- (id) initWithFolderName:(NSString *)fn maxNumLogs:(int)ml;

//	cleans up any extraneous logs, makes a new log file, and immediately redirects all logging to that file.
- (void) redirectLogs;

- (NSString *) pathForLogEncompassingDate:(NSDate *)n;
- (NSString *) pathForLogRightBeforeDate:(NSDate *)n;
- (NSString *) pathForCurrentLogFile;

@end

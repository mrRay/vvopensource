
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <VVBasics/VVBasics.h>
#import <regex.h>




NSCharacterSet		*_OSCStrAdditionsWildcardCharSet;
MutLockDict			*_OSCStrPOSIXRegexDict;	//	key is the regex string, object is an OSCPOSIXRegExpHolder containing the compiled regex- which is threadsafe, and may be reused




@interface OSCPOSIXRegExpHolder : NSObject	{
	NSString	*regexString;
	regex_t		*regex;
}

+ (id) createWithString:(NSString *)n;
- (id) initWithString:(NSString *)n;
- (BOOL) evalAgainstString:(NSString *)n;
- (NSString *) regexString;

@end




@interface NSString (OSCStringAdditions)

- (NSString *) trimFirstAndLastSlashes;
- (NSString *) stringByDeletingFirstPathComponent;
- (NSString *) firstPathComponent;
- (NSString *) stringBySanitizingForOSCPath;
- (BOOL) containsOSCWildCard;

- (BOOL) predicateMatchAgainstRegex:(NSString *)r;
- (BOOL) posixMatchAgainstSlowRegex:(NSString *)r;
- (BOOL) posixMatchAgainstFastRegex:(NSString *)r;

@end

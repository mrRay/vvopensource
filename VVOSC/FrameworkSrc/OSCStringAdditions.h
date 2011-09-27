
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <VVBasics/VVBasics.h>
#import <regex.h>




extern NSCharacterSet		*_OSCStrAdditionsWildcardCharSet;
extern MutLockDict			*_OSCStrPOSIXRegexDict;	//	key is the regex string, object is an OSCPOSIXRegExpHolder containing the compiled regex- which is threadsafe, and may be reused




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

+ (NSString *) stringWithBytes:(const void *)b length:(NSUInteger)l encoding:(NSStringEncoding)e;
+ (NSString *) stringFromRawIPAddress:(unsigned long)i;
- (NSString *) trimFirstAndLastSlashes;
- (NSString *) stringByDeletingFirstPathComponent;
- (NSString *) firstPathComponent;
- (NSString *) stringBySanitizingForOSCPath;
- (NSString *) stringByDeletingLastAndAddingFirstSlash;
- (BOOL) containsOSCWildCard;

- (BOOL) predicateMatchAgainstRegex:(NSString *)r;
- (BOOL) posixMatchAgainstSlowRegex:(NSString *)r;
- (BOOL) posixMatchAgainstFastRegex:(NSString *)r;

@end

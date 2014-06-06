
#import "OSCStringAdditions.h"
#include <ifaddrs.h>
#include <arpa/inet.h>




NSCharacterSet		*_OSCStrAdditionsWildcardCharSet;
MutLockDict			*_OSCStrPOSIXRegexDict;	//	key is the regex string, object is an OSCPOSIXRegExpHolder containing the compiled regex- which is threadsafe, and may be reused




@implementation OSCPOSIXRegExpHolder


+ (id) createWithString:(NSString *)n	{
	id		returnMe = (id)[[OSCPOSIXRegExpHolder alloc] initWithString:n];
	return (returnMe==nil) ? nil : [returnMe autorelease];
}
- (id) initWithString:(NSString *)n	{
	if (self = [super init])	{
		regexString = nil;
		regex = nil;
		if (n==nil)
			goto BAIL;
		regexString = [n retain];
		regex = calloc(1,sizeof(regex_t));
		const char		*cStr = [regexString cStringUsingEncoding:NSASCIIStringEncoding];
		if (cStr == nil)
			goto BAIL;
		int				err = regcomp(regex,cStr,REG_EXTENDED|REG_NOSUB);
		if (err != 0)	{
			NSLog(@"\t\terr %d while compiling regex in %s",err,__func__);
			goto BAIL;
		}
		return self;
	}
	BAIL:
	[self release];
	return nil;
}
- (void) dealloc	{
	if (regexString != nil)	{
		[regexString release];
		regexString = nil;
	}
	if (regex != nil)	{
		regfree(regex);
		free(regex);
		regex = nil;
	}
	[super dealloc];
}
- (BOOL) evalAgainstString:(NSString *)n	{
	if (n == nil)
		return NO;
	const char		*cStr = [n cStringUsingEncoding:NSASCIIStringEncoding];
	if (cStr == nil)
		return NO;
	int				err = regexec(regex,cStr,0,nil,0);
	if (err != 0)	{
		//NSLog(@"\t\terr %d while executing regex %@ on string %@",err,regexString,n);
		return NO;
	}
	return YES;
}
- (NSString *) regexString	{
	return regexString;
}


@end




@implementation NSString (OSCStringAdditions)


+ (void) load	{
	//NSLog(@"%s",__func__);
	_OSCStrAdditionsWildcardCharSet = nil;
	_OSCStrPOSIXRegexDict = nil;
}
+ (NSString *) stringWithBytes:(const void *)b length:(NSUInteger)l encoding:(NSStringEncoding)e	{
	NSString		*returnMe = nil;
	returnMe = [[NSString alloc]
		initWithBytes:b
		length:l
		encoding:e];
	return (returnMe==nil)?nil:[returnMe autorelease];
}
+ (NSString *) stringFromRawIPAddress:(unsigned long)i	{
	struct in_addr		tmpAddr;
	tmpAddr.s_addr = (unsigned int)i;
	return [NSString stringWithCString:inet_ntoa(tmpAddr) encoding:NSASCIIStringEncoding];
}
- (NSString *) trimFirstAndLastSlashes	{
	NSUInteger		origLength = [self length];
	NSRange			desiredRange = NSMakeRange(0,origLength);
	switch (origLength)	{
		case 0:
			return self;
		case 1:
			return (([self isEqualToString:@"/"]) ? [NSString string] : self);
		default:
			if ([self characterAtIndex:desiredRange.length-1] == '/')
				--desiredRange.length;
			if ([self characterAtIndex:0] == '/')	{
				--desiredRange.length;
				++desiredRange.location;
			}
			break;
	}
	if (desiredRange.length==origLength)
		return self;
	return [self substringWithRange:desiredRange];
}
- (NSString *) stringByDeletingFirstPathComponent	{
	//NSLog(@"%s ... %@",__func__,self);
	NSArray			*pathArray = [[self trimFirstAndLastSlashes] pathComponents];
	NSString		*tmpString = nil;
	for (NSString *pathComponent in pathArray)	{
		if (tmpString == nil)
			tmpString = @"";
		else
			tmpString = [NSString stringWithFormat:@"%@/%@",tmpString,pathComponent];
	}
	//NSLog(@"\treturning %@",tmpString);
	return tmpString;
	
	/*
	NSMutableArray		*pathComponents = [[[[self trimFirstAndLastSlashes] pathComponents] mutableCopy] autorelease];
	//NSLog(@"\tinterim is %@",pathComponents);
	if ((pathComponents!=nil)&&([pathComponents count]>0))	{
		[pathComponents removeObjectAtIndex:0];
		//NSLog(@"\tinterim2 is %@",pathComponents);
		//NSLog(@"\treturning %@",[NSString pathWithComponents:pathComponents]);
		return [NSString stringWithFormat:@"/%@",[NSString pathWithComponents:pathComponents]];
	}
	return nil;
	*/
}
- (NSString *) firstPathComponent	{
	NSString	*trimmedString = [self trimFirstAndLastSlashes];
	NSArray		*pathComponents = [trimmedString pathComponents];
	return [pathComponents objectAtIndex:0];
}
- (NSString *) stringBySanitizingForOSCPath	{
	//NSLog(@"%s",__func__);
	//	if i don't have any characters, return nil immediately
	if ([self length]<1)
		return nil;
	//	if there are two slashes next to one another, return nil immediately
	if ([self rangeOfString:@"//"].location != NSNotFound)
		return nil;
	
	long			length = [self length];
	NSRange			desiredRange = NSMakeRange(0,length);
	
	//	figure out if it ends with a slash
	if ([self characterAtIndex:desiredRange.length-1] == '/')
		--desiredRange.length;
	
	//	if i start with a slash...
	if ([self characterAtIndex:0] == '/')	{
		//	if the length didn't change, i don't end with a slash- so i can just return myself
		if (length == desiredRange.length)
			return self;
		//	else if the desired range has a length of less than 1, return nil
		else if (desiredRange.length < 1)
			return nil;
		//	else if the length did change, just return a substring
		return [self substringWithRange:desiredRange];
	}
	//	else if i don't start with a slash, i'll have to add one
	else	{
		//	if the length didn't change, i don't end with a slash- i just have to add one
		if (length == desiredRange.length)
			return [NSString stringWithFormat:@"/%@",self];
		//	else if the length changed, i have to add a slash at the start and delete one at the end
		else
			return [NSString stringWithFormat:@"/%@",[self substringWithRange:desiredRange]];
	}
}
- (NSString *) stringByDeletingLastAndAddingFirstSlash	{
	NSString	*returnMe = nil;
	NSUInteger	myLength = [self length];
	if (myLength < 1)
		return nil;
	BOOL		endsWSlash = ([self characterAtIndex:myLength-1]=='/')?YES:NO;
	BOOL		startsWSlash = ([self characterAtIndex:0]=='/')?YES:NO;
	if (startsWSlash && myLength<2)
		endsWSlash = NO;
	if (startsWSlash && endsWSlash)
		returnMe = [self substringWithRange:NSMakeRange(0,myLength-1)];
	else if (startsWSlash && !endsWSlash)
		returnMe = self;
	else if (!startsWSlash && endsWSlash)
		returnMe = [NSString stringWithFormat:@"/%@",[self substringWithRange:NSMakeRange(0,myLength-1)]];
	else if (!startsWSlash && !endsWSlash)
		returnMe = [NSString stringWithFormat:@"/%@",self];
	return returnMe;
}
- (BOOL) containsOSCWildCard	{
	if (_OSCStrAdditionsWildcardCharSet == nil)	{
		@synchronized ([self class])	{
			if (_OSCStrAdditionsWildcardCharSet == nil)	{
				_OSCStrAdditionsWildcardCharSet = [NSCharacterSet characterSetWithCharactersInString:@"[\\^$.|?*+("];
				if (_OSCStrAdditionsWildcardCharSet != nil)	{
					//NSLog(@"\t\tmade OSC wildcard char set!");
					[_OSCStrAdditionsWildcardCharSet retain];
				}
			}
		}
	}
	NSRange		foundRange = [self rangeOfCharacterFromSet:_OSCStrAdditionsWildcardCharSet];
	if (foundRange.location==NSNotFound || foundRange.length<1)
		return NO;
	return YES;
}
- (BOOL) predicateMatchAgainstRegex:(NSString *)r	{
	if (r==nil || [r length]<1)
		return NO;
	NSPredicate		*pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",r];
	return (pred==nil) ? NO : [pred evaluateWithObject:self];
}
- (BOOL) posixMatchAgainstSlowRegex:(NSString *)r	{
	if (r==nil)
		return NO;
	const char			*regexCStr = [r cStringUsingEncoding:NSASCIIStringEncoding];
	if (regexCStr == nil)
		return NO;
	regex_t				regex;
	int					err = regcomp(&regex,regexCStr,REG_EXTENDED|REG_NOSUB);
	if (err != 0)	{
		NSLog(@"\t\terr %d while compiling regex",err);
		regfree(&regex);
		return NO;
	}
	const char			*targetCStr = [self cStringUsingEncoding:NSASCIIStringEncoding];
	//const int			count = 1 + regex->re_nsub;
	//regmatch_t			match[count];
	//err = regexec(&regex,targetCStr,count,match,0);
	err = regexec(&regex,targetCStr,0,nil,0);
	if (err != 0)	{
		NSLog(@"\t\terr %d while executing regex",err);
		regfree(&regex);
		return NO;
	}
	
	regfree(&regex);
	return YES;
}
- (BOOL) posixMatchAgainstFastRegex:(NSString *)r	{
	if (r == nil)
		return NO;
	if (_OSCStrPOSIXRegexDict == nil)	{
		@synchronized ([self class])	{
			if (_OSCStrPOSIXRegexDict == nil)	{
				_OSCStrPOSIXRegexDict = [[MutLockDict alloc] init];
			}
		}
	}
	OSCPOSIXRegExpHolder		*regex = [_OSCStrPOSIXRegexDict lockObjectForKey:r];
	if (regex == nil)	{
		regex = [OSCPOSIXRegExpHolder createWithString:r];
		if (regex != nil)	{
			BOOL		returnMe = [regex evalAgainstString:self];
			[_OSCStrPOSIXRegexDict lockSetObject:regex forKey:r];
			return returnMe;
		}
		else
			return NO;
	}
	else
		return [regex evalAgainstString:self];
}


@end

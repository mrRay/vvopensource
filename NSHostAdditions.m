
#import "NSHostAdditions.h"
#include <ifaddrs.h>
#include <arpa/inet.h>




@implementation NSHost (NSHostAdditions)

- (NSArray *) IPv4Addresses	{
	struct ifaddrs		*interfaces = nil;
	int					err = 0;
	//	get the current interfaces
	err = getifaddrs(&interfaces);
	if (err)	{
		NSLog(@"\t\terr %d getting ifaddrs in %s",err,__func__);
		return nil;
	}
	//	define a character range with alpha-numeric chars so i can exclude IPv6 addresses!
	NSCharacterSet		*charSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefABCDEF:%"];
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	
	//	run through the interfaces
	struct ifaddrs		*tmpAddr = interfaces;
	while (tmpAddr != nil)	{
		if (tmpAddr->ifa_addr->sa_family == AF_INET)	{
			//	get the string for the interface
			NSString		*tmpString = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)tmpAddr->ifa_addr)->sin_addr)];
			if (tmpString != nil)	{
				//	make sure the interface string doesn't have any alpha-numeric/IPv6 chars in it!
				NSRange				charSetRange = [tmpString rangeOfCharacterFromSet:charSet];
				if ((charSetRange.length==0) && (charSetRange.location==NSNotFound))	{
					if (![tmpString isEqualToString:@"127.0.0.1"])
						[returnMe addObject:tmpString];
				}
			}
		}
		tmpAddr = tmpAddr->ifa_next;
	}
	
	if (interfaces != nil)	{
		freeifaddrs(interfaces);
		interfaces = nil;
	}
	return returnMe;
}

@end

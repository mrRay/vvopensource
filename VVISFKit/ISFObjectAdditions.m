#import "ISFObjectAdditions.h"




@implementation NSObject (ISFObjectAdditions)


- (NSString *) JSONString	{
	//NSLog(@"%s",__func__);
	NSError			*nsErr = nil;
	NSData			*tmpData = [NSJSONSerialization dataWithJSONObject:self options:0 error:&nsErr];
	if (tmpData == nil || [tmpData length]<1)	{
		NSLog(@"\t\terr, %s: %@.  %@",__func__,nsErr,self);
	}
	NSString		*returnMe = (tmpData==nil) ? nil : [[[NSString alloc] initWithData:tmpData encoding:NSUTF8StringEncoding] autorelease];
	return returnMe;
}
- (NSString *) prettyJSONString	{
	//NSLog(@"%s",__func__);
	NSError			*nsErr = nil;
	NSData			*tmpData = [NSJSONSerialization dataWithJSONObject:self options:NSJSONWritingPrettyPrinted error:&nsErr];
	if (tmpData == nil || [tmpData length]<1)	{
		NSLog(@"\t\terr, %s: %@.  %@",__func__,nsErr,self);
	}
	NSString		*returnMe = (tmpData==nil) ? nil : [[[NSString alloc] initWithData:tmpData encoding:NSUTF8StringEncoding] autorelease];
	return returnMe;
}


@end


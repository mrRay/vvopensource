
#import "VVAssertionHandler.h"




@implementation VVAssertionHandler


- (void)handleFailureInMethod:(SEL)selector object:(id)object file:(NSString *)fileName lineNumber:(NSInteger)line description:(NSString *)format,...	{
	NSLog(@"**** ERR: assertion failure!");
	NSLog(@"**** [%@ %@]",object,NSStringFromSelector(selector));
	NSLog(@"**** %@, %ld",fileName,line);
	
	va_list			argList;
	va_start(argList,format);
	NSLog(format,argList);
	va_end(argList);
}
- (void)handleFailureInFunction:(NSString *)functionName file:(NSString *)fileName lineNumber:(NSInteger)line description:(NSString *)format,...	{
	NSLog(@"**** ERR: assertion failure!");
	NSLog(@"**** %@",functionName);
	NSLog(@"**** %@, %ld",fileName,line);
	
	va_list			argList;
	va_start(argList,format);
	NSLog(format,argList);
	va_end(argList);
}


@end

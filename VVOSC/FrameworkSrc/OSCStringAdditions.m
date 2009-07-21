
#import "OSCStringAdditions.h"




@implementation NSString (OSCStringAdditions)


- (NSString *) trimFirstAndLastSlashes	{
	NSRange			desiredRange = NSMakeRange(0,[self length]);
	if ([self characterAtIndex:desiredRange.length-1] == '/')
		--desiredRange.length;
	if ([self characterAtIndex:0] == '/')	{
		--desiredRange.length;
		++desiredRange.location;
	}
	
	if (desiredRange.length == [self length])
		return self;
	return [self substringWithRange:desiredRange];
}
- (NSString *) stringByDeletingFirstPathComponent	{
	//NSLog(@"%s ... %@",__func__,self);
	NSArray			*pathArray = [[self trimFirstAndLastSlashes] pathComponents];
	NSString		*tmpString = nil;
	for (NSString *pathComponent in pathArray)	{
		if (tmpString == nil)
			tmpString = [NSString stringWithString:@""];
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
	
	int				length = [self length];
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


@end

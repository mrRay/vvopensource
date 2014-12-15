#import "VVBufferPoolStringAdditions.h"




@implementation NSString (VVBufferPoolStringAdditions)


+ (NSString *) stringFromFourCC:(OSType)n	{
	char		destCharPtr[5];
	destCharPtr[0] = (n>>24) & 0xFF;
	destCharPtr[1] = (n>>16) & 0xFF;
	destCharPtr[2] = (n>>8) & 0xFF;
	destCharPtr[3] = (n) & 0xFF;
	destCharPtr[4] = 0;
	return [NSString stringWithCString:destCharPtr encoding:NSASCIIStringEncoding];
	
}
- (BOOL) containsString:(NSString *)s	{
	NSUInteger			passedStringLength = [s length];
	if ((s == nil) || (passedStringLength > [self length]))
		return NO;
	NSRange		foundRange = [self rangeOfString:s];
	if ((foundRange.location==NSNotFound)||(foundRange.length!=passedStringLength))
		return NO;
	return YES;
}
- (BOOL) containsString:(NSString *)s options:(NSStringCompareOptions)mask	{
	NSUInteger			passedStringLength = [s length];
	if ((s == nil) || (passedStringLength > [self length]))
		return NO;
	NSRange		rangeOfString = [self rangeOfString:s options:mask];
	if ((rangeOfString.location == NSNotFound) || (rangeOfString.length!=passedStringLength))
		return NO;
	return YES;
}

- (NSString *) firstChar	{
	unichar		lastCharacter;
	lastCharacter = [self characterAtIndex:0];
	return [NSString stringWithCharacters:&lastCharacter length:1];
}
- (BOOL) denotesFXPrimaryInput	{
	if ([self length]!=10)
		return NO;
	
	NSRange		tmpRange;
	tmpRange = [self rangeOfString:@"inputImage" options:NSCaseInsensitiveSearch];
	if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==10)&&([self length]==tmpRange.length))
		return YES;
	
	return NO;
}
- (BOOL) denotesFXInput	{
	if ([self length]<10)
		return NO;
	
	NSRange		tmpRange;
	tmpRange = [self rangeOfString:@"InputImage" options:NSCaseInsensitiveSearch];
	if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==10)&&([self length]==tmpRange.length))
		return YES;
	tmpRange = [self rangeOfString:@"Input Image" options:NSCaseInsensitiveSearch];
	if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==11)&&([self length]==tmpRange.length))
		return YES;
	tmpRange = [self rangeOfString:@"Input_Image" options:NSCaseInsensitiveSearch];
	if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==11)&&([self length]==tmpRange.length))
		return YES;
	tmpRange = [self rangeOfString:@"_protocolInput_Image" options:NSCaseInsensitiveSearch];
	if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==20)&&([self length]==tmpRange.length))
		return YES;
	tmpRange = [self rangeOfString:@"protocolInput_Image" options:NSCaseInsensitiveSearch];
	if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==19)&&([self length]==tmpRange.length))
		return YES;
	
	return NO;
}
- (BOOL) denotesCompositionTopImage	{
	if ([self length]<10)
		return NO;
	
	NSRange		tmpRange;
	tmpRange = [self rangeOfString:@"foreground" options:NSCaseInsensitiveSearch];
	if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==10)&&([self length]==tmpRange.length))
		return YES;
	tmpRange = [self rangeOfString:@"_protocolInput_DestinationImage" options:NSCaseInsensitiveSearch];
	if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==31)&&([self length]==tmpRange.length))
		return YES;
	tmpRange = [self rangeOfString:@"protocolInput_DestinationImage" options:NSCaseInsensitiveSearch];
	if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==30)&&([self length]==tmpRange.length))
		return YES;
	
	return NO;
}
- (BOOL) denotesCompositionBottomImage	{
	if ([self length]<10)
		return NO;
	
	NSRange		tmpRange;
	tmpRange = [self rangeOfString:@"background" options:NSCaseInsensitiveSearch];
	if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==10)&&([self length]==tmpRange.length))
		return YES;
	tmpRange = [self rangeOfString:@"_protocolInput_SourceImage" options:NSCaseInsensitiveSearch];
	if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==26)&&([self length]==tmpRange.length))
		return YES;
	tmpRange = [self rangeOfString:@"protocolInput_SourceImage" options:NSCaseInsensitiveSearch];
	if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==25)&&([self length]==tmpRange.length))
		return YES;
	
	return NO;
}
- (BOOL) denotesCompositionOpacity	{
	if ([self length]<7)
		return NO;
	
	NSRange		tmpRange;
	tmpRange = [self rangeOfString:@"opacity" options:NSCaseInsensitiveSearch];
	if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==7)&&([self length]==tmpRange.length))
		return YES;
	
	return NO;
}
- (BOOL) denotesTXTFileInput	{
	BOOL			returnMe = NO;
	if ([self length]==9)	{
		NSRange		tmpRange = [self rangeOfString:@"FileInput" options:NSCaseInsensitiveSearch];
		if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==9))
			returnMe = YES;
	}
	return returnMe;
}
- (BOOL) denotesIMGFileInput	{
	BOOL			returnMe = NO;
	if ([self length]==14)	{
		NSRange		tmpRange = [self rangeOfString:@"imageFileInput" options:NSCaseInsensitiveSearch];
		if ((tmpRange.location!=NSNotFound)&&(tmpRange.length==14))
			returnMe = YES;
	}
	return returnMe;
}


@end

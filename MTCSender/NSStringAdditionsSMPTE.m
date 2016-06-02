#import "NSStringAdditionsSMPTE.h"
//#import <DDMathParser/DDMathParser.h>




@implementation NSString (NSStringAdditions)


- (NSArray *) componentsSeparatedByRegex:(NSString *)r	{
	if (r==nil || [r length]<1)
		return nil;
	long			myLength = [self length];
	if (myLength<2)
		return [NSArray arrayWithObject:self];
	NSRegularExpression		*expr = [[[NSRegularExpression alloc] initWithPattern:r options:0 error:nil] autorelease];
	NSArray					*matches = [expr matchesInString:self options:0 range:NSMakeRange(0,myLength)];
	if (matches==nil || [matches count]<1)
		return [NSArray arrayWithObject:self];
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	NSRange				prevMatchRange = NSMakeRange(0,0);
	for (NSTextCheckingResult *match in matches)	{
		NSRange			matchRange = [match range];
		NSRange			interMatchStringRange;
		interMatchStringRange.location = prevMatchRange.location + prevMatchRange.length;
		interMatchStringRange.length = matchRange.location - interMatchStringRange.location;
		if (interMatchStringRange.length>0)	{
			NSString		*interMatchString = [self substringWithRange:interMatchStringRange];
			if (interMatchString != nil)
				[returnMe addObject:interMatchString];
		}
		prevMatchRange = matchRange;
	}
	
	if ((prevMatchRange.location+prevMatchRange.length)<myLength)	{
		NSRange			lastComponentRange;
		lastComponentRange.location = prevMatchRange.location + prevMatchRange.length;
		lastComponentRange.length = myLength - lastComponentRange.location;
		if (lastComponentRange.length>0)	{
			NSString		*lastComponent = [self substringWithRange:lastComponentRange];
			if (lastComponent != nil)
				[returnMe addObject:lastComponent];
		}
	}
	
	return returnMe;
}
+ (NSString *) smpteStringForTimeInSeconds:(double)time withFPS:(double)fps	{
	NSString		*returnMe = nil;
	double			smpteFPS = fps;
	double			rangedVal = time;
	
	long	tmpVal = floor(rangedVal);
	int		f = 0;
	int		h = 0;
	int		m = 0;
	int		s = 0;
	//NSLog(@"\t\tfps is %f, val is %f",smpteFPS,(rangedVal-floor(rangedVal)));
	//	note that a +1 is added for the frames because the start time is at 0:0:0:1
	f = floor((rangedVal - floor(rangedVal)) * smpteFPS) + 1;
	//NSLog(@"\t\tcalculated f is %d",f);
	s = tmpVal % 60;
	tmpVal = tmpVal / 60.0;
	m = tmpVal % 60;
	tmpVal = tmpVal / 60.0;
	h = tmpVal % 60;
	//NSLog(@"\t\t%d:%d:%d:%d",h,m,s,f);
	returnMe = [NSString stringWithFormat:@"%0.2d:%0.2d:%0.2d.%0.2d",h,m,s,f];
	
	return returnMe;
}

+ (double) timeInSecondsForSMPTEString:(NSString*)smpte withFPS:(double)fps	{
	//NSLog(@"%s ... \"%@\", %f",__func__,smpte,fps);
	
	double			returnMe = 0.0;
	
	if (smpte!=nil)	{
		//NSString	*tmpString = [NSString stringWithFormat:@"%d",(int)floor(fps)];
		NSArray		*matchArray = [smpte componentsSeparatedByRegex:@"[^0-9]+"];
		if (matchArray==nil || [matchArray count]<1)	{
			//	intentionally blank, do nothing
		}
		else	{
			double			newVal = 0.;
			double			tmpVal = 0.;
			int				place = 0;
			for (NSString *tmpString in [matchArray reverseObjectEnumerator])	{
				//	if we've gone past "hours", we need to bail from the loop
				if (place >= 4)
					break;
				//NSNumber		*tmpNum = [tmpString numberByEvaluatingString];
				//tmpVal = (tmpNum==nil) ? 0. : [tmpNum doubleValue];
				tmpVal = (double)[tmpString integerValue];
				//	note that frames has a +1 on display that we must subtract
				switch (place)	{
				case 0:	//	frames
					if (tmpVal == 0.)	//	we want to prevent "frame 0" from being entered
						tmpVal = 1.;
					newVal += ((tmpVal-1)/fps);
					break;
				case 1:	//	seconds
					newVal += tmpVal;
					break;
				case 2:	//	minutes
					newVal += (tmpVal * 60.);
					break;
				case 3:	//	hours
					newVal += (tmpVal * 60. * 60.);
					break;
				}
				
				++place;
			}
			
			returnMe = newVal;
		}
		
	}
	//NSLog(@"\t\treturning %f",returnMe);
	return returnMe;
	
	return 0.;
}


@end

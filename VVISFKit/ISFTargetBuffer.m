#import "ISFTargetBuffer.h"
#import "VVBufferCopier.h"




@implementation ISFTargetBuffer


- (NSString *) description	{
	return VVFMTSTRING(@"<ISFTargetBuffer %@>",name);
}
+ (id) create	{
	id		returnMe = [[ISFTargetBuffer alloc] init];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}


- (id) init	{
	if (self = [super init])	{
		name = nil;
		buffer = nil;
		targetWidth = 1.0;
		targetWidthString = nil;
		targetWidthExpression = nil;
		targetHeight = 1.0;
		targetHeightString = nil;
		targetHeightExpression = nil;
		floatFlag = NO;
		for (int i=0; i<4; ++i)
			uniformLocation[i] = -1;
		return self;
	}
	[self release];
	return nil;
}
- (void) dealloc	{
	VVRELEASE(name);
	VVRELEASE(buffer);
	VVRELEASE(targetWidthString);
	VVRELEASE(targetWidthExpression);
	VVRELEASE(targetHeightString);
	VVRELEASE(targetHeightExpression);
	[super dealloc];
}


- (void) setTargetWidthString:(NSString *)n	{
	VVRELEASE(targetWidthString);
	VVRELEASE(targetWidthExpression);
	if (n != nil)	{
		targetWidthString = [n retain];
		NSError		*err = nil;
		targetWidthExpression = [[DDExpression expressionFromString:n error:&err] retain];
	}
}
- (void) setTargetHeightString:(NSString *)n	{
	VVRELEASE(targetHeightString);
	VVRELEASE(targetHeightExpression);
	if (n != nil)	{
		targetHeightString = [n retain];
		NSError		*err = nil;
		targetHeightExpression = [[DDExpression expressionFromString:n error:&err] retain];
	}
}
- (void) setFloatFlag:(BOOL)n	{
	//NSLog(@"%s ... %d",__func__,n);
	BOOL		changed = (floatFlag==n) ? NO : YES;
	if (!changed)
		return;
	//	if i'm here, i just changed the float flag
	floatFlag = n;
	//	if there's a buffer, i need to copy it to a float buffer
	if (buffer != nil)	{
		//	make a new buffer of the appropriate type
		VVBuffer		*newBuffer = (floatFlag)
			? [_globalVVBufferPool allocBGRFloatTexSized:NSMakeSize(targetWidth,targetHeight)]
			: [_globalVVBufferPool allocBGRTexSized:NSMakeSize(targetWidth,targetHeight)];
		//	copy the old buffer to the new, get rid of the old
		if (newBuffer != nil)	{
			[_globalVVBufferCopier ignoreSizeCopyThisBuffer:buffer toThisBuffer:newBuffer];
			VVRELEASE(buffer);
			buffer = newBuffer;
		}
	}
}
- (BOOL) floatFlag	{
	return floatFlag;
}
- (void) setTargetSize:(NSSize)n	{
	[self setTargetSize:n resizeExistingBuffer:YES createNewBuffer:YES];
}
- (void) setTargetSize:(NSSize)n createNewBuffer:(BOOL)c	{
	[self setTargetSize:n resizeExistingBuffer:YES createNewBuffer:c];
}
- (void) setTargetSize:(NSSize)n resizeExistingBuffer:(BOOL)r	{
	[self setTargetSize:n resizeExistingBuffer:r createNewBuffer:YES];
}
- (void) setTargetSize:(NSSize)n resizeExistingBuffer:(BOOL)r createNewBuffer:(BOOL)c	{
	//NSLog(@"%s ... %0.2f x %0.2f, %d, %d",__func__, n.width, n.height, r, c);
	targetWidth = n.width;
	targetHeight = n.height;
	//	if the buffer's currently nil...
	if (buffer==nil)	{
		if (c)	{
			buffer = (floatFlag)
				? [_globalVVBufferPool allocBGRFloatTexSized:n]
				: [_globalVVBufferPool allocBGRTexSized:n];
			[_globalVVBufferCopier copyBlackFrameToThisBuffer:buffer];
			//NSLog(@"\t\tnow working with buffer %@",buffer);
		}
	}
	//	else there's a buffer...
	else	{
		//	if the buffer size is wrong...
		if (!NSEqualSizes(n, [buffer srcRect].size))	{
			//	if i'm supposed to resize, do so
			if (r)	{
				VVBuffer		*newBuffer = (floatFlag)
					? [_globalVVBufferPool allocBGRFloatTexSized:NSMakeSize(targetWidth,targetHeight)]
					: [_globalVVBufferPool allocBGRTexSized:NSMakeSize(targetWidth,targetHeight)];
				[_globalVVBufferCopier sizeVariantCopyThisBuffer:buffer toThisBuffer:newBuffer];
				VVRELEASE(buffer);
				buffer = newBuffer;
				//NSLog(@"\t\tnow working with buffer %@",buffer);
			}
			//	else i'm not supposed to resize
			else	{
				//	if i'm supposed to create a new buffer
				if (c)	{
					VVRELEASE(buffer);
					buffer = (floatFlag)
						? [_globalVVBufferPool allocBGRFloatTexSized:NSMakeSize(targetWidth,targetHeight)]
						: [_globalVVBufferPool allocBGRTexSized:NSMakeSize(targetWidth,targetHeight)];
					[_globalVVBufferCopier copyBlackFrameToThisBuffer:buffer];
				}
				//	else i'm not supposed to create a new buffer
				else	{
					VVRELEASE(buffer);
				}
				//NSLog(@"\t\tnow working with buffer %@",buffer);
			}
		}
	}
}
- (void) clearBuffer	{
	VVRELEASE(buffer);
}


//	returns a YES if there's a target width string
- (BOOL) targetSizeNeedsEval	{
	if (targetHeightString!=nil || targetWidthString!=nil)
		return YES;
	return NO;
}
- (void) evalTargetSizeWithSubstitutionsDict:(NSDictionary *)d	{
	[self evalTargetSizeWithSubstitutionsDict:d resizeExistingBuffer:YES];
}
- (void) evalTargetSizeWithSubstitutionsDict:(NSDictionary *)d resizeExistingBuffer:(BOOL)r	{
	[self evalTargetSizeWithSubstitutionsDict:d resizeExistingBuffer:r createNewBuffer:YES];
}
- (void) evalTargetSizeWithSubstitutionsDict:(NSDictionary *)d resizeExistingBuffer:(BOOL)r createNewBuffer:(BOOL)c	{
	//NSLog(@"%s ... %@",__func__,self);
	//NSLog(@"\t\tresize is %d, dict is %@",r,d);
	if (targetWidthExpression==nil && targetHeightExpression==nil)
		return;
	//NSLog(@"\t\twidthString is %@",targetWidthString);
	//NSLog(@"\t\theightString is %@",targetHeightString);
	NSSize		newSize = NSMakeSize(0,0);
	NSNumber	*tmpNum = nil;
	tmpNum = [d objectForKey:@"WIDTH"];
	if (tmpNum != nil)
		newSize.width = [tmpNum doubleValue];
	tmpNum = [d objectForKey:@"HEIGHT"];
	if (tmpNum != nil)
		newSize.height = [tmpNum doubleValue];
	
	NSError		*err = nil;
	if (targetWidthExpression != nil)	{
		newSize.width = [[targetWidthExpression evaluateWithSubstitutions:d evaluator:nil error:&err] floatValue];
	}
	if (targetHeightExpression != nil)	{
		newSize.height = [[targetHeightExpression evaluateWithSubstitutions:d evaluator:nil error:&err] floatValue];
	}
	if (err != nil)
		NSLog(@"\t\terror evaluating term in %s: %@",__func__,err);
	
	[self setTargetSize:newSize resizeExistingBuffer:r createNewBuffer:c];
}


@synthesize name;
@synthesize buffer;


- (NSSize) targetSize	{
	return NSMakeSize(targetWidth,targetHeight);
}


- (void) setUniformLocation:(int)n forIndex:(int)i	{
	//NSLog(@"%s ... %@, [%d] %d",__func__,name,i,n);
	if (i>=0 && i<4)
		uniformLocation[i] = n;
}
- (int) uniformLocationForIndex:(int)i	{
	if (i>=0 && i<4)
		return uniformLocation[i];
	return -1;
}
- (void) clearUniformLocations	{
	for (int i=0; i<4; ++i)
		uniformLocation[i] = -1;
}


@end

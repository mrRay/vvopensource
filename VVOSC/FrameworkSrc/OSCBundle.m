//
//  OSCBundle.m
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCBundle.h"




@implementation OSCBundle


+ (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l toInPort:(id)p	{
	//NSLog(@"%s",__func__);
	if ((b == nil) || (l == 0) || (p == NULL))
		return;
	
	//	remember, OSC data is clumped in a minimum of 4 byte groups!
	//	bytes 0-7 consist of '#bundle', and then a null character to make it an even multiple of 4
	//	bytes 8-15 is an 8-byte (64-bit!) time tag which ostensibly applies to the entire bundle
	//	this is followed by the bundle elements.  each element consists of two things:
	//	1)- a 4-byte (32-bit) int.  this is the bundle length.
	//	2)- the bundle itself- the length of the bundle is described by the 4-byte int before it
	
	int				baseIndex = 16;
	unsigned char	*c = b;
	int				length = 0;
	
	while (baseIndex < l)	{
		length = (c[baseIndex+3]) + (c[baseIndex+2] << 8) + (c[baseIndex+1] << 16) + (c[baseIndex] << 24);
		baseIndex = baseIndex + 4;
		if (c[baseIndex] == '#')	{
			[OSCBundle
				parseRawBuffer:b+baseIndex
				ofMaxLength:length
				toInPort:p];
		}
		else if (c[baseIndex] == '/')	{
			[OSCMessage
				parseRawBuffer:b+baseIndex
				ofMaxLength:length
				toInPort:p];
		}
		
		baseIndex = baseIndex + length;
	}
}

+ (id) create	{
	OSCBundle		*returnMe = [[OSCBundle alloc] init];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithElement:(id)n	{
	OSCBundle		*returnMe = [[OSCBundle alloc] init];
	if (returnMe == nil)
		return nil;
	if (n != nil)
		[returnMe addElement:n];
	return [returnMe autorelease];
}
+ (id) createWithElementArray:(id)a	{
	OSCBundle		*returnMe = [[OSCBundle alloc] init];
	if (returnMe == nil)
		return nil;
	if (a != nil)
		[returnMe addElementArray:a];
	return [returnMe autorelease];
}
- (id) init	{
	if (self = [super init])	{
		elementArray = [[NSMutableArray arrayWithCapacity:0] retain];
		return self;
	}
	[self release];
	return nil;
}

- (void) dealloc	{
	if (elementArray != nil)
		[elementArray release];
	elementArray = nil;
	[super dealloc];
}

- (void) addElement:(id)n	{
	if (n == nil)
		return;
	if ((![n isKindOfClass:[OSCBundle class]]) && (![n isKindOfClass:[OSCMessage class]]))
		return;
	[elementArray addObject:n];
}
- (void) addElementArray:(NSArray *)a	{
	if ((a==nil) || ([a count]<1))
		return;
	NSEnumerator		*it = [a objectEnumerator];
	id					anObj;
	while (anObj = [it nextObject])	{
		if (([anObj isKindOfClass:[OSCBundle class]]) || ([anObj isKindOfClass:[OSCMessage class]]))	{
			[elementArray addObject:anObj];
		}
	}
}

- (int) bufferLength	{
	//NSLog(@"%s",__func__);
	int				totalSize = 0;
	NSEnumerator	*it;
	id				anObj;
	
	/*
	a bundle starts off with:
		8 bytes for the '#bundle'
		8 bytes for the timestamp
	*/
	totalSize = 16;
	
	//	run through my elements, getting their sizes
	it = [elementArray objectEnumerator];
	while (anObj = [it nextObject])	{
		/*
		each element will occupy an amount of space equal to the size of the payload plus
		4 bytes (these 4 bytes are used to store the size of the payload which follows it)
		*/
		totalSize = totalSize + 4 + [anObj bufferLength];
	}
	
	return totalSize;
}
- (void) writeToBuffer:(unsigned char *)b	{
	if (b == NULL)
		return;
	int				writeOffset;
	int				elementLength;
	UInt32			tmpInt;
	NSEnumerator	*it;
	id				anObj;
	
	//	write the "#bundle" to the buffer
	strncpy((char *)b, "#bundle", 7);
	//	adjust the offset to take into account the #bundle and the timestamp
	writeOffset = 16;
	//	run through all the elements in this bundle
	it = [elementArray objectEnumerator];
	while (anObj = [it nextObject])	{
		//	write the message's size to the buffer
		elementLength = [anObj bufferLength];
		tmpInt = htonl(*((UInt32 *)(&elementLength)));
		memcpy(b+writeOffset, &tmpInt, 4);
		//	adjust the write offset to compensate for writing the message size
		writeOffset = writeOffset + 4;
		//	write the message to the buffer
		[anObj writeToBuffer:b+writeOffset];
		//	adjust the write offset to compensate for the data i just wrote to the buffer
		writeOffset = writeOffset + elementLength;
	}
}


@end

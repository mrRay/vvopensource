//
//  OSCInPortRetainsRaw.m
//  VVOSC
//
//  Created by bagheera on 10/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCInPortRetainsRaw.h"


@implementation OSCInPortRetainsRaw


- (id) initWithPort:(unsigned short)p labelled:(NSString *)l	{
	//NSLog(@"%s",__func__);
	if (self = [super initWithPort:p labelled:l])	{
		packetStringArray = [[NSMutableArray arrayWithCapacity:0] retain];
		return self;
	}
	[self release];
	return nil;
}
- (void) dealloc	{
	if (packetStringArray != nil)	{
		[packetStringArray release];
		packetStringArray = nil;
	}
	[super dealloc];
}
/*
	this formats a bunch of strings based on the raw data, stores them,
	then lets the super do it's thing.  the strings it formats are used
	for displaying the raw OSC data which has been received.  this is 
	formatted & stored here because this is the easiest place to do it.
*/
- (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l fromAddr:(unsigned int)txAddr port:(unsigned short)txPort	{
	//NSLog(@"%s",__func__);
	NSMutableDictionary		*mutDict = [NSMutableDictionary dictionaryWithCapacity:0];
	NSMutableString			*mutString = nil;
	int						bundleIndexCount;
	unsigned char			*charPtr = b;
	
	//	assemble a string
	mutString = [NSMutableString stringWithCapacity:0];
	[mutString appendString:@"***************\r"];
	for (bundleIndexCount = 0; bundleIndexCount < (l/4); ++bundleIndexCount)	{
		[mutString appendFormat:@"(%d)\t\t%c\t%c\t%c\t%c\r",bundleIndexCount*4, charPtr[bundleIndexCount*4], charPtr[bundleIndexCount*4+1], charPtr[bundleIndexCount*4+2], charPtr[bundleIndexCount*4+3]];
	}
	//	add the string to the dict
	[mutDict setObject:[[mutString copy] autorelease] forKey:@"char"];
	
	
	mutString = [NSMutableString stringWithCapacity:0];
	[mutString appendString:@"***************\r"];
	for (bundleIndexCount = 0; bundleIndexCount < (l/4); ++bundleIndexCount)	{
		[mutString appendFormat:@"(%d)\t\t%X\t%X\t%X\t%X\r",bundleIndexCount*4, charPtr[bundleIndexCount*4], charPtr[bundleIndexCount*4+1],charPtr[bundleIndexCount*4+2],charPtr[bundleIndexCount*4+3]];
	}
	[mutDict setObject:[[mutString copy] autorelease] forKey:@"hex"];
	
	
	mutString = [NSMutableString stringWithCapacity:0];
	[mutString appendString:@"***************\r"];
	for (bundleIndexCount = 0; bundleIndexCount < (l/4); ++bundleIndexCount)	{
		[mutString appendFormat:@"(%d)\t\t%d\t%d\t%d\t%d\r",bundleIndexCount*4, charPtr[bundleIndexCount*4], charPtr[bundleIndexCount*4+1],charPtr[bundleIndexCount*4+2],charPtr[bundleIndexCount*4+3]];
	}
	[mutDict setObject:[[mutString copy] autorelease] forKey:@"dec"];
	
	
	//	add the dict to the array of packet string dicts
	[packetStringArray addObject:mutDict];
	
	//	make sure there aren't more than 25 dicts in the array
	while ([packetStringArray count] > 25)
		[packetStringArray removeObjectAtIndex:0];
	
	//	tell the super to parse the raw data
	[super parseRawBuffer:b ofMaxLength:l fromAddr:txAddr port:txPort];
}
/*
	this formats and stores a bunch of strings based on the OSCMessage and 
	OSCValue instances received and parsed by the input.
*/
- (void) handleScratchArray:(NSArray *)a	{
	//NSLog(@"%s",__func__);
	NSMutableString		*mutString = [NSMutableString stringWithCapacity:0];
	NSEnumerator		*it = [a objectEnumerator];
	OSCMessage			*anObj;
	
	[mutString appendString:@"***************"];
	while (anObj = [it nextObject])	{
		//NSLog(@"\t\tanObj is %@",anObj);
		if ([anObj valueCount] < 2)
			[mutString appendFormat:@"\r%@ : %@",[anObj address],[anObj value]];
		else
			[mutString appendFormat:@"\r%@ : %@",[anObj address],[anObj valueArray]];
	}
	[[packetStringArray lastObject] setObject:mutString forKey:@"serial"];
	
	[super handleScratchArray:a];
}

- (NSMutableArray *) packetStringArray	{
	return packetStringArray;
}
- (void) setPacketStringArray:(NSArray *)a	{
	[packetStringArray removeAllObjects];
	if ((a != nil) && ([a count] > 0))	{
		[packetStringArray addObjectsFromArray:a];
	}
}


@end







































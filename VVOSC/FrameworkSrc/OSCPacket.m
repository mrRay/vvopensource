
#import "OSCPacket.h"
#import "OSCInPort.h"




@implementation OSCPacket


+ (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l toInPort:(id)p fromAddr:(unsigned int)txAddr port:(unsigned short)txPort	{
	//NSLog(@"%s",__func__);
	//	this stuff prints out the buffer to the console log- it's very, very useful.  probably will be added to the test app at some point.
	/*
	printf("******************************\n");
	int				bundleIndexCount;
	unsigned char	*bufferCharPtr=b;
	for (bundleIndexCount=0; bundleIndexCount<(l/4); ++bundleIndexCount)	{
		printf("\t(%d)\t\t%c\t%c\t%c\t%c\t\t%d\t\t%d\t\t%d\t\t%d\n",bundleIndexCount * 4,
			*(bufferCharPtr+bundleIndexCount*4), *(bufferCharPtr+bundleIndexCount*4+1), *(bufferCharPtr+bundleIndexCount*4+2), *(bufferCharPtr+bundleIndexCount*4+3),
			*(bufferCharPtr+bundleIndexCount*4), *(bufferCharPtr+bundleIndexCount*4+1), *(bufferCharPtr+bundleIndexCount*4+2), *(bufferCharPtr+bundleIndexCount*4+3));
	}
	printf("******************************\n");
	*/
	
	unsigned char	*buffPtr = b;
	BOOL			isBundle = NO;
	if ((buffPtr[0]=='#') && (buffPtr[1]=='b'))
		isBundle = YES;
	
	if (isBundle)	{
		[OSCBundle
			parseRawBuffer:b
			ofMaxLength:l
			toInPort:p
			inheritedTimeTag:nil
			fromAddr:txAddr
			port:txPort];
	}
	else	{
		OSCMessage		*tmpMsg = [OSCMessage
			parseRawBuffer:b
			ofMaxLength:l
			fromAddr:txAddr
			port:txPort];
		if (tmpMsg != nil)	{
			//if ([tmpMsg messageType] == OSCMessageTypeQuery)
			//	[tmpMsg XXXXXXXXXXXX];
			[p _addMessage:tmpMsg];
		}
	}
	
	/*
	if (buffPtr[0] == '#')	{
		[OSCBundle
			parseRawBuffer:b
			ofMaxLength:l
			toInPort:p
			inheritedTimeTag:nil
			fromAddr:txAddr
			port:txPort];
	}
	else if (buffPtr[0] == '/')	{
		OSCMessage		*tmpMsg = [OSCMessage
			parseRawBuffer:b
			ofMaxLength:l
			fromAddr:txAddr
			port:txPort];
		if (tmpMsg != nil)	{
			//if ([tmpMsg messageType] == OSCMessageTypeQuery)
			//	[tmpMsg XXXXXXXXXXXX];
			[p _addMessage:tmpMsg];
		}
	}
	*/
}
+ (id) createWithContent:(id)c	{
	OSCPacket		*returnMe = [[OSCPacket alloc] initWithContent:c];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithContent:(id)c	{
	//NSLog(@"%s ... %@",__func__,c);
	if (c == nil)
		goto BAIL;
	
	if (self = [super init])	{
		bufferLength = [c bufferLength];
		payload = NULL;
		if (bufferLength < 1)
			goto BAIL;
		payload = malloc(bufferLength * sizeof(unsigned char));
		memset(payload,'\0',bufferLength);
		[c writeToBuffer:payload];
		/*
		printf("******************************\n");
		int				bundleIndexCount;
		unsigned char	*bufferCharPtr=payload;
		for (bundleIndexCount=0; bundleIndexCount<(bufferLength/4); ++bundleIndexCount)	{
			printf("\t(%d)\t\t%c\t%c\t%c\t%c\t\t%d\t\t%d\t\t%d\t\t%d\n",bundleIndexCount * 4,
				*(bufferCharPtr+bundleIndexCount*4), *(bufferCharPtr+bundleIndexCount*4+1), *(bufferCharPtr+bundleIndexCount*4+2), *(bufferCharPtr+bundleIndexCount*4+3),
				*(bufferCharPtr+bundleIndexCount*4), *(bufferCharPtr+bundleIndexCount*4+1), *(bufferCharPtr+bundleIndexCount*4+2), *(bufferCharPtr+bundleIndexCount*4+3));
		}
		printf("******************************\n");
		*/
		return self;
	}
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	[self release];
	return nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	bufferLength = 0;
	if (payload != NULL)
		free(payload);
	payload = NULL;
	[super dealloc];
}

- (long) bufferLength	{
	return bufferLength;
}
- (unsigned char *) payload	{
	return payload;
}


@end

//
//  AppController.m
//  VVOpenSource
//
//  Created by bagheera on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "AppController.h"




#define NSNULL [NSNull null]
#define MAXMSGS 25




@implementation AppController


+ (void) load	{
	[OSCAddressSpace class];
}
- (id) init	{
	if (self = [super init])	{
		rxMsgs = [[MutLockArray alloc] init];
		txMsgs = [[MutLockArray alloc] init];
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (void) awakeFromNib	{
	[_mainAddressSpace setDelegate:self];
	[_mainAddressSpace setAutoQueryReply:YES];
	[_mainAddressSpace setQueryDelegate:self];
	[oscManager setDelegate:self];
}


- (IBAction) createButtonUsed:(id)sender	{
}


- (IBAction) populateButtonUsed:(id)sender	{

}

- (IBAction) listNodesClicked:(id)sender	{
	NSLog(@"%s",__func__);
	OSCOutPort		*manualOutput = [oscManager findOutputWithLabel:@"ManualOutput"];
	if (manualOutput == nil)	{
		NSLog(@"\t\terr: couldn't find manual output in %s",__func__);
		return;
	}
	NSString		*address = [oscAddressField stringValue];
	OSCMessage		*msg = [OSCMessage createQueryType:OSCQueryTypeNamespaceExploration forAddress:address];
	
	
	[rxMsgs wrlock];
	[txMsgs wrlock];
		[rxMsgs addObject:NSNULL];
		[txMsgs addObject:msg];
		[self _lockedUpdateDataAndViews];
	[rxMsgs unlock];
	[txMsgs unlock];
	
	//NSLog(@"\t\tmsg being sent is %@",msg);
	//	i send the query out the OSC MANAGER- it has to be dispatched through an input or the raw packet header won't have a return address with a port that i'm listening to!
	[oscManager dispatchQuery:msg toOutput:manualOutput];
}
- (IBAction) documentationClicked:(id)sender	{
	NSLog(@"%s",__func__);
}
- (IBAction) acceptedTypesClicked:(id)sender	{
	NSLog(@"%s",__func__);
}
- (IBAction) currentValClicked:(id)sender	{
	NSLog(@"%s",__func__);
}


- (void) _lockedUpdateDataAndViews	{
	while ([rxMsgs count] > MAXMSGS)
		[rxMsgs removeObjectAtIndex:0];
	while ([txMsgs count] > MAXMSGS)
		[txMsgs removeObjectAtIndex:0];
	
	NSMutableString		*rxString = [NSMutableString stringWithCapacity:0];
	NSMutableString		*txString = [NSMutableString stringWithCapacity:0];
	int					lineCount = 0;
	
	for (OSCMessage *tmpMsg in [rxMsgs array])	{
		if ((NSNull *)tmpMsg == NSNULL)
			[rxString appendFormat:@"%d\n",lineCount];
		else
			[rxString appendFormat:@"%d\t%@\n",lineCount,[tmpMsg description]];
		++lineCount;
	}
	[rxDataView
		performSelectorOnMainThread:@selector(setString:)
		withObject:[[rxString copy] autorelease]
		waitUntilDone:NO];
	
	lineCount = 0;
	for (OSCMessage *tmpMsg in [txMsgs array])	{
		if ((NSNull *)tmpMsg == NSNULL)
			[txString appendFormat:@"%d\n",lineCount];
		else
			[txString appendFormat:@"%d\t%@\n",lineCount,[tmpMsg description]];
		++lineCount;
	}
	[txDataView
		performSelectorOnMainThread:@selector(setString:)
		withObject:[[txString copy] autorelease]
		waitUntilDone:NO];
}


/*===================================================================================*/
#pragma mark --------------------- OSCManager delegate (OSCDelegateProtocol)
/*------------------------------------*/


- (void) receivedOSCMessage:(OSCMessage *)m	{
	NSLog(@"%s ... %@",__func__,m);
	[rxMsgs wrlock];
	[txMsgs wrlock];
		[rxMsgs addObject:m];
		[txMsgs addObject:NSNULL];
		[self _lockedUpdateDataAndViews];
	[rxMsgs unlock];
	[txMsgs unlock];
	
	OSCMessageType		mType = [m messageType];
	switch (mType)	{
		case OSCMessageTypeReply:
		case OSCMessageTypeError:
			NSLog(@"\t\treceived reply/error: %@",m);
			break;
		default:
			[_mainAddressSpace dispatchMessage:m];
			break;
	}
}


/*===================================================================================*/
#pragma mark --------------------- OSCNodeQueryDelegateProtocol
/*------------------------------------*/


- (NSMutableArray *) namespaceArray	{
	return nil;
}
- (NSString *) docString	{
	return nil;
}
- (NSString *) typeSignature	{
	return nil;
}
- (OSCValue *) currentValue	{
	return nil;
}
- (NSString *) returnTypeString	{
	return nil;
}


/*===================================================================================*/
#pragma mark --------------------- OSCAddressSpaceDelegateProtocol
/*------------------------------------*/


- (void) nodeRenamed:(OSCNode *)n	{
	/*		left intentionally blank- don't need to do anything, just want to avoid a warning for not having this method		*/
}
- (void) dispatchReplyOrError:(OSCMessage *)m	{
	NSLog(@"%s ... %@",__func__,m);
	[rxMsgs wrlock];
	[txMsgs wrlock];
		[rxMsgs addObject:NSNULL];
		[txMsgs addObject:m];
		[self _lockedUpdateDataAndViews];
	[rxMsgs unlock];
	[txMsgs unlock];
	
	[oscManager dispatchReplyOrError:m];
}


@end

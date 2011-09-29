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


/*===================================================================================*/
#pragma mark --------------------- OSCManager delegate (OSCDelegateProtocol)
/*------------------------------------*/


- (void) receivedOSCMessage:(OSCMessage *)m	{
	NSLog(@"%s ... %@",__func__,m);
	[rxMsgs wrlock];
	[txMsgs wrlock];
		[rxMsgs addObject:m];
		[txMsgs addObject:NSNULL];
		while ([rxMsgs count] > MAXMSGS)
			[rxMsgs removeObjectAtIndex:0];
		while ([txMsgs count] > MAXMSGS)
			[txMsgs removeObjectAtIndex:0];
	[rxMsgs unlock];
	[txMsgs unlock];
	
	[_mainAddressSpace dispatchMessage:m];
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
	[oscManager dispatchReplyOrError:m];
}

/*				OSCNodeDelegateProtocol				*/
/*
//	AppController is the address space's main delegate
- (void) node:(id)n receivedOSCMessage:(id)m	{
	NSLog(@"%s ... %@",__func__,m);
	
	OSCMessageType		mType = [m messageType];
	OSCQueryType		qType;
	switch (mType)	{
		case OSCMessageTypeControl:
			[_mainAddressSpace dispatchMessage:m];
			break;
		case OSCMessageTypeQuery:
			NSLog(@"\t\treceived query %@",m);
			qType = [m queryType];
			switch (qType)	{
				case OSCQueryTypeNamespaceExploration:
				case OSCQueryTypeDocumentation:
				case OSCQueryTypeTypeSignature:
				case OSCQueryTypeCurrentValue:
				case OSCQueryTypeReturnTypeString:
					break;
			}
			break;
		case OSCMessageTypeReply:
			NSLog(@"\t\treceived reply %@",m);
			break;
		case OSCMessageTypeError:
			NSLog(@"\t\treceived error %@",m);
			break;
	}
	
}
- (void) nodeNameChanged:(id)node	{
	NSLog(@"%s ... %@",__func__,node);
}
- (void) nodeDeleted:(id)node	{
	NSLog(@"%s ... %@",__func__,node);
}
*/


@end

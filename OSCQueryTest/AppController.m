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
	//	the OSCAddressSpace automatically creates a single instance of itself when the class is initialized (as soon as you call anything that uses the OSCAddressSpace class, it gets created)
	[OSCAddressSpace class];
}
- (id) init	{
	if (self = [super init])	{
		myChain = nil;
		targetChain = nil;
		rxMsgs = [[MutLockArray alloc] init];
		txMsgs = [[MutLockArray alloc] init];
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (void) awakeFromNib	{
	/*	set this object as the address space's delegate.  the address space needs to dispatch replies to queries it received- the main instance of OSCAddressSpace does this by notifying its delegate (which presumably dispatches it to an OSCManager or directly to the port)		*/
	[(OSCAddressSpace *)_mainVVOSCAddressSpace setDelegate:self];
	/*	enable auto query reply in the main address space node- the OSCAddressSpace instance (which is the "top-level" OSC node) will automatically assemble replies for queries		*/
	[_mainVVOSCAddressSpace setAutoQueryReply:YES];
	
	
	[oscManager setDelegate:self];
}


- (IBAction) createMenuItemChosen:(id)sender	{
	//NSLog(@"%s ... %@",__func__,sender);
	NSString		*title = [sender title];
	if (title == nil)
		return;
	ElementBox		*newBox = [[ElementBox alloc] initWithFrame:NSMakeRect(0,0,300,80)];
	if (newBox == nil)
		return;
	
	if ([title isEqualToString:@"Button (Boolean)"])
		[newBox setType:OSCValBool andName:[NSString stringWithFormat:@"Item %d",[myChain count]+1]];
	else if ([title isEqualToString:@"Slider (Float)"])
		[newBox setType:OSCValFloat andName:[NSString stringWithFormat:@"Item %d",[myChain count]+1]];
	else if ([title isEqualToString:@"Text Field (String)"])
		[newBox setType:OSCValString andName:[NSString stringWithFormat:@"Item %d",[myChain count]+1]];
	
	[myChain addElement:newBox];
	[newBox release];
}
- (IBAction) clearButtonUsed:(id)sender	{
	//NSLog(@"%s",__func__);
	[myChain clearAllElements];
}


- (IBAction) listNodesClicked:(id)sender	{
	//NSLog(@"%s",__func__);
	OSCOutPort		*manualOutput = [oscManager findOutputWithLabel:@"ManualOutput"];
	if (manualOutput == nil)	{
		NSLog(@"\t\terr: couldn't find manual output in %s",__func__);
		return;
	}
	NSString		*address = [oscAddressField stringValue];
	OSCMessage		*msg = [OSCMessage createQueryType:OSCQueryTypeNamespaceExploration forAddress:address];
	
	[self addTXMsg:msg];
	
	//	i send the query out the OSC MANAGER- it has to be dispatched through an input or the raw packet header won't have a return address with a port that i'm listening to!
	[oscManager dispatchQuery:msg toOutPort:manualOutput timeout:5.0 replyHandler:^(OSCMessage *replyMsg)	{
		NSLog(@"%s- %@",__func__,replyMsg);
		[self addRXMsg:replyMsg];
	}];
}
- (IBAction) documentationClicked:(id)sender	{
	//NSLog(@"%s",__func__);
	OSCOutPort		*manualOutput = [oscManager findOutputWithLabel:@"ManualOutput"];
	if (manualOutput == nil)	{
		NSLog(@"\t\terr: couldn't find manual output in %s",__func__);
		return;
	}
	NSString		*address = [oscAddressField stringValue];
	OSCMessage		*msg = [OSCMessage createQueryType:OSCQueryTypeDocumentation forAddress:address];
	
	[self addTXMsg:msg];
	
	//	i send the query out the OSC MANAGER- it has to be dispatched through an input or the raw packet header won't have a return address with a port that i'm listening to!
	[oscManager dispatchQuery:msg toOutPort:manualOutput timeout:5.0 replyHandler:^(OSCMessage *replyMsg)	{
		NSLog(@"%s- %@",__func__,replyMsg);
		[self addRXMsg:replyMsg];
	}];
}
- (IBAction) acceptedTypesClicked:(id)sender	{
	//NSLog(@"%s",__func__);
	OSCOutPort		*manualOutput = [oscManager findOutputWithLabel:@"ManualOutput"];
	if (manualOutput == nil)	{
		NSLog(@"\t\terr: couldn't find manual output in %s",__func__);
		return;
	}
	NSString		*address = [oscAddressField stringValue];
	OSCMessage		*msg = [OSCMessage createQueryType:OSCQueryTypeTypeSignature forAddress:address];
	
	[self addTXMsg:msg];
	
	//	i send the query out the OSC MANAGER- it has to be dispatched through an input or the raw packet header won't have a return address with a port that i'm listening to!
	[oscManager dispatchQuery:msg toOutPort:manualOutput timeout:5.0 replyHandler:^(OSCMessage *replyMsg)	{
		NSLog(@"%s- %@",__func__,replyMsg);
		[self addRXMsg:replyMsg];
	}];
}
- (IBAction) returnTypesClicked:(id)sender	{
	//NSLog(@"%s",__func__);
	OSCOutPort		*manualOutput = [oscManager findOutputWithLabel:@"ManualOutput"];
	if (manualOutput == nil)	{
		NSLog(@"\t\terr: couldn't find manual output in %s",__func__);
		return;
	}
	NSString		*address = [oscAddressField stringValue];
	OSCMessage		*msg = [OSCMessage createQueryType:OSCQueryTypeReturnTypeSignature forAddress:address];
	
	[self addTXMsg:msg];
	
	//	i send the query out the OSC MANAGER- it has to be dispatched through an input or the raw packet header won't have a return address with a port that i'm listening to!
	[oscManager dispatchQuery:msg toOutPort:manualOutput timeout:5.0 replyHandler:^(OSCMessage *replyMsg)	{
		NSLog(@"%s- %@",__func__,replyMsg);
		[self addRXMsg:replyMsg];
	}];
}
- (IBAction) currentValClicked:(id)sender	{
	//NSLog(@"%s",__func__);
	OSCOutPort		*manualOutput = [oscManager findOutputWithLabel:@"ManualOutput"];
	if (manualOutput == nil)	{
		NSLog(@"\t\terr: couldn't find manual output in %s",__func__);
		return;
	}
	NSString		*address = [oscAddressField stringValue];
	OSCMessage		*msg = [OSCMessage createQueryType:OSCQueryTypeCurrentValue forAddress:address];
	
	[self addTXMsg:msg];
	
	//	i send the query out the OSC MANAGER- it has to be dispatched through an input or the raw packet header won't have a return address with a port that i'm listening to!
	[oscManager dispatchQuery:msg toOutPort:manualOutput timeout:5.0 replyHandler:^(OSCMessage *replyMsg)	{
		NSLog(@"%s- %@",__func__,replyMsg);
		[self addRXMsg:replyMsg];
	}];
}


- (IBAction) clearDataViewsClicked:(id)sender	{
	//NSLog(@"%s",__func__);
	[txMsgs wrlock];
	[rxMsgs wrlock];
	
	[txMsgs removeAllObjects];
	[rxMsgs removeAllObjects];
	[self _lockedUpdateDataAndViews];
	
	[txMsgs unlock];
	[rxMsgs unlock];
}
- (void) addTXMsg:(OSCMessage *)m	{
	if (m==nil)
		return;
	[rxMsgs wrlock];
	[txMsgs wrlock];
		[rxMsgs addObject:NSNULL];
		[txMsgs addObject:m];
		[self _lockedUpdateDataAndViews];
	[rxMsgs unlock];
	[txMsgs unlock];
}
- (void) addRXMsg:(OSCMessage *)m	{
	if (m==nil)
		return;
	[rxMsgs wrlock];
	[txMsgs wrlock];
		[rxMsgs addObject:m];
		[txMsgs addObject:NSNULL];
		[self _lockedUpdateDataAndViews];
	[rxMsgs unlock];
	[txMsgs unlock];
}
//	this method updates the text views at the bottom of the app with the contents of the received messages
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
	//	add the message to the array of received messages for display in the data views
	[self addRXMsg:m];
	
	//	dispatch the message to the OSC address space- this sends the message to the appropriate node
	[_mainVVOSCAddressSpace dispatchMessage:m];
}


/*===================================================================================*/
#pragma mark --------------------- OSCAddressSpaceDelegateProtocol- i'm the OSCAddressSpace's delegate
/*------------------------------------*/


- (void) nodeRenamed:(OSCNode *)n	{
	/*		left intentionally blank- don't need to do anything, just want to avoid a warning for not having this method		*/
}
- (void) queryResponseNeedsToBeSent:(OSCMessage *)m	{
	//	add the message to the array of msgs that were sent for display in the data view
	[self addTXMsg:m];
	
	//	tell the OSC manager to tranmist the reply- this actually sends the reply over the network
	[oscManager transmitReplyOrError:m];
}


@end

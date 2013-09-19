//
//  ElementBox.m
//  VVOpenSource
//
//  Created by bagheera on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ElementBox.h"




@implementation ElementBox


- (id) initWithFrame:(NSRect)f	{
	if (self = [super initWithFrame:f])	{
		deleted = NO;
		myUIItem = nil;
		myNode = nil;
		[[self contentView] setAutoresizesSubviews:YES];
		return self;
	}
	if (self != nil)
		[self release];
	return nil;
}
- (void) prepareToBeDeleted	{
	if (myUIItem != nil)	{
		[myUIItem setTarget:nil];
		[myUIItem removeFromSuperview];
		[myUIItem release];
		myUIItem = nil;
	}
	if (myNode != nil)	{
		[myNode removeFromAddressSpace];
		myNode = nil;
	}
	deleted = YES;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	
	[super dealloc];
}


- (void) setType:(OSCValueType)n andName:(NSString *)a	{
	NSLog(@"%s ... %@",__func__,a);
	[self setTitle:a];
	
	//	if there's an existing node, clear it out
	if (myNode != nil)
		[myNode removeFromAddressSpace];
	//	if there's an existing UI item, clear it out
	if (myUIItem != nil)	{
		[myUIItem setTarget:nil];
		[myUIItem removeFromSuperview];
		[myUIItem release];
		myUIItem = nil;
	}
	
	
	if (a==nil)
		return;
	
	
	OSCValue		*itemVal = nil;
	//	create a new UI item & OSC node
	NSRect			tmpRect = [self bounds];
	tmpRect.size.width -= 30;
	tmpRect.size.height -= 30;
	tmpRect.origin.x += 15;
	tmpRect.origin.y += 15;
	
	tmpRect.size.height -= 15;
	switch (n)	{
		case OSCValFloat:
			//	create the UI item
			myUIItem = [[NSSlider alloc] initWithFrame:tmpRect];
			[myUIItem setTarget:self];
			[myUIItem setAction:@selector(sliderUsed:)];
			//	create the node (note it is autoreleased, and must be retained if it is to stick around)
			myNode = [OSCNode createWithName:a];
			[myNode setNodeType:OSCNodeTypeNumber];
			itemVal = [OSCValue createWithFloat:[myUIItem floatValue]];
			break;
		case OSCValString:
			myUIItem = [[NSTextField alloc] initWithFrame:tmpRect];
			[myUIItem setTarget:self];
			[myUIItem setAction:@selector(textUsed:)];
			myNode = [OSCNode createWithName:a];
			[myNode setNodeType:OSCNodeTypeString];
			itemVal = [OSCValue createWithString:[myUIItem stringValue]];
			break;
		case OSCValBool:
			myUIItem = [[NSButton alloc] initWithFrame:tmpRect];
			[myUIItem setButtonType:NSSwitchButton];
			[myUIItem setTitle:a];
			[myUIItem setTarget:self];
			[myUIItem setAction:@selector(buttonUsed:)];
			myNode = [OSCNode createWithName:a];
			[myNode setNodeType:OSCNodeTypeNumber];
			itemVal = [OSCValue createWithBool:([myUIItem intValue]==NSOnState)?YES:NO];
			break;
		case OSCValArray:
		case OSCValBlob:
		case OSCVal64Int:
		case OSCValChar:
		case OSCValColor:
		case OSCValDouble:
		case OSCValInfinity:
		case OSCValInt:
		case OSCValMIDI:
		case OSCValNil:
		case OSCValTimeTag:
		case OSCValSMPTE:
			break;
	}
	
	OSCMessage		*tmpMsg = [OSCMessage createWithAddress:@""];
	[tmpMsg addValue:itemVal];
	[myNode dispatchMessage:tmpMsg];
	
	[myNode setAutoQueryReply:YES];
	
	//	put the UI item in my content view, set up autoresizing
	[[self contentView] addSubview:myUIItem];
	[(NSView *)myUIItem setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	//	put the node in the address space, which retains it so it doesn't get released
	[_mainVVOSCAddressSpace setNode:myNode forAddress:[NSString stringWithFormat:@"/%@",[myNode nodeName]]];
	//	set myself up as the node's delegate (so i receive OSCMessages dispatched to the node, as well as other node-related stuff)
	[myNode addDelegate:self];
	
	/*	if you un-comment this next line, then basic querying would work even if you didn't set this 
	object as the query delegate- or even if you didn't implement OSCNodeQueryDelegate!		*/
	//[myNode setAutoQueryReply:YES];
	
	//	set myself as the node's query delegate (this class demonstrates a use of the query protocol)
	[myNode setQueryDelegate:self];
}


- (IBAction) sliderUsed:(id)sender	{
	NSLog(@"%s",__func__);
	if (deleted || myNode==nil)
		return;
	OSCMessage		*tmpMsg = [OSCMessage createWithAddress:[myNode fullName]];
	[tmpMsg addValue:[OSCValue createWithFloat:[sender floatValue]]];
	[myNode dispatchMessage:tmpMsg];
}
- (IBAction) textUsed:(id)sender	{
	NSLog(@"%s",__func__);
	if (deleted || myNode==nil)
		return;
	OSCMessage		*tmpMsg = [OSCMessage createWithAddress:[myNode fullName]];
	[tmpMsg addValue:[OSCValue createWithString:[sender stringValue]]];
	[myNode dispatchMessage:tmpMsg];
}
- (IBAction) buttonUsed:(id)sender	{
	NSLog(@"%s",__func__);
	if (deleted || myNode==nil)
		return;
	OSCMessage		*tmpMsg = [OSCMessage createWithAddress:[myNode fullName]];
	[tmpMsg addValue:[OSCValue createWithBool:([sender intValue]==NSOnState)?YES:NO]];
	[myNode dispatchMessage:tmpMsg];
}


/*===================================================================================*/
#pragma mark --------------------- OSCNodeDelegateProtocol
/*------------------------------------*/


- (void) node:(id)n receivedOSCMessage:(OSCMessage *)msg	{
	NSLog(@"%s ... %@",__func__,msg);
}
- (void) nodeNameChanged:(id)node	{
	NSLog(@"%s ... %@",__func__,node);
}
- (void) nodeDeleted:(id)node	{
	NSLog(@"%s ... %@",__func__,node);
	myNode = nil;
}


/*===================================================================================*/
#pragma mark --------------------- OSCNodeQueryDelegate
/*------------------------------------*/


- (NSMutableArray *) namespaceArrayForNode:(OSCNode *)n	{
	NSLog(@"%s ... %@",__func__,n);
	//	if i return nil, then the OSCNode will only respond to the query protocol if it's autoQueryReply has been set to YES!
	return nil;
}
- (NSString *) docStringForNode:(OSCNode *)n	{
	NSLog(@"%s ... %@",__func__,n);
	//	if i return nil, then the OSCNode will only respond to the query protocol if it's autoQueryReply has been set to YES!
	return nil;
}
- (NSString *) typeSignatureForNode:(OSCNode *)n	{
	NSLog(@"%s ... %@",__func__,n);
	//	if i return nil, then the OSCNode will only respond to the query protocol if it's autoQueryReply has been set to YES!
	return nil;
}
- (OSCValue *) currentValueForNode:(OSCNode *)n	{
	NSLog(@"%s ... %@",__func__,n);
	//	if i return nil, then the OSCNode will only respond to the query protocol if it's autoQueryReply has been set to YES!
	return nil;
}
- (NSString *) returnTypeStringForNode:(OSCNode *)n	{
	NSLog(@"%s ... %@",__func__,n);
	//	if i return nil, then the OSCNode will only respond to the query protocol if it's autoQueryReply has been set to YES!
	return nil;
}


@end

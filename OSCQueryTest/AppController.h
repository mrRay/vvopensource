//
//  AppController.h
//  VVOpenSource
//
//  Created by bagheera on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVOSC/VVOSC.h>
#import "ElementChain.h"




@interface AppController : NSObject <OSCDelegateProtocol,OSCAddressSpaceDelegateProtocol> {
	IBOutlet NSPopUpButton		*createTypePopUpButton;
	IBOutlet NSScrollView		*myScrollView;
	IBOutlet ElementChain		*myChain;	//	ElementChain is an NSView subclass with an array of ElementBox instances.  looks like a filter chain.
	
	IBOutlet NSScrollView		*targetScrollView;
	IBOutlet ElementChain		*targetChain;
	
	IBOutlet NSTextView			*rxDataView;
	IBOutlet NSTextView			*txDataView;
	
	IBOutlet OSCManager			*oscManager;
	
	IBOutlet NSTextField		*oscAddressField;
	
	MutLockArray				*rxMsgs;
	MutLockArray				*txMsgs;
}

- (IBAction) createMenuItemChosen:(id)sender;
- (IBAction) clearButtonUsed:(id)sender;

- (IBAction) listNodesClicked:(id)sender;
- (IBAction) documentationClicked:(id)sender;
- (IBAction) acceptedTypesClicked:(id)sender;
- (IBAction) returnTypesClicked:(id)sender;
- (IBAction) currentValClicked:(id)sender;

- (IBAction) clearDataViewsClicked:(id)sender;

- (void) addTXMsg:(OSCMessage *)m;
- (void) addRXMsg:(OSCMessage *)m;

- (void) _lockedUpdateDataAndViews;

@end

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




@interface AppController : NSObject {
	IBOutlet NSPopUpButton		*createTypePopUpButton;
	IBOutlet NSScrollView		*myScrollView;
	
	IBOutlet NSScrollView		*targetScrollView;
	
	IBOutlet NSTextView			*rxDataView;
	IBOutlet NSTextView			*txDataView;
	
	IBOutlet OSCManager			*oscManager;
}

- (IBAction) createButtonUsed:(id)sender;

- (IBAction) populateButtonUsed:(id)sender;

@end

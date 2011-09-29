//
//  NetworkSetupController.h
//  VVOpenSource
//
//  Created by bagheera on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVOSC/VVOSC.h>




@interface NetworkSetupController : NSObject {
	IBOutlet NSTextField		*myIPField;
	IBOutlet NSTextField		*myPortField;
	
	IBOutlet NSPopUpButton		*dstPopUpButton;	//	the OSC manager's automatically-created outputs are used to populate the contents of this pop-up button
	IBOutlet NSTextField		*dstIPField;
	IBOutlet NSTextField		*dstPortField;
	
	IBOutlet OSCManager			*oscManager;
}

- (void) refreshDestinations:(NSNotification *)note;

- (IBAction) myPortFieldUsed:(id)sender;

- (IBAction) dstPopUpButtonUsed:(id)sender;
- (IBAction) dstFieldUsed:(id)sender;

@end

//
//  AppController.h
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVOSC/VVOSC.h>


@interface AppController : NSObject {
	OSCManager					*manager;
	OSCInPort					*inPort;
	OSCOutPort					*manualOutPort;	//	this is the port that will actually be sending the data
	
	IBOutlet NSTextField		*receivingAddressField;
	IBOutlet NSTextField		*receivingPortField;
	IBOutlet NSTextView			*receivingTextView;
	
	IBOutlet NSTextField		*ipField;
	IBOutlet NSTextField		*portField;
	IBOutlet NSTextField		*oscAddressField;
	IBOutlet NSButton			*bundleMsgsButton;
	
	IBOutlet NSSlider			*floatSlider;
	IBOutlet NSTextField		*floatField;
	IBOutlet NSTextField		*intField;
	IBOutlet NSTextField		*longLongField;
	IBOutlet NSColorWell		*colorWell;
	IBOutlet NSButton			*trueButton;
	IBOutlet NSButton			*falseButton;
	IBOutlet NSTextField		*stringField;
	
	IBOutlet NSMatrix			*displayTypeRadioGroup;
	
	IBOutlet NSPopUpButton		*outputDestinationButton;
}

- (void) displayPackets;

- (void) oscOutputsChangedNotification:(NSNotification *)note;
- (IBAction) outputDestinationButtonUsed:(id)sender;

//	called when IP address or port field is used
- (IBAction) setupFieldUsed:(id)sender;
//	called when float/int/color/etc. field is used
- (IBAction) valueFieldUsed:(id)sender;
//	called when user changes display mode
- (IBAction) displayTypeMatrixUsed:(id)sender;
//	called when the user clicks the "clear" button
- (IBAction) clearButtonUsed:(id)sender;

- (IBAction) logAddressSpace:(id)sender;

- (IBAction) timeTestUsed:(id)sender;

- (IBAction) intTest:(id)sender;
- (IBAction) floatTest:(id)sender;
- (IBAction) colorTest:(id)sender;
- (IBAction) stringTest:(id)sender;
- (IBAction) lengthTest:(id)sender;
- (IBAction) blobTest:(id)sender;

@end

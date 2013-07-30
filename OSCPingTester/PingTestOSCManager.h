//
//  PingTestOSCManager.h
//  VVOpenSource
//
//  Created by bagheera on 3/29/13.
//
//

#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVOSC/VVOSC.h>




@interface PingTestOSCManager : OSCManager	{
	OSCInPort		*inPort;
	OSCOutPort		*outPort;
	
	IBOutlet NSTextField		*ipField;
	IBOutlet NSTextField		*portField;
	IBOutlet NSPopUpButton		*outputDestinationButton;
	IBOutlet NSTextField		*networkAddressField;
	
	BOOL			ignoreReceivedVals;
	VVStopwatch		*swatch;
}

- (void) oscOutputsChangedNotification:(NSNotification *)note;
- (IBAction) setupFieldUsed:(id)sender;
- (IBAction) outputDestinationButtonUsed:(id)sender;

- (IBAction) pingClicked:(id)sender;

@end

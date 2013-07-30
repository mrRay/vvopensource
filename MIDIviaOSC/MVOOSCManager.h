#import <Cocoa/Cocoa.h>
#import <VVOSC/VVOSC.h>




//	key for notification which is fired whenever a new output is created
//#define VVOSCOutPortsChangedNotification @"VVOSCOutPortsChangedNotification"




@interface MVOOSCManager : OSCManager {
	MutLockArray				*receivedMIDIStringArray;
	IBOutlet NSTextField		*receivedMIDIField;
	IBOutlet NSButton			*receivedMIDIPreviewToggle;
	
	MutLockArray				*outgoingBuffer;
	VVThreadLoop				*oscSendingThread;
	
	OSCInPort					*inPort;
	OSCOutPort					*outPort;
	
	IBOutlet NSTextField		*ipField;
	IBOutlet NSTextField		*portField;
	IBOutlet NSPopUpButton		*outputDestinationButton;
	IBOutlet NSTextField		*networkAddressField;
	
	IBOutlet NSTableView		*midiSourcesTable;
	IBOutlet NSTableView		*midiDestTable;
}

- (void) sendOSC;
- (void) oscOutputsChangedNotification:(NSNotification *)note;
- (IBAction) setupFieldUsed:(id)sender;
- (IBAction) outputDestinationButtonUsed:(id)sender;

@end

//
//  AppController.h
//  VVMIDI
//
//  Created by bagheera on 10/21/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVMIDI/VVMIDI.h>




@interface AppController : NSObject <VVMIDIDelegateProtocol> {
	IBOutlet VVMIDIManager		*midiManager;
	IBOutlet NSTableView		*sourcesTableView;
	IBOutlet NSTableColumn		*sourcesNameColumn;
	IBOutlet NSTableColumn		*sourcesEnableColumn;
	
	IBOutlet NSTableView		*receiversTableView;
	IBOutlet NSTableColumn		*receiversNameColumn;
	IBOutlet NSTableColumn		*receiversEnableColumn;
	
	NSMutableArray				*msgArray;
	IBOutlet NSTextView			*receivedView;
	
	IBOutlet NSTextField		*channelField;
	IBOutlet NSTextField		*ctrlField;
}

- (void) setupChanged;
- (void) receivedMIDI:(NSArray *)a fromNode:(VVMIDINode *)n;

- (IBAction) ctrlValSliderUsed:(id)sender;

@end

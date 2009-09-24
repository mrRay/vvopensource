#import <Cocoa/Cocoa.h>
#import <VVMIDI/VVMIDI.h>




@interface MVOMIDIManager : VVMIDIManager {
	MutLockArray				*receivedOSCStringArray;
	IBOutlet NSTextField		*receivedOSCField;
	IBOutlet NSButton			*receivedOSCPreviewToggle;
	
	IBOutlet NSTableView		*sourcesTableView;
	IBOutlet NSTableColumn		*sourcesNameColumn;
	IBOutlet NSTableColumn		*sourcesEnableColumn;
	
	IBOutlet NSTableView		*receiversTableView;
	IBOutlet NSTableColumn		*receiversNameColumn;
	IBOutlet NSTableColumn		*receiversEnableColumn;
	
	NSMutableDictionary			*sourceEnableStateDict;
	NSMutableDictionary			*destEnableStateDict;
}

- (void) appWillTerminateNotification:(NSNotification *)note;

@end

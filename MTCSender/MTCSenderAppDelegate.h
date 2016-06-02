#import <Cocoa/Cocoa.h>
#import <VVMIDI/VVMIDI.h>
#import "MTCMIDIManager.h"




/* From CoreAudioTypes.h:
	enum {
		kSMPTETimeType24		= 0,
		kSMPTETimeType25		= 1,
		kSMPTETimeType30Drop	= 2,
		kSMPTETimeType30		= 3,
		kSMPTETimeType2997		= 4,
		kSMPTETimeType2997Drop	= 5
	};
*/




@interface MTCSenderAppDelegate : NSObject <NSApplicationDelegate,VVMIDIDelegateProtocol>	{
	IBOutlet NSTextField		*startTimeField;
	IBOutlet NSPopUpButton		*formatPUB;
	IBOutlet NSPopUpButton		*targetDevicePUB;
	
	MTCMIDIManager				*mm;
	VVMIDINode					*outputNode;	//	this is the output node chosen by the midi manager
	long						smpteFormat;
	double						startTimeInSeconds;
	BOOL						running;
	CAClockRef					outputClock;
	
	NSTimer						*statusTimer;
	IBOutlet NSTextField		*statusField;
}

- (IBAction) startTimeFieldUsed:(id)sender;
- (IBAction) formatPUBUsed:(id)sender;
- (IBAction) targetDevicePUBUsed:(id)sender;

- (IBAction) startClicked:(id)sender;
- (IBAction) stopClicked:(id)sender;

- (void) start;
- (void) stop;
- (BOOL) running;
- (double) startTimeInSeconds;
- (double) fps;

@end


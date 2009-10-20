#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>




@interface AppController : NSObject {
	VVCrashReporter		*crashReporter;
}

- (IBAction) forceCrashClicked:(id)sender;
- (IBAction) checkClicked:(id)sender;

@end

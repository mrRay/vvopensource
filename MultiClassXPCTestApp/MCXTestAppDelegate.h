#import <Cocoa/Cocoa.h>
#import <MultiClassXPC/MultiClassXPC.h>
#import "ClassAMCXRemote.h"
#import "ClassBMCXRemote.h"




extern MCXServiceManager		*_mcxTestAppServiceMgr;




@interface MCXTestAppDelegate : NSObject <NSApplicationDelegate>	{
	ClassAMCXRemote		*remoteA;
	ClassBMCXRemote		*remoteB;
}

- (IBAction) processA:(id)sender;
- (IBAction) processB:(id)sender;

@end


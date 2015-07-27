#import "MCXTestAppDelegate.h"




MCXServiceManager		*_mcxTestAppServiceMgr = nil;




@implementation MCXTestAppDelegate


+ (void) initialize	{
	@synchronized (self)	{
		if (_mcxTestAppServiceMgr==nil)
			_mcxTestAppServiceMgr = [[MCXServiceManager alloc] initWithXPCServiceIdentifier:@"com.Vidvox.MultiClassXPCTestService"];
	}
}
- (id) init	{
	self = [super init];
	if (self!=nil)	{
		remoteA = nil;
		remoteB = nil;
	}
	return self;
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSLog(@"%s",__func__);
	[self makeSureXPCServiceIsAvailable];
}
- (void) makeSureXPCServiceIsAvailable	{
	NSLog(@"%s",__func__);
	//	loop a small delay while there aren't any available classes
	if (![_mcxTestAppServiceMgr classesAvailable])	{
		__block id		bss = self;
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			[bss makeSureXPCServiceIsAvailable];
		});
		return;
	}
	NSLog(@"\t\tclassDict is %@",[_mcxTestAppServiceMgr classDict]);
	remoteA = [[ClassAMCXRemote alloc] init];
	remoteB = [[ClassBMCXRemote alloc] init];
}
- (IBAction) processA:(id)sender	{
	if (![_mcxTestAppServiceMgr classesAvailable])	{
		NSLog(@"\t\tERR: classes aren't available yet, %s",__func__);
		return;
	}
	[remoteA processAThing];
}
- (IBAction) processB:(id)sender	{
	if (![_mcxTestAppServiceMgr classesAvailable])	{
		NSLog(@"\t\tERR: classes aren't available yet, %s",__func__);
		return;
	}
	[remoteB processAThing];
}


@end

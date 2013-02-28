#import "AppController.h"




@implementation AppController


- (id) init	{
	self = [super init];
	crashReporter = [[VVCrashReporter alloc] init];
	[crashReporter setUploadURL:@"http://127.0.0.1/~yourUserName/serverSideCrashReporter.php"];
	[crashReporter setDeveloperEmail:@"support@vidvox.net"];
	[crashReporter setDelegate:self];
	return self;
}
- (IBAction) forceCrashClicked:(id)sender	{
	NSTask			*task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/killall"];
	[task setArguments:[NSArray arrayWithObjects:
		@"-SIGABRT",
		@"CrashReporterTestApp",
		nil]	];
	[task launch];
}
- (IBAction) checkClicked:(id)sender	{
	[crashReporter check];
}
- (void) crashReporterCheckDone	{
	NSLog(@"%s",__func__);
}


@end

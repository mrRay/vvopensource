#import "AppController.h"




@implementation AppController


- (id) init	{
	self = [super init];
	crashReporter = [[VVCrashReporter alloc] init];
	[crashReporter setUploadURL:[NSString stringWithString:@"http://127.0.0.1/~yourUserName/serverSideCrashReporter.php"]];
	[crashReporter setDeveloperEmail:[NSString stringWithString:@"support@vidvox.net"]];
	[crashReporter setDelegate:self];
	return self;
}
- (IBAction) forceCrashClicked:(id)sender	{
	NSTask			*task = [[NSTask alloc] init];
	[task setLaunchPath:@"/usr/bin/killall"];
	[task setArguments:[NSArray arrayWithObjects:
		[NSString stringWithString:@"-SIGABRT"],
		[NSString stringWithString:@"CrashReporterTestApp"],
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

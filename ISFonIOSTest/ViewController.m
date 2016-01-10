#import "ViewController.h"




@implementation ViewController

- (id) initWithCoder:(NSCoder *)c	{
	NSLog(@"%s",__func__);
	self = [super initWithCoder:c];
	if (self != nil)	{
		NSBundle		*mb = [NSBundle mainBundle];
		[VVBufferPool createGlobalVVBufferPool];
		NSLog(@"\t\tbuffer pool ctx is %@, sharegroup is %@",[VVBufferPool globalVVBufferPool],[[VVBufferPool globalVVBufferPool] sharegroup]);
		isfScene = [[ISFGLScene alloc] initWithSharegroup:[[VVBufferPool globalVVBufferPool] sharegroup] sized:VVMAKESIZE(640,480)];
		[isfScene useFile:[mb pathForResource:@"blueelectricspiral" ofType:@"fs"]];
	}
	return self;
}
- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	CADisplayLink		*dl = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
	[dl addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}
- (void) displayLinkCallback:(CADisplayLink *)dl	{
	//NSLog(@"%s",__func__);
	[self timerCallback:nil];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (void) timerCallback:(NSTimer *)t	{
	//NSLog(@"%s",__func__);
	VVBuffer		*isfBuffer = [isfScene allocAndRenderToBufferSized:VVMAKESIZE(640,480)];
	[bufferView drawBuffer:isfBuffer];
	isfBuffer = nil;
}


@end

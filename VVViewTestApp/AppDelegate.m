//
//  AppDelegate.m
//  VVViewTestApp
//
//  Created by bagheera on 11/11/12.
//
//

#import "AppDelegate.h"




@implementation AppDelegate


- (void)dealloc	{
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification	{
	NSLog(@"%s",__func__);
	[spriteView setClearColor:[NSColor colorWithDeviceRed:1.0 green:0.0 blue:0.0 alpha:1.0]];
	[spriteView setFlipped:YES];
	
	blueView = [[BlueView alloc] initWithFrame:NSMakeRect(80,60,160,120)];
	[spriteView addVVSubview:blueView];
	//[blueView setAutoresizingMask:VVViewResizeMinYMargin|VVViewResizeMinXMargin];
	//[blueView setAutoresizingMask:VVViewResizeWidth|VVViewResizeHeight];
	//[blueView setAutoresizingMask:VVViewResizeMinXMargin|VVViewResizeMaxXMargin|VVViewResizeWidth|VVViewResizeMinYMargin|VVViewResizeMaxYMargin];
	
	greenView = [[GreenView alloc] initWithFrame:NSMakeRect(10,10,10,10)];
	[spriteView addVVSubview:greenView];
	//[greenView setAutoresizingMask:VVViewResizeMinYMargin|VVViewResizeMinXMargin];
	//[greenView setAutoresizingMask:VVViewResizeWidth|VVViewResizeHeight];
	
	[spriteView setNeedsDisplay:YES];
	
	//[NSTimer
	//	scheduledTimerWithTimeInterval:1.0/10.0
	//	target:self
	//	selector:@selector(timerCallback:)
	//	userInfo:nil
	//	repeats:YES];
}
- (void) timerCallback:(NSTimer *)t	{
	NSLog(@"%s",__func__);
	//[spriteView setInitialized:NO];
	//[spriteView setNeedsDisplay:YES];
}


@end

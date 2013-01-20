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
	[spriteView setClearColor:[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:1.0]];
	[spriteView setFlipped:YES];
	
	redView = [[RedView alloc] initWithFrame:NSMakeRect(0,0,160,120)];
	[spriteView addVVSubview:redView];
	[redView release];
	[redView setBoundsRotation:90.0];
	[redView setBoundsOrigin:NSMakePoint(0,120)];
	[redView setAutoresizingMask:VVViewResizeWidth|VVViewResizeHeight];
	//[redView setFrameOrigin:NSMakePoint(10,10)];
	
	blueView = [[BlueView alloc] initWithFrame:NSMakeRect(80,60,80,60)];
	[redView addSubview:blueView];
	[blueView release];
	//[blueView setAutoresizingMask:VVViewResizeMinYMargin|VVViewResizeMinXMargin];
	//[blueView setAutoresizingMask:VVViewResizeWidth|VVViewResizeHeight];
	//[blueView setAutoresizingMask:VVViewResizeMinXMargin|VVViewResizeMaxXMargin|VVViewResizeWidth|VVViewResizeMinYMargin|VVViewResizeMaxYMargin];
	
	greenView = [[GreenView alloc] initWithFrame:NSMakeRect(10,10,10,10)];
	[redView addSubview:greenView];
	[greenView release];
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

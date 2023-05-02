//
//  UIToolboxTestAppDelegate.m
//  UIToolboxTestApp
//
//  Created by testadmin on 4/27/23.
//

#import "UIToolboxTestAppDelegate.h"
#import "GreenVVView.h"
#import "RedVVView.h"




@interface UIToolboxTestAppDelegate ()
@property (strong) IBOutlet NSWindow *window;
@end




@implementation UIToolboxTestAppDelegate


- (instancetype) init	{
	self = [super init];
	if (self != nil)	{
		
		//	make a shared GL context.  other GL contexts created to share this one may share resources (textures, buffers, etc).
		sharedContext = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:nil];
		
		//	create the global buffer pool from the shared context
		[VVBufferPool createGlobalVVBufferPoolWithSharedContext:sharedContext];
		//	...other stuff in the VVBufferPool framework- like the views, the buffer copier, etc- will 
		//	automatically use the global buffer pool's shared context to set themselves up to function with the pool.
		
		device = MTLCreateSystemDefaultDevice();
		cmdQueue = [device newCommandQueue];
	}
	return self;
}
- (void) awakeFromNib	{
	//	make GL contexts for the GL views
	NSOpenGLPixelFormat		*pf = [GLScene defaultPixelFormat];
	NSOpenGLContext			*tmpCtx = nil;
	tmpCtx = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:sharedContext];
	[_spriteGLView setOpenGLContext:tmpCtx];
	[_spriteGLView setClearColors:0.:0.:0.:1.];
	tmpCtx = nil;
	
	//	set up retina vs non-retina!
	[_spriteGLView setWantsBestResolutionOpenGLSurface:NO];
	//	set up the metal device!
	_spriteMTLView.device = device;
	
	//	we're going to make the same views and add them to the following array of container views.
	NSArray<id<VVViewContainer>>	*views = @[
		_spriteView,
		_spriteGLView,
		_spriteMTLView
	];
	
	for (id<VVViewContainer> view in views)	{
		//NSRect			glViewBounds = [(NSView*)view bounds];
		
		//NSRect			greenFrame = [_spriteGLView bounds];
		NSRect			greenFrame = NSInsetRect([_spriteGLView bounds],10,10);
		NSLog(@"\t\tgreenFrame is %@",NSStringFromRect(greenFrame));
		GreenVVView		*greenView = [[GreenVVView alloc] initWithFrame:greenFrame];
		[greenView setClearColors:0.:1.:0.:1.];
		//[greenView setLocalToBackingBoundsMultiplier:1.0];
		//[greenView setRoundFlag:FARoundRectCorner_TL|FARoundRectCorner_TR|FARoundRectCorner_BL|FARoundRectCorner_BR];
		//[greenView setRoundAmount:5.0];
		//[greenView setClearColors:1:0:0:1];
		//[greenView setIsOpaque:YES];
		//[greenView setBoundsOrientation:VVViewBOBottom];
		//[greenView setBoundsOrientation:VVViewBOTop];
		//[greenView setBoundsOrientation:VVViewBOLeft];
		//[greenView setBoundsOrientation:VVViewBORight];
		//[greenView setBoundsOrigin:NSMakePoint(-10,-10)];
		[view addVVSubview:greenView];
		
		
		//NSRect			redFrame = greenFrame;
		NSRect			redFrame = NSInsetRect(greenFrame,10,10);
		redFrame.origin = NSMakePoint(10,10);
		NSLog(@"\t\tredFrame is %@",NSStringFromRect(redFrame));
		RedVVView		*redView = [[RedVVView alloc] initWithFrame:redFrame];
		[redView setClearColors:1.:0.:0.:1.];
		//[redView setBoundsOrientation:VVViewBOBottom];
		//[redView setBoundsOrientation:VVViewBOTop];
		//[redView setBoundsOrientation:VVViewBOLeft];
		//[redView setBoundsOrientation:VVViewBORight];
		//[redView setBoundsOrigin:NSMakePoint(-10,-10)];
		[greenView addSubview:redView];
		
	}
	
	
	/*
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
		[self blockRenderCallback];
	});
	*/
	/*
	[NSTimer
		scheduledTimerWithTimeInterval:5.0
		target:self
		selector:@selector(timerRenderCallback:)
		userInfo:nil
		repeats:YES];
	*/
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	
	
	//	make the displaylink, which will drive rendering
	CVReturn				err = kCVReturnSuccess;
	CGOpenGLDisplayMask		totalDisplayMask = 0;
	GLint					virtualScreen = 0;
	GLint					displayMask = 0;
	NSOpenGLPixelFormat		*format = [GLScene defaultPixelFormat];
	
	for (virtualScreen=0; virtualScreen<[format numberOfVirtualScreens]; ++virtualScreen)	{
		[format getValues:&displayMask forAttribute:NSOpenGLPFAScreenMask forVirtualScreen:virtualScreen];
		totalDisplayMask |= displayMask;
	}
	err = CVDisplayLinkCreateWithOpenGLDisplayMask(totalDisplayMask, &displayLink);
	if (err)	{
		NSLog(@"\t\terr %d creating display link in %s",err,__func__);
		displayLink = NULL;
	}
	else	{
		CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, (__bridge void * _Nullable)(self));
		CVDisplayLinkStart(displayLink);
	}
}


- (void) renderCallback	{
	//NSLog(@"%s",__func__);
	//NSLog(@"\t\t%f - %f",[_spriteGLView localToBackingBoundsMultiplier],[retinaView localToBackingBoundsMultiplier]);
	
	[_spriteGLView drawRect:[_spriteGLView backingBounds]];
	[_spriteMTLView performDrawing:[_spriteMTLView backingBounds] onCommandQueue:cmdQueue];
	
	//NSRectLog(@"\t\tframe of label view is",[labelView frame]);
	//NSSizeLog(@"\t\tsize of label view is",[[labelView label] labelSize]);
	
	//	tell the buffer pool to do its housekeeping (releases any "old" resources in the pool that have been sticking around for a while)
	[[VVBufferPool globalVVBufferPool] housekeeping];
	
	
	//NSLog(@"SHOULD BE DRAWING HERE %s",__func__);
	//[_spriteMTLView
	//	performDrawing:XXX
	//	inEncoder:XXX
	//	commandBuffer:XXX];
	
	
}


@end














CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, 
	const CVTimeStamp *inNow, 
	const CVTimeStamp *inOutputTime, 
	CVOptionFlags flagsIn, 
	CVOptionFlags *flagsOut, 
	void *displayLinkContext)
{
	@autoreleasepool	{
		[(__bridge UIToolboxTestAppDelegate *)displayLinkContext renderCallback];
	}
	return kCVReturnSuccess;
}

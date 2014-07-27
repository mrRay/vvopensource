#import "AppDelegate.h"




@implementation AppDelegate


- (id) init	{
	if (self = [super init])	{
		sharedContext = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:nil];
		[VVBufferPool createGlobalVVBufferPoolWithSharedContext:sharedContext];
		displayLink = NULL;
		videoSource = [[QTVideoSource alloc] init];
		return self;
	}
	[self release];
	return nil;
}
- (void)dealloc	{
    [super dealloc];
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification	{
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
		CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, self);
		CVDisplayLinkStart(displayLink);
	}
}
- (IBAction) openDocument:(id)sender	{
	NSLog(@"%s",__func__);
	NSUserDefaults	*def = [NSUserDefaults standardUserDefaults];
	NSString		*importDir = [def objectForKey:@"lastOpenDocumentFolder"];
	if (importDir == nil)
		importDir = [@"~/Desktop" stringByExpandingTildeInPath];
	NSString		*importFile = [def objectForKey:@"lastOpenDocumentFile"];
	NSOpenPanel		*op = [[NSOpenPanel openPanel] retain];
	[op setAllowsMultipleSelection:NO];
	[op setCanChooseDirectories:NO];
	[op setResolvesAliases:YES];
	[op setMessage:@"Select a QuickTime movie"];
	[op setTitle:@"Open file"];
	[op setAllowedFileTypes:OBJARRAY(@"mov")];
	//[op setAllowedFileTypes:OBJSARRAY(@"mov",@"mp4",@"mpg",@"qtz","tiff","jpg","jpeg","png")];
	//[op setDirectoryURL:[NSURL fileURLWithPath:importDir]];
	if (importFile != nil)
		[op setDirectoryURL:[NSURL fileURLWithPath:importFile]];
	else
		[op setDirectoryURL:[NSURL fileURLWithPath:importDir]];
	
	[op
		beginSheetModalForWindow:nil
		completionHandler:^(NSInteger result)	{
			if (result == NSFileHandlingPanelOKButton)	{
				//	get the inspected object
				NSArray			*fileURLs = [op URLs];
				NSURL			*urlPtr = (fileURLs==nil) ? nil : [fileURLs objectAtIndex:0];
				NSString		*urlPath = (urlPtr==nil) ? nil : [urlPtr path];
				
				[videoSource loadFileAtPath:urlPath];
				
				//	update the defaults so i know where the law directory i browsed was
				NSString		*directoryString = [urlPath stringByDeletingLastPathComponent];
				[[NSUserDefaults standardUserDefaults] setObject:directoryString forKey:@"lastOpenDocumentFolder"];
				[[NSUserDefaults standardUserDefaults] setObject:urlPath forKey:@"lastOpenDocumentFile"];
				[[NSUserDefaults standardUserDefaults] synchronize];
			}
		}];
	VVRELEASE(op);
}
- (void) renderCallback	{
	VVBuffer		*newFrame = [videoSource allocNewFrame];
	if (newFrame != nil)	{
		[glView drawBuffer:newFrame];
		[newFrame release];
		newFrame = nil;
	}
	[[VVBufferPool globalVVBufferPool] housekeeping];
}


@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, 
	const CVTimeStamp *inNow, 
	const CVTimeStamp *inOutputTime, 
	CVOptionFlags flagsIn, 
	CVOptionFlags *flagsOut, 
	void *displayLinkContext)
{
	//NSLog(@"%s",__func__);
	NSAutoreleasePool		*pool =[[NSAutoreleasePool alloc] init];
	[(AppDelegate *)displayLinkContext renderCallback];
	[pool release];
	return kCVReturnSuccess;
}

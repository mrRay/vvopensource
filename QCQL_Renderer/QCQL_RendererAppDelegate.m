#import "QCQL_RendererAppDelegate.h"
#import "QCQLRendererAgent.h"
#import <VVBufferPool/VVBufferPool.h>




VVBuffer		*_globalColorBars = nil;
ISFGLScene		*_swizzleScene = nil;


#define LOCK OSSpinLockLock
#define UNLOCK OSSpinLockUnlock




@implementation QCQL_RendererAppDelegate


- (id) init	{
	//NSLog(@"%s",__func__);
	self = [super init];
	if (self != nil)	{
		ttlLock = OS_SPINLOCK_INIT;
		ttlTimer = nil;
		
		//	make the GL resources
		NSOpenGLPixelFormat		*pf = [GLScene defaultPixelFormat];
		NSOpenGLContext			*sharedContext = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:nil];
		
		[VVBufferPool createGlobalVVBufferPoolWithSharedContext:sharedContext];
		[QCGLScene prepCommonQCBackendToRenderOnContext:sharedContext pixelFormat:[GLScene defaultPixelFormat]];
		
		//	load the color bars image into a GL texture
		NSImage			*bars = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"ColorBars" ofType:@"png"]];
		_globalColorBars = [_globalVVBufferPool allocBufferForNSImage:bars];
		[bars release];
		bars = nil;
		
		//	load the swizzle scene
		_swizzleScene = [[ISFGLScene alloc] initWithSharedContext:sharedContext pixelFormat:pf sized:NSMakeSize(800,600)];
		NSString		*swizzleSrc = [[NSBundle mainBundle] pathForResource:@"SwizzleISF-RGBAtoBGRA" ofType:@"fs"];
		[_swizzleScene useFile:swizzleSrc];
		
		//	spawn a thread- the listener will run on this thread
		[NSThread detachNewThreadSelector:@selector(threadLaunch:) toTarget:self withObject:nil];
		
		[self resetTTLTimer];
	}
	//NSLog(@"\t\t%s - FINISHED",__func__);
	return self;
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	//NSLog(@"%s",__func__);
	//NSLog(@"\t\t%s - FINISHED",__func__);
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {
	//NSLog(@"%s",__func__);
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	[super dealloc];
}


#pragma mark renderer timeout methods


- (void) noMoreRenderersTimer:(NSTimer *)t	{
	//NSLog(@"%s",__func__);
	VVRELEASE(_globalColorBars);
	exit(0);
}
- (void) resetTTLTimer	{
	//NSLog(@"%s",__func__);
	LOCK(&ttlLock);
	if (ttlTimer != nil)	{
		[ttlTimer invalidate];
		ttlTimer = nil;
	}
	UNLOCK(&ttlLock);
	
	dispatch_async(dispatch_get_main_queue(), ^{
		LOCK(&ttlLock);
		if (ttlTimer != nil)
			[ttlTimer invalidate];
		ttlTimer = [NSTimer
			scheduledTimerWithTimeInterval:5.
			target:self
			selector:@selector(noMoreRenderersTimer:)
			userInfo:nil
			repeats:NO];
		UNLOCK(&ttlLock);
	});
}


#pragma mark XPC and XPC thread-related


- (void) threadLaunch:(id)sender	{
	//NSLog(@"%s",__func__);
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	NSXPCListener			*listener = [[NSXPCListener alloc] initWithMachServiceName:@"com.vidvox.QCQL-Renderer"];
	[listener setDelegate:self];
	[listener resume];
	[pool release];
	pool = nil;
	//NSLog(@"\t\t%s - FINISHED",__func__);
}
- (BOOL) listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection	{
	//NSLog(@"%s",__func__);
	//	reset the TTL timer
	[self resetTTLTimer];
	
	//	make a local object for the new connection- this object must be freed later, or it will leak!
	QCQLRendererAgent		*exportedObj = [[QCQLRendererAgent alloc] init];
	[newConnection setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(QCQLAgentService)]];
	[newConnection setExportedObject:exportedObj];
	//	we don't want to free this now- the agent will free itself either when it's done rendering a frame or when it times out
	//[exportedObj release];
	
	[newConnection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(QCQLService)]];
	[newConnection resume];
	
	[exportedObj setConn:newConnection];
	[exportedObj setDelegate:self];
	//NSLog(@"\t\t%s - FINISHED",__func__);
	return YES;
	
}


#pragma mark QCQLRendererAgentDelegate


//	this method is called 
- (void) agentKilled:(id)renderer	{
	//NSLog(@"%s",__func__);
	[self resetTTLTimer];
}


@end

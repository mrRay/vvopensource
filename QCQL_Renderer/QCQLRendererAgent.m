#import "QCQLRendererAgent.h"
#import <VVBufferPool/VVBufferPool.h>
#import "QCQL_RendererAppDelegate.h"




#define LOCK OSSpinLockLock
#define UNLOCK OSSpinLockUnlock




@interface QCQLRendererAgent ()
- (void) resetTTLTimer;
@end




@implementation QCQLRendererAgent


- (id) init	{
	//NSLog(@"%s ... %p",__func__,self);
	if (self = [super init])	{
		deleted = NO;
		connLock = OS_SPINLOCK_INIT;
		conn = nil;
		timerLock = OS_SPINLOCK_INIT;
		ttlTimer = nil;
		delegateLock = OS_SPINLOCK_INIT;
		delegate = nil;
		return self;
	}
	[self release];
	return nil;
}
- (void) prepareToBeDeleted	{
	if (deleted)
		return;
	//NSLog(@"%s ... %p",__func__,self);
	
	deleted = YES;
	
	//	kill the timer
	LOCK(&timerLock);
	if (ttlTimer != nil)	{
		[ttlTimer invalidate];
		ttlTimer = nil;
	}
	UNLOCK(&timerLock);
	
	//	kill the connection
	LOCK(&connLock);
	[conn invalidate];
	conn = nil;
	UNLOCK(&connLock);
	
	//	tell the delegate that i'm dying
	id			myDelegate = [self delegate];
	if (myDelegate != nil)
		[myDelegate agentKilled:self];
	
	//	release myself (not a bug!)
	[self autorelease];
}
- (void) dealloc	{
	//NSLog(@"%s ... %p",__func__,self);
	if (!deleted)
		[self prepareToBeDeleted];
	
	[super dealloc];
}


#pragma mark XPC backend


- (void) setConn:(NSXPCConnection *)n	{
	//NSLog(@"%s ... %p",__func__,self);
	OSSpinLockLock(&connLock);
	conn = n;
	OSSpinLockUnlock(&connLock);
	
	[n setInvalidationHandler:^()	{
		NSLog(@"err: %@ invalidation handler",[self className]);
	}];
	[n setInterruptionHandler:^()	{
		NSLog(@"err: %@ interruption handler",[self className]);
	}];
}


#pragma mark TTL timer stuff


//	this is a timeout method- if it gets called, something went wrong and i need to kill this agent.
- (void) ttlTimer:(NSTimer *)t	{
	//NSLog(@"%s ... %p",__func__,self);
	if (deleted)
		return;
	
	LOCK(&timerLock);
	ttlTimer = nil;
	UNLOCK(&timerLock);
	
	//	get the ROP, and pass empty bitmap data back to it
	LOCK(&connLock);
	id<QCQLService>	rop = (conn==nil) ? nil : [conn remoteObjectProxy];
	UNLOCK(&connLock);
	
	if (rop != nil)	{
		NSLog(@"\t\terr: timed out, passing back empty frame, %s",__func__);
		[rop renderedBitmapData:[NSData data] sized:NSMakeSize(0,0)];
	}
	else	{
		NSLog(@"\t\terr: timed out, but ROP was nil, %s",__func__);
	}
	
	//	prepping for deletion kills the connection & timer and releases myself
	[self prepareToBeDeleted];
}
- (void) resetTTLTimer	{
	//NSLog(@"%s ... %p",__func__,self);
	LOCK(&timerLock);
	if (ttlTimer != nil)	{
		[ttlTimer invalidate];
		ttlTimer = nil;
	}
	UNLOCK(&timerLock);
	
	dispatch_async(dispatch_get_main_queue(), ^{
		if (!deleted)	{
			LOCK(&timerLock);
			ttlTimer = [NSTimer
				scheduledTimerWithTimeInterval:3.
				target:self
				selector:@selector(ttlTimer:)
				userInfo:nil
				repeats:NO];
			UNLOCK(&timerLock);
		}
	});
}


#pragma mark QCQLAgentService


- (void) renderThumbnailForPath:(NSString *)n sized:(NSSize)s	{
	//NSLog(@"%s ... %@",__func__,n);
	//NSLog(@"%s ... %p",__func__,self);
	
	//	start a render timer- if the frame takes longer than a couple seconds, bail and return
	[self resetTTLTimer];
	
	
	//	actually render the frame
	NSSize					renderSize = s;
	QCGLScene				*scene = [[QCGLScene alloc] initCommonBackendSceneSized:renderSize];
	VVBuffer				*renderBuffer = [_globalVVBufferPool allocBGRTexSized:renderSize];
	VVBuffer				*swizzleBuffer = nil;
	BOOL					problemRendering = NO;
	
	@try	{
		
		[scene useFile:n];
		
		if ([[scene comp] hasFXInput])	{
			QCRenderer		*renderer = [scene renderer];
			if (renderer != nil)	{
				CGColorSpaceRef		colorSpace = [scene colorSpace];
				CIImage				*tmpImg = [CIImage
					imageWithTexture:[_globalColorBars name]
					size:NSMAKECGSIZE([_globalColorBars size])
					flipped:[_globalColorBars flipped]
					colorSpace:colorSpace];
				[renderer setValue:tmpImg forInputKey:@"inputImage"];
			}
		}
		
		VVBuffer		*fbo = [_globalVVBufferPool allocFBO];
		VVBuffer		*depth = [_globalVVBufferPool allocDepthSized:renderSize];
		[scene renderInFBO:[fbo name] colorTex:[renderBuffer name] depthTex:[depth name]];
		VVRELEASE(depth);
		VVRELEASE(fbo);
		
		//	it's not really flipped, but CGImage stuff wants a flipped buffer...
		[renderBuffer setFlipped:YES];
		
		//	swizzle the colors!
		[_swizzleScene setSize:[renderBuffer srcRect].size];
		[_swizzleScene setFilterInputImageBuffer:renderBuffer];
		swizzleBuffer = [_swizzleScene allocAndRenderABuffer];
	}
	@catch (NSException *err)	{
		problemRendering = YES;
	}
	
	
	
	//NSLog(@"\t\tswizzleBuffer is %@",swizzleBuffer);
	
	
	
	//	if i had a problem rendering, return an empty image immediately
	if (problemRendering)	{
		NSLog(@"\t\terr: there was a problem, passing back an empty frame");
		LOCK(&connLock);
		id<QCQLService>	rop = (conn==nil) ? nil : [conn remoteObjectProxy];
		UNLOCK(&connLock);
		if (rop != nil)
			[rop renderedBitmapData:[NSData data] sized:NSMakeSize(0,0)];
	}
	//	else rendering happened without issue- download the image we rendered, then pass it back to the ROP
	else	{
		TexRangeGLCPUStreamer	*streamer = [[TexRangeGLCPUStreamer alloc] init];
		[streamer setNextTexBufferForStream:swizzleBuffer];
		VVBuffer				*cpuBuffer = nil;
		while (cpuBuffer == nil)	{
			cpuBuffer = [streamer copyAndGetCPUBackedBufferForStream];
		}
		//NSLog(@"\t\tcpuBuffer is %@",cpuBuffer);
		unsigned long			cpuBufferSize = VVBufferDescriptorCalculateCPUBackingForSize([cpuBuffer descriptorPtr], [cpuBuffer size]);
		if ([cpuBuffer cpuBackingPtr]==nil)
			cpuBufferSize = 0;
		//NSLog(@"\t\tcpuBufferSize is %ld, backing ptr is %p",cpuBufferSize,[cpuBuffer cpuBackingPtr]);
		NSData					*cpuBufferData = (cpuBufferSize<=0) ? [NSData data] : [NSData dataWithBytes:[cpuBuffer cpuBackingPtr] length:cpuBufferSize];
		
		LOCK(&connLock);
		id<QCQLService>	rop = (conn==nil) ? nil : [conn remoteObjectProxy];
		UNLOCK(&connLock);
		if (!deleted && rop!=nil)	{
			//NSLog(@"\t\tfinished rendering, passing bitmap data back from agent, %s",__func__);
			[rop renderedBitmapData:cpuBufferData sized:renderSize];
		}
		else	{
			NSLog(@"\t\terr: finished rendering, but ROP is nil- nothing to pass back, %s",__func__);
		}
	
		//	free stuff
		VVRELEASE(cpuBuffer);
		VVRELEASE(streamer);
	}
	
	VVRELEASE(swizzleBuffer);
	VVRELEASE(renderBuffer);
	VVRELEASE(scene);
	
	//	prepping for deletion kills the connection & timer and releases myself
	[self prepareToBeDeleted];
	
}


#pragma mark key/value


- (void) setDelegate:(id<QCQLRendererAgentDelegate>)n	{
	LOCK(&delegateLock);
	delegate = n;
	UNLOCK(&delegateLock);
}
- (id<QCQLRendererAgentDelegate>) delegate	{
	id<QCQLRendererAgentDelegate>		returnMe = nil;
	LOCK(&delegateLock);
	returnMe = delegate;
	UNLOCK(&delegateLock);
	return returnMe;
}


@end

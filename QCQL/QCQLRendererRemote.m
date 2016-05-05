#import "QCQLRendererRemote.h"
#import <AppKit/AppKit.h>




#define LOCK OSSpinLockLock
#define UNLOCK OSSpinLockUnlock




@implementation QCQLRendererRemote


- (id) init	{
	//NSLog(@"%s",__func__);
	self = [super init];
	if (self != nil)	{
		deleted = NO;
		connLock = OS_SPINLOCK_INIT;
		conn = nil;
		thumbnailData = nil;
		thumbnailSize = NSMakeSize(0,0);
		
		//	make and set up an XPC connection
		LOCK(&connLock);
		conn = [[NSXPCConnection alloc] initWithMachServiceName:@"com.vidvox.QCQL-Renderer" options:0];
		//NSLog(@"\t\tconn is %@",conn);
		[conn setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(QCQLAgentService)]];
		[conn setExportedInterface:[NSXPCInterface interfaceWithProtocol:@protocol(QCQLService)]];
		[conn setExportedObject:self];
		[conn setInvalidationHandler:^()	{
			//NSLog(@"%@ invalidation handler",[self className]);
		}];
		[conn setInterruptionHandler:^()	{
			//NSLog(@"%@ interruption handler",[self className]);
		}];
		[conn resume];
		UNLOCK(&connLock);
		
		//	ping the remote object (this will launch the service if it doesn't already exist)
		//[rop ping];
	}
	return self;
}
- (void) prepareToBeDeleted	{
	//NSLog(@"%s",__func__);
	
	LOCK(&connLock);
	if (conn != nil)	{
		//[conn suspend];	//	DO NOT SUSPEND- for some reason, this prevents 'invalidate' from working.
		[conn invalidate];
		//	if i don't explicitly set the exported object to nil, the exported object (self) just leaks.
		[conn setExportedObject:nil];
		[conn release];
		conn = nil;
	}
	UNLOCK(&connLock);
	
	deleted = YES;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (!deleted)
		[self prepareToBeDeleted];
	[self setThumbnailData:nil];
	[super dealloc];
}


@synthesize thumbnailData;
@synthesize thumbnailSize;


- (void) renderThumbnailForPath:(NSString *)n sized:(NSSize)s	{
	//NSLog(@"%s ... %@",__func__,n);
	if (deleted)
		return;
	LOCK(&connLock);
	id<QCQLAgentService>	rop = [conn remoteObjectProxy];
	UNLOCK(&connLock);
	
	[rop renderThumbnailForPath:n sized:s];
}



- (CGImageRef) allocCGImageFromThumbnailData	{
	//	implement the timeout here
	NSData					*tmpData = nil;
	NSDate					*nowDate = [NSDate date];
	while (tmpData == nil)	{
		tmpData = [self thumbnailData];
		if (tmpData == nil)
			[NSThread sleepForTimeInterval:1./10.];
		if (fabs([nowDate timeIntervalSinceNow])>=4.)
			break;
	}
	//	if we couldn't get any data and we're here, we've timed out- return nil immediately
	if (tmpData == nil)
		return NULL;
	
	NSSize					renderSize = [self thumbnailSize];
	CGColorSpaceRef			colorSpace = CGColorSpaceCreateDeviceRGB();
	CGDataProviderRef		provider = CGDataProviderCreateWithCFData((CFDataRef)tmpData);
	CGImageRef				img = (provider==NULL) ? NULL : CGImageCreate(renderSize.width,
		renderSize.height,
		8,
		32,
		32*renderSize.width/8,
		colorSpace,	//	colorspace
		kCGBitmapByteOrderDefault | kCGImageAlphaLast,
		provider,	//	provider
		NULL,
		true,
		kCGRenderingIntentPerceptual);
	if (img == NULL)
		NSLog(@"\t\terr: img NULL in %s",__func__);
	
	if (provider != NULL)	{
		CGDataProviderRelease(provider);
		provider = NULL;
	}
	if (colorSpace != NULL)	{
		CGColorSpaceRelease(colorSpace);
		colorSpace = NULL;
	}
	
	return img;
}

- (NSImage *) allocNSImageFromThumbnailData	{
	CGImageRef				cgImg = [self allocCGImageFromThumbnailData];
	if (cgImg == NULL)
		return nil;
	NSImage					*returnMe = [[NSImage alloc] initWithCGImage:cgImg size:NSMakeSize(CGImageGetWidth(cgImg), CGImageGetHeight(cgImg))];
	CGImageRelease(cgImg);
	cgImg = NULL;
	return returnMe;
}


#pragma mark QCQLService


- (void) renderedBitmapData:(NSData *)d sized:(NSSize)s	{
	//NSLog(@"%s ... %d x %d",__func__,(int)s.width,(int)s.height);
	[self setThumbnailData:d];
	[self setThumbnailSize:s];
}


@end

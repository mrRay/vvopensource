#import "AVCaptureVideoSource.h"




@implementation AVCaptureVideoSource


/*===================================================================================*/
#pragma mark --------------------- init/dealloc
/*------------------------------------*/


- (id) init	{
	//NSLog(@"%s",__func__);
	if (self = [super init])	{
		propDeviceInput = nil;
		propSession = nil;
		propOutput = nil;
		propQueue = NULL;
		CVReturn			err = kCVReturnSuccess;
		//NSLog(@"\t\tshared context used for tex cache is %@",[_globalVVBufferPool sharedContext]);
		err = CVOpenGLTextureCacheCreate(NULL,NULL,[[_globalVVBufferPool sharedContext] CGLContextObj],[[GLScene defaultPixelFormat] CGLPixelFormatObj],NULL,&propTextureCache);
		if (err != kCVReturnSuccess)	{
			NSLog(@"\t\terr %d at CVOpenGLTextureCacheCreate, %s",err,__func__);
		}
		propLastBuffer = nil;
		return self;
	}
	[self release];
	return nil;
}
- (void) prepareToBeDeleted	{
	[super prepareToBeDeleted];
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (!deleted)
		[self prepareToBeDeleted];
	
	OSSpinLockLock(&propLock);
	CVOpenGLTextureCacheRelease(propTextureCache);
	VVRELEASE(propLastBuffer);
	OSSpinLockUnlock(&propLock);
	
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- superclass overrides
/*------------------------------------*/


- (NSArray *) arrayOfSourceMenuItems	{
	NSArray		*devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	if (devices==nil || [devices count]<1)
		return nil;
	NSMutableArray		*returnMe = MUTARRAY;
	for (AVCaptureDevice *devicePtr in devices)	{
		NSMenuItem		*newItem = [[NSMenuItem alloc] initWithTitle:[devicePtr localizedName] action:nil keyEquivalent:@""];
		NSString		*uniqueID = [devicePtr uniqueID];
		[newItem setRepresentedObject:uniqueID];
		[returnMe addObject:newItem];
		[newItem release];
	}
	return returnMe;
}
- (void) _stop	{
	//NSLog(@"%s",__func__);
	if (propSession != nil)	{
		[propSession stopRunning];
		if (propDeviceInput != nil)
			[propSession removeInput:propDeviceInput];
		if (propOutput != nil)
			[propSession removeOutput:propOutput];
		
		dispatch_release(propQueue);
		propQueue = NULL;
		
		[propDeviceInput release];
		propDeviceInput = nil;
		[propOutput release];
		propOutput = nil;
		[propSession release];
		propSession = nil;
	}
	VVRELEASE(propLastBuffer);
}
- (VVBuffer *) allocBuffer	{
	VVBuffer		*returnMe = nil;
	OSSpinLockLock(&propLock);
	returnMe = (propLastBuffer==nil) ? nil : [propLastBuffer retain];
	OSSpinLockUnlock(&propLock);
	return returnMe;
}


/*===================================================================================*/
#pragma mark --------------------- misc
/*------------------------------------*/


- (void) loadDeviceWithUniqueID:(NSString *)n	{
	if ([self propRunning])
		[self stop];
	if (n==nil)
		return;
	BOOL				bail = NO;
	NSError				*err = nil;
	OSSpinLockLock(&propLock);
	AVCaptureDevice		*propDevice = [AVCaptureDevice deviceWithUniqueID:n];
	propDeviceInput = (propDevice==nil) ? nil : [[AVCaptureDeviceInput alloc] initWithDevice:propDevice error:&err];
	if (propDeviceInput != nil)	{
		propSession = [[AVCaptureSession alloc] init];
		propOutput = [[AVCaptureVideoDataOutput alloc] init];
		
		if (![propSession canAddInput:propDeviceInput])	{
			NSLog(@"\t\terr: problem adding propDeviceInput in %s",__func__);
			bail = YES;
		}
		if (![propSession canAddOutput:propOutput])	{
			NSLog(@"\t\terr: problem adding propOutput in %s",__func__);
			bail = YES;
		}
		
		if (!bail)	{
			propQueue = dispatch_queue_create([[[NSBundle mainBundle] bundleIdentifier] UTF8String], NULL);
			[propOutput setSampleBufferDelegate:self queue:propQueue];
			
			[propSession addInput:propDeviceInput];
			[propSession addOutput:propOutput];
			[propSession startRunning];
		}
	}
	else
		bail = YES;
	OSSpinLockUnlock(&propLock);
	
	if (bail)
		[self stop];
	else
		[self start];
}


/*===================================================================================*/
#pragma mark --------------------- AVCaptureVideoDataOutputSampleBufferDelegate protocol (and AVCaptureFileOutputDelegate, too- some protocols share these methods)
/*------------------------------------*/


- (void)captureOutput:(AVCaptureOutput *)o didDropSampleBuffer:(CMSampleBufferRef)b fromConnection:(AVCaptureConnection *)c	{
	NSLog(@"%s",__func__);
}
- (void)captureOutput:(AVCaptureOutput *)o didOutputSampleBuffer:(CMSampleBufferRef)b fromConnection:(AVCaptureConnection *)c	{
	//NSLog(@"%s",__func__);
	/*
	CMFormatDescriptionRef		portFormatDesc = CMSampleBufferGetFormatDescription(b);
	NSLog(@"\t\t\tCMMediaType is %ld, video is %ld",CMFormatDescriptionGetMediaType(portFormatDesc),kCMMediaType_Video);
	NSLog(@"\t\t\tthe FourCharCode for the media subtype is %ld",CMFormatDescriptionGetMediaSubType(portFormatDesc));
	CMVideoDimensions		vidDims = CMVideoFormatDescriptionGetDimensions(portFormatDesc);
	NSLog(@"\t\t\tport size is %d x %d",vidDims.width,vidDims.height);
	*/
	
	OSSpinLockLock(&propLock);
	//	if this came from a connection belonging to the data output
	VVBuffer				*newBuffer = nil;
	//CMBlockBufferRef		blockBufferRef = CMSampleBufferGetDataBuffer(b)
	CVImageBufferRef		imgBufferRef = CMSampleBufferGetImageBuffer(b);
	if (imgBufferRef != NULL)	{
		//CGSize		imgBufferSize = CVImageBufferGetDisplaySize(imgBufferRef);
		//NSSizeLog(@"\t\timg buffer size is",imgBufferSize);
		CVOpenGLTextureRef		cvTexRef = NULL;
		CVReturn				err = kCVReturnSuccess;
		
		
		err = CVOpenGLTextureCacheCreateTextureFromImage(NULL,propTextureCache,imgBufferRef,NULL,&cvTexRef);
		if (err != kCVReturnSuccess)	{
			NSLog(@"\t\terr %d at CVOpenGLTextureCacheCreateTextureFromImage() in %s",err,__func__);
		}
		else	{
			newBuffer = [_globalVVBufferPool allocBufferForCVGLTex:cvTexRef];
			if (newBuffer != nil)	{
				VVRELEASE(propLastBuffer);
				propLastBuffer = [newBuffer retain];
				
				[newBuffer release];
				newBuffer = nil;
			}
			CVOpenGLTextureRelease(cvTexRef);
		}
	}
	CVOpenGLTextureCacheFlush(propTextureCache,0);
	OSSpinLockUnlock(&propLock);
	
}


@end

#import "HapInAVFAppDelegate.h"
#import "SampleVVBufferPoolAdditions.h"




@interface HapInAVFAppDelegate ()
- (void) _finishDecodingHapFrame:(HapDecoderFrame *)decodedFrame;
@end




@implementation HapInAVFAppDelegate

- (id) init	{
	self = [super init];
	if (self != nil)	{
		NSOpenGLPixelFormat		*pf = [GLScene defaultPixelFormat];
		sharedCtx = [[NSOpenGLContext alloc] initWithFormat:pf shareContext:nil];
		[VVBufferPool createGlobalVVBufferPoolWithSharedContext:sharedCtx];
		
		CVReturn		err = CVOpenGLTextureCacheCreate(kCFAllocatorDefault,
			NULL,
			[sharedCtx CGLContextObj],
			[pf CGLPixelFormatObj],
			NULL,
			&texCache);
		if (err!=kCVReturnSuccess)
			NSLog(@"\t\terr %d at CVOpenGLTextureCacheCreate()",err);
		
		player = [[AVPlayer alloc] init];
		[player setActionAtItemEnd:AVPlayerActionAtItemEndNone];
		playerItem = nil;
		videoPlayerItemIsHap = NO;
		nativeAVFOutput = nil;
		hapOutput = nil;
		
		swizzleScene = [[ISFGLScene alloc] initWithSharedContext:sharedCtx pixelFormat:pf];
		
		lastRenderedBuffer = nil;
	}
	return self;
}
- (void) dealloc	{
	
	[super dealloc];
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
		CVDisplayLinkSetOutputCallback(displayLink, displayLinkCallback, self);
		CVDisplayLinkStart(displayLink);
	}
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {
}


- (void) _finishDecodingHapFrame:(HapDecoderFrame *)decodedFrame	{
	//	this method is called from a dispatch queue owned by the AVPlayerItemHapDXTOutput- this is important, because of the operating's restrictions on running GL contexts: a GL context may be used only by one thread at a time.  since this method will potentially be called simultaneously from multiple threads, we need to synchronized access to the GL context that this method uses to upload texture data.  we're doing this with a simple @synchronized here, but a pool of contexts would also be effective.
	NSArray			*newBuffers = (decodedFrame==nil) ? nil : [decodedFrame userInfo];
	if (newBuffers != nil)	{
		@synchronized (self)	{
			for (VVBuffer *newBuffer in newBuffers)	{
				[VVBufferPool pushTexRangeBufferRAMtoVRAM:newBuffer usingContext:[sharedCtx CGLContextObj]];
			}
		}
	}
}


- (void) openDocument:(id)sender	{
	NSOpenPanel		*openPanel = [[NSOpenPanel openPanel] retain];
	NSUserDefaults	*def = [NSUserDefaults standardUserDefaults];
	NSString		*openPanelDir = [def objectForKey:@"openPanelDir"];
	if (openPanelDir==nil)
		openPanelDir = [@"~/" stringByExpandingTildeInPath];
	[openPanel setDirectoryURL:[NSURL fileURLWithPath:openPanelDir]];
	[openPanel
		beginSheetModalForWindow:window
		completionHandler:^(NSInteger result)	{
			NSString		*path = (result!=NSFileHandlingPanelOKButton) ? nil : [[openPanel URL] path];
			if (path != nil)	{
				NSUserDefaults		*udef = [NSUserDefaults standardUserDefaults];
				[udef setObject:[path stringByDeletingLastPathComponent] forKey:@"openPanelDir"];
				[udef synchronize];
			}
			//[self loadFileAtPath:path];
			dispatch_async(dispatch_get_main_queue(), ^{
				if (![self loadFileAtPath:path])
					NSLog(@"\t\terr: couldn't load file at path %@",path);
			});
			[openPanel release];
		}];
}


- (BOOL) loadFileAtPath:(NSString *)n	{
	NSURL			*newURL = (n==nil) ? nil : [NSURL fileURLWithPath:n];
	return [self loadFileAtURL:newURL];
}
- (BOOL) loadFileAtURL:(NSURL *)n	{
	if (n == nil)
		return NO;
	AVURLAsset			*newAsset = (n==nil) ? nil : [AVURLAsset
		URLAssetWithURL:n
		options:@{AVURLAssetPreferPreciseDurationAndTimingKey:@YES}];
	return [self loadAsset:newAsset];
}
- (BOOL) loadAsset:(AVAsset *)n	{
	NSLog(@"%s ... %@",__func__,n);
	@synchronized (self)	{
		NSArray			*videoTracks = [n tracksWithMediaType:AVMediaTypeVideo];
		BOOL			playableVideo = NO;
		BOOL			assetIsHap = NO;
		NSError			*nsErr = nil;
	
		for (AVAssetTrack *videoTrack in videoTracks)	{
			//	if the track's playable, flag it as such immediately
			if ([videoTrack isPlayable])
				playableVideo = YES;
			//	else the track's not natively playable...
			else	{
				//	check the track's format description- if it's a hap track, flag it as playable
				NSArray				*trackFmts = [videoTrack formatDescriptions];
				for (id fmtDescRef in trackFmts)	{
					switch (CMFormatDescriptionGetMediaSubType((CMFormatDescriptionRef)fmtDescRef))	{
						case 'Hap1':
						case 'Hap5':
							playableVideo = YES;
							assetIsHap = YES;
							break;
						case 'HapY':
							playableVideo = YES;
							assetIsHap = YES;
							[swizzleScene useFile:[[NSBundle mainBundle] pathForResource:@"SwizzleISF-ScaledCoCgYtoRGBA" ofType:@"fs"]];
							break;
						case 'HapM':
							playableVideo = YES;
							assetIsHap = YES;
							[swizzleScene useFile:[[NSBundle mainBundle] pathForResource:@"SwizzleISF-ScaledCoCgYplusAtoRGBA" ofType:@"fs"]];
							break;
						default:
							break;
					}
				}
			}
		
		}
	
	
		//	remove myself from observing "play to end" notifications
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
	
		//	if there's an AVF output, remove it from the item
		if (nativeAVFOutput != nil)	{
			if (playerItem != nil)	{
				[playerItem removeOutput:nativeAVFOutput];
			}
		}
		//	else there's no AVF output- should i create one?
		else	{
			if (!assetIsHap)	{
				NSDictionary				*pba = [NSDictionary dictionaryWithObjectsAndKeys:
					//NUMINT(kCVPixelFormatType_422YpCbCr8), kCVPixelBufferPixelFormatTypeKey,
					//NUMINT(kCVPixelFormatType_32BGRA), kCVPixelBufferPixelFormatTypeKey,
					//NUMINT(FOURCC_PACK('D','X','t','1')), kCVPixelBufferPixelFormatTypeKey,
					NUMBOOL(YES), kCVPixelBufferIOSurfaceOpenGLFBOCompatibilityKey,
					//NUMINT(dims.width), kCVPixelBufferWidthKey,
					//NUMINT(dims.height), kCVPixelBufferHeightKey,
					nil];
				nativeAVFOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:pba];
				[nativeAVFOutput setSuppressesPlayerRendering:YES];
			}
		}
	
	
		//	if there's a hap output, remove it from the item
		if (hapOutput != nil)	{
			if (playerItem != nil)	{
				[playerItem removeOutput:hapOutput];
			}
		}
		//	else there's no hap output- should i create one?
		else	{
			if (assetIsHap)	{
				hapOutput = [[AVPlayerItemHapDXTOutput alloc] init];
				[hapOutput setSuppressesPlayerRendering:YES];
			
				//	make the decoder frame alocator block: i want to create a frame that will decode into a texture range- RAM that is mapped directly to VRAM and uploads via DMA
				[hapOutput setAllocFrameBlock:^(CMSampleBufferRef decompressMe)	{
					HapDecoderFrame		*returnMe = nil;
					if (decompressMe!=NULL)	{
						//	make an empty decoder frame from the buffer (the basic fields describing the data properties of the DXT frame are populated, but no memory is allocated to decompress the DXT into)
						returnMe = [[HapDecoderFrame alloc] initEmptyWithHapSampleBuffer:decompressMe];
						//	make a CPU-backed/tex range VVBuffers for each plane in the decoder frame
						NSArray			*bufferArray = [_globalVVBufferPool createBuffersForHapDecoderFrame:returnMe];
						if (bufferArray != nil)	{
							//	populate the hap decoder frame i'll be returning with the CPU-based memory from the buffer, and ensure that the decoder will retain the buffers (this has to be done for each plane in the frame)
							void			**dxtDatas = [returnMe dxtDatas];
							size_t			*dxtDataSizes = [returnMe dxtDataSizes];
							NSInteger		tmpIndex = 0;
							for (VVBuffer *buffer in bufferArray)	{
								dxtDatas[tmpIndex] = [buffer cpuBackingPtr];
								dxtDataSizes[tmpIndex] = VVBufferDescriptorCalculateCPUBackingForSize([buffer descriptorPtr],[buffer backingSize]);
								++tmpIndex;
							}
							//	add the array of buffers to the frame's userInfo- we want the frame to retain the array of buffers...
							[returnMe setUserInfo:bufferArray];
						}
					}
					return returnMe;
				}];
				//	make the post decode block: after decoding, i want to upload the DXT data to a GL texture via DMA, on the decode thread
				ObjectHolder					*selfHolder = [[[ObjectHolder alloc] initWithZWRObject:self] autorelease];
				AVFHapDXTPostDecodeBlock		tmpBlock = ^(HapDecoderFrame *decodedFrame)	{
					//NSLog(@"%s ... %@",__func__,decodedFrame);
					HapInAVFAppDelegate					*bss = (HapInAVFAppDelegate *)[selfHolder object];
					if (bss != nil)
						[bss _finishDecodingHapFrame:decodedFrame];
				};
			
				[hapOutput setPostDecodeBlock:tmpBlock];
			}
		}
	
	
		//	kill the existing player item
		[player replaceCurrentItemWithPlayerItem:nil];
		VVRELEASE(playerItem);
	
		videoPlayerItemIsHap = assetIsHap;
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
	
		//	make a new player item, add the appropriate output
		playerItem = [[AVPlayerItem alloc] initWithAsset:n];
		if (assetIsHap && hapOutput!=nil)
			[playerItem addOutput:hapOutput];
		else if (!assetIsHap && nativeAVFOutput!=nil)
			[playerItem addOutput:nativeAVFOutput];
	
		//	load the player item
		[player replaceCurrentItemWithPlayerItem:playerItem];
	
		[player play];
		return YES;
	}
	return YES;
}
- (void) itemDidPlayToEnd:(NSNotification *)note	{
	if (playerItem == nil)
		return;
	AVAsset		*currentAsset = [playerItem asset];
	if (currentAsset == nil)
		return;
	dispatch_async(dispatch_get_main_queue(), ^{
		[self loadAsset:currentAsset];
	});
}


- (VVBuffer *)allocBuffer	{
	//NSLog(@"%s",__func__);
	VVBuffer		*returnMe = nil;
	//	if i'm playing back a hap item and the hap output exists...
	if (videoPlayerItemIsHap && hapOutput!=nil)	{
		//	figure out the time
		CMTime				frameTime = [hapOutput itemTimeForMachAbsoluteTime:mach_absolute_time()];
		//	get the frame nearest to the time from the output
		HapDecoderFrame		*hapFrame = [hapOutput allocFrameClosestToTime:frameTime];
		//	get the array of VVBuffers from the hap frame
		NSArray				*frameBuffers = (hapFrame==nil) ? nil : [hapFrame userInfo];
		if (hapFrame!=nil && frameBuffers!=nil)	{
			switch ([hapFrame codecSubType])	{
			case kHapCodecSubType:
			case kHapAlphaCodecSubType:
			case kHapAOnlyCodecSubType:
				//	no conversion necessary, we can return the texture created by directly uploading the data from the hap frame
				if ([frameBuffers count]>0)
					returnMe = [[frameBuffers objectAtIndex:0] retain];
				break;
			case kHapYCoCgCodecSubType:
				//	the buffer describes a YCoCg image, which we use an ISF scene to convert to RGBA
				if ([frameBuffers count]>0)	{
					VVBuffer		*tmpBuffer = [frameBuffers objectAtIndex:0];
					[swizzleScene setFilterInputImageBuffer:tmpBuffer];
					returnMe = [swizzleScene allocAndRenderToBufferSized:[tmpBuffer srcRect].size];
				}
				break;
			case kHapYCoCgACodecSubType:
				//	the buffer describes a YCoCg+A (HapQ+A) image, which we has an ISF scene to combine and convert to an RGBA texture
				if ([frameBuffers count]>1)	{
					VVBuffer		*tmpBuffer = nil;
					tmpBuffer = [frameBuffers objectAtIndex:0];
					if (tmpBuffer != nil)
						[swizzleScene setFilterInputImageBuffer:tmpBuffer];
					tmpBuffer = [frameBuffers objectAtIndex:1];
					if (tmpBuffer != nil)
						[swizzleScene setBuffer:tmpBuffer forInputImageKey:@"alphaImage"];
					returnMe = [swizzleScene allocAndRenderToBufferSized:[tmpBuffer srcRect].size];
				}
				break;
			}
			[hapFrame release];
			hapFrame = nil;
		}
	}
	//	else the video player's working with a native AVF file
	else if (!videoPlayerItemIsHap && nativeAVFOutput!=nil && texCache!=NULL)	{
		//	figure out the time
		CMTime				frameTime = [nativeAVFOutput itemTimeForMachAbsoluteTime:mach_absolute_time()];
		if ([nativeAVFOutput hasNewPixelBufferForItemTime:frameTime])	{
			CMTime				frameDisplayTime = kCMTimeNegativeInfinity;
			CVPixelBufferRef	pb = [nativeAVFOutput copyPixelBufferForItemTime:frameTime itemTimeForDisplay:&frameDisplayTime];
			if (pb != NULL)	{
				//NSLog(@"\t\tgot a pixel buffer...");
				CVOpenGLTextureRef		newTex = NULL;
				CVReturn				err = CVOpenGLTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
					texCache,
					pb,
					NULL,
					&newTex);
				if (err == kCVReturnSuccess)	{
					//NSLog(@"\t\tturned the pixel buffer into a GL texture!");
					returnMe = [_globalVVBufferPool allocBufferForCVGLTex:newTex];
					
					//CVOpenGLTextureRelease(newTex);
					CFRelease(newTex);
				}
				else	{
					NSLog(@"\t\terr %d at CVOpenGLTextureCacheCreateTextureFromImage()",err);
				}
				
				//CVPixelBufferRelease(pb);
				CFRelease(pb);
				pb = NULL;
			}
			//else
			//	NSLog(@"\t\tERR: unable to copy pixel buffer from nativeAVFOutput");
		}
	}
	
	return returnMe;
}
- (void) renderCallback	{
	@synchronized (self)	{
		VVBuffer		*newBuffer = [self allocBuffer];
		if (newBuffer != nil)	{
			VVRELEASE(lastRenderedBuffer);
			lastRenderedBuffer = [newBuffer retain];
			[view drawBuffer:newBuffer];
		
			[newBuffer release];
			newBuffer = nil;
		}
	}
	
	CVOpenGLTextureCacheFlush(texCache,0);
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
	NSAutoreleasePool		*pool =[[NSAutoreleasePool alloc] init];
	[(HapInAVFAppDelegate *)displayLinkContext renderCallback];
	[pool release];
	return kCVReturnSuccess;
}

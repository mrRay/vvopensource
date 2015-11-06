#import "SyphonToAndFromVVBufferAppDelegate.h"
#import <OpenGL/CGLMacro.h>
#import "VVBufferPoolSyphonAdditions.h"



@implementation SyphonToAndFromVVBufferAppDelegate


- (id) init	{
	if (self = [super init])	{
		syphonServer = nil;
		syphonClient = nil;
		
		//	make a shared GL context.  other GL contexts created to share this one may share resources (textures, buffers, etc).
		sharedContext = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:nil];
		syphonServerContext = [[NSOpenGLContext alloc] initWithFormat:[GLScene defaultPixelFormat] shareContext:sharedContext];
		//	create the global buffer pool from the shared context
		[VVBufferPool createGlobalVVBufferPoolWithSharedContext:sharedContext];
		//	...other stuff in the VVBufferPool framework- like the views, the buffer copier, etc- will 
		//	automatically use the global buffer pool's shared context to set themselves up to function with the pool.
		
		//	set up the QC backend to use the shared context to render
		[QCGLScene prepCommonQCBackendToRenderOnContext:sharedContext pixelFormat:[GLScene defaultPixelFormat]];
		qcScene = [[QCGLScene alloc] initCommonBackendSceneSized:NSMakeSize(1024,768)];
		//	load the included QC composition, which was created by apple and is included in the app bundle
		NSString		*compPath = [[NSBundle mainBundle] pathForResource:@"Blue" ofType:@"qtz"];
		[qcScene useFile:compPath];
		return self;
	}
	[self release];
	return nil;
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification	{
	//	create the syphon server
	syphonServer = [[SyphonServer alloc]
		initWithName:@"SUPER AWESOME SPECIAL SYPHON SERVER"
		context:[syphonServerContext CGLContextObj]
		options:nil];
	//	populate the syphon server name field
	[syphonServerNameField setStringValue:[syphonServer name]];
	
	
	//	populate the pop-up button with a list of syphon clients
	[self populateSyphonClientPUB];
	//	select the first syphon client in the pop-up button
	if ([syphonClientPUB numberOfItems]>0)	{
		[syphonClientPUB selectItemAtIndex:0];
		[self syphonClientPUBUsed:syphonClientPUB];
	}
	//	register to receive notifications that the list of syphon clients has changed
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSyphonServerNotification:) name:SyphonServerAnnounceNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSyphonServerNotification:) name:SyphonServerUpdateNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadSyphonServerNotification:) name:SyphonServerRetireNotification object:nil];
	
	
	
	
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


- (void) populateSyphonClientPUB	{
	//	clear out the menu
	NSMenu			*pubMenu = [syphonClientPUB menu];
	[pubMenu setAutoenablesItems:NO];
	[pubMenu removeAllItems];
	
	//	get an array of dicts, each of which describes a syphon server- run through the array
	NSArray			*servers = [[SyphonServerDirectory sharedDirectory] servers];
	for (NSDictionary *serverDict in servers)	{
		//NSLog(@"\t\tserverDict is %@",serverDict);
		NSString		*serverAppName = [serverDict objectForKey:SyphonServerDescriptionAppNameKey];
		NSString		*serverName = [serverDict objectForKey:SyphonServerDescriptionNameKey];
		NSString		*serverUUID = [serverDict objectForKey:SyphonServerDescriptionUUIDKey];
		if (serverAppName!=nil && serverName!=nil && serverUUID!=nil && ![serverAppName isEqualToString:@"SyphonTestApp"])	{
			//	make a menu item for this server dict, add it to the menu
			NSMenuItem		*newItem = [[NSMenuItem alloc] initWithTitle:VVFMTSTRING(@"%@-%@",serverAppName,serverName) action:nil keyEquivalent:@""];
			//	the syphon server UUID is the menu item's representedObject.  this is how a menu item knows which syphon server it specifies in the UI action!
			[newItem setRepresentedObject:serverDict];
			[pubMenu addItem:[newItem autorelease]];
		}
	}
}
- (void) reloadSyphonServerNotification:(NSNotification *)note	{
	//	make sure that i only call this method on the main thread
	if (![NSThread isMainThread])	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self reloadSyphonServerNotification:note];
		});
		return;
	}
	//	before i reload anything, figure out what the currently selected item name is- we need to figure out if it disappears or not!
	NSMenuItem		*origSelectedItem = [syphonClientPUB selectedItem];
	NSString		*origSelectedItemName = (origSelectedItem==nil) ? nil : [origSelectedItem title];
	BOOL			origItemDisappeared = NO;
	//	repopulate the pop-up button
	[self populateSyphonClientPUB];
	//	figure out if the originally-selected item has disappeared or not
	if (origSelectedItemName!=nil && [syphonClientPUB itemWithTitle:origSelectedItemName]==nil)
		origItemDisappeared = YES;
	
	//	if the originally-selectd item hasn't disappeared, just update the pop-up button to display it
	if (!origItemDisappeared)
		[syphonClientPUB selectItemWithTitle:origSelectedItemName];
	//	else the originally-selected item has disappeared- select an item if possible...
	else	{
		if ([syphonClientPUB numberOfItems]>0)	{
			[syphonClientPUB selectItemAtIndex:0];
			[self syphonClientPUBUsed:syphonClientPUB];
		}
	}
}
- (IBAction) syphonClientPUBUsed:(id)sender	{
	NSLog(@"%s",__func__);
	@synchronized (self)	{
		//	figure out what the UUID of the currently-selected syphon client is (if there is one)
		NSString		*currentUUIDString = nil;
		if (syphonClient!=nil && [syphonClient isValid])
			currentUUIDString = [[syphonClient serverDescription] objectForKey:SyphonServerDescriptionUUIDKey];
		//	figure out what the UUID is of the syphon server that we want to start receiving from
		NSMenuItem		*selectedItem = [syphonClientPUB selectedItem];
		NSDictionary	*newServerDict = (selectedItem==nil) ? nil : [selectedItem representedObject];
		NSString		*newUUIDString = (newServerDict==nil) ? nil : [newServerDict objectForKey:SyphonServerDescriptionUUIDKey];
		
		//	no matter what, i can only proceed if i know what i'm supposed to be selecting, so let's take care of that, logically speaking
		if (newUUIDString==nil)
			return;
		
		//	if the UUID has changed, release the syphon client
		if (currentUUIDString==nil || ![currentUUIDString isEqualToString:newUUIDString])	{
			if (syphonClient != nil)	{
				[syphonClient release];
				syphonClient = nil;
			}
		}
		
		//	if the client's nil, make a client
		if (syphonClient==nil)	{
			syphonClient = [[SyphonClient alloc]
				initWithServerDescription:newServerDict
				options:nil
				newFrameHandler:^(SyphonClient *theClient)	{
					//	when there's a new frame, get a VVBuffer for the SyphonClient, pass it to self (self retains it)- we'll retrieve and draw it in the display callback
					VVBuffer	*newBuffer = [[VVBufferPool globalVVBufferPool] allocBufferForSyphonClient:theClient];
					if (newBuffer!=nil)	{
						[self setSyphonClientBuffer:newBuffer];
						[newBuffer release];
						newBuffer = nil;
					}
				}];
			if (syphonClient==nil)
				NSLog(@"\t\terr: %s couldn't create syphonClient with server description %@",__func__,newServerDict);
		}
	}
}


//	this method is called from the displaylink callback
- (void) renderCallback	{
	//	we're going to deal with the syphon server first: render the QC comp to a texture, and publish it via syphon.
	VVBuffer		*newTex = [qcScene allocAndRenderABuffer];
	if (syphonServer!=nil && newTex!=nil)	{
		[syphonServer
			publishFrameTexture:[newTex name]
			textureTarget:[newTex target]
			imageRegion:[newTex srcRect]
			textureDimensions:[newTex size]
			flipped:[newTex flipped]];
	}
	//	draw the GL texture i just published via syphon in the server view
	[serverView drawBuffer:newTex];
	//	don't forget to release the buffer we allocated!
	VVRELEASE(newTex);
	
	
	
	
	//	my 'syphonClientBuffer' is populated in the new frame handler of the SyphonClient- we'll just draw whatever's there!
	VVBuffer		*clientBuffer = [self syphonClientBuffer];
	[clientView drawBuffer:clientBuffer];
	
	
	
	//	tell the buffer pool to do its housekeeping (releases any "old" resources in the pool that have been sticking around for a while)
	[_globalVVBufferPool housekeeping];
}


@synthesize syphonClientBuffer;


@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, 
	const CVTimeStamp *inNow, 
	const CVTimeStamp *inOutputTime, 
	CVOptionFlags flagsIn, 
	CVOptionFlags *flagsOut, 
	void *displayLinkContext)
{
	NSAutoreleasePool		*pool =[[NSAutoreleasePool alloc] init];
	[(SyphonToAndFromVVBufferAppDelegate *)displayLinkContext renderCallback];
	[pool release];
	return kCVReturnSuccess;
}

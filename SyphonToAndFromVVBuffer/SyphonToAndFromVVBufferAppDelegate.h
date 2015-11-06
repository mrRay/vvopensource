#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>
#import <Syphon/Syphon.h>




/*	this app demonstrates how to create a VVBuffer from a SyphonClient, and also how to publish a VVBuffer via Syphon		*/

@interface SyphonToAndFromVVBufferAppDelegate : NSObject <NSApplicationDelegate>	{
	CVDisplayLinkRef			displayLink;
	NSOpenGLContext				*sharedContext;
	
	QCGLScene					*qcScene;	//	this QC scene renders content that we will publish via syphon
	
	SyphonServer				*syphonServer;
	NSOpenGLContext				*syphonServerContext;	//	belongs to the syphon server
	SyphonClient				*syphonClient;
	NSOpenGLContext				*syphonClientContext;
	VVBuffer					*syphonClientBuffer;
	
	IBOutlet NSTextField		*syphonServerNameField;
	IBOutlet NSPopUpButton		*syphonClientPUB;
	
	IBOutlet VVBufferGLView		*serverView;	//	displays the video stream being published as a syphon server by this app
	IBOutlet VVBufferGLView		*clientView;	//	displays the video stream being received from the syphon server
}

- (void) populateSyphonClientPUB;
- (void) reloadSyphonServerNotification:(NSNotification *)note;

- (IBAction) syphonClientPUBUsed:(id)sender;

- (void) renderCallback;

@property (retain,readwrite) VVBuffer *syphonClientBuffer;

@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);

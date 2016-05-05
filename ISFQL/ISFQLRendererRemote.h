#import <Foundation/Foundation.h>
#import "ISFQL_RendererProtocols.h"




/*	this is the object that you put in your app- it communicates with ISFQLRendererAgent, which is 
	a cocoa app running as a LaunchAgent.  comm is handled via XPC via a mach service
*/




@interface ISFQLRendererRemote : NSObject <ISFQLService>	{
	BOOL				deleted;
	
	OSSpinLock			connLock;
	NSXPCConnection		*conn;
	
	NSData				*thumbnailData;
	NSSize				thumbnailSize;
}

- (void) prepareToBeDeleted;

//	this method is asynchronous- call this, then call "allocCGImage/alloNSImage...", which will return 
//	as soon as the remote process has rendered and passed back a frame.
- (void) renderThumbnailForPath:(NSString *)n sized:(NSSize)s;

@property (retain,readwrite) NSData *thumbnailData;
@property (assign,readwrite) NSSize thumbnailSize;

//	stalls until it returns a frame or times out.  the agent has a timeout, the app that owns the 
//	agent has another timeout, and this method has a third timeout in these methods- it should 
//	always return within a couple seconds, no matter what.
- (CGImageRef) allocCGImageFromThumbnailData;
- (NSImage *) allocNSImageFromThumbnailData;

@end

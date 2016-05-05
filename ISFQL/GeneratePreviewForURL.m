#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Foundation/Foundation.h>
#import "../ISFQL_Renderer/ISFQL_RendererProtocols.h"
#import "ISFQLRendererRemote.h"


OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options);
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview);

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
	NSString				*pathToFile = [(NSURL *)url path];
	//NSLog(@"%s ...%@",__func__,pathToFile);
	
	ISFQLRendererRemote		*renderer = [[ISFQLRendererRemote alloc] init];
	[renderer renderThumbnailForPath:pathToFile sized:NSMakeSize(640,480)];
	CGImageRef				tmpImg = [renderer allocCGImageFromThumbnailData];
	BOOL					problemRendering = NO;
	CGSize					size = CGSizeMake(CGImageGetWidth(tmpImg), CGImageGetHeight(tmpImg));
	if (size.width<=0 || size.height<=0)	{
		NSLog(@"\t\terr: problem rendering file %@",pathToFile);
		problemRendering = YES;
	}
	else	{
		CGContextRef			ctx = QLPreviewRequestCreateContext(preview, size, YES, nil);
		if (ctx != NULL)	{
			CGContextDrawImage(ctx, CGRectMake(0, 0, size.width, size.height), tmpImg);
			QLPreviewRequestFlushContext(preview, ctx);
			CGContextRelease(ctx);
			ctx = NULL;
		}
	}
	
	CGImageRelease(tmpImg);
	tmpImg = NULL;
	
	[renderer prepareToBeDeleted];
	[renderer release];
	renderer = nil;
	
	if (problemRendering)
		return -3025;
	else
		return noErr;
}
void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)	{

}

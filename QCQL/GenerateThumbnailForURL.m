#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#import <Foundation/Foundation.h>
#import "../QCQL_Renderer/QCQL_RendererProtocols.h"
#import "QCQLRendererRemote.h"


OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize);
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail);

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
	NSString				*pathToFile = [(NSURL *)url path];
	//NSLog(@"%s ...%@",__func__,pathToFile);
	
	QCQLRendererRemote		*renderer = [[QCQLRendererRemote alloc] init];
	[renderer renderThumbnailForPath:pathToFile sized:NSMakeSize(maxSize.width, maxSize.height)];
	CGImageRef				tmpImg = [renderer allocCGImageFromThumbnailData];
	BOOL					problemRendering = NO;
	CGSize					size = CGSizeMake(CGImageGetWidth(tmpImg), CGImageGetHeight(tmpImg));
	if (size.width<=0 || size.height<=0)	{
		NSLog(@"\t\terr: problem rendering file %@",pathToFile);
		problemRendering = YES;
	}
	else	{
		CGContextRef			ctx = QLThumbnailRequestCreateContext(thumbnail, size, true, nil);
		if (ctx != NULL)	{
			CGContextDrawImage(ctx, CGRectMake(0, 0, size.width, size.height), tmpImg);
			QLThumbnailRequestFlushContext(thumbnail, ctx);
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
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail)	{

}

//
//  VVCURLDL.m
//  VVOpenSource
//
//  Created by bagheera on 9/17/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "VVCURLDL.h"




@implementation VVCURLDL


+ (id) createWithAddress:(NSString *)a	{
	VVCURLDL		*returnMe = [[VVCURLDL alloc] initWithAddress:a];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithAddress:(NSString *)a	{
	if (a==nil)
		goto BAIL;
	if (self = [super init])	{
		urlString = [a retain];
		curlHandle = nil;
		postData = nil;
		responseData = nil;
		returnOnMain = NO;
		return self;
	}
	BAIL:
	[self release];
	return nil;
}
- (void) dealloc	{
	if (urlString != nil)	{
		[urlString release];
		urlString = nil;
	}
	if (postData != nil)	{
		[postData release];
		postData = nil;
	}
	if (responseData != nil)	{
		[responseData release];
		responseData = nil;
	}
	[super dealloc];
}

- (void) perform	{
	[self performAsync:NO withDelegate:nil];
}
- (void) performAsync:(BOOL)as withDelegate:(id <VVCURLDLDelegate>)d	{
	//	if i'm performing asynchronously, spawn a thread (make an autorelease pool!) and go
	if (as)
		[NSThread detachNewThreadSelector:@selector(_performAsyncWithDelegate:) toTarget:self withObject:d];
	//	else just go
	else
		[self _performWithDelegate:d];
}
//	DO NOT CALL THIS METHOD DIRECTLY
- (void) _performAsyncWithDelegate:(id <VVCURLDLDelegate>)d	{
	//	make a pool
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	//	perform the download
	[self _performWithDelegate:d];
	//	release the pool
	[pool release];
}
//	DO NOT CALL THIS METHOD DIRECTLY
- (void) _performWithDelegate:(id <VVCURLDLDelegate>)d	{
	CURLcode			err;
	
	curlHandle = curl_easy_init();
	if (curlHandle)	{
		//	set the URL
		curl_easy_setopt(curlHandle,CURLOPT_URL,[urlString UTF8String]);
		//	if there's post data, set that up
		if (postData != nil)	{
			curl_easy_setopt(curlHandle,CURLOPT_POSTFIELDS,[postData bytes]);
		}
		//	set up a write function so libcurl can send me data it receives
		curl_easy_setopt(curlHandle,CURLOPT_WRITEFUNCTION,vvcurlWriteFunction);
		//	i'm going to pass a pointer to myself as the file stream, so i can get back into objective-c
		curl_easy_setopt(curlHandle,CURLOPT_WRITEDATA,self);
		//	perform the transfer
		err = curl_easy_perform(curlHandle);
		if (err)	{
			NSLog(@"\terr %ld at curl_easy_perform",err);
			
		}
		else	{
			/*
			if (responseData != nil)	{
				NSString	*tmpString = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
				NSLog(@"%@",tmpString);
			}
			*/
		}
		//	clean up after the transfer
		curl_easy_cleanup(curlHandle);
		curlHandle = nil;
	}
	else
		NSLog(@"\terror at curl_easy_init() in %s",__func__);
	
	//	if there's a delegate, tell the delegate that shit's done
	if ((d!=nil)&&([(id)d conformsToProtocol:@protocol(VVCURLDLDelegate)]))	{
		if (returnOnMain)
			[(id)d performSelectorOnMainThread:@selector(dlFinished:) withObject:self waitUntilDone:YES];
		[(id)d dlFinished:self];
	}
}

- (void) appendDataToPost:(NSData *)d	{
	if (d == nil)
		return;
	if (postData == nil)
		postData = [[NSMutableData dataWithCapacity:0] retain];
	[postData appendData:d];
}
- (void) appendStringToPost:(NSString *)s	{
	if (s == nil)
		return;
	[self appendDataToPost:[s dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void) writePtr:(void *)ptr size:(size_t)s	{
	//NSLog(@"%s",__func__);
	if (responseData == nil)
		responseData = [[NSMutableData dataWithCapacity:0] retain];
	[responseData appendBytes:ptr length:s];
}

@synthesize returnOnMain;


@end


size_t vvcurlWriteFunction(void *ptr, size_t size, size_t nmemb, void *stream)	{
	if (stream != nil)
		[(VVCURLDL *)stream writePtr:ptr size:size*nmemb];
	return size*nmemb;
}
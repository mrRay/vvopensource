//
//  VVCURLDL.h
//  VVOpenSource
//
//  Created by bagheera on 9/17/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <curl/curl.h>




@protocol VVCURLDLDelegate
- (void) dlFinished:(id)h;
@end




@interface VVCURLDL : NSObject {
	NSString			*urlString;
	CURL				*curlHandle;
	NSMutableData		*postData;
	NSMutableData		*responseData;
	
	BOOL				returnOnMain;
}

+ (id) createWithAddress:(NSString *)a;
- (id) initWithAddress:(NSString *)a;

- (void) perform;
- (void) performAsync:(BOOL)as withDelegate:(id <VVCURLDLDelegate>)d;
- (void) _performAsyncWithDelegate:(id <VVCURLDLDelegate>)d;
- (void) _performWithDelegate:(id <VVCURLDLDelegate>)d;

- (void) appendDataToPost:(NSData *)d;
- (void) appendStringToPost:(NSString *)s;

- (void) writePtr:(void *)ptr size:(size_t)s;

@property (assign,readonly) BOOL returnOnMain;

@end

size_t vvcurlWriteFunction(void *ptr, size_t size, size_t nmemb, void *stream);

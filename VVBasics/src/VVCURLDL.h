
/*
	this class offers a very limited, very simple cocoa interface to libcurl for doing extremely 
	basic http transfer ops
	
	basically, this class exists because at this time NSURLConnection is problematic and 
	top-heavy, and i wanted an easy, effective, and reliable interface for handling the extremely 
	limited set of http data transfer operations required by my frameworks/apps.
	
	this class was meant to be used as a one-shot throwaway; that is, you're meant to create an 
	instance of this class which will be auto-released as soon as the autorelease pool is 
	popped.  the instance you create is meant to be used once, and then thrown away- THIS WILL 
	PROBABLY BREAK IF YOU TRY TO USE THE SAME INSTANCE TO PERFORM MORE THAN ONE TRANSFER.
*/


#import <Cocoa/Cocoa.h>
#import <curl/curl.h>




@protocol VVCURLDLDelegate
- (void) dlFinished:(id)h;
@end




@interface VVCURLDL : NSObject {
	NSString				*urlString;
	CURL					*curlHandle;
	
	NSMutableData			*responseData;
	
	struct curl_slist		*headerList;	//	nil by default- if non-nil, supplied to the handle as CURLOPT_HTTPHEADER
	NSMutableData			*postData;		//	if non-nil, simply posted as CURLOPT_POSTFIELDS
	struct curl_httppost	*firstFormPtr;	//	if postData was nil but this isn't, posted as CURLOPT_HTTPPOST
	struct curl_httppost	*lastFormPtr;
	
	BOOL					returnOnMain;
	BOOL					performing;
	CURLcode				err;
}

+ (id) createWithAddress:(NSString *)a;
- (id) initWithAddress:(NSString *)a;

- (void) perform;
- (void) performAsync:(BOOL)as withDelegate:(id <VVCURLDLDelegate>)d;
- (void) _performAsyncWithDelegate:(id <VVCURLDLDelegate>)d;
- (void) _performWithDelegate:(id <VVCURLDLDelegate>)d;

//- (struct curl_slist *) headerList;
//- (struct curl_httppost *) firstFormPtr;
//- (struct curl_httppost *) lastFormPtr;
- (void) appendDataToPOST:(NSData *)d;
- (void) appendStringToPOST:(NSString *)s;

- (void) writePtr:(void *)ptr size:(size_t)s;

@property (assign,readwrite) struct curl_slist *headerList;
@property (assign,readwrite) struct curl_httppost *firstFormPtr;
@property (assign,readwrite) struct curl_httppost *lastFormPtr;
@property (assign,readwrite) BOOL returnOnMain;
@property (readonly) NSMutableData *responseData;
@property (readonly) NSString *responseString;
@property (readonly) CURLcode err;

@end

size_t vvcurlWriteFunction(void *ptr, size_t size, size_t nmemb, void *stream);

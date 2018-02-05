#import <Foundation/Foundation.h>


/*	this class offers a very limited, very simple cocoa interface to libcurl for doing extremely 
	basic http transfer ops
	
	basically, this class exists because at this time NSURLConnection is problematic and 
	top-heavy, and i wanted an easy, effective, and reliable interface for handling the extremely 
	limited set of http data transfer operations required by my frameworks/apps.
	
	this class was meant to be used as a one-shot throwaway; that is, you're meant to create an 
	instance of this class which will be auto-released as soon as the autorelease pool is 
	popped.  the instance you create is meant to be used once, and then thrown away- THIS WILL 
	PROBABLY BREAK IF YOU TRY TO USE THE SAME INSTANCE TO PERFORM MORE THAN ONE TRANSFER.
*/


@protocol VVCURLDLDelegate
- (void) dlFinished:(id)h;
@end




@interface VVCURLDL : NSObject {
	NSString				*urlString;
	
	long					dnsCacheTimeout;
	long					connectTimeout;
	NSString				*log;
	NSString				*pass;
	NSString				*userAgent;	//	passed to libcurl as CURLOPT_USERAGENT
	NSString				*referer;	//	passed to libcurl as CURLOPT_REFERER
	NSString				*acceptedEncoding;	//	passed to libcurl as CURLOPT_ACCEPT_ENCODING
	
	long					httpResponseCode;
	NSMutableData			*responseData;
	
	void					*curlHandle;	//	really a CURL*, but declared here as a void* so when you import this header you don't wind up importing curl.h and adding it as a dependency
	struct curl_slist		*headerList;	//	nil by default- if non-nil, supplied to the handle as CURLOPT_HTTPHEADER
	NSMutableData			*postData;		//	if non-nil, simply posted as CURLOPT_POSTFIELDS
	struct curl_httppost	*firstFormPtr;	//	if postData was nil but this isn't, posted as CURLOPT_HTTPPOST
	struct curl_httppost	*lastFormPtr;
	
	BOOL					returnOnMain;
	BOOL					performing;
	long					err;
}

+ (id) createWithAddress:(NSString *)a;
- (id) initWithAddress:(NSString *)a;

- (void) perform;
- (void) performAsync:(BOOL)as withDelegate:(id <VVCURLDLDelegate>)d;
- (void) performAsync:(BOOL)as withBlock:(void (^)(VVCURLDL *completedDL))b;
- (void) performOnQueue:(dispatch_queue_t)q block:(void (^)(VVCURLDL *completedDL))b;

- (void) appendDataToPOST:(NSData *)d;
- (void) appendStringToPOST:(NSString *)s;
@property (readonly) NSString *urlString;
@property (assign,readwrite,setter=setDNSCacheTimeout:) long dnsCacheTimeout;
@property (assign,readwrite) long connectTimeout;
- (void) setLogin:(NSString *)user password:(NSString *)pass;
@property (retain,readwrite) NSString *userAgent;
@property (retain,readwrite) NSString *referer;
@property (retain,readwrite) NSString *acceptedEncoding;

- (void) writePtr:(void *)ptr size:(size_t)s;
- (void) appendStringToHeader:(NSString *)s;
- (void) addFormNSString:(NSString *)s forName:(NSString *)n;
- (void) addFormZipData:(NSData *)d forName:(NSString *)n;

@property (assign,readwrite) BOOL returnOnMain;
@property (readonly) long httpResponseCode;
@property (readonly) NSMutableData *responseData;
@property (readonly) NSString *responseString;
@property (readonly) long err;	//	really a CURLcode

@end

size_t CURLDLWriteFunction(void *ptr, size_t size, size_t nmemb, void *stream);

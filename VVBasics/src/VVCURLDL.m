#import "VVCURLDL.h"
#import "VVBasicMacros.h"




@implementation VVCURLDL


+ (id) createWithAddress:(NSString *)a	{
	VVCURLDL		*returnMe = [[VVCURLDL alloc] initWithAddress:a];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithAddress:(NSString *)a	{
	//NSLog(@"%s",__func__);
	if (a==nil)
		goto BAIL;
	if (self = [super init])	{
		urlString = [a retain];
		curlHandle = nil;
		dnsCacheTimeout = 0;
		connectTimeout = 0;
		log = nil;
		pass = nil;
		userAgent = nil;
		referer = nil;
		acceptedEncoding = nil;
		postData = nil;
		//headerArray = nil;
		httpResponseCode = 0;
		responseData = nil;
		headerList = nil;
		firstFormPtr = nil;
		lastFormPtr = nil;
		returnOnMain = NO;
		performing = NO;
		err = 0;
		return self;
	}
	BAIL:
	NSLog(@"\t\terr: %s - BAIL",__func__);
	[self release];
	return nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	VVRELEASE(urlString);
	VVRELEASE(log);
	VVRELEASE(pass);
	VVRELEASE(userAgent);
	VVRELEASE(referer);
	VVRELEASE(acceptedEncoding);
	VVRELEASE(postData);
	//VVRELEASE(headerArray);
	VVRELEASE(responseData);
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
//	NEVER CALL THIS METHOD DIRECTLY!
- (void) _performAsyncWithDelegate:(id <VVCURLDLDelegate>)d	{
	//	make a pool
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	//	perform the download
	[self _performWithDelegate:d];
	//	release the pool
	[pool release];
}
//	NEVER CALL THIS METHOD DIRECTLY!
- (void) _performWithDelegate:(id <VVCURLDLDelegate>)d	{
	[self _execute];
	
	//	if there's a delegate, tell the delegate that shit's done
	if ((d!=nil)&&([(id)d conformsToProtocol:@protocol(VVCURLDLDelegate)]))	{
		if (returnOnMain)
			[(id)d performSelectorOnMainThread:@selector(dlFinished:) withObject:self waitUntilDone:YES];
		else
			[(id)d dlFinished:self];
	}
	
}


- (void) performAsync:(BOOL)as withBlock:(void (^)(VVCURLDL *completedDL))b	{
	//	if i'm performing asynchronously, spawn a thread (make an autorelease pool!) and go
	if (as)
		[NSThread detachNewThreadSelector:@selector(_performAsyncWithBlock:) toTarget:self withObject:b];
	//	else just go
	else
		[self _performWithBlock:b];
}
- (void) _performAsyncWithBlock:(void (^)(VVCURLDL *completedDL))b	{
	//	make a pool
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	//	perform the download
	[self _performWithBlock:b];
	//	release the pool
	[pool release];
}
- (void) _performWithBlock:(void (^)(VVCURLDL *completedDL))b	{
	[self _execute];
	
	if (b != nil)	{
		__block VVCURLDL	*blockSafeSelf = self;
		if (returnOnMain)	{
			dispatch_async(dispatch_get_main_queue(), ^{
				b(blockSafeSelf);
			});
		}
		else	{
			b(blockSafeSelf);
		}
	}
}


- (void) _execute	{
	performing = YES;
	curlHandle = curl_easy_init();
	if (curlHandle)	{
		char			errBuffer[CURL_ERROR_SIZE];
		//	set up the error buffer
		curl_easy_setopt(curlHandle,CURLOPT_ERRORBUFFER,errBuffer);
		//	turn on verbose information
		//curl_easy_setopt(curlHandle,CURLOPT_VERBOSE,1);
		//	set the URL
		curl_easy_setopt(curlHandle,CURLOPT_URL,[urlString UTF8String]);
		//	if there's an slist of headers, use it
		if (headerList != nil)	{
			//NSLog(@"\tsetting headers");
			curl_easy_setopt(curlHandle,CURLOPT_HTTPHEADER,headerList);
		}
		/*
		struct curl_slist		*headers = nil;
		if ((headerArray!=nil)&&([headerArray count]>0))	{
			for (NSString *tmpHeader in headerArray)
				headers = curl_slist_append(headers,[tmpHeader UTF8String]);
			curl_easy_setopt(curlHandle,CURLOPT_HTTPHEADER,headers);
		}
		*/
		
		//curl_easy_setopt(curlHandle, CURLOPT_VERBOSE, 1L);
		
		NSString		*tmpString = [self acceptedEncoding];
		if (tmpString!=nil)
			curl_easy_setopt(curlHandle, CURLOPT_ACCEPT_ENCODING, [tmpString UTF8String]);
		
		//	if there's a log/pass, set them up
		if (log!=nil && pass!=nil)	{
			NSString		*tmpString = [NSString stringWithFormat:@"%@:%@",log,pass];
			curl_easy_setopt(curlHandle,CURLOPT_USERPWD,[tmpString UTF8String]);
		}
		
		//	if there's a user agent, set it up
		if (userAgent != nil)	{
			curl_easy_setopt(curlHandle, CURLOPT_USERAGENT, [userAgent UTF8String]);
		}
		
		//	if there's a referer, set it up
		if (referer != nil)	{
			curl_easy_setopt(curlHandle, CURLOPT_REFERER, [referer UTF8String]);
		}
		
		//	if there's post data, set up the handle to use it
		if (postData != nil)	{
			//NSLog(@"\tsetting POST data");
			curl_easy_setopt(curlHandle, CURLOPT_POST, 1);
			curl_easy_setopt(curlHandle, CURLOPT_POSTFIELDSIZE, [postData length]);
			curl_easy_setopt(curlHandle,CURLOPT_POSTFIELDS,[postData bytes]);
		}
		else	{
			//NSLog(@"\tno POST data to send- checking for form data");
			//	if there's no post data- but there's a ptr to a multipart/formdata HTTP POST...
			if (firstFormPtr != nil)	{
				//NSLog(@"\tsending form data");
				curl_easy_setopt(curlHandle,CURLOPT_HTTPPOST,firstFormPtr);
			}
			else	{
				curl_easy_setopt(curlHandle,CURLOPT_HTTPGET,1L);
			}
		}
		
		//	set up a write function so libcurl can send me data it receives
		curl_easy_setopt(curlHandle,CURLOPT_WRITEFUNCTION,vvcurlWriteFunction);
		//	i'm going to pass a pointer to myself as the file stream, so i can get back into objective-c
		curl_easy_setopt(curlHandle,CURLOPT_WRITEDATA,self);
		
		if (dnsCacheTimeout>0)
			curl_easy_setopt(curlHandle, CURLOPT_DNS_CACHE_TIMEOUT, dnsCacheTimeout);
		if (connectTimeout>0)
			curl_easy_setopt(curlHandle, CURLOPT_CONNECTTIMEOUT, connectTimeout);
		
		//	perform the transfer
		err = curl_easy_perform(curlHandle);
		
		
		
		//	get the http response code
		curl_easy_getinfo(curlHandle, CURLINFO_RESPONSE_CODE, &httpResponseCode);
		
		if (err)	{
			NSLog(@"\terr %u at curl_easy_perform for %@",err,urlString);
			//NSLog(@"\t\terrBuffer is %s",errBuffer);
			
			//	returns error code 6 when the machine isn't connected to a network
			//	returns error code 6 is the network doesn't have internet access
			//	returns error code 7 when littlesnitch prevents
		}
		
		//	clean up after the transfer
		curl_easy_cleanup(curlHandle);
		curlHandle = nil;
		//	free the slist (if i made one!)
		if (headerList != nil)	{
			curl_slist_free_all(headerList);
			headerList = nil;
		}
		//	free the form list
		if (firstFormPtr != nil)	{
			curl_formfree(firstFormPtr);
			firstFormPtr = nil;
			lastFormPtr = nil;
		}
		
	}
	else	{
		NSLog(@"\terror at curl_easy_init() in %s",__func__);
	}
	
	performing = NO;
}


- (void) appendDataToPOST:(NSData *)d	{
	if (d == nil)
		return;
	if (postData == nil)
		postData = [[NSMutableData dataWithCapacity:0] retain];
	[postData appendData:d];
}
- (void) appendStringToPOST:(NSString *)s	{
	if (s == nil)
		return;
	[self appendDataToPOST:[s dataUsingEncoding:NSUTF8StringEncoding]];
}
@synthesize dnsCacheTimeout;
@synthesize connectTimeout;
- (void) setLogin:(NSString *)u password:(NSString *)p	{
	if (u==nil || p==nil)
		return;
	VVRELEASE(log);
	log = [u retain];
	VVRELEASE(pass);
	pass = [p retain];
}
@synthesize userAgent;
@synthesize referer;
@synthesize acceptedEncoding;
/*
- (void) appendHeaderString:(NSString *)n	{
	if (n == nil)
		return;
	if (headerArray == nil)	{
		headerArray = [[NSMutableArray arrayWithCapacity:0] retain];
		//	add the "expect" header stating that Expect: 100-continue is not wanted
		[headerArray addObject:[NSString stringWithString:@"Expect:"]];
	}
	[headerArray addObject:n];
}
*/
- (void) writePtr:(void *)ptr size:(size_t)s	{
	//NSLog(@"%s",__func__);
	if (responseData == nil)
		responseData = [[NSMutableData dataWithCapacity:0] retain];
	[responseData appendBytes:ptr length:s];
}
- (void) appendStringToHeader:(NSString *)s	{
	if (s == nil)
		return;
	headerList = curl_slist_append(headerList,[s UTF8String]);
}
- (void) addFormNSString:(NSString *)s forName:(NSString *)n	{
	if (s==nil || n==nil)
		return;
	curl_formadd(&firstFormPtr,&lastFormPtr,
		CURLFORM_COPYNAME, [n UTF8String],
		CURLFORM_COPYCONTENTS, [s UTF8String],
		CURLFORM_END);
}
- (void) addFormZipData:(NSData *)d forName:(NSString *)n	{
	if (d==nil || n==nil)
		return;
	curl_formadd(&firstFormPtr,&lastFormPtr,
			CURLFORM_CONTENTTYPE,"application/zip",
			CURLFORM_COPYNAME,[n UTF8String],
			CURLFORM_BUFFER,[n UTF8String],
			CURLFORM_BUFFERPTR,[d bytes],
			CURLFORM_BUFFERLENGTH,[d length],
			CURLFORM_END);
}

@synthesize headerList;
@synthesize firstFormPtr;
@synthesize lastFormPtr;
@synthesize returnOnMain;
@synthesize httpResponseCode;
@synthesize responseData;
@synthesize err;

- (NSString *) responseString	{
	if (responseData == nil)
		return nil;
	NSString		*returnMe = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}


@end


size_t vvcurlWriteFunction(void *ptr, size_t size, size_t nmemb, void *stream)	{
	if (stream != nil)
		[(VVCURLDL *)stream writePtr:ptr size:size*nmemb];
	return size*nmemb;
}
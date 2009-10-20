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
		postData = nil;
		//headerArray = nil;
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
	[self release];
	return nil;
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	VVRELEASE(urlString);
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
		
		//	if there's post data, set up the handle to use it
		if (postData != nil)	{
			//NSLog(@"\tsetting POST data");
			curl_easy_setopt(curlHandle,CURLOPT_POSTFIELDS,[postData bytes]);
		}
		else	{
			//NSLog(@"\tno POST data to send- checking for form data");
			//	if there's no post data- but there's a ptr to a multipart/formdata HTTP POST...
			if (firstFormPtr != nil)	{
				//NSLog(@"\tsending form data");
				curl_easy_setopt(curlHandle,CURLOPT_HTTPPOST,firstFormPtr);
			}
		}
		
		//	set up a write function so libcurl can send me data it receives
		curl_easy_setopt(curlHandle,CURLOPT_WRITEFUNCTION,vvcurlWriteFunction);
		//	i'm going to pass a pointer to myself as the file stream, so i can get back into objective-c
		curl_easy_setopt(curlHandle,CURLOPT_WRITEDATA,self);
		
		//	perform the transfer
		err = curl_easy_perform(curlHandle);
		//	there's a 60-second timeout on this perform!
		if (err)	{
			NSLog(@"\terr %ld at curl_easy_perform for %@: %s",err,urlString,errBuffer);
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
	
	//	if there's a delegate, tell the delegate that shit's done
	if ((d!=nil)&&([(id)d conformsToProtocol:@protocol(VVCURLDLDelegate)]))	{
		if (returnOnMain)
			[(id)d performSelectorOnMainThread:@selector(dlFinished:) withObject:self waitUntilDone:YES];
		else
			[(id)d dlFinished:self];
	}
	
}


- (struct curl_slist *) headerList	{
	return headerList;
}
- (struct curl_httppost *) firstFormPtr	{
	return firstFormPtr;
}
- (struct curl_httppost *) lastFormPtr	{
	return lastFormPtr;
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

@synthesize headerList;
@synthesize firstFormPtr;
@synthesize lastFormPtr;
@synthesize returnOnMain;
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
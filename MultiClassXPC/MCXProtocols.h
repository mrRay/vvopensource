#ifndef MultiClassXPC_MCXProtocols_h
#define MultiClassXPC_MCXProtocols_h




//	the XPC service responds to this protocol
@protocol MCXService
- (void) fetchListenerEndpoints;
@end
//	the XPC service manager responds to this protocol
@protocol MCXServiceManager
- (void) fetchedEndpoint:(NSXPCListenerEndpoint *)e forClassName:(NSString *)n;
- (void) finishedFetchingEndpoints;
@end




#endif

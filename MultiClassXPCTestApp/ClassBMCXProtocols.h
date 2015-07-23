#ifndef MultiClassXPC_ClassBMCXProtocols_h
#define MultiClassXPC_ClassBMCXProtocols_h




//	this is the protocol implemented by the main app for class B
@protocol ClassBAppService
- (void) connectionEstablished;
- (void) finishedProcessingB;
@end

//	this is the protocol implemented by the XPC service for class B
@protocol ClassBXPCService
- (void) establishConnection;
- (void) startProcessingB;
@end




#endif

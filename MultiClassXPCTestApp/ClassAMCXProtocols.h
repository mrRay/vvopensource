#ifndef MultiClassXPC_ClassAMCXProtocols_h
#define MultiClassXPC_ClassAMCXProtocols_h




//	this is the protocol implemented by the main app for class A
@protocol ClassAAppService
- (void) connectionEstablished;
- (void) finishedProcessingA;
@end

//	this is the protocol implemented by the XPC service for class A
@protocol ClassAXPCService
- (void) establishConnection;
- (void) startProcessingA;
@end




#endif

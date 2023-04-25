#import <Foundation/Foundation.h>
#import "VideoSource.h"
#import "AVCaptureVideoSource.h"
#import "MovieFileVideoSource.h"
#import "QCVideoSource.h"
#import "IMGVideoSource.h"
#import "SyphonVideoSource.h"




typedef enum	{
	SrcMode_None = 0,
	SrcMode_VidIn,
	SrcMode_AVFMov,
	SrcMode_QC,
	SrcMode_IMG,
	SrcMode_Syphon
} SrcMode;

@protocol DynamicVideoSourceDelegate
- (void) listOfStaticSourcesUpdated:(id)ds;
@end




@interface DynamicVideoSource : NSObject <VideoSourceDelegate>	{
	BOOL			deleted;
	
	VVLock			srcLock;	//	used to lock the various src vars
	SrcMode			srcMode;	//	which source i'm currently using
	
	VVLock			delegateLock;
	id				delegate;
	
	AVCaptureVideoSource	*vidInSrc;
	MovieFileVideoSource	*movSrc;
	QCVideoSource			*qcSrc;
	IMGVideoSource			*imgSrc;
	SyphonVideoSource		*syphonSrc;
	
	VVLock			lastBufferLock;
	VVBuffer		*lastBuffer;
}

- (void) loadVidInWithUniqueID:(NSString *)u;
- (void) loadMovieAtPath:(NSString *)p;
- (void) loadQCCompAtPath:(NSString *)p;
- (void) loadImgAtPath:(NSString *)p;
- (void) loadSyphonServerWithDescription:(NSDictionary *)d;

- (void) eject;

- (NSMenu *) allocStaticSourcesMenu;
- (VVBuffer *) allocBuffer;

- (void) _useMode:(SrcMode)n;

- (void) setDelegate:(id<DynamicVideoSourceDelegate>)n;

@end

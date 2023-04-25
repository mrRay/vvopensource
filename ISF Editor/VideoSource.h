#import <Foundation/Foundation.h>
#import <VVBufferPool/VVBufferPool.h>
#import <VVISFKit/VVISFKit.h>
#import <VVBasics/VVBasicMacros.h>




@protocol VideoSourceDelegate
- (void) listOfStaticSourcesUpdated:(id)ds;
@end




@interface VideoSource : NSObject	{
	BOOL			deleted;
	
	//OSSpinLock		lastBufferLock;
	//VVBuffer		*lastBuffer;
	
	VVLock			propLock;
	BOOL			propRunning;
	id <VideoSourceDelegate>	propDelegate;
}

- (void) prepareToBeDeleted;
- (VVBuffer *) allocBuffer;
- (NSArray *) arrayOfSourceMenuItems;

- (void) start;
- (void) _start;
- (void) stop;
- (void) _stop;

//- (void) render;
//- (void) _render;

- (BOOL) propRunning;
- (void) setPropDelegate:(id<VideoSourceDelegate>)n;

@end

#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <VVBasics/VVBasicMacros.h>
#include <libkern/OSAtomic.h>




@interface VVTrackingArea : NSObject	{
	OSSpinLock				attribLock;	//	locks everything
	
	VVRECT					rect;	//	the rect in local coords for the VVView
	NSTrackingAreaOptions	options;
	id						owner;	//	NOT RETAINED
	NSDictionary			*userInfo;	//	RETAINED
	
	NSTrackingArea			*appleTrackingArea;	//	RETAINED populated when this VVTrackingArea is added to a VVView
}

- (id) initWithRect:(VVRECT)r options:(NSTrackingAreaOptions)opt owner:(id)owner userInfo:(NSDictionary *)userInfo;

- (void) setRect:(VVRECT)n;
- (VVRECT) rect;
- (NSTrackingAreaOptions) options;
- (id) owner;
- (NSDictionary *) userInfo;

- (void) updateAppleTrackingAreaWithContainerView:(NSView *)v containerViewRect:(VVRECT)r;
- (void) removeAppleTrackingAreaFromContainerView:(NSView *)v;

//	JUST retains the tracking area locally.  does NOT add the tracking area to anything in the NSView hierarchy.
//- (void) setAppleTrackingArea:(NSTrackingArea *)n;
//- (NSTrackingArea *) appleTrackingArea;

@end

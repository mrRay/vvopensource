#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import <VVBasics/VVBasics.h>
#import <VVUIToolbox/VVUIToolbox.h>




@interface VVScrollView : VVView	{
	VVView			*_documentView;	//	also a vvSubview- everything in the scroll view is actually in this "documentView", and we scroll by changing the bounds of this view
	
	VVSIZE			lastSubviewsUnion;	//	updated every time sprites are updated- the size of the last union rect for all my subviews
	
	BOOL			showHScroll;
	//VVSprite		*hLeftSprite;
	//VVSprite		*hRightSprite;
	VVSprite		*hScrollTrack;
	VVSprite		*hScrollBar;
	
	BOOL			showVScroll;
	//VVSprite		*vUpSprite;
	//VVSprite		*vDownSprite;
	VVSprite		*vScrollTrack;
	VVSprite		*vScrollBar;
}

- (void) hSpriteAction:(VVSprite *)s;
- (void) drawHSprite:(VVSprite *)s;
- (void) vSpriteAction:(VVSprite *)s;
- (void) drawVSprite:(VVSprite *)s;

- (VVView *) documentView;

@property (assign,readwrite) BOOL showHScroll;
@property (assign,readwrite) BOOL showVScroll;
- (VVPOINT) normalizedScrollVal;
- (void) scrollToNormalizedVal:(VVPOINT)n;
- (void) scrollTopLeftToPoint:(VVPOINT)n;
- (void) scrollByAmount:(VVPOINT)delta;

- (VVRECT) documentVisibleRect;

@end

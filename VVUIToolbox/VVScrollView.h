#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVUIToolbox/VVUIToolbox.h>




@interface VVScrollView : VVView	{
	VVView			*_documentView;	//	also a vvSubview- everything in the scroll view is actually in this "documentView", and we scroll by changing the bounds of this view
	
	NSSize			lastSubviewsUnion;	//	updated every time sprites are updated- the size of the last union rect for all my subviews
	
	//VVSprite		*hLeftSprite;
	//VVSprite		*hRightSprite;
	VVSprite		*hScrollTrack;
	VVSprite		*hScrollBar;
	
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

- (NSPoint) normalizedScrollVal;
- (void) scrollToNormalizedVal:(NSPoint)n;
- (void) scrollTopLeftToPoint:(NSPoint)n;
- (void) scrollByAmount:(NSPoint)delta;

@end

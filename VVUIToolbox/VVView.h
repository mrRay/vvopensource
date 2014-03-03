//
//  VVView.h
//  VVOpenSource
//
//  Created by bagheera on 11/1/12.
//
//

#import <Foundation/Foundation.h>
#import "VVSpriteManager.h"
#include <libkern/OSAtomic.h>
#import <OpenGL/OpenGL.h>
#include <AvailabilityMacros.h>
#import "VVTrackingArea.h"




/*		this class is basically a replacement for NSView.  it's assumed that this class will be 
		"inside" a VVSpriteView/VVSpriteGLView/etc, and i'll probably be using a subclass of VVView...
*/




typedef enum	{
	VVViewResizeNone = 0,	//	can't be resized
	VVViewResizeMinXMargin = 1,	//	min x margin can be resized
	VVViewResizeMaxXMargin = 2,	//	max x margin can be resized
	VVViewResizeMinYMargin = 4,	//	...etc...
	VVViewResizeMaxYMargin = 8,
	VVViewResizeWidth = 16,
	VVViewResizeHeight = 32
} VVViewResizeMask;

typedef enum	{
	VVViewBOBottom = 0,
	VVViewBORight,
	VVViewBOTop,
	VVViewBOLeft
} VVViewBoundsOrientation;



#if (__MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
@interface VVView : NSObject <NSDraggingDestination>	{
#else
@interface VVView : NSObject	{
#endif
	BOOL				deleted;
	VVSpriteManager		*spriteManager;
	BOOL				spritesNeedUpdate;
	pthread_mutex_t		spritesUpdateLock;	//	used to lock around 'updateSprites' and access to 'spritesNeedUpdate'
	CGLContextObj		spriteCtx;	//	NOT RETAINED! only NON-nil during draw callback, var exists so stuff with draw callbacks can get the GL context w/o having to pass it in methods (which would require discrete code paths)
	BOOL				needsDisplay;
	
	NSRect				_frame;	//	the area i occupy in my superview's coordinate space
	NSSize				minFrameSize;	//	frame's size cannot be set less than this
	double				localToBackingBoundsMultiplier;
	NSPoint					_boundsOrigin;
	VVViewBoundsOrientation	_boundsOrientation;
	MutLockArray		*trackingAreas;
	
	id					_superview;	//	NOT RETAINED- the "VVView" that owns me, or nil. if nil, "containerView" will be non-nil, and will point to the NSView subclass that "owns" me!
	id					_containerView;	//	NOT RETAINED- points to the NSView-subclass that contains me (tracked because i need to tell it it needs display)
	MutLockArray		*subviews;
	BOOL				autoresizesSubviews;
	VVViewResizeMask	autoresizingMask;	//	same as the NSView resizing masks!
	
	OSSpinLock			propertyLock;	//	locks the items below it (mouse event, clear color stuff)
	NSEvent				*lastMouseEvent;
	BOOL				isOpaque;
	GLfloat				clearColor[4];
	BOOL				drawBorder;
	GLfloat				borderColor[4];
	
	long				mouseDownModifierFlags;
	VVSpriteEventType	mouseDownEventType;
	long				modifierFlags;
	BOOL				mouseIsDown;
	id					clickedSubview;	//	NOT RETAINED
	
	MutLockArray		*dragTypes;	//	always non-nil, holds the strings of the regsitered drag types. empty by default.
}

- (id) initWithFrame:(NSRect)n;
- (void) generalInit;
- (void) initComplete;
- (void) prepareToBeDeleted;

- (void) mouseDown:(NSEvent *)e;
- (void) rightMouseDown:(NSEvent *)e;
- (void) mouseDragged:(NSEvent *)e;
- (void) mouseUp:(NSEvent *)e;
- (void) rightMouseUp:(NSEvent *)e;
- (void) mouseEntered:(NSEvent *)e;
- (void) mouseExited:(NSEvent *)e;
- (void) mouseMoved:(NSEvent *)e;
- (void) scrollWheel:(NSEvent *)e;
- (void) keyDown:(NSEvent *)e;
- (void) keyUp:(NSEvent *)e;

//- (id) hitTest:(NSPoint)n;	//	the point it's passed is in coords local to self!
- (id) vvSubviewHitTest:(NSPoint)p;	//	the point it's passed is in coords local to self!
- (BOOL) checkRect:(NSRect)n;

- (NSPoint) convertPoint:(NSPoint)viewCoords fromView:(id)view;

- (NSPoint) convertPointFromContainerViewCoords:(NSPoint)pointInContainer;
- (NSPoint) convertPointFromWinCoords:(NSPoint)pointInWindow;
- (NSPoint) convertPointFromDisplayCoords:(NSPoint)displayPoint;
- (NSRect) convertRectFromContainerViewCoords:(NSRect)rectInContainer;

- (NSPoint) convertPointToContainerViewCoords:(NSPoint)localCoords;
- (NSPoint) convertPointToWinCoords:(NSPoint)localCoords;
- (NSPoint) convertPointToDisplayCoords:(NSPoint)localCoords;
- (NSRect) convertRectToContainerViewCoords:(NSRect)localRect;

//- (NSPoint) containerViewCoordsOfLocalPoint:(NSPoint)n;
- (NSPoint) winCoordsOfLocalPoint:(NSPoint)n;
- (NSPoint) displayCoordsOfLocalPoint:(NSPoint)n;
- (NSMutableArray *) _locationTransformsToContainerView;

- (NSRect) frame;
- (void) setFrame:(NSRect)n;
- (void) setFrameSize:(NSSize)n;
- (void) _setFrameSize:(NSSize)n;
- (void) setFrameOrigin:(NSPoint)n;
- (void) _setFrameOrigin:(NSPoint)n;
- (NSRect) bounds;
//- (void) setBounds:(NSRect)n;
- (void) setBoundsOrigin:(NSPoint)n;
- (NSPoint) boundsOrigin;
//- (void) setBoundsRotation:(GLfloat)n;
//- (GLfloat) boundsRotation;
- (VVViewBoundsOrientation) boundsOrientation;
- (void) setBoundsOrientation:(VVViewBoundsOrientation)n;

//- (NSTrackingRectTag) addTrackingRect:(NSRect)aRect owner:(id)userObject userData:(void *)userData assumeInside:(BOOL)flag;
//- (void) removeTrackingRect:(NSTrackingRectTag)aTag;
- (void) updateTrackingAreas;
- (void) addTrackingArea:(VVTrackingArea *)n;
- (void) removeTrackingArea:(VVTrackingArea *)n;
- (void) _clearAppleTrackingAreas;
- (void) _refreshAppleTrackingAreas;

- (void) _viewDidMoveToWindow;
- (void) viewDidMoveToWindow;
- (NSRect) visibleRect;
- (NSRect) _visibleRect;
//	returns YES if at least one of its views has a window and a non-zero visible rect
- (BOOL) hasVisibleView;

@property (assign,readwrite) BOOL autoresizesSubviews;
@property (assign,readwrite) VVViewResizeMask autoresizingMask;

- (void) addSubview:(id)n;
- (void) removeSubview:(id)n;
- (void) removeFromSuperview;
- (BOOL) containsSubview:(id)n;
- (void) _setSuperview:(id)n;
- (id) superview;
//	returns the bounds of the superview (or the container view if applicable). returns NSZeroRect if something's wrong or missing
- (NSRect) superBounds;
//	returns an NSUnionRect of the frames of all my subviews
- (NSRect) subviewFramesUnion;
- (void) registerForDraggedTypes:(NSArray *)a;
- (void) _collectDragTypesInArray:(NSMutableArray *)n;
- (MutLockArray *) dragTypes;
- (void) setContainerView:(id)n;
- (id) containerView;
- (MutLockArray *) subviews;
- (id) window;

- (void) _drawRect:(NSRect)r inContext:(CGLContextObj)cgl_ctx;
- (void) drawRect:(NSRect)r inContext:(CGLContextObj)cgl_ctx;
- (BOOL) isOpaque;
- (void) setIsOpaque:(BOOL)n;
- (void) finishedDrawing;
- (void) updateSprites;	//	you MUST LOCK 'spritesUpdateLock' BEFORE CALLING THIS METHOD
- (NSRect) backingBounds;	//	GL views don't respect NSView's "bounds", even if the GL view is on a retina machine and its bounds are of a different dpi than the frame.  this returns the # of pixels this view is rendering.
- (double) localToBackingBoundsMultiplier;
- (void) setLocalToBackingBoundsMultiplier:(double)n;

@property (readonly) BOOL deleted;
@property (readonly) VVSpriteManager *spriteManager;
@property (assign, readwrite) BOOL spritesNeedUpdate;
- (void) setSpritesNeedUpdate;
@property (assign,readwrite) BOOL needsDisplay;
- (void) setNeedsDisplay;
@property (assign,readwrite) BOOL needsRender;	//	does same thing as needsDisplay
- (void) setNeedsRender;
@property (readonly) NSEvent *lastMouseEvent;
- (void) setClearColor:(NSColor *)n;
- (void) setClearColors:(GLfloat)r :(GLfloat)g :(GLfloat)b :(GLfloat)a;
@property (assign,readwrite) BOOL drawBorder;
- (void) setBorderColor:(NSColor *)n;
- (void) setBorderColors:(GLfloat)r :(GLfloat)g :(GLfloat)b :(GLfloat)a;
@property (readonly) long mouseDownModifierFlags;
@property (assign,readwrite) VVSpriteEventType mouseDownEventType;
@property (readonly) long modifierFlags;
@property (readonly) BOOL mouseIsDown;
- (void) _setMouseIsDown:(BOOL)n;	//	used to work around the fact that NSViews don't get a "mouseUp" when they open a contextual menu
@property (readonly) MutLockArray *dragTypes;


@end

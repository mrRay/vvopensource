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
#if IPHONE
#import <OpenGLES/EAGL.h>
#import <GLKit/GLKit.h>
#else
#import <OpenGL/OpenGL.h>
#endif
#include <AvailabilityMacros.h>
#if !IPHONE
#import "VVTrackingArea.h"
#endif



/*		this class is basically a replacement for NSView.  it's assumed that this class will be 
		"inside" a VVSpriteView/VVSpriteGLView/etc, and i'll probably be using a subclass of VVView...
*/




#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
typedef NS_ENUM(NSInteger, VVViewResizeMask)	{
	VVViewResizeNone = 0,	//	can't be resized
	VVViewResizeMinXMargin = 1,	//	min x margin can be resized
	VVViewResizeMaxXMargin = 2,	//	max x margin can be resized
	VVViewResizeMinYMargin = 4,	//	...etc...
	VVViewResizeMaxYMargin = 8,
	VVViewResizeWidth = 16,
	VVViewResizeHeight = 32
};
typedef NS_ENUM(NSInteger, VVViewBoundsOrientation)	{
	VVViewBOBottom = 0,
	VVViewBORight,
	VVViewBOTop,
	VVViewBOLeft
};
#else
typedef enum VVViewResizeMask	{
	VVViewResizeNone = 0,	//	can't be resized
	VVViewResizeMinXMargin = 1,	//	min x margin can be resized
	VVViewResizeMaxXMargin = 2,	//	max x margin can be resized
	VVViewResizeMinYMargin = 4,	//	...etc...
	VVViewResizeMaxYMargin = 8,
	VVViewResizeWidth = 16,
	VVViewResizeHeight = 32
} VVViewResizeMask;
typedef enum VVViewBoundsOrientation	{
	VVViewBOBottom = 0,
	VVViewBORight,
	VVViewBOTop,
	VVViewBOLeft
} VVViewBoundsOrientation;
#endif




#if !IPHONE
#if (__MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
@interface VVView : NSObject <NSDraggingDestination>	{
#else	//	else __MAC_OS_X_VERSION_MAX_ALLOWED < 1070
@interface VVView : NSObject <NSDraggingSource>	{
#endif
#else	//	else IPHONE
@interface VVView : NSObject	{
#endif
	BOOL				deleted;
	VVSpriteManager		*spriteManager;
	BOOL				spritesNeedUpdate;
	pthread_mutex_t		spritesUpdateLock;	//	used to lock around 'updateSprites' and access to 'spritesNeedUpdate'
#if !IPHONE
	CGLContextObj		spriteCtx;	//	NOT RETAINED! only NON-nil during draw callback, var exists so stuff with draw callbacks can get the GL context w/o having to pass it in methods (which would require discrete code paths)
#endif
	BOOL				needsDisplay;
	
	
	OSSpinLock			geometryLock;
	VVRECT				_frame;	//	the area i occupy in my superview's coordinate space
	VVSIZE				minFrameSize;	//	frame's size cannot be set less than this
	double				localToBackingBoundsMultiplier;
	VVPOINT					_boundsOrigin;
	VVViewBoundsOrientation	_boundsOrientation;
	
	
#if IPHONE
	OSSpinLock			boundsProjectionEffectLock;	//	locks the GLKBaseEffect
	GLKBaseEffect		*boundsProjectionEffect;	//	the projection matrix on this effect's transform property is equivalent to a glOrtho (for the container view) on the projection matrix, followed by a series of translate/rotate transforms such that, when applied to the modelview matrix transform, the drawing coordinates' "origin" (0., 0.) will be aligned with the origin of the bounds of the view currently being drawn (with appropriate rotation for the view's bounds origin).
	BOOL				boundsProjectionEffectNeedsUpdate;	//	if YES, the effect needs update.
#else
	MutLockArray		*trackingAreas;
#endif
	
	
	OSSpinLock			hierarchyLock;
	id					_superview;	//	NOT RETAINED- the "VVView" that owns me, or nil. if nil, "containerView" will be non-nil, and will point to the NSView subclass that "owns" me!
	id					_containerView;	//	NOT RETAINED- points to the NSView-subclass that contains me (tracked because i need to tell it it needs display)
	MutLockArray		*subviews;
	BOOL				autoresizesSubviews;
	VVViewResizeMask	autoresizingMask;	//	same as the NSView resizing masks!
	
	
	OSSpinLock			propertyLock;	//	locks the items below it (mouse event, clear color stuff)
#if !IPHONE
	NSEvent				*lastMouseEvent;
#endif
	BOOL				isOpaque;
	GLfloat				clearColor[4];
	BOOL				drawBorder;
	GLfloat				borderColor[4];
	
	
	OSSpinLock			mouseLock;
	long				mouseDownModifierFlags;
	VVSpriteEventType	mouseDownEventType;
	long				modifierFlags;
	BOOL				mouseIsDown;
	id					clickedSubview;	//	NOT RETAINED
	
	MutLockArray		*dragTypes;	//	always non-nil, holds the strings of the regsitered drag types. empty by default.
}

- (id) initWithFrame:(VVRECT)n;
- (void) generalInit;
- (void) initComplete;
- (void) prepareToBeDeleted;

#if IPHONE
- (void) touchBegan:(UITouch *)touch withEvent:(UIEvent *)event;
- (void) touchMoved:(UITouch *)touch withEvent:(UIEvent *)event;
- (void) touchEnded:(UITouch *)touch withEvent:(UIEvent *)event;
- (void) touchCancelled:(UITouch *)touch withEvent:(UIEvent *)event;
#else
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
- (NSDraggingSession *) beginDraggingSessionWithItems:(NSArray *)items event:(NSEvent *)event source:(id<NSDraggingSource>)source;
#endif

//- (id) hitTest:(VVPOINT)n;	//	the point it's passed is in coords local to self!
- (id) vvSubviewHitTest:(VVPOINT)p;	//	the point it's passed is in coords local to self!
- (BOOL) checkRect:(VVRECT)n;

- (VVPOINT) convertPoint:(VVPOINT)viewCoords fromView:(id)view;

- (VVPOINT) convertPointFromContainerViewCoords:(VVPOINT)pointInContainer;
- (VVPOINT) convertPointFromWinCoords:(VVPOINT)pointInWindow;
- (VVPOINT) convertPointFromDisplayCoords:(VVPOINT)displayPoint;
- (VVRECT) convertRectFromContainerViewCoords:(VVRECT)rectInContainer;

- (VVPOINT) convertPointToContainerViewCoords:(VVPOINT)localCoords;
- (VVPOINT) convertPointToWinCoords:(VVPOINT)localCoords;
- (VVPOINT) convertPointToDisplayCoords:(VVPOINT)localCoords;
- (VVRECT) convertRectToContainerViewCoords:(VVRECT)localRect;

//- (VVPOINT) containerViewCoordsOfLocalPoint:(VVPOINT)n;
- (VVPOINT) winCoordsOfLocalPoint:(VVPOINT)n;
- (VVPOINT) displayCoordsOfLocalPoint:(VVPOINT)n;
- (NSMutableArray *) _locationTransformsToContainerView;

- (VVRECT) frame;
- (void) setFrame:(VVRECT)n;
- (void) setFrameSize:(VVSIZE)n;
- (void) _setFrameSize:(VVSIZE)n;
- (void) setFrameOrigin:(VVPOINT)n;
- (void) _setFrameOrigin:(VVPOINT)n;
- (VVRECT) bounds;
//- (void) setBounds:(VVRECT)n;
- (void) setBoundsOrigin:(VVPOINT)n;
- (VVPOINT) boundsOrigin;
//- (void) setBoundsRotation:(GLfloat)n;
//- (GLfloat) boundsRotation;
- (VVViewBoundsOrientation) boundsOrientation;
- (void) setBoundsOrientation:(VVViewBoundsOrientation)n;

#if IPHONE
- (GLKBaseEffect *) safelyGetBoundsProjectionEffect;
#else
//- (NSTrackingRectTag) addTrackingRect:(VVRECT)aRect owner:(id)userObject userData:(void *)userData assumeInside:(BOOL)flag;
//- (void) removeTrackingRect:(NSTrackingRectTag)aTag;
- (void) updateTrackingAreas;
- (void) addTrackingArea:(VVTrackingArea *)n;
- (void) removeTrackingArea:(VVTrackingArea *)n;
- (void) _clearAppleTrackingAreas;
- (void) _refreshAppleTrackingAreas;
#endif

- (void) _viewDidMoveToWindow;
- (void) viewDidMoveToWindow;
- (VVRECT) visibleRect;
- (VVRECT) _visibleRect;
//	returns YES if at least one of its views has a window and a non-zero visible rect
- (BOOL) hasVisibleView;

- (void) setAutoresizesSubviews:(BOOL)n;
- (BOOL) autoresizesSubviews;
- (void) setAutoresizingMask:(VVViewResizeMask)n;
- (VVViewResizeMask) autoresizingMask;
- (void) addSubview:(id)n;
- (void) removeSubview:(id)n;
- (void) removeFromSuperview;
- (BOOL) containsSubview:(id)n;
- (void) _setSuperview:(id)n;
- (id) superview;
- (id) enclosingScrollView;
//	returns the bounds of the superview (or the container view if applicable). returns VVZERORECT if something's wrong or missing
- (VVRECT) superBounds;
//	returns an VVUNIONRECT of the frames of all my subviews
- (VVRECT) subviewFramesUnion;
- (void) registerForDraggedTypes:(NSArray *)a;
- (void) _collectDragTypesInArray:(NSMutableArray *)n;
- (MutLockArray *) dragTypes;
- (void) setContainerView:(id)n;
- (id) containerView;
- (MutLockArray *) subviews;
- (id) window;

#if !IPHONE
- (void) _drawRect:(VVRECT)r inContext:(CGLContextObj)cgl_ctx;
- (void) drawRect:(VVRECT)r inContext:(CGLContextObj)cgl_ctx;
#else
- (void) _drawRect:(VVRECT)r;
- (void) drawRect:(VVRECT)r;
#endif
- (BOOL) isOpaque;
- (void) setIsOpaque:(BOOL)n;
- (void) finishedDrawing;
- (void) updateSprites;	//	you MUST LOCK 'spritesUpdateLock' BEFORE CALLING THIS METHOD
- (VVRECT) backingBounds;	//	GL views don't respect NSView's "bounds", even if the GL view is on a retina machine and its bounds are of a different dpi than the frame.  this returns the # of pixels this view is rendering.
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
#if !IPHONE
@property (readonly) NSEvent *lastMouseEvent;
#endif
#if IPHONE
- (void) setClearColor:(UIColor *)n;
#else
- (void) setClearColor:(NSColor *)n;
#endif
- (void) setClearColors:(GLfloat)r :(GLfloat)g :(GLfloat)b :(GLfloat)a;
@property (assign,readwrite) BOOL drawBorder;
#if IPHONE
- (void) setBorderColor:(UIColor *)n;
#else
- (void) setBorderColor:(NSColor *)n;
#endif
- (void) setBorderColors:(GLfloat)r :(GLfloat)g :(GLfloat)b :(GLfloat)a;
@property (readonly) long mouseDownModifierFlags;
@property (assign,readwrite) VVSpriteEventType mouseDownEventType;
@property (readonly) long modifierFlags;
@property (readonly) BOOL mouseIsDown;
- (void) _setMouseIsDown:(BOOL)n;	//	used to work around the fact that NSViews don't get a "mouseUp" when they open a contextual menu
@property (readonly) MutLockArray *dragTypes;


@end

#import <TargetConditionals.h>
#import <Foundation/Foundation.h>
#import <VVUIToolbox/VVSpriteManager.h>
#include <libkern/OSAtomic.h>
#import <OpenGL/OpenGL.h>
#include <AvailabilityMacros.h>
#import <VVUIToolbox/VVTrackingArea.h>

@class VVView;




/*		this class is basically a replacement for NSView.  it's assumed that this class will be 
		"inside" a VVSpriteView/VVSpriteGLView/etc, and i'll probably be using a subclass of VVView...
*/




//#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
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
//#else
//typedef enum VVViewResizeMask	{
//	VVViewResizeNone = 0,	//	can't be resized
//	VVViewResizeMinXMargin = 1,	//	min x margin can be resized
//	VVViewResizeMaxXMargin = 2,	//	max x margin can be resized
//	VVViewResizeMinYMargin = 4,	//	...etc...
//	VVViewResizeMaxYMargin = 8,
//	VVViewResizeWidth = 16,
//	VVViewResizeHeight = 32
//} VVViewResizeMask;
//typedef enum VVViewBoundsOrientation	{
//	VVViewBOBottom = 0,
//	VVViewBORight,
//	VVViewBOTop,
//	VVViewBOLeft
//} VVViewBoundsOrientation;
//#endif




@protocol VVViewContainer
- (void) addVVSubview:(VVView *)n;
- (void) removeVVSubview:(VVView *)n;
- (BOOL) containsSubview:(VVView *)n;
- (VVView *) vvSubviewHitTest:(VVPOINT)p;
- (void) reconcileVVSubviewDragTypes;
- (double) localToBackingBoundsMultiplier;
- (void) _setMouseIsDown:(BOOL)n;
@end




//#if (__MAC_OS_X_VERSION_MAX_ALLOWED >= 1070)
@interface VVView : NSObject <NSDraggingDestination>	{
//#else	//	else __MAC_OS_X_VERSION_MAX_ALLOWED < 1070
//@interface VVView : NSObject <NSDraggingSource>	{
//#endif
	BOOL				deleted;
	VVSpriteManager		*spriteManager;
	BOOL				spritesNeedUpdate;
	pthread_mutex_t		spritesUpdateLock;	//	used to lock around 'updateSprites' and access to 'spritesNeedUpdate'
	CGLContextObj		spriteCtx;	//	NOT RETAINED! only NON-nil during draw callback, var exists so stuff with draw callbacks can get the GL context w/o having to pass it in methods (which would require discrete code paths)
	BOOL				needsDisplay;
	
	
	VVLock			geometryLock;
	VVRECT				_frame;	//	the area i occupy in my superview's coordinate space
	VVSIZE				minFrameSize;	//	frame's size cannot be set less than this
	double				localToBackingBoundsMultiplier;
	VVPOINT					_boundsOrigin;
	VVViewBoundsOrientation	_boundsOrientation;
	
	
	MutLockArray		*trackingAreas;
	id<MTLBuffer>		mvpBuffer;	//	the buffer that contains the model-view-projection matrix, which much be applied to vertex coords to ensure that a vertex positioned at (0,0) draws in the appropriate location in the parent window
	
	
	VVLock			hierarchyLock;
	__weak VVView		*_superview;	//	NOT RETAINED- the "VVView" that owns me, or nil. if nil, "containerView" will be non-nil, and will point to the NSView subclass that "owns" me!
	NSView				*_containerView;	//	NOT RETAINED- points to the NSView-subclass that contains me (tracked because i need to tell it it needs display)
	MutLockArray		*subviews;
	BOOL				autoresizesSubviews;
	VVViewResizeMask	autoresizingMask;	//	same as the NSView resizing masks!
	
	
	VVLock			_propertyLock;	//	locks the items below it (mouse event, clear color stuff)
	NSEvent				*lastMouseEvent;
	BOOL				isOpaque;
	float				clearColor[4];
	BOOL				drawBorder;
	float				borderColor[4];
	
	
	VVLock			mouseLock;
	long				mouseDownModifierFlags;
	VVSpriteEventType	mouseDownEventType;
	long				modifierFlags;
	BOOL				mouseIsDown;
	__weak id			clickedSubview;	//	NOT RETAINED
	
	MutLockArray		*dragTypes;	//	always non-nil, holds the strings of the regsitered drag types. empty by default.
}

- (instancetype) initWithFrame:(VVRECT)n;
- (void) generalInit;
- (void) initComplete;
- (void) prepareToBeDeleted;

- (void) mouseDown:(NSEvent *)e;
- (void) rightMouseDown:(NSEvent *)e;
- (void) mouseDragged:(NSEvent *)e;
- (void) rightMouseDragged:(NSEvent *)e;
- (void) mouseUp:(NSEvent *)e;
- (void) rightMouseUp:(NSEvent *)e;
- (void) mouseEntered:(NSEvent *)e;
- (void) mouseExited:(NSEvent *)e;
- (void) mouseMoved:(NSEvent *)e;
- (void) scrollWheel:(NSEvent *)e;
- (void) keyDown:(NSEvent *)e;
- (void) keyUp:(NSEvent *)e;
- (NSDraggingSession *) beginDraggingSessionWithItems:(NSArray *)items event:(NSEvent *)event source:(id<NSDraggingSource>)source;

//- (id) hitTest:(VVPOINT)n;	//	the point it's passed is in coords local to self!
- (VVView *) vvSubviewHitTest:(VVPOINT)p;	//	the point it's passed is in coords local to self!
- (BOOL) checkRect:(VVRECT)n;

- (VVPOINT) convertPoint:(VVPOINT)viewCoords fromView:(id)view;

- (VVPOINT) convertPointFromContainerViewCoords:(VVPOINT)pointInContainer;
- (VVPOINT) convertPointFromWinCoords:(VVPOINT)pointInWindow;
- (VVPOINT) convertPointFromDisplayCoords:(VVPOINT)displayPoint;
- (VVRECT) convertRectFromContainerViewCoords:(VVRECT)rectInContainer;
- (VVRECT) convertRectFromSuperviewCoords:(VVRECT)rectInSuperview;

- (VVPOINT) convertPointToContainerViewCoords:(VVPOINT)localCoords;
- (VVPOINT) convertPointToWinCoords:(VVPOINT)localCoords;
- (VVPOINT) convertPointToDisplayCoords:(VVPOINT)localCoords;
- (VVRECT) convertRectToContainerViewCoords:(VVRECT)localRect;
- (VVRECT) convertRectToSuperviewCoords:(VVRECT)localRect;

//- (VVPOINT) containerViewCoordsOfLocalPoint:(VVPOINT)n;
- (VVPOINT) winCoordsOfLocalPoint:(VVPOINT)n;
- (VVPOINT) displayCoordsOfLocalPoint:(VVPOINT)n;
- (NSMutableArray *) _locationTransformsToContainerView;

- (NSMutableArray<NSAffineTransform*> *) localToSuperviewCoordinateSpaceDrawTransforms;
- (NSMutableArray<NSAffineTransform*> *) localToContainerCoordinateSpaceDrawTransforms;

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
//- (void) setBoundsRotation:(float)n;
//- (float) boundsRotation;
- (VVViewBoundsOrientation) boundsOrientation;
- (void) setBoundsOrientation:(VVViewBoundsOrientation)n;

//- (NSTrackingRectTag) addTrackingRect:(VVRECT)aRect owner:(id)userObject userData:(void *)userData assumeInside:(BOOL)flag;
//- (void) removeTrackingRect:(NSTrackingRectTag)aTag;
- (void) updateTrackingAreas;
- (void) addTrackingArea:(VVTrackingArea *)n;
- (void) removeTrackingArea:(VVTrackingArea *)n;
- (void) _clearAppleTrackingAreas;
- (void) _refreshAppleTrackingAreas;

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
- (void) setContainerView:(NSView *)n;
- (NSView *) containerView;
- (MutLockArray *) subviews;
- (id) window;

- (void) drawRect:(VVRECT)r;	//	put drawing code for subclasses in here
- (void) _drawRect:(VVRECT)r;	//	container view calls this (also calls itself recursively on its subviews)
- (void) _drawRect:(VVRECT)r inContext:(CGLContextObj)cgl_ctx;
- (void) drawRect:(VVRECT)r inContext:(CGLContextObj)cgl_ctx;
- (void) _drawRect:(VVRECT)r inEncoder:(id<MTLRenderCommandEncoder>)inEnc commandBuffer:(id<MTLCommandBuffer>)cb;
- (void) drawRect:(VVRECT)r inEncoder:(id<MTLRenderCommandEncoder>)inEnc commandBuffer:(id<MTLCommandBuffer>)cb;
- (BOOL) isOpaque;
- (void) setIsOpaque:(BOOL)n;
- (void) finishedDrawing;
- (void) updateSprites;	//	you MUST LOCK 'spritesUpdateLock' BEFORE CALLING THIS METHOD
- (VVRECT) backingBounds;	//	GL views don't respect NSView's "bounds", even if the GL view is on a retina machine and its bounds are of a different dpi than the frame.  this returns the # of pixels this view is rendering.
- (double) localToBackingBoundsMultiplier;
- (void) setLocalToBackingBoundsMultiplier:(double)n;
- (VVRECT) convertRectToBacking:(VVRECT)n;
- (VVRECT) convertRectToLocalBackingBounds:(VVRECT)n;

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
- (void) setClearColors:(float)r :(float)g :(float)b :(float)a;
- (void) getClearColors:(float *)n;
@property (assign,readwrite) BOOL drawBorder;
- (void) setBorderColor:(NSColor *)n;
- (void) setBorderColors:(float)r :(float)g :(float)b :(float)a;
@property (readonly) long mouseDownModifierFlags;
@property (assign,readwrite) VVSpriteEventType mouseDownEventType;
@property (readonly) long modifierFlags;
@property (readonly) BOOL mouseIsDown;
- (void) _setMouseIsDown:(BOOL)n;	//	used to work around the fact that NSViews don't get a "mouseUp" when they open a contextual menu
@property (readonly) MutLockArray *dragTypes;


@end



@interface NSObject (VVView)
@property (readonly) BOOL isVVView;
@end

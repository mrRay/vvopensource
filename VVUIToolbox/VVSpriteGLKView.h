#import <Foundation/Foundation.h>
#import "VVSpriteManager.h"
#import <OpenGLES/EAGL.h>
#import <libkern/OSAtomic.h>
#import "VVView.h"




@interface VVSpriteGLKView : GLKView	{
	BOOL					deleted;
	
	BOOL					initialized;
	//BOOL					needsReshape;
	pthread_mutex_t			glLock;
	BOOL					flipped;	//	whether or not the context renders upside-down.  NO by default, but some subclasses just render upside-down...
	double					localToBackingBoundsMultiplier;
	MutLockArray			*vvSubviews;
	id						dragNDropSubview;	//	NOT RETAINED
	
	VVSpriteManager			*spriteManager;
	BOOL					spritesNeedUpdate;
	//NSEvent					*lastMouseEvent;
	GLfloat					clearColor[4];
	BOOL					drawBorder;
	GLfloat					borderColor[4];
	
	MutNRLockDict			*perTouchClickedSubviews;	//	key/val dict, key is UITouch val is ObjectHolder (ZWR) pointing to the subview that touch should be delivered to
	
	OSSpinLock				boundsProjectionEffectLock;	//	locks the GLKBaseEffect
	GLKBaseEffect			*boundsProjectionEffect;	//	the projection matrix on this effect's transform property is equivalent to a glOrtho (for the container view) on the projection matrix, followed by a series of translate/rotate transforms such that, when applied to the modelview matrix transform, the drawing coordinates' "origin" (0., 0.) will be aligned with the origin of the bounds of the view currently being drawn (with appropriate rotation for the view's bounds origin).
	BOOL					boundsProjectionEffectNeedsUpdate;	//	if YES, the effect needs update.
}

- (void) generalInit;
- (void) prepareToBeDeleted;

- (void) initializeGL;
- (void) finishedDrawing;
//- (void) reshapeGL;
- (void) updateSprites;
- (VVRECT) backingBounds;	//	GL views don't respect NSView's "bounds", even if the GL view is on a retina machine and its bounds are of a different dpi than the frame.  this returns the # of pixels this view is rendering.
- (VVRECT) visibleRect;
- (double) localToBackingBoundsMultiplier;
- (VVRECT) convertRectToBacking:(VVRECT)n;

- (void) _lock;
- (void) _unlock;
//- (void) lockSetOpenGLContext:(NSOpenGLContext *)n;
- (void) addVVSubview:(id)n;
- (void) removeVVSubview:(id)n;
- (BOOL) containsSubview:(id)n;
- (id) vvSubviewHitTest:(VVPOINT)p;
- (void) reconcileVVSubviewDragTypes;

@property (readonly) BOOL deleted;
@property (assign,readwrite) BOOL initialized;
@property (assign,readwrite) BOOL flipped;
@property (readonly) double localToBackingBoundsMultiplier;
@property (readonly) MutLockArray *vvSubviews;
@property (assign, readwrite) BOOL spritesNeedUpdate;
- (void) setSpritesNeedUpdate;
//@property (readonly) NSEvent *lastMouseEvent;
@property (retain,readwrite) UIColor *clearColor;
- (void) setClearColors:(GLfloat)r :(GLfloat)g :(GLfloat)b :(GLfloat)a;
@property (assign,readwrite) BOOL drawBorder;
@property (retain,readwrite) UIColor *borderColor;
@property (readonly) VVSpriteManager *spriteManager;

@end

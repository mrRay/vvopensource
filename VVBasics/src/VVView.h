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
#import <OpenGL/CGLMacro.h>




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




@interface VVView : NSObject	{
	BOOL				deleted;
	VVSpriteManager		*spriteManager;
	BOOL				spritesNeedUpdate;
	CGLContextObj		spriteCtx;	//	NOT RETAINED! only NON-nil during draw callback, var exists so stuff with draw callbacks can get the GL context w/o having to pass it in methods (which would require discrete code paths)
	BOOL				needsDisplay;
	
	NSRect				_frame;
	NSSize				minFrameSize;	//	frame's size cannot be set less than this
	NSRect				_bounds;
	GLfloat				_boundsRotation;
	NSPoint				_boundsOrigin;	//	the bounds origin offset is kept as a separate var so i can quickly refer to "bounds" w/o having to worry about compensating for a non-zero origin.
	id					superview;	//	NOT RETAINED- the "VVView" that owns me, or nil. if nil, "containerView" will be non-nil, and will point to the NSView subclass that "owns" me!
	id					containerView;	//	NOT RETAINED- points to the NSView-subclass that contains me (tracked because i need to tell it it needs display)
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
	long				modifierFlags;
	BOOL				mouseIsDown;
	id					clickedSubview;	//	NOT RETAINED
}

- (id) initWithFrame:(NSRect)n;
- (void) generalInit;
- (void) prepareToBeDeleted;

- (void) mouseDown:(NSEvent *)e;
- (void) rightMouseDown:(NSEvent *)e;
- (void) mouseDragged:(NSEvent *)e;
- (void) mouseUp:(NSEvent *)e;
- (void) rightMouseUp:(NSEvent *)e;
- (void) keyDown:(NSEvent *)e;
- (void) keyUp:(NSEvent *)e;

- (NSPoint) convertPoint:(NSPoint)pointInWindow fromView:(id)view;
//- (id) hitTest:(NSPoint)n;	//	the point it's passed is in coords local to self!
- (id) vvSubviewHitTest:(NSPoint)p;	//	the point it's passed is in coords local to self!
- (BOOL) checkRect:(NSRect)n;

- (NSRect) frame;
- (void) setFrame:(NSRect)n;
- (void) setFrameSize:(NSSize)n;
- (void) setFrameOrigin:(NSPoint)n;
- (NSRect) bounds;
- (void) setBounds:(NSRect)n;
- (void) setBoundsOrigin:(NSPoint)n;
- (NSPoint) boundsOrigin;
- (void) setBoundsRotation:(GLfloat)n;
- (GLfloat) boundsRotation;
- (NSRect) visibleRect;

@property (readonly) id superview;
@property (assign,readwrite) BOOL autoresizesSubviews;
@property (assign,readwrite) VVViewResizeMask autoresizingMask;

- (void) addSubview:(id)n;
- (void) removeSubview:(id)n;
- (void) removeFromSuperview;
- (void) setSuperview:(id)n;
- (id) superview;
- (void) setContainerView:(id)n;
- (id) containerView;
- (MutLockArray *) subviews;
- (id) window;

- (void) _drawRect:(NSRect)r inContext:(CGLContextObj)cgl_ctx;
- (void) drawRect:(NSRect)r inContext:(CGLContextObj)cgl_ctx;
- (BOOL) isOpaque;
- (void) finishedDrawing;
- (void) updateSprites;

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
@property (readonly) long modifierFlags;
@property (readonly) BOOL mouseIsDown;


@end

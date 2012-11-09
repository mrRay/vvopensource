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




@interface VVView : NSResponder	{
	BOOL				deleted;
	VVSpriteManager		*spriteManager;
	BOOL				spritesNeedUpdate;
	BOOL				needsDisplay;

	NSRect				frame;
	NSRect				bounds;
	id					superview;	//	NOT RETAINED
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
- (id) hitTest:(NSPoint)n;

- (NSRect) frame;
- (void) setFrame:(NSRect)n;
- (void) setFrameSize:(NSSize)n;
- (NSRect) bounds;
- (void) setBounds:(NSRect)n;
- (NSRect) visibleRect;

@property (assign,readwrite) BOOL autoresizesSubviews;
@property (assign,readwrite) VVViewResizeMask autoresizingMask;

- (void) addSubview:(id)n;
- (void) removeSubview:(id)n;
- (void) removeFromSuperview;
- (MutLockArray *) subviews;
- (id) window;

- (void) drawRect:(NSRect)r;
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
- (void) setClearColors:(GLfloat)r:(GLfloat)g:(GLfloat)b:(GLfloat)a;
@property (assign,readwrite) BOOL drawBorder;
- (void) setBorderColor:(NSColor *)n;
- (void) setBorderColors:(GLfloat)r:(GLfloat)g:(GLfloat)b:(GLfloat)a;
@property (readonly) long mouseDownModifierFlags;
@property (readonly) long modifierFlags;
@property (readonly) BOOL mouseIsDown;


@end

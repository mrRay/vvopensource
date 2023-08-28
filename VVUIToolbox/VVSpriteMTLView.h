//
//  VVSpriteMTLView.h
//  VVOpenSource
//
//  Created by testadmin on 4/25/23.
//

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <TargetConditionals.h>
#import <simd/simd.h>
#import <QuartzCore/QuartzCore.h>
#import <VVUIToolbox/VVView.h>

//@class VVSpriteMTLView;
@class MutLockArray;

NS_ASSUME_NONNULL_BEGIN




@interface VVSpriteMTLView : NSView <CALayerDelegate,VVViewContainer>	{
	//id<MTLDevice>			device;
	MTLRenderPassDescriptor			*passDescriptor;
	id<MTLRenderPipelineState>		pso;
	//vector_uint2			viewportSize;
	CAMetalLayer			*metalLayer;
	id<CAMetalDrawable>		currentDrawable;
	
	//	the following vars are also used in VVSpriteGLView, etc.  really, 
	//double					localToBackingBoundsMultiplier;
	//MutLockArray			*vvSubviews;
	__weak id				dragNDropSubview;	//	NOT RETAINED
	
	//VVSpriteManager			*spriteManager;
	//BOOL					spritesNeedUpdate;
	//NSEvent					*lastMouseEvent;
	
	float					clearColorVals[4];
	//BOOL					drawBorder;
	float					borderColorVals[4];
	
	//long					mouseDownModifierFlags;
	//VVSpriteEventType		mouseDownEventType;
	//long					modifierFlags;
	//BOOL					mouseIsDown;
	//__weak VVView			*clickedSubview;	//	NOT RETAINED
}

- (void) generalInit;
- (void) prepareToBeDeleted;

@property (readonly) BOOL deleted;
//@property (assign,readwrite) BOOL initialized;
//@property (assign,readwrite) BOOL flipped;
@property (readonly) double localToBackingBoundsMultiplier;
@property (strong,readonly) MutLockArray *vvSubviews;
@property (assign, readwrite) BOOL spritesNeedUpdate;
- (void) setSpritesNeedUpdate;
@property (strong,readonly) NSEvent *lastMouseEvent;
@property (strong,readwrite) NSColor *clearColor;
- (void) setClearColors:(float)r :(float)g :(float)b :(float)a;
- (void) getClearColors:(float *)n;
@property (assign,readwrite) BOOL drawBorder;
@property (strong,readwrite) NSColor *borderColor;
@property (strong,readonly) VVSpriteManager *spriteManager;
@property (readonly) long mouseDownModifierFlags;
@property (assign,readwrite) VVSpriteEventType mouseDownEventType;
@property (readonly) long modifierFlags;
@property (readonly) BOOL mouseIsDown;
- (void) _setMouseIsDown:(BOOL)n;	//	used to work around the fact that NSViews don't get a "mouseUp" when they open a contextual menu
@property (weak,readwrite,nullable) VVView * clickedSubview;

@property (strong,readwrite) id<MTLDevice> device;
@property (readwrite) MTLPixelFormat pixelFormat;
@property (readwrite,nullable) CGColorSpaceRef colorspace;
@property (readonly) vector_uint2 viewportSize;
//	set it to nil and any pixels with an alpha < 1 in the layer will be composited as transparent in the window hierarchy
@property (strong,nullable) NSColor * layerBackgroundColor;

//	buffer containing the model/view/projection matrices that control display
@property (strong,nullable) id<MTLBuffer> mvpBuffer;

//	isn't used to do anything by the backend, but is set to YES every time reconfigureDrawable is called.  if you want to throttle drawing- as opposed to just drawing every time your proc hits- you should use this property to flag the image as needing redraw and check the flag to determine when to redraw.
@property (readwrite) BOOL contentNeedsRedraw;

//	returns a YES if the dimensions of the drawable have changed
- (BOOL) reconfigureDrawable;

- (void) setNeedsDisplay;

//- (void) performDrawing:(VVRECT)r;
//	try to call this method, as it's the highest-level method.  if a UI item requires a multi-pass drawing approach, override this method to create and configure the multiple encoders...
- (void) performDrawing:(VVRECT)r onCommandQueue:(id<MTLCommandQueue>)q;
//	the main drawing method- by default it calls this methods on the receiver's vvSubviews, and then tells the receiver's spriteManager to draw
- (void) performDrawing:(VVRECT)r inEncoder:(id<MTLRenderCommandEncoder>)inEnc commandBuffer:(id<MTLCommandBuffer>)cb;
- (void) prepForDrawing;
- (void) finishedDrawing;
- (void) updateSprites;
- (VVRECT) backingBounds;	//	return a rect describing the # of pixels we're rendering
- (double) localToBackingBoundsMultiplier;

- (void) addVVSubview:(VVView *)n;
- (void) removeVVSubview:(VVView *)n;
- (BOOL) containsSubview:(VVView *)n;
- (VVView *) vvSubviewHitTest:(VVPOINT)p;
- (void) reconcileVVSubviewDragTypes;

@end




NS_ASSUME_NONNULL_END

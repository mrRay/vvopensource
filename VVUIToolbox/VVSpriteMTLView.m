//
//  VVSpriteMTLView.m
//  VVOpenSource
//
//  Created by testadmin on 4/25/23.
//

#import "VVSpriteMTLView.h"
#import "VVSpriteMTLViewShaderTypes.h"




#define A_HAS_B(a,b) (((a)&(b))==(b))

long		_spriteMTLViewSysVers;




@interface VVSpriteMTLView ()

@property (readwrite) double localToBackingBoundsMultiplier;
@property (strong,readwrite) MutLockArray *vvSubviews;
@property (strong,readwrite) NSEvent *lastMouseEvent;
@property (strong,readwrite) VVSpriteManager *spriteManager;
@property (readwrite) long mouseDownModifierFlags;
@property (readwrite) long modifierFlags;
@property (readwrite) BOOL mouseIsDown;
@property (readwrite) vector_uint2 viewportSize;

@end




@implementation VVSpriteMTLView


#pragma mark - class methods


+ (void) initialize	{
	_spriteMTLViewSysVers = [VVSysVersion majorSysVersion];
}


#pragma mark - init/teardown


- (instancetype) initWithFrame:(NSRect)frame	{
	self = [super initWithFrame:frame];
	if (self != nil)	{
		[self generalInit];
	}
	return self;
}
- (instancetype) initWithCoder:(NSCoder *)inCoder	{
	self = [super initWithCoder:inCoder];
	if (self != nil)	{
		[self generalInit];
	}
	return self;
}
- (void) generalInit	{
	//NSLog(@"%s ... %@",__func__,self);
	
	//	initialize thel ocal properties
	_deleted = NO;
	//_initialized = NO;
	//_flipped = NO;
	_localToBackingBoundsMultiplier = 1.0;
	_vvSubviews = [[MutLockArray alloc] init];
	_spritesNeedUpdate = YES;
	_lastMouseEvent = nil;
	//_clearColor = nil;
	_drawBorder = NO;
	//_borderColor = nil;
	_spriteManager = [[VVSpriteManager alloc] init];
	_mouseDownModifierFlags = 0;
	_mouseDownEventType = VVSpriteEventNULL;
	_modifierFlags = 0;
	_mouseIsDown = NO;
	_clickedSubview = nil;
	
	_device = nil;
	//self.pixelFormat = MTLPixelFormatRGBA32Float;	//	doesn't work (throws exception, invalid pixel format)
	self.pixelFormat = MTLPixelFormatBGRA8Unorm;
	//self.pixelFormat = MTLPixelFormatRGB10A2Unorm;	//	used this for a long time
	
	CGColorSpaceRef		tmpSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_709);
	//CGColorSpaceRef		tmpSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	
	//CGColorSpaceRef		tmpSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGBLinear);
	//CGColorSpaceRef		tmpSpace = CGColorSpaceCreateWithName(kCGColorSpaceLinearSRGB);
	//CGColorSpaceRef		tmpSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
	self.colorspace = tmpSpace;
	if (tmpSpace != NULL)
		CGColorSpaceRelease(tmpSpace);
	
	_viewportSize = simd_make_uint2(1,1);
	self.layerBackgroundColor = nil;
	self.mvpBuffer = nil;
	self.contentNeedsRedraw = NO;
	
	//	initialize the local ivars
	passDescriptor = [MTLRenderPassDescriptor new];
	passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
	passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
	passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
	pso = nil;
	metalLayer = [CAMetalLayer layer];
	//metalLayer.maximumDrawableCount = 2;
	//metalLayer.framebufferOnly = true;
	//NSLog(@"\t\tmetalLayer is now %@",metalLayer);
	currentDrawable = nil;
	dragNDropSubview = nil;
	for (long i=0;i<4;++i)	{
		clearColorVals[i] = (GLfloat)0.0;
		borderColorVals[i] = (GLfloat)0.0;
	}
	
	//	configure the CALayer stuff
	self.wantsLayer = YES;
	//self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawDuringViewResize;
	self.layerContentsRedrawPolicy = NSViewLayerContentsRedrawCrossfade;
	self.layer = metalLayer;
	//[self.layer addSublayer:metalLayer];	//	doesn't work!
	
	self.layer.delegate = self;
	
}
- (void) awakeFromNib	{
	NSLog(@"%s ... %@",__func__,self);
	_spritesNeedUpdate = YES;
}
- (void) prepareToBeDeleted	{
	NSMutableArray		*subCopy = [_vvSubviews lockCreateArrayCopy];
	if (subCopy != nil)	{
		for (id subview in subCopy)
			[self removeVVSubview:subview];
		[subCopy removeAllObjects];
	}
	dragNDropSubview = nil;
	
	if (_spriteManager != nil)
		[_spriteManager prepareToBeDeleted];
	_spritesNeedUpdate = NO;
	_deleted = YES;
}
- (void) dealloc	{
	//NSLog(@"%s ... %@",__func__,self);
	if (!_deleted)
		[self prepareToBeDeleted];
	self.colorspace = NULL;
}


#pragma mark - superclass overrides


+ (Class) layerClass	{
	//return [super layerClass];
	return [CAMetalLayer class];
}
- (void) viewDidChangeBackingProperties	{
	//NSLog(@"%s ... %@",__func__,self);
	[super viewDidChangeBackingProperties];
	[self reconfigureDrawable];
	[self setNeedsDisplay:YES];
}
- (void)viewDidMoveToWindow	{
	//NSLog(@"%s ... %@",__func__,self);
	if (_deleted)
		return;
	
	[super viewDidMoveToWindow];
	[self reconfigureDrawable];
	[self setNeedsDisplay:YES];
	
	if (_vvSubviews==nil || [_vvSubviews count]<1)
		return;
	[_vvSubviews rdlock];
	for (VVView *viewPtr in [_vvSubviews array])	{
		[viewPtr _viewDidMoveToWindow];
	}
	[_vvSubviews unlock];
	
	[self updateTrackingAreas];
}
- (void) updateTrackingAreas	{
	[super updateTrackingAreas];
	
	if (_deleted || _vvSubviews==nil || [_vvSubviews count]<1)
		return;
	[_vvSubviews rdlock];
	for (VVView *viewPtr in [_vvSubviews array])	{
		[viewPtr updateTrackingAreas];
	}
	[_vvSubviews unlock];
}
//- (void) setFrameSize:(NSSize)n	{
//	[super setFrameSize:n];
//	[self reconfigureDrawable];
//	[self setNeedsDisplay:YES];
//}
- (void) setBoundsSize:(NSSize)n	{
	[super setBoundsSize:n];
	[self reconfigureDrawable];
	[self setNeedsDisplay:YES];
}


- (BOOL) acceptsFirstMouse:(NSEvent *)theEvent	{
	return YES;
}
- (BOOL) isOpaque	{
	if (self.layerBackgroundColor == nil)
		return NO;
	return YES;
}
- (BOOL) acceptsFirstResponder	{
	return YES;
}
- (BOOL) becomeFirstResponder	{
	return YES;
}
- (BOOL) resignFirstResponder	{
	return YES;
}
- (BOOL) needsPanelToBecomeKey	{
	return YES;
}


- (CALayer *) makeBackingLayer	{
	return [CAMetalLayer layer];
}


- (void) setNeedsDisplay	{
	[self setNeedsDisplay:YES];
}
//@synthesize needsDisplay=myNeedsDisplay;
- (void) setNeedsDisplay:(BOOL)n	{
	//myNeedsDisplay = n;
	if (n)
		self.contentNeedsRedraw = YES;
	[super setNeedsDisplay:n];
	//if (n && self.delegate != nil)
	//	[self.delegate redrawView:self];
}


/*===================================================================================*/
#pragma mark --------------------- subview-related
/*------------------------------------*/


- (void) addVVSubview:(VVView *)n	{
	//NSLog(@"%s",__func__);
	if (_deleted || n==nil)
		return;
	if (![n isKindOfClass:[VVView class]])
		return;
	
	[_vvSubviews wrlock];
	if (![_vvSubviews containsIdenticalPtr:n])	{
		[_vvSubviews insertObject:n atIndex:0];
		[n setContainerView:self];
		[n _setSuperview:nil];
	}
	[_vvSubviews unlock];
	
	//	if the subviews i'm adding have any drag types, tell the container view to reconcile its drag types
	NSMutableArray		*tmpArray = MUTARRAY;
	[n _collectDragTypesInArray:tmpArray];
	if ([tmpArray count]>0)
		[self reconcileVVSubviewDragTypes];
	
	[self setNeedsDisplay:YES];
}
- (void) removeVVSubview:(VVView *)n	{
	//NSLog(@"%s",__func__);
	if (_deleted || n==nil)
		return;
	if (![n isKindOfClass:[VVView class]])
		return;
	id			tmpSubview = n;
	[_vvSubviews lockRemoveIdenticalPtr:tmpSubview];
	[tmpSubview setContainerView:nil];
	
	//	if there's a drag and drop subview (if i'm in the middle of a drag and drop action), i have to check if it's in the subview i'm removing!
	if (dragNDropSubview!=nil && [n containsSubview:dragNDropSubview])	{
		[dragNDropSubview draggingExited:nil];
		dragNDropSubview = nil;
	}
	//	if the subviews i'm adding have any drag types, tell the container view to reconcile its drag types
	NSMutableArray		*tmpArray = MUTARRAY;
	[tmpSubview _collectDragTypesInArray:tmpArray];
	if ([tmpArray count]>0)
		[self reconcileVVSubviewDragTypes];
}
- (BOOL) containsSubview:(VVView *)n	{
	if (_deleted || n==nil || _vvSubviews==nil)
		return NO;
	BOOL		returnMe = NO;
	[_vvSubviews rdlock];
	for (VVView *viewPtr in [_vvSubviews array])	{
		if (viewPtr==n || [viewPtr containsSubview:n])	{
			returnMe = YES;
			break;
		}
	}
	[_vvSubviews unlock];
	return returnMe;
}
- (VVView *) vvSubviewHitTest:(VVPOINT)p	{
	//NSLog(@"%s ... (%f, %f)",__func__,p.x,p.y);
	if (_deleted || _vvSubviews==nil)
		return nil;
	
	id					returnMe = nil;
	//	run from "top" view to bottom, checking to see if the point lies within any of the views
	[_vvSubviews rdlock];
	for (VVView *viewPtr in [_vvSubviews array])	{
		VVRECT			tmpFrame = [viewPtr frame];
		//VVRectLog(@"\t\tview's frame is",tmpFrame);
		if (VVPOINTINRECT(p,tmpFrame))	{
			returnMe = [viewPtr vvSubviewHitTest:p];
			if (returnMe != nil)
				break;
		}
	}
	[_vvSubviews unlock];
	
	return returnMe;
}
- (void) reconcileVVSubviewDragTypes	{
	//NSLog(@"%s",__func__);
	if (_deleted || _vvSubviews==nil)
		return;
	NSMutableArray		*tmpArray = [NSMutableArray arrayWithCapacity:0];
	[_vvSubviews rdlock];
	for (VVView *viewPtr in [_vvSubviews array])	{
		[viewPtr _collectDragTypesInArray:tmpArray];
	}
	[_vvSubviews unlock];
	
	[self unregisterDraggedTypes];
	[self registerForDraggedTypes:tmpArray];
}


/*===================================================================================*/
#pragma mark --------------------- NSDraggingDestination protocol
/*------------------------------------*/


- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	if (_deleted || _vvSubviews==nil || [_vvSubviews count]<1)
		return NSDragOperationNone;
	//	get the dragging pasteboard
	NSPasteboard		*pboard = [sender draggingPasteboard];
	if (pboard == nil)
		return NSDragOperationNone;
	//	get the array of drag types
	NSArray				*dragTypes = [pboard types];
	if (dragTypes==nil || [dragTypes count]<1)
		return NSDragOperationNone;
	//	...the reported dragging point is in window coords- convert it to my local coords
	VVPOINT				dragPoint = [sender draggingLocation];
	NSView				*winCV = [[self window] contentView];
	dragPoint = [self convertPoint:dragPoint fromView:winCV];
	//	check to see if there's a subview under the dragged point
	id					matchingSubview = [self vvSubviewHitTest:dragPoint];
	MutLockArray		*viewDragTypes = (matchingSubview==nil) ? nil : [matchingSubview dragTypes];
	if (viewDragTypes != nil)	{
		[viewDragTypes rdlock];
		BOOL				matchesDragType = NO;
		for (NSString *dragType in dragTypes)	{
			if ([viewDragTypes containsObject:dragType])	{
				matchesDragType = YES;
				break;
			}
		}
		[viewDragTypes unlock];
		//	if the subview under the cursor matches the drag type, i'm going to work with it...
		if (matchesDragType)	{
			dragNDropSubview = matchingSubview;
			return [dragNDropSubview draggingEntered:sender];
		}
	}
	return NSDragOperationNone;
}
- (NSDragOperation) draggingUpdated:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	if (_deleted || _vvSubviews==nil || [_vvSubviews count]<1)
		return NSDragOperationNone;
	//	get the dragging pasteboard
	NSPasteboard		*pboard = [sender draggingPasteboard];
	if (pboard == nil)
		return NSDragOperationNone;
	//	get the array of drag types
	NSArray				*dragTypes = [pboard types];
	if (dragTypes==nil || [dragTypes count]<1)
		return NSDragOperationNone;
	//	...the reported dragging point is in the display backing coords
	VVPOINT				dragPoint = [sender draggingLocation];
	NSView				*winCV = [[self window] contentView];
	dragPoint = [self convertPoint:dragPoint fromView:winCV];
	//	check to see if there's a subview under the dragged point
	id					matchingSubview = [self vvSubviewHitTest:dragPoint];
	//	if it's the same subview i'm already doing a drag-and-drop with, just update it & return!
	if (dragNDropSubview!=nil && matchingSubview==dragNDropSubview)
		return [dragNDropSubview draggingUpdated:sender];
	
	
	//	...if i'm here, then i'm either dragging and dropping on a different- or on no!- subview...
	
	
	//	finish the drag on the old...
	if (dragNDropSubview != nil)
		[dragNDropSubview draggingExited:nil];
	dragNDropSubview = nil;
	
	//	now check to see if i should be starting a drag on this new view!
	MutLockArray		*viewDragTypes = (matchingSubview==nil) ? nil : [matchingSubview dragTypes];
	if (viewDragTypes != nil)	{
		[viewDragTypes rdlock];
		BOOL				matchesDragType = NO;
		for (NSString *dragType in dragTypes)	{
			if ([viewDragTypes containsObject:dragType])	{
				matchesDragType = YES;
				break;
			}
		}
		[viewDragTypes unlock];
		//	if the subview under the cursor matches the drag type, i'm going to work with it...
		if (matchesDragType)	{
			dragNDropSubview = matchingSubview;
			return [dragNDropSubview draggingEntered:sender];
		}
	}
	return NSDragOperationNone;
}
- (void) draggingExited:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	if (_deleted || dragNDropSubview==nil)
		return;
	[dragNDropSubview draggingExited:sender];
}
- (void) draggingEnded:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	if (_deleted || dragNDropSubview==nil)
		return;
	[dragNDropSubview draggingEnded:sender];
}

- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	if (_deleted || dragNDropSubview==nil)
		return NO;
	return [dragNDropSubview prepareForDragOperation:sender];
}
- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	if (_deleted || dragNDropSubview==nil)
		return NO;
	return [dragNDropSubview performDragOperation:sender];
}
- (void) concludeDragOperation:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	if (_deleted || dragNDropSubview==nil)
		return;
	[dragNDropSubview concludeDragOperation:sender];
}


/*===================================================================================*/
#pragma mark --------------------- frame-related
/*------------------------------------*/


- (void) setFrame:(VVRECT)f	{
	//NSLog(@"%s ... %@, %@",__func__,self,NSStringFromRect(f));
	if (_deleted)
		return;
	//pthread_mutex_lock(&glLock);
		[super setFrame:f];
		//[self updateSprites];
		//_spritesNeedUpdate = YES;
		self.spritesNeedUpdate = YES;
		//needsReshape = YES;
		//initialized = NO;
	//pthread_mutex_unlock(&glLock);
	
	//	update the bounds to real bounds multiplier
	//BOOL		backingBoundsChanged = NO;
	//if (_spriteGLViewSysVers>=7 && [(id)self wantsBestResolutionOpenGLSurface])	{
	//	VVRECT		bounds = [self bounds];
	//	VVRECT		backingBounds = [(id)self convertRectToBacking:bounds];
	//	double		tmpDouble;
	//	tmpDouble = (backingBounds.size.width/bounds.size.width);
	//	if (tmpDouble != _localToBackingBoundsMultiplier)
	//		backingBoundsChanged = YES;
	//	_localToBackingBoundsMultiplier = tmpDouble;
	//}
	//else	{
	//	if (localToBackingBoundsMultiplier != 1.0)
	//		backingBoundsChanged = YES;
	//	localToBackingBoundsMultiplier = 1.0;
	//}
	//NSLog(@"\t\t%s, local to backing multiplier is %f for %@",__func__,localToBackingBoundsMultiplier,self);
	
	//[_vvSubviews rdlock];
	//if (backingBoundsChanged)	{
	//	for (VVView *viewPtr in [_vvSubviews array])	{
	//		[viewPtr setLocalToBackingBoundsMultiplier:localToBackingBoundsMultiplier];
	//	}
	//}
	//[_vvSubviews unlock];
	//NSLog(@"\t\t%s, BTRBM is %f for %@",__func__,localToBackingBoundsMultiplier,self);
	
	//NSLog(@"\t\t%s - FINISHED",__func__);
}
- (void) setFrameSize:(VVSIZE)n	{
	//NSLog(@"%s ... %@, %@",__func__,self,NSStringFromSize(n));
	VVSIZE			oldSize = [self frame].size;
	double			oldBackingBounds = _localToBackingBoundsMultiplier;
	
	[super setFrameSize:n];
	[self reconfigureDrawable];
	
	BOOL			backingBoundsChanged = (oldBackingBounds != _localToBackingBoundsMultiplier);
	
	if ([self autoresizesSubviews])	{
		double		widthDelta = n.width - oldSize.width;
		double		heightDelta = n.height - oldSize.height;
		[_vvSubviews rdlock];
		for (VVView *viewPtr in [_vvSubviews array])	{
			VVViewResizeMask	viewResizeMask = [viewPtr autoresizingMask];
			VVRECT				viewNewFrame = [viewPtr frame];
			//VVRectLog(@"\t\torig viewNewFrame is",viewNewFrame);
			int					hSubDivs = 0;
			int					vSubDivs = 0;
			if (A_HAS_B(viewResizeMask,VVViewResizeMinXMargin))
				++hSubDivs;
			if (A_HAS_B(viewResizeMask,VVViewResizeMaxXMargin))
				++hSubDivs;
			if (A_HAS_B(viewResizeMask,VVViewResizeWidth))
				++hSubDivs;
			
			if (A_HAS_B(viewResizeMask,VVViewResizeMinYMargin))
				++vSubDivs;
			if (A_HAS_B(viewResizeMask,VVViewResizeMaxYMargin))
				++vSubDivs;
			if (A_HAS_B(viewResizeMask,VVViewResizeHeight))
				++vSubDivs;
			
			if (hSubDivs>0 || vSubDivs>0)	{
				if (hSubDivs>0 && A_HAS_B(viewResizeMask,VVViewResizeWidth))
					viewNewFrame.size.width += widthDelta/hSubDivs;
				if (vSubDivs>0 && A_HAS_B(viewResizeMask,VVViewResizeHeight))
					viewNewFrame.size.height += heightDelta/vSubDivs;
				if (A_HAS_B(viewResizeMask,VVViewResizeMinXMargin))
					viewNewFrame.origin.x += widthDelta/hSubDivs;
				if (A_HAS_B(viewResizeMask,VVViewResizeMinYMargin))
					viewNewFrame.origin.y += heightDelta/vSubDivs;
			}
			//VVRectLog(@"\t\tmod viewNewFrame is",viewNewFrame);
			[viewPtr setFrame:viewNewFrame];
		}
		[_vvSubviews unlock];
	}
	
	if (backingBoundsChanged || !NSEqualSizes(oldSize,n))	{
		//NSLog(@"\t\tsized changed!");
		//	update the bounds to real bounds multiplier
		//if (_spriteGLViewSysVers>=7 && [(id)self wantsBestResolutionOpenGLSurface])	{
		//	VVRECT		bounds = [self bounds];
		//	VVRECT		backingBounds = [(id)self convertRectToBacking:bounds];
		//	_localToBackingBoundsMultiplier(backingBounds.size.width/bounds.size.width);
		//}
		//else
		//	_localToBackingBoundsMultiplier1.0;
		//NSLog(@"\t\t%s, local to backing multiplier is %f for %@",__func__,_localToBackingBoundsMultiplier,self);
		
		[_vvSubviews rdlock];
		for (VVView *viewPtr in [_vvSubviews array])	{
			[viewPtr setLocalToBackingBoundsMultiplier:_localToBackingBoundsMultiplier];
		}
		[_vvSubviews unlock];
		//NSLog(@"\t\t%s, BTRBM is %f for %@",__func__,_localToBackingBoundsMultiplier,self);
		
		//pthread_mutex_lock(&glLock);
		//initialized = NO;
		//pthread_mutex_unlock(&glLock);
	}
	
	[self updateSprites];
	//self.spritesNeedUpdate = YES;
	[self setNeedsDisplay:YES];
}
- (void) updateSprites	{
	_spritesNeedUpdate = NO;
}


- (VVRECT) backingBounds	{
	//if (_spriteGLViewSysVers >= 7)
		return [(id)self convertRectToBacking:[self bounds]];
	//else
	//	return [self bounds];
}


/*===================================================================================*/
#pragma mark --------------------- UI
/*------------------------------------*/


- (void) mouseDown:(NSEvent *)e	{
	//NSLog(@"%s",__func__);
	if (_deleted)
		return;
	VVRELEASE(_lastMouseEvent);
	if (e != nil)
		_lastMouseEvent = e;
	_mouseIsDown = YES;
	VVPOINT		locationInWindow = [e locationInWindow];
	VVPOINT		localPoint = [self convertPoint:locationInWindow fromView:nil];
	//localPoint = VVMAKEPOINT(localPoint.x*_localToBackingBoundsMultiplier, localPoint.y*_localToBackingBoundsMultiplier);
	//VVPointLog(@"\t\tlocalPoint is",localPoint);
	//	if i have subviews and i clicked on one of them, skip the sprite manager
	if ([_vvSubviews count]>0)	{
		_clickedSubview = [self vvSubviewHitTest:localPoint];
		if (_clickedSubview == (id)self)
			_clickedSubview = nil;
		//NSLog(@"\t\tclickedSubview is %@",_clickedSubview);
		//VVRectLog(@"\t\tclickedSubview frame is",[_clickedSubview frame]);
		if (_clickedSubview != nil)	{
			[_clickedSubview mouseDown:e];
			return;
		}
	}
	//	else there aren't any subviews or i didn't click on any of them- do the sprite manager...
	//	convert the local point to use this view's bounds (may be different than frame for retina displays)
	localPoint = VVMAKEPOINT(localPoint.x*_localToBackingBoundsMultiplier, localPoint.y*_localToBackingBoundsMultiplier);
	//VVPointLog(@"\t\tmodified localPoint is",localPoint);
	_mouseDownModifierFlags = [e modifierFlags];
	_modifierFlags = _mouseDownModifierFlags;
	if ((_mouseDownModifierFlags&NSEventModifierFlagControl)==NSEventModifierFlagControl)	{
		_mouseDownEventType = VVSpriteEventRightDown;
		[_spriteManager localRightMouseDown:localPoint modifierFlag:_mouseDownModifierFlags];
	}
	else	{
		if ([e clickCount]>=2)	{
			_mouseDownEventType = VVSpriteEventDouble;
			[_spriteManager localMouseDoubleDown:localPoint modifierFlag:_mouseDownModifierFlags];
		}
		else	{
			_mouseDownEventType = VVSpriteEventDown;
			[_spriteManager localMouseDown:localPoint modifierFlag:_mouseDownModifierFlags];
		}
	}
}
- (void) mouseUp:(NSEvent *)e	{
	if (_deleted)
		return;
	
	if (_mouseDownEventType == VVSpriteEventRightDown)	{
		[self rightMouseUp:e];
		return;
	}
	
	VVRELEASE(_lastMouseEvent);
	if (e != nil)
		_lastMouseEvent = e;
	
	_modifierFlags = [e modifierFlags];
	_mouseIsDown = NO;
	VVPOINT		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//localPoint = VVMAKEPOINT(localPoint.x*_localToBackingBoundsMultiplier, localPoint.y*_localToBackingBoundsMultiplier);
	//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
	if (_clickedSubview != nil)
		[_clickedSubview mouseUp:e];
	else	{
		//	convert the local point to use this view's bounds (may be different than frame for retina displays)
		localPoint = VVMAKEPOINT(localPoint.x*_localToBackingBoundsMultiplier, localPoint.y*_localToBackingBoundsMultiplier);
		[_spriteManager localMouseUp:localPoint];
	}
}
- (void) rightMouseDown:(NSEvent *)e	{
	//NSLog(@"%s",__func__);
	if (_deleted)
		return;
	VVRELEASE(_lastMouseEvent);
	if (e != nil)
		_lastMouseEvent = e;
	_mouseIsDown = YES;
	VVPOINT		locationInWindow = [e locationInWindow];
	VVPOINT		localPoint = [self convertPoint:locationInWindow fromView:nil];
	//localPoint = VVMAKEPOINT(localPoint.x*_localToBackingBoundsMultiplier, localPoint.y*_localToBackingBoundsMultiplier);
	//VVPointLog(@"\t\tlocalPoint is",localPoint);
	//	if i have subviews and i clicked on one of them, skip the sprite manager
	if ([_vvSubviews count]>0)	{
		_clickedSubview = [self vvSubviewHitTest:localPoint];
		//NSLog(@"\t\tclickedSubview is %@",[_clickedSubview class]);
		if (_clickedSubview == (id)self)
			_clickedSubview = nil;
		if (_clickedSubview != nil)	{
			[_clickedSubview rightMouseDown:e];
			return;
		}
	}
	
	//	convert the local point to use this view's bounds (may be different than frame for retina displays)
	localPoint = VVMAKEPOINT(localPoint.x*_localToBackingBoundsMultiplier, localPoint.y*_localToBackingBoundsMultiplier);
	
	_mouseDownModifierFlags = [e modifierFlags];
	_mouseDownEventType = VVSpriteEventRightDown;
	_modifierFlags = _mouseDownModifierFlags;
	//	else there aren't any subviews or i didn't click on any of them- do the sprite manager
	[_spriteManager localRightMouseDown:localPoint modifierFlag:_mouseDownModifierFlags];
}
- (void) rightMouseUp:(NSEvent *)e	{
	if (_deleted)
		return;
	VVRELEASE(_lastMouseEvent);
	if (e != nil)
		_lastMouseEvent = e;
	_mouseIsDown = NO;
	VVPOINT		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//localPoint = VVMAKEPOINT(localPoint.x*_localToBackingBoundsMultiplier, localPoint.y*_localToBackingBoundsMultiplier);
	//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
	if (_clickedSubview != nil)
		[_clickedSubview rightMouseUp:e];
	else	{
		//	convert the local point to use this view's bounds (may be different than frame for retina displays)
		localPoint = VVMAKEPOINT(localPoint.x*_localToBackingBoundsMultiplier, localPoint.y*_localToBackingBoundsMultiplier);
		[_spriteManager localRightMouseUp:localPoint];
	}
}
- (void) mouseDragged:(NSEvent *)e	{
	if (_deleted)
		return;
	VVRELEASE(_lastMouseEvent);
	if (e != nil)//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
		_lastMouseEvent = e;
	
	_modifierFlags = [e modifierFlags];
	VVPOINT		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//localPoint = VVMAKEPOINT(localPoint.x*_localToBackingBoundsMultiplier, localPoint.y*_localToBackingBoundsMultiplier);
	//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
	if (_clickedSubview != nil)
		[_clickedSubview mouseDragged:e];
	else	{
		//	convert the local point to use this view's bounds (may be different than frame for retina displays)
		localPoint = VVMAKEPOINT(localPoint.x*_localToBackingBoundsMultiplier, localPoint.y*_localToBackingBoundsMultiplier);
		[_spriteManager localMouseDragged:localPoint];
	}
}
- (void) rightMouseDragged:(NSEvent *)e	{
	if (_deleted)
		return;
	VVRELEASE(_lastMouseEvent);
	if (e != nil)//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
		_lastMouseEvent = e;
	
	_modifierFlags = [e modifierFlags];
	VVPOINT		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//localPoint = VVMAKEPOINT(localPoint.x*_localToBackingBoundsMultiplier, localPoint.y*_localToBackingBoundsMultiplier);
	//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
	if (_clickedSubview != nil)
		[_clickedSubview rightMouseDragged:e];
	else	{
		//	convert the local point to use this view's bounds (may be different than frame for retina displays)
		localPoint = VVMAKEPOINT(localPoint.x*_localToBackingBoundsMultiplier, localPoint.y*_localToBackingBoundsMultiplier);
		[_spriteManager localMouseDragged:localPoint];
	}
}
- (void) scrollWheel:(NSEvent *)e	{
	//NSLog(@"%s",__func__);
	if (_deleted)
		return;
	
	//	find the view under the event location, call "scrollWheel:" on it
	VVPOINT		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//VVPointLog(@"\t\tlocalPoint is",localPoint);
	if ([_vvSubviews count]>0)	{
		VVView		*scrollSubview = [self vvSubviewHitTest:localPoint];
		//NSLog(@"\t\tscrollSubview is %@",scrollSubview);
		if (scrollSubview==(id)self)
			scrollSubview=nil;
		if (scrollSubview != nil)
			[scrollSubview scrollWheel:e];
	}
}
- (void) scrollLineDown:(id)s	{
	NSLog(@"%s",__func__);
}
- (void) scrollLineUp:(id)s	{
	NSLog(@"%s",__func__);
}
- (void) scrollPageDown:(id)s	{
	NSLog(@"%s",__func__);
}
- (void) scrollPageUp:(id)s	{
	NSLog(@"%s",__func__);
}


#pragma mark - drawing backend


- (BOOL) reconfigureDrawable	{
	//NSLog(@"%s ... %@",__func__,self);
	
	//	we have to find the screen our window is on (so we can get its pixel density)...but there's a catch: 
	//	if the window isn't open, calling "self.window.screen" returns nil- even though the window has a 
	//	frame and can figure out what screen it's on.  so: if we can't find the screen, we work around this 
	//	by comparing the window and screen bounds and locating the screen manually.
	NSWindow		*tmpWin = self.window;
	NSScreen		*tmpScreen = tmpWin.screen;
	if (tmpScreen == nil)	{
		
		//	...this was lifted verbatim from VVCore's NSScreenAdditions, i just don't want to add the dependency and it's simple enough...
		NSScreen* (^ScreenForWindowFrame)(NSRect) = ^(NSRect n)	{
			//NSLog(@"%s ... %@",__func__,NSStringFromRect(n));
			if (n.size.width == 0. && n.size.height == 0.)
				return (NSScreen*)nil;
			
			NSMutableArray<NSScreen*>		*overlappedScreens = [NSMutableArray new];
			NSMutableArray<NSNumber*>		*overlappedScreenAmounts = [NSMutableArray new];
			
			for (NSScreen * screen in [NSScreen screens])	{
				NSRect		screenFrame = screen.frame;
				//NSLog(@"\t\tscreenFrame is %@",NSStringFromRect(screenFrame));
				NSRect		overlap = NSIntersectionRect(n, screenFrame);
				//NSLog(@"\t\toverlap is %@",NSStringFromRect(overlap));
				if (overlap.size.width==0. && overlap.size.height==0.)
					continue;
				[overlappedScreens addObject:screen];
				[overlappedScreenAmounts addObject:@( (overlap.size.width * overlap.size.height)/(n.size.width * n.size.height) )];
			}
			
			if (overlappedScreens.count < 1)
				return (NSScreen*)nil;
			NSScreen			*mainScreen = nil;
			NSNumber			*mainScreenAmount = nil;
			NSEnumerator		*screenIt = [overlappedScreens objectEnumerator];
			NSEnumerator		*screenAmountIt = [overlappedScreenAmounts objectEnumerator];
			NSScreen			*screenPtr = [screenIt nextObject];
			NSNumber			*screenAmountPtr = [screenAmountIt nextObject];
			while (screenPtr != nil && screenAmountPtr != nil)	{
				if (mainScreen == nil)	{
					mainScreen = screenPtr;
					mainScreenAmount = screenAmountPtr;
				}
				else	{
					if (screenAmountPtr.doubleValue > mainScreenAmount.doubleValue)	{
						mainScreen = screenPtr;
						mainScreenAmount = screenAmountPtr;
					}
				}
				
				screenPtr = [screenIt nextObject];
				screenAmountPtr = [screenAmountIt nextObject];
			}
			
			return mainScreen;
		};
		
		tmpScreen = ScreenForWindowFrame(tmpWin.frame);
	}
	CGFloat			scale = tmpScreen.backingScaleFactor;
	self.localToBackingBoundsMultiplier = scale;
	
	//NSLog(@"\t\tscreen is %@, window is %@, scale is %0.2f", self.window.screen, self.window, scale);
	
	//NSLog(@"\t\tbounds are %@",NSStringFromRect(self.bounds));
	CGSize			newSize = self.bounds.size;
	newSize.width *= scale;
	newSize.height *= scale;
	
	BOOL			returnMe = (newSize.width!=_viewportSize.x || newSize.height!=_viewportSize.y) ? YES : NO;
	
	metalLayer.drawableSize = newSize;
	_viewportSize.x = newSize.width;
	_viewportSize.y = newSize.height;
	self.mvpBuffer = nil;
	
	self.contentNeedsRedraw = YES;
	
	return returnMe;
}


#pragma mark - drawing frontend


//- (void) performDrawing:(VVRECT)r	{
//}
- (void) performDrawing:(VVRECT)r onCommandQueue:(id<MTLCommandQueue>)q	{
	if (pso == nil || _device == nil)
		return;
	if (q == nil)
		return;
	
	currentDrawable = metalLayer.nextDrawable;
	if (currentDrawable == nil)
		return;
	
	
#define CAPTURE 0
#if CAPTURE
	MTLCaptureManager		*cm = nil;
	static int				counter = 0;
	++counter;
	//if (counter > 10)
	//	return;
	if (counter == 10)
		cm = [MTLCaptureManager sharedCaptureManager];
	MTLCaptureDescriptor		*desc = [[MTLCaptureDescriptor alloc] init];
	desc.captureObject = q;
	
	if (cm != nil)	{
		if ([cm startCaptureWithDescriptor:desc error:nil])	{
			NSLog(@"SUCCESS: started capturing metal data");
		}
		else	{
			NSLog(@"ERR: couldn't start capturing metal data");
		}
	}
	else	{
	}
#endif
	
	
	id<MTLCommandBuffer>		cmdBuffer = [q commandBuffer];
	
	passDescriptor.colorAttachments[0].texture = currentDrawable.texture;
	
	id<MTLRenderCommandEncoder>		encoder = [cmdBuffer renderCommandEncoderWithDescriptor:passDescriptor];
	encoder.label = self.description;
	[encoder setViewport:(MTLViewport){ 0.f, 0.f, _viewportSize.x, _viewportSize.y, -1.f, 1.f }];
	[encoder setRenderPipelineState:pso];
	
	[self performDrawing:r inEncoder:encoder commandBuffer:cmdBuffer];
	
	[encoder endEncoding];
	[cmdBuffer presentDrawable:currentDrawable];
	
	[cmdBuffer commit];
	
	currentDrawable = nil;
	
	
#if CAPTURE
	if (cm != nil)	{
		NSLog(@"STOPPING CAPTURE, WAITING TO BE COMPLETE...");
		[cm stopCapture];
		[cmdBuffer waitUntilCompleted];
		NSLog(@"...CMD BUFFER COMPLETE");
	}
#endif
}
- (void) performDrawing:(VVRECT)r inEncoder:(id<MTLRenderCommandEncoder>)inEnc commandBuffer:(id<MTLCommandBuffer>)cb	{
	//NSLog(@"%s ... %@, %p, %p",__func__,NSStringFromRect(r),inEnc,cb);
	//NSLog(@"%s ... %@",__func__,NSStringFromRect(r));
	
	cmdBuffer = cb;
	encoder = inEnc;
	//	ALWAYS include the following line in your subclass overrides of this method:
	//self.contentNeedsRedraw = NO;
	
	
	if (_deleted)	{
		cmdBuffer = nil;
		encoder = nil;
		return;
	}
	
	id			myWin = [self window];
	if (myWin == nil)	{
		cmdBuffer = nil;
		encoder = nil;
		return;
	}
	
	//	apply the MVP buffer- all our sprites/subviews will draw using these coords, and are expected to perform geometry that has already been positioned accordingly
	if (self.mvpBuffer == nil)	{
		double			left = 0.0;
		double			right = _viewportSize.x;
		double			top = _viewportSize.y;
		double			bottom = 0.0;
		double			far = 1.0;
		double			near = -1.0;
		BOOL		flipV = NO;
		BOOL		flipH = NO;
		if (flipV)	{
			top = 0.0;
			bottom = _viewportSize.y;
		}
		if (flipH)	{
			right = 0.0;
			left = _viewportSize.x;
		}
		matrix_float4x4			mvp = simd_matrix_from_rows(
			//	old and busted
			//simd_make_float4( 2.0/(right-left), 0.0, 0.0, -1.0*(right+left)/(right-left) ),
			//simd_make_float4( 0.0, 2.0/(top-bottom), 0.0, -1.0*(top+bottom)/(top-bottom) ),
			//simd_make_float4( 0.0, 0.0, -2.0/(far-near), -1.0*(far+near)/(far-near) ),
			//simd_make_float4( 0.0, 0.0, 0.0, 1.0 )
			
			//	left-handed coordinate ortho!
			//simd_make_float4(	2.0/(right-left),	0.0,				0.0,				(right+left)/(left-right) ),
			//simd_make_float4(	0.0,				2.0/(top-bottom),	0.0,				(top+bottom)/(bottom-top) ),
			//simd_make_float4(	0.0,				0.0,				2.0/(far-near),	(near)/(near-far) ),
			//simd_make_float4(	0.0,				0.0,				0.0,				1.0 )
			
			//	right-handed coordinate ortho!
			simd_make_float4(	2.0/(right-left),	0.0,				0.0,				(right+left)/(left-right) ),
			simd_make_float4(	0.0,				2.0/(top-bottom),	0.0,				(top+bottom)/(bottom-top) ),
			simd_make_float4(	0.0,				0.0,				-2.0/(far-near),	(near)/(near-far) ),
			simd_make_float4(	0.0,				0.0,				0.0,				1.0 )
			
		);
	
		self.mvpBuffer = [metalLayer.device
			newBufferWithBytes:&mvp
			length:sizeof(mvp)
			options:MTLResourceStorageModeShared];
	}
	[inEnc
		setVertexBuffer:self.mvpBuffer
		offset:0
		atIndex:VVSpriteMTLView_VS_Idx_MVPMatrix];
	
	//	if the sprites need to be updated, do so now...this should probably be done inside the gl lock!
	if (_spritesNeedUpdate)
		[self updateSprites];
	
	[self prepForDrawing];
	
	//	clear the view
	//glClearColor(clearColorVals[0],clearColorVals[1],clearColorVals[2],clearColorVals[3]);
	//glClear(GL_COLOR_BUFFER_BIT);
	
	//	tell the sprite manager to start drawing the sprites
	if (_spriteManager != nil)	{
		//if (_spriteGLViewSysVers >= 7)	{
			//[_spriteManager drawRect:[(id)self convertRectToBacking:r]];
			//[_spriteManager drawRect:[(id)self convertRectToBacking:r] inContext:cgl_ctx];
			[_spriteManager drawRect:[(id)self convertRectToBacking:r] inEncoder:inEnc commandBuffer:cb];
		//}
		//else	{
		//	//[_spriteManager drawRect:r];
		//	[_spriteManager drawRect:r inContext:cgl_ctx];
		//}
	}
	
	
	//	tell the subviews to draw
	[_vvSubviews rdlock];
	if ([_vvSubviews count]>0)	{
		//	run through my subviews (backwards)
		NSEnumerator		*it = [[_vvSubviews array] reverseObjectEnumerator];
		VVView				*viewPtr;
		while (viewPtr = [it nextObject])	{
			//	if the frame of this subview intersects the rect i'm being asked to draw, tell the subview to draw
			VVRECT				viewFrameInMyLocalBounds = [viewPtr frame];
			VVRECT				intersectRectInMyLocalBounds = VVINTERSECTIONRECT(r,viewFrameInMyLocalBounds);
			if (intersectRectInMyLocalBounds.size.width>0 && intersectRectInMyLocalBounds.size.height>0)	{
				//	convert the intersection rect into the container view's coordinate space, and ensure that the rect has positive dimensions
				NSRect				intersectionRectInViewBounds = [viewPtr convertRectFromSuperviewCoords:intersectRectInMyLocalBounds];
				//	make sure that the rect's dimensions or positive, or it won't draw!
				//intersectionRectInViewBounds = NSPositiveDimensionsRect(intersectionRectInViewBounds);
				intersectionRectInViewBounds = NSIntegralPositiveDimensionsRect(intersectionRectInViewBounds);
				[viewPtr _drawRect:intersectionRectInViewBounds inEncoder:inEnc commandBuffer:cb];
			}
		}
		
	}
	[_vvSubviews unlock];
	
	
	
	//	if appropriate, draw the border
	if (_drawBorder)	{
		//glColor4f(borderColorVals[0],borderColorVals[1],borderColorVals[2],borderColorVals[3]);
		//glEnableClientState(GL_VERTEX_ARRAY);
		//glDisableClientState(GL_TEXTURE_COORD_ARRAY);
		//GLSTROKERECT([self backingBounds]);
	}
	
	
	//	call 'finishedDrawing' so subclasses of me have a chance to perform post-draw cleanup
	[self finishedDrawing];
	
	//else
	//	NSLog(@"\t\terr: sprite GL view fence prevented output!");
	
	self.contentNeedsRedraw = NO;
	
	cmdBuffer = nil;
	encoder = nil;
	
	//pthread_mutex_unlock(&glLock);
}


/*	these methods exist so subclasses of me have an opportunity to do something before/after drawing 
	has completed.  this is particularly handy with the GL view, as drawing does not complete- and 
	therefore resources have to stay available- until after glFlush() has been called.		*/
- (void) prepForDrawing	{
}
- (void) finishedDrawing	{
}


#pragma mark - key-value overrides


- (void) setSpritesNeedUpdate	{
	self.spritesNeedUpdate = YES;
}
- (void) setClearColor:(NSColor *)c	{
	if ((_deleted)||(c==nil))
		return;
	NSColorSpace	*devRGBColorSpace = [NSColorSpace deviceRGBColorSpace];
	NSColor			*calibratedColor = ((__bridge void *)[c colorSpace]==(__bridge void *)devRGBColorSpace) ? c :[c colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	CGFloat			tmpVals[4];
	[calibratedColor getComponents:(CGFloat *)tmpVals];
	
	//pthread_mutex_lock(&glLock);
	//CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
	for (int i=0;i<4;++i)
		clearColorVals[i] = tmpVals[i];
	//glClearColor(clearColorVals[0],clearColorVals[1],clearColorVals[2],clearColorVals[3]);
	//pthread_mutex_unlock(&glLock);
}
//@synthesize clearColor=_clearColor;
- (NSColor *) clearColor	{
	if (_deleted)
		return nil;
	return [NSColor colorWithDeviceRed:clearColorVals[0] green:clearColorVals[1] blue:clearColorVals[2] alpha:clearColorVals[3]];
}
- (void) setClearColors:(GLfloat)r :(GLfloat)g :(GLfloat)b :(GLfloat)a	{
	//pthread_mutex_lock(&glLock);
	clearColorVals[0] = r;
	clearColorVals[1] = g;
	clearColorVals[2] = b;
	clearColorVals[3] = a;
	//pthread_mutex_unlock(&glLock);
}
- (void) getClearColors:(GLfloat *)n	{
	if (n==nil)
		return;
	for (int i=0; i<4; ++i)
		*(n+i)=clearColorVals[i];
}
@synthesize drawBorder=_drawBorder;
- (void) setBorderColor:(NSColor *)c	{
	if ((_deleted)||(c==nil))
		return;
	NSColorSpace	*devRGBColorSpace = [NSColorSpace deviceRGBColorSpace];
	NSColor			*calibratedColor = ((__bridge void *)[c colorSpace]==(__bridge void *)devRGBColorSpace) ? c :[c colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	CGFloat			tmpColor[4];
	[calibratedColor getComponents:tmpColor];
	
	//pthread_mutex_lock(&glLock);
	//CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
	[calibratedColor getComponents:(CGFloat *)borderColorVals];
	for (int i=0; i<4; ++i)
		borderColorVals[i] = tmpColor[i];
	//glClearColor(clearColorVals[0],clearColorVals[1],clearColorVals[2],clearColorVals[3]);
	//pthread_mutex_unlock(&glLock);
}
- (NSColor *) borderColor	{
	if (_deleted)
		return nil;
	return [NSColor colorWithDeviceRed:borderColorVals[0] green:borderColorVals[1] blue:borderColorVals[2] alpha:borderColorVals[3]];
}
//	used to work around the fact that NSViews don't get a "mouseUp" when they open a contextual menu
- (void) _setMouseIsDown:(BOOL)n	{
	self.mouseIsDown = n;
}


@synthesize device=_device;
- (void) setDevice:(id<MTLDevice>)n	{
	_device = n;
	
	metalLayer.device = _device;
	
	metalLayer.pixelFormat = self.pixelFormat;
	
	//if (self.colorspace != NULL)	{
		metalLayer.colorspace = self.colorspace;
	//}
	
	//	subclasses should override this method, call the super, and then make the pso here
	
	NSError				*nsErr = nil;
	NSBundle			*myBundle = [NSBundle bundleForClass:[VVSpriteMTLView class]];
	id<MTLLibrary>		defaultLibrary = [n newDefaultLibraryWithBundle:myBundle error:&nsErr];
	id<MTLFunction>		vertFunc = [defaultLibrary newFunctionWithName:@"VVSpriteMTLViewVertShader"];
	id<MTLFunction>		fragFunc = [defaultLibrary newFunctionWithName:@"VVSpriteMTLViewFragShader"];
	
	MTLRenderPipelineDescriptor		*psDesc = [[MTLRenderPipelineDescriptor alloc] init];
	psDesc.label = @"Generic VVSpriteMTLView";
	psDesc.vertexFunction = vertFunc;
	psDesc.fragmentFunction = fragFunc;
	psDesc.colorAttachments[0].pixelFormat = metalLayer.pixelFormat;
	
	//	commented out- this was an attempt to make MTLImgBufferView "transparent" (0 alpha would display view behind it)
	psDesc.alphaToCoverageEnabled = NO;
	psDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
	psDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
	//psDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
	psDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
	psDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
	//psDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
	psDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorZero;
	psDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
	psDesc.colorAttachments[0].blendingEnabled = YES;
	
	pso = [_device newRenderPipelineStateWithDescriptor:psDesc error:&nsErr];
	
	self.mvpBuffer = nil;
	
	self.contentNeedsRedraw = YES;
}
- (id<MTLDevice>) device	{
	return _device;
}


@synthesize pixelFormat=myPixelFormat;
- (void) setPixelFormat:(MTLPixelFormat)n	{
	myPixelFormat = n;
	
	metalLayer.pixelFormat = n;
}
- (MTLPixelFormat) pixelFormat	{
	return myPixelFormat;
}


@synthesize colorspace=_colorspace;
- (void) setColorspace:(CGColorSpaceRef)n	{
	if (_colorspace != NULL)
		CGColorSpaceRelease(_colorspace);
	_colorspace = (n==NULL) ? NULL : CGColorSpaceRetain(n);
	
	metalLayer.colorspace = n;
}
- (CGColorSpaceRef) colorspace	{
	return _colorspace;
}


//- (NSSize) viewportSize	{
//	return NSMakeSize( viewportSize[0], viewportSize[1] );
//}


@synthesize layerBackgroundColor=_layerBackgroundColor;
- (void) setLayerBackgroundColor:(NSColor *)n	{
	_layerBackgroundColor = [n colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
	
	if (_layerBackgroundColor == nil)	{
		//	this makes the view "transparent" (areas with alpha of 0 will show the background of the enclosing view)
		self.layer.opaque = NO;
		self.layer.backgroundColor = [[NSColor clearColor] CGColor];
		passDescriptor = [MTLRenderPassDescriptor new];
		passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
		passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
		passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
	}
	else	{
		self.layer.opaque = YES;
		CGFloat			components[8];
		[_layerBackgroundColor getComponents:components];
		//NSLog(@"\t\tcolor was %@, comps are %0.2f, %0.2f, %0.2f",_layerBackgroundColor,components[0],components[1],components[2]);
		self.layer.backgroundColor = [_layerBackgroundColor CGColor];
		passDescriptor = [MTLRenderPassDescriptor new];
		passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
		passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake( components[0], components[1], components[2], components[3] );
		passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
	}
}
- (NSColor *) layerBackgroundColor	{
	return _layerBackgroundColor;
}


@end

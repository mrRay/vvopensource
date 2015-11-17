
#import "VVSpriteGLView.h"
#import <OpenGL/CGLMacro.h>
#import "VVBasicMacros.h"
//#import "VVControl.h"
#import "VVView.h"




#define VVBITMASKCHECK(mask,flagToCheck) ((mask & flagToCheck) == flagToCheck) ? ((BOOL)YES) : ((BOOL)NO)

long			_spriteGLViewSysVers;



@implementation VVSpriteGLView


+ (void) initialize	{
	_spriteGLViewSysVers = [VVSysVersion majorSysVersion];
	//NSLog(@"\t\t_spriteGLViewSysVers = %ld",_spriteGLViewSysVers);
}
- (id) initWithFrame:(VVRECT)f pixelFormat:(NSOpenGLPixelFormat *)p	{
	//NSLog(@"%s",__func__);
	if (self = [super initWithFrame:f pixelFormat:p])	{
		[self generalInit];
		return self;
	}
	[self release];
	return nil;
}
- (id) initWithCoder:(NSCoder *)c	{
	//NSLog(@"%s",__func__);
	if (self = [super initWithCoder:c])	{
		[self generalInit];
		return self;
	}
	[self release];
	return nil;
}
- (void) generalInit	{
	//NSLog(@"%s ... %@, %p",__func__,[self class],self);
	//NSLog(@"\t\t%s, local to backing multiplier is %f for %@",__func__,localToBackingBoundsMultiplier,self);
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(_glContextNeedsRefresh:)
		name:NSViewGlobalFrameDidChangeNotification
		object:self];
	
	deleted = NO;
	initialized = NO;
	flipped = NO;
	localToBackingBoundsMultiplier = 1.0;
	vvSubviews = [[MutLockArray alloc] init];
	dragNDropSubview = nil;
	//needsReshape = YES;
	spriteManager = [[VVSpriteManager alloc] init];
	spritesNeedUpdate = YES;
	lastMouseEvent = nil;
	drawBorder = NO;
	for (long i=0;i<4;++i)	{
		clearColor[i] = (GLfloat)0.0;
		borderColor[i] = (GLfloat)0.0;
	}
	mouseDownModifierFlags = 0;
	mouseDownEventType = VVSpriteEventNULL;
	modifierFlags = 0;
	mouseIsDown = NO;
	clickedSubview = nil;
	
	pthread_mutexattr_t		attr;
	
	pthread_mutexattr_init(&attr);
	//pthread_mutexattr_settype(&attr,PTHREAD_MUTEX_NORMAL);
	pthread_mutexattr_settype(&attr,PTHREAD_MUTEX_RECURSIVE);
	pthread_mutex_init(&glLock,&attr);
	pthread_mutexattr_destroy(&attr);
	
	flushMode = VVFlushModeGL;
	
	fenceMode = VVFenceModeEveryRefresh;
	fenceA = 0;
	fenceB = 0;
	waitingForFenceA = YES;
	fenceADeployed = NO;
	fenceBDeployed = NO;
	fenceLock = OS_SPINLOCK_INIT;
	
	[(id)self setWantsBestResolutionOpenGLSurface:(_spriteGLViewSysVers>=7)?YES:NO];
	//NSLog(@"\t\t%s ... %@, %p - FINISHED",__func__,[self class],self);
}
- (void) awakeFromNib	{
	//NSLog(@"%s",__func__);
	spritesNeedUpdate = YES;
}
- (void) prepareToBeDeleted	{
	NSMutableArray		*subCopy = [vvSubviews lockCreateArrayCopy];
	if (subCopy != nil)	{
		[subCopy retain];
		for (id subview in subCopy)
			[self removeVVSubview:subview];
		[subCopy removeAllObjects];
		[subCopy release];
		subCopy = nil;
	}
	dragNDropSubview = nil;
	
	if (spriteManager != nil)
		[spriteManager prepareToBeDeleted];
	spritesNeedUpdate = NO;
	deleted = YES;
	
	pthread_mutex_lock(&glLock);
	OSSpinLockLock(&fenceLock);
		//NSLog(@"\t\tdeleting fences %ld & %ld in context %p",fenceA,fenceB,[self openGLContext]);
		CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
		glDeleteFencesAPPLE(1,&fenceA);
		fenceA = 0;
		fenceADeployed = NO;
		glDeleteFencesAPPLE(1,&fenceB);
		fenceB = 0;
		fenceBDeployed = NO;
	OSSpinLockUnlock(&fenceLock);
	pthread_mutex_unlock(&glLock);
	
	[[NSNotificationCenter defaultCenter]
		removeObserver:self
		name:NSViewGlobalFrameDidChangeNotification
		object:self];
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(spriteManager);
	VVRELEASE(lastMouseEvent);
	VVRELEASE(vvSubviews);
	pthread_mutex_destroy(&glLock);
	[super dealloc];
}


/*===================================================================================*/
#pragma mark --------------------- overrides
/*------------------------------------*/


- (void) setOpenGLContext:(NSOpenGLContext *)c	{
	//NSLog(@"%s",__func__);
	pthread_mutex_lock(&glLock);
		OSSpinLockLock(&fenceLock);
		CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
		if (fenceA > 0)
			glDeleteFencesAPPLE(1,&fenceA);
		fenceA = 0;
		fenceADeployed = NO;
		if (fenceB > 0)
			glDeleteFencesAPPLE(1,&fenceB);
		fenceB = 0;
		fenceBDeployed = NO;
		OSSpinLockUnlock(&fenceLock);
		
		[super setOpenGLContext:c];
		[c setView:self];
		initialized = NO;
	pthread_mutex_unlock(&glLock);
	//needsReshape = YES;
}

- (BOOL) acceptsFirstMouse:(NSEvent *)theEvent	{
	return YES;
}
- (BOOL) isOpaque	{
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
- (void) removeFromSuperview	{
	pthread_mutex_lock(&glLock);
	[super removeFromSuperview];
	pthread_mutex_unlock(&glLock);
}
- (void) setWantsBestResolutionOpenGLSurface:(BOOL)n	{
	//NSLog(@"%s ... %@, %d",__func__,self,n);
	//	update my local display bounds multiplier
	if (_spriteGLViewSysVers>=7)	{
		//	note: only tells the super to do it if the current OS is 10.7 or newer!
		[super setWantsBestResolutionOpenGLSurface:n];
		
		if (n)	{
			VVRECT		bounds = [self bounds];
			VVRECT		backingBounds = [(id)self convertRectToBacking:bounds];
			localToBackingBoundsMultiplier = (backingBounds.size.width/bounds.size.width);
		}
		else
			localToBackingBoundsMultiplier = 1.0;
	}
	else	{
		localToBackingBoundsMultiplier = 1.0;
	}
	//NSLog(@"\t\t%s, local to backing multiplier is %f for %@",__func__,localToBackingBoundsMultiplier,self);
	//NSLog(@"\t\tsprites need updating!");
	[self setSpritesNeedUpdate:YES];
	//	if i have subviews, tell them to update their display bounds multipliers!
	[vvSubviews rdlock];
	for (VVView *viewPtr in [vvSubviews array])	{
		[viewPtr setLocalToBackingBoundsMultiplier:localToBackingBoundsMultiplier];
	}
	[vvSubviews unlock];
}
- (void)viewDidMoveToWindow	{
	//NSLog(@"%s ... %@",__func__,self);
	if (deleted || vvSubviews==nil || [vvSubviews count]<1)
		return;
	[vvSubviews rdlock];
	for (VVView *viewPtr in [vvSubviews array])	{
		[viewPtr _viewDidMoveToWindow];
	}
	[vvSubviews unlock];
	
	[self updateTrackingAreas];
}
- (void) updateTrackingAreas	{
	[super updateTrackingAreas];
	
	if (deleted || vvSubviews==nil || [vvSubviews count]<1)
		return;
	[vvSubviews rdlock];
	for (VVView *viewPtr in [vvSubviews array])	{
		[viewPtr updateTrackingAreas];
	}
	[vvSubviews unlock];
}
/*
- (NSView *) hitTest:(VVPOINT)p	{
	NSLog(@"%s ... (%f, %f)",__func__,p.x,p.y);
	if (deleted || vvSubviews==nil)
		return nil;
	id			tmpSubview = nil;
	if ([vvSubviews count]>0)	{
		[vvSubviews rdlock];
		for (VVView *viewPtr in [vvSubviews array])	{
			tmpSubview = [viewPtr vvSubviewHitTest:p];
			if (tmpSubview != nil)
				break;
		}
		[vvSubviews unlock];
	}
	NSLog(@"\t\ti appear to have clicked on %@",tmpSubview);
	return tmpSubview;
}
*/
/*
- (void) keyDown:(NSEvent *)event	{
	NSLog(@"%s",__func__);
	//[VVControl keyPressed:event];
	//[super keyDown:event];
}
- (void) keyUp:(NSEvent *)event	{
	NSLog(@"%s",__func__);
	//[VVControl keyPressed:event];
	//[super keyUp:event];
}
*/


/*===================================================================================*/
#pragma mark --------------------- subview-related
/*------------------------------------*/


- (void) addVVSubview:(id)n	{
	//NSLog(@"%s",__func__);
	if (deleted || n==nil)
		return;
	if (![n isKindOfClass:[VVView class]])
		return;
	
	[vvSubviews wrlock];
	if (![vvSubviews containsIdenticalPtr:n])	{
		[vvSubviews insertObject:n atIndex:0];
		[n setContainerView:self];
		[n _setSuperview:nil];
	}
	[vvSubviews unlock];
	
	//	if the subviews i'm adding have any drag types, tell the container view to reconcile its drag types
	NSMutableArray		*tmpArray = MUTARRAY;
	[n _collectDragTypesInArray:tmpArray];
	if ([tmpArray count]>0)
		[self reconcileVVSubviewDragTypes];
	
	[self setNeedsDisplay:YES];
}
- (void) removeVVSubview:(id)n	{
	//NSLog(@"%s",__func__);
	if (deleted || n==nil)
		return;
	if (![n isKindOfClass:[VVView class]])
		return;
	[n retain];
	[vvSubviews lockRemoveIdenticalPtr:n];
	[n setContainerView:nil];
	
	//	if there's a drag and drop subview (if i'm in the middle of a drag and drop action), i have to check if it's in the subview i'm removing!
	if (dragNDropSubview!=nil && [n containsSubview:dragNDropSubview])	{
		[dragNDropSubview draggingExited:nil];
		dragNDropSubview = nil;
	}
	//	if the subviews i'm adding have any drag types, tell the container view to reconcile its drag types
	NSMutableArray		*tmpArray = MUTARRAY;
	[n _collectDragTypesInArray:tmpArray];
	if ([tmpArray count]>0)
		[self reconcileVVSubviewDragTypes];
	
	[n release];
}
- (BOOL) containsSubview:(id)n	{
	if (deleted || n==nil || vvSubviews==nil)
		return NO;
	BOOL		returnMe = NO;
	[vvSubviews rdlock];
	for (VVView *viewPtr in [vvSubviews array])	{
		if (viewPtr==n || [viewPtr containsSubview:n])	{
			returnMe = YES;
			break;
		}
	}
	[vvSubviews unlock];
	return returnMe;
}
- (id) vvSubviewHitTest:(VVPOINT)p	{
	//NSLog(@"%s ... (%f, %f)",__func__,p.x,p.y);
	if (deleted || vvSubviews==nil)
		return nil;
	
	id					returnMe = nil;
	//	run from "top" view to bottom, checking to see if the point lies within any of the views
	[vvSubviews rdlock];
	for (VVView *viewPtr in [vvSubviews array])	{
		VVRECT			tmpFrame = [viewPtr frame];
		//VVRectLog(@"\t\tview's frame is",tmpFrame);
		if (VVPOINTINRECT(p,tmpFrame))	{
			returnMe = [viewPtr vvSubviewHitTest:p];
			if (returnMe != nil)
				break;
		}
	}
	[vvSubviews unlock];
	
	return returnMe;
}
- (void) reconcileVVSubviewDragTypes	{
	//NSLog(@"%s",__func__);
	if (deleted || vvSubviews==nil)
		return;
	NSMutableArray		*tmpArray = [NSMutableArray arrayWithCapacity:0];
	[vvSubviews rdlock];
	for (VVView *viewPtr in [vvSubviews array])	{
		[viewPtr _collectDragTypesInArray:tmpArray];
	}
	[vvSubviews unlock];
	
	[self unregisterDraggedTypes];
	[self registerForDraggedTypes:tmpArray];
}


/*===================================================================================*/
#pragma mark --------------------- NSDraggingDestination protocol
/*------------------------------------*/


- (NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	if (deleted || vvSubviews==nil || [vvSubviews count]<1)
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
	if (deleted || vvSubviews==nil || [vvSubviews count]<1)
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
	if (deleted || dragNDropSubview==nil)
		return;
	[dragNDropSubview draggingExited:sender];
}
- (void) draggingEnded:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	if (deleted || dragNDropSubview==nil)
		return;
	[dragNDropSubview draggingEnded:sender];
}

- (BOOL) prepareForDragOperation:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	if (deleted || dragNDropSubview==nil)
		return NO;
	return [dragNDropSubview prepareForDragOperation:sender];
}
- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	if (deleted || dragNDropSubview==nil)
		return NO;
	return [dragNDropSubview performDragOperation:sender];
}
- (void) concludeDragOperation:(id <NSDraggingInfo>)sender	{
	//NSLog(@"%s",__func__);
	if (deleted || dragNDropSubview==nil)
		return;
	[dragNDropSubview concludeDragOperation:sender];
}


/*===================================================================================*/
#pragma mark --------------------- frame-related
/*------------------------------------*/


- (void) setFrame:(VVRECT)f	{
	//NSLog(@"%s ... %@, (%0.2f, %0.2f) %0.2f x %0.2f",__func__, self, f.origin.x, f.origin.y, f.size.width, f.size.height);
	if (deleted)
		return;
	pthread_mutex_lock(&glLock);
		[super setFrame:f];
		[self updateSprites];
		//spritesNeedUpdate = YES;
		//needsReshape = YES;
		initialized = NO;
	pthread_mutex_unlock(&glLock);
	
	//	update the bounds to real bounds multiplier
	BOOL		backingBoundsChanged = NO;
	if (_spriteGLViewSysVers>=7 && [(id)self wantsBestResolutionOpenGLSurface])	{
		VVRECT		bounds = [self bounds];
		VVRECT		backingBounds = [(id)self convertRectToBacking:bounds];
		double		tmpDouble;
		tmpDouble = (backingBounds.size.width/bounds.size.width);
		if (tmpDouble != localToBackingBoundsMultiplier)
			backingBoundsChanged = YES;
		localToBackingBoundsMultiplier = tmpDouble;
	}
	else	{
		if (localToBackingBoundsMultiplier != 1.0)
			backingBoundsChanged = YES;
		localToBackingBoundsMultiplier = 1.0;
	}
	//NSLog(@"\t\t%s, local to backing multiplier is %f for %@",__func__,localToBackingBoundsMultiplier,self);
	
	[vvSubviews rdlock];
	if (backingBoundsChanged)	{
		for (VVView *viewPtr in [vvSubviews array])	{
			[viewPtr setLocalToBackingBoundsMultiplier:localToBackingBoundsMultiplier];
		}
	}
	[vvSubviews unlock];
	//NSLog(@"\t\t%s, BTRBM is %f for %@",__func__,localToBackingBoundsMultiplier,self);
	
	//NSLog(@"\t\t%s - FINISHED",__func__);
}
- (void) setFrameSize:(VVSIZE)n	{
	//NSLog(@"%s ... %@, %f x %f",__func__,self,n.width,n.height);
	VVSIZE			oldSize = [self frame].size;
	[super setFrameSize:n];
	
	if ([self autoresizesSubviews])	{
		double		widthDelta = n.width - oldSize.width;
		double		heightDelta = n.height - oldSize.height;
		[vvSubviews rdlock];
		for (VVView *viewPtr in [vvSubviews array])	{
			VVViewResizeMask	viewResizeMask = [viewPtr autoresizingMask];
			VVRECT				viewNewFrame = [viewPtr frame];
			//VVRectLog(@"\t\torig viewNewFrame is",viewNewFrame);
			int					hSubDivs = 0;
			int					vSubDivs = 0;
			if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMinXMargin))
				++hSubDivs;
			if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMaxXMargin))
				++hSubDivs;
			if (VVBITMASKCHECK(viewResizeMask,VVViewResizeWidth))
				++hSubDivs;
			
			if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMinYMargin))
				++vSubDivs;
			if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMaxYMargin))
				++vSubDivs;
			if (VVBITMASKCHECK(viewResizeMask,VVViewResizeHeight))
				++vSubDivs;
			
			if (hSubDivs>0 || vSubDivs>0)	{
				if (hSubDivs>0 && VVBITMASKCHECK(viewResizeMask,VVViewResizeWidth))
					viewNewFrame.size.width += widthDelta/hSubDivs;
				if (vSubDivs>0 && VVBITMASKCHECK(viewResizeMask,VVViewResizeHeight))
					viewNewFrame.size.height += heightDelta/vSubDivs;
				if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMinXMargin))
					viewNewFrame.origin.x += widthDelta/hSubDivs;
				if (VVBITMASKCHECK(viewResizeMask,VVViewResizeMinYMargin))
					viewNewFrame.origin.y += heightDelta/vSubDivs;
			}
			//VVRectLog(@"\t\tmod viewNewFrame is",viewNewFrame);
			[viewPtr setFrame:viewNewFrame];
		}
		[vvSubviews unlock];
	}
	
	if (!NSEqualSizes(oldSize,n))	{
		//NSLog(@"\t\tsized changed!");
		//	update the bounds to real bounds multiplier
		if (_spriteGLViewSysVers>=7 && [(id)self wantsBestResolutionOpenGLSurface])	{
			VVRECT		bounds = [self bounds];
			VVRECT		backingBounds = [(id)self convertRectToBacking:bounds];
			localToBackingBoundsMultiplier = (backingBounds.size.width/bounds.size.width);
		}
		else
			localToBackingBoundsMultiplier = 1.0;
		//NSLog(@"\t\t%s, local to backing multiplier is %f for %@",__func__,localToBackingBoundsMultiplier,self);
		
		[vvSubviews rdlock];
		for (VVView *viewPtr in [vvSubviews array])	{
			[viewPtr setLocalToBackingBoundsMultiplier:localToBackingBoundsMultiplier];
		}
		[vvSubviews unlock];
		//NSLog(@"\t\t%s, BTRBM is %f for %@",__func__,localToBackingBoundsMultiplier,self);
		
		pthread_mutex_lock(&glLock);
		initialized = NO;
		pthread_mutex_unlock(&glLock);
	}
}
- (void) updateSprites	{
	spritesNeedUpdate = NO;
	
	long				swap = 1;
	[[self openGLContext] setValues:(GLint *)&swap forParameter:NSOpenGLCPSwapInterval];
}
- (void) _glContextNeedsRefresh:(NSNotification *)note	{
	[self setSpritesNeedUpdate:YES];
	//	update the bounds to real bounds multiplier
	if (_spriteGLViewSysVers>=7 && [(id)self wantsBestResolutionOpenGLSurface])	{
		VVRECT		bounds = [self bounds];
		VVRECT		backingBounds = [(id)self convertRectToBacking:bounds];
		localToBackingBoundsMultiplier = (backingBounds.size.width/bounds.size.width);
	}
	else
		localToBackingBoundsMultiplier = 1.0;
	//NSLog(@"\t\t%s, local to backing multiplier is %f for %@",__func__,localToBackingBoundsMultiplier,self);
	
	[vvSubviews rdlock];
	for (VVView *viewPtr in [vvSubviews array])	{
		[viewPtr setLocalToBackingBoundsMultiplier:localToBackingBoundsMultiplier];
	}
	[vvSubviews unlock];
}
- (void) reshape	{
	//NSLog(@"%s",__func__);
	[super reshape];
	
	spritesNeedUpdate = YES;
	initialized = NO;
}
- (void) update	{
	[super update];
	
	spritesNeedUpdate = YES;
	initialized = NO;
}


- (void) _lock	{
	pthread_mutex_lock(&glLock);
}
- (void) _unlock	{
	pthread_mutex_unlock(&glLock);
}
- (VVRECT) backingBounds	{
	if (_spriteGLViewSysVers >= 7)
		return [(id)self convertRectToBacking:[self bounds]];
	else
		return [self bounds];
}
- (double) localToBackingBoundsMultiplier	{
	return localToBackingBoundsMultiplier;
}


/*===================================================================================*/
#pragma mark --------------------- UI
/*------------------------------------*/


- (void) mouseDown:(NSEvent *)e	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	mouseIsDown = YES;
	VVPOINT		locationInWindow = [e locationInWindow];
	VVPOINT		localPoint = [self convertPoint:locationInWindow fromView:nil];
	//localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	//VVPointLog(@"\t\tlocalPoint is",localPoint);
	//	if i have subviews and i clicked on one of them, skip the sprite manager
	if ([[self vvSubviews] count]>0)	{
		clickedSubview = [self vvSubviewHitTest:localPoint];
		if (clickedSubview == (id)self)
			clickedSubview = nil;
		//NSLog(@"\t\tclickedSubview is %@",clickedSubview);
		//VVRectLog(@"\t\tclickedSubview frame is",[clickedSubview frame]);
		if (clickedSubview != nil)	{
			[clickedSubview mouseDown:e];
			return;
		}
	}
	//	else there aren't any subviews or i didn't click on any of them- do the sprite manager...
	//	convert the local point to use this view's bounds (may be different than frame for retina displays)
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	//VVPointLog(@"\t\tmodified localPoint is",localPoint);
	mouseDownModifierFlags = [e modifierFlags];
	modifierFlags = mouseDownModifierFlags;
	if ((mouseDownModifierFlags&NSControlKeyMask)==NSControlKeyMask)	{
		mouseDownEventType = VVSpriteEventRightDown;
		[spriteManager localRightMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
	}
	else	{
		mouseDownEventType = VVSpriteEventDown;
		[spriteManager localMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
	}
}
- (void) mouseUp:(NSEvent *)e	{
	if (deleted)
		return;
	
	if (mouseDownEventType == VVSpriteEventRightDown)	{
		[self rightMouseUp:e];
		return;
	}
	
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	
	modifierFlags = [e modifierFlags];
	mouseIsDown = NO;
	VVPOINT		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
	if (clickedSubview != nil)
		[clickedSubview mouseUp:e];
	else	{
		//	convert the local point to use this view's bounds (may be different than frame for retina displays)
		localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
		[spriteManager localMouseUp:localPoint];
	}
}
- (void) rightMouseDown:(NSEvent *)e	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	mouseIsDown = YES;
	VVPOINT		locationInWindow = [e locationInWindow];
	VVPOINT		localPoint = [self convertPoint:locationInWindow fromView:nil];
	//localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	//VVPointLog(@"\t\tlocalPoint is",localPoint);
	//	if i have subviews and i clicked on one of them, skip the sprite manager
	if ([[self vvSubviews] count]>0)	{
		clickedSubview = [self vvSubviewHitTest:localPoint];
		//NSLog(@"\t\tclickedSubview is %@",clickedSubview);
		if (clickedSubview == (id)self)
			clickedSubview = nil;
		if (clickedSubview != nil)	{
			[clickedSubview rightMouseDown:e];
			return;
		}
	}
	
	//	convert the local point to use this view's bounds (may be different than frame for retina displays)
	localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	
	mouseDownModifierFlags = [e modifierFlags];
	mouseDownEventType = VVSpriteEventRightDown;
	modifierFlags = mouseDownModifierFlags;
	//	else there aren't any subviews or i didn't click on any of them- do the sprite manager
	[spriteManager localRightMouseDown:localPoint modifierFlag:mouseDownModifierFlags];
}
- (void) rightMouseUp:(NSEvent *)e	{
	if (deleted)
		return;
	VVRELEASE(lastMouseEvent);
	if (e != nil)
		lastMouseEvent = [e retain];
	mouseIsDown = NO;
	VVPOINT		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
	if (clickedSubview != nil)
		[clickedSubview rightMouseUp:e];
	else	{
		//	convert the local point to use this view's bounds (may be different than frame for retina displays)
		localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
		[spriteManager localRightMouseUp:localPoint];
	}
}
- (void) mouseDragged:(NSEvent *)e	{
	if (deleted)
		return;
	VVRELEASE(lastMouseEvent);
	if (e != nil)//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
		lastMouseEvent = [e retain];
	
	modifierFlags = [e modifierFlags];
	VVPOINT		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
	//	if i clicked on a subview earlier, pass mouse events to it instead of the sprite manager
	if (clickedSubview != nil)
		[clickedSubview mouseDragged:e];
	else	{
		//	convert the local point to use this view's bounds (may be different than frame for retina displays)
		localPoint = VVMAKEPOINT(localPoint.x*localToBackingBoundsMultiplier, localPoint.y*localToBackingBoundsMultiplier);
		[spriteManager localMouseDragged:localPoint];
	}
}
- (void) rightMouseDragged:(NSEvent *)e	{
	[self mouseDragged:e];
}
- (void) scrollWheel:(NSEvent *)e	{
	//NSLog(@"%s",__func__);
	if (deleted)
		return;
	
	//	find the view under the event location, call "scrollWheel:" on it
	VVPOINT		localPoint = [self convertPoint:[e locationInWindow] fromView:nil];
	//VVPointLog(@"\t\tlocalPoint is",localPoint);
	if ([[self vvSubviews] count]>0)	{
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


/*===================================================================================*/
#pragma mark --------------------- drawing
/*------------------------------------*/


- (void) lockFocus	{
	if (deleted)	{
		[super lockFocus];
		return;
	}
	
	pthread_mutex_lock(&glLock);
	[super lockFocus];
	pthread_mutex_unlock(&glLock);
}
- (void) setNeedsDisplay	{
	[self setNeedsDisplay:YES];
}
- (void) drawRect:(VVRECT)r	{
	[self performDrawing:r];
}
//	split off into its own method so i can invoke drawing without triggering any of my superclass's drawRect:-related backend
- (void) performDrawing:(VVRECT)r	{
	//NSLog(@"*****************************");
	//NSLog(@"%s",__func__);
	//VVRectLog(@"\t\trect is",r);
	if (deleted)
		return;
	
	id			myWin = [self window];
	if (myWin == nil)
		return;
	
	//pthread_mutex_lock(&glLock);
	if (pthread_mutex_trylock(&glLock) != 0)	{	//	returns 0 if successful- so if i can't get a gl lock, skip drawing!
		NSLog(@"\t\terr: couldn't get GL lock, bailing %s",__func__);
		return;
	}
	
	//	if the sprites need to be updated, do so now...this should probably be done inside the gl lock!
	if (spritesNeedUpdate)
		[self updateSprites];
	
	if (!initialized)	{
		[self initializeGL];
		initialized = YES;
	}
	NSOpenGLContext		*context = [self openGLContext];
	CGLContextObj		cgl_ctx = [context CGLContextObj];
	
	//	lock around the fence, determine whether i should proceed with the render or not
	OSSpinLockLock(&fenceLock);
	BOOL		proceedWithRender = NO;
	//	if the fences are broken, i'm going to proceed with rendering and ignore fencing
	if ((fenceA < 1) || (fenceB < 1))
		proceedWithRender = YES;
	//	else the fences are fine- fence based on the fencing mode
	else	{
		//	if the fence mode wants to draw every refresh, proceed with rendering
		if ((fenceMode==VVFenceModeEveryRefresh) || (fenceMode==VVFenceModeFinish))	{
			//NSLog(@"\t\tfence mode is every refresh!");
			proceedWithRender = YES;
		}
		//	else the fence mode *isn't* drawing every refresh- i need to test fenceA no matter what
		else	{
			//	if i'm in single-buffer mode but i'm not waiting for fenceA, something's wrong- i should be waiting for A!
			if ((fenceMode==VVFenceModeSBSkip) && (!waitingForFenceA))
				waitingForFenceA = YES;
			
			//	if i'm waiting for fence A....
			if (waitingForFenceA)	{
				//	if fence A hasn't been deployed, proceed with rendering anyway
				if (!fenceADeployed)
					proceedWithRender = YES;
				else	{
					proceedWithRender = glTestFenceAPPLE(fenceA);
					fenceADeployed = (proceedWithRender)?NO:YES;
				}
				//if (proceedWithRender)	{
				//	//NSLog(@"\t\tfenceA executed- clear to render");
				//}
				//else	{
				//	//NSLog(@"\t\tfenceA hasn't executed yet");
				//}
				
			}
			//	if i'm in DB skip mode and i'm not waiting for fence A...
			if ((fenceMode==VVFenceModeDBSkip) && (!waitingForFenceA))	{
				//	if fence B hasn't been deployed, proceed with rendering anyway
				if (!fenceBDeployed)
					proceedWithRender = YES;
				else	{
					proceedWithRender = glTestFenceAPPLE(fenceB);
					fenceBDeployed = (proceedWithRender)?NO:YES;
				}
				//if (proceedWithRender)	{
				//	//NSLog(@"\t\tfenceB executed- clear to render");
				//}
				//else	{
				//	//NSLog(@"\t\tfenceB hasn't executed yet");
				//}
			}
		}
	}
	OSSpinLockUnlock(&fenceLock);
	
	
	
	if (proceedWithRender)	{
		//	clear the view
		glClearColor(clearColor[0],clearColor[1],clearColor[2],clearColor[3]);
		glClear(GL_COLOR_BUFFER_BIT);
		
		//	tell the sprite manager to start drawing the sprites
		if (spriteManager != nil)	{
			if (_spriteGLViewSysVers >= 7)	{
				//[spriteManager drawRect:[(id)self convertRectToBacking:r]];
				[spriteManager drawRect:[(id)self convertRectToBacking:r] inContext:cgl_ctx];
			}
			else	{
				//[spriteManager drawRect:r];
				[spriteManager drawRect:r inContext:cgl_ctx];
			}
		}
		
		
		//	tell the subviews to draw
		[vvSubviews rdlock];
		if ([vvSubviews count]>0)	{
			//	before i begin, enable the scissor test and get my bounds
			//VVRectLog(@"\t\tmy reported bounds are",[self bounds]);
			//VVRectLog(@"\t\tmy real bounds are",_bounds);
			glEnable(GL_SCISSOR_TEST);
			//	run through all the subviews (last to first), drawing them
			NSEnumerator		*it = [[vvSubviews array] reverseObjectEnumerator];
			VVView				*viewPtr;
			while (viewPtr = [it nextObject])	{
				//NSLog(@"\t\tview is %@",viewPtr);
				//VVRECT				viewBounds = [viewPtr bounds];
				VVRECT				viewFrameInMyLocalBounds = [viewPtr frame];
				//VVRectLog(@"\t\tviewFrameInMyLocalBounds is",viewFrameInMyLocalBounds);
				VVRECT				intersectRectInMyLocalBounds = VVINTERSECTIONRECT(r,viewFrameInMyLocalBounds);
				if (intersectRectInMyLocalBounds.size.width>0 && intersectRectInMyLocalBounds.size.height>0)	{
					//	update the intersect rect so it's local to the view i'm going to ask to draw
					//intersectRectInMyLocalBounds.origin = VVMAKEPOINT(intersectRectInMyLocalBounds.origin.x-viewFrameInMyLocalBounds.origin.x, intersectRectInMyLocalBounds.origin.y-viewFrameInMyLocalBounds.origin.y);
					//VVRectLog(@"\t\tintersectRectInMyLocalBounds is",intersectRectInMyLocalBounds);
					//	apply transformation matrices so that when the view draws, its origin in GL is the correct location in the context
					glMatrixMode(GL_MODELVIEW);
					glPushMatrix();
					glTranslatef(viewFrameInMyLocalBounds.origin.x*localToBackingBoundsMultiplier, viewFrameInMyLocalBounds.origin.y*localToBackingBoundsMultiplier, 0.0);
					
					//	calculate the rect (in the view's local coordinate space) of the are of the view i'm going to ask to draw
					VVRECT					viewBoundsToDraw = intersectRectInMyLocalBounds;
					viewBoundsToDraw.origin = VVMAKEPOINT(viewBoundsToDraw.origin.x-viewFrameInMyLocalBounds.origin.x, viewBoundsToDraw.origin.y-viewFrameInMyLocalBounds.origin.y);
					NSAffineTransform		*rotTrans = [NSAffineTransform transform];
					VVViewBoundsOrientation	viewBO = [viewPtr boundsOrientation];
					if (viewBO != VVViewBOBottom)	{
						switch (viewBO)	{
							case VVViewBORight:
								[rotTrans rotateByDegrees:-90.0];
								break;
							case VVViewBOTop:
								[rotTrans rotateByDegrees:-180.0];
								break;
							case VVViewBOLeft:
								[rotTrans rotateByDegrees:-270.0];
								break;
							case VVViewBOBottom:
								break;
						}
						viewBoundsToDraw.origin = [rotTrans transformPoint:viewBoundsToDraw.origin];
						viewBoundsToDraw.size = [rotTrans transformSize:viewBoundsToDraw.size];
						//	...make sure the size is valid.  i don't understand why this step is necessary- i think it's a sign i may be doing something wrong.
						viewBoundsToDraw.size = VVMAKESIZE(fabs(viewBoundsToDraw.size.width), fabs(viewBoundsToDraw.size.height));
					}
					/*
					VVRECT					viewBoundsToDraw = intersectRectInMyLocalBounds;
					viewBoundsToDraw.origin = VVMAKEPOINT(viewBoundsToDraw.origin.x-viewFrameInMyLocalBounds.origin.x, viewBoundsToDraw.origin.y-viewFrameInMyLocalBounds.origin.y);
					NSAffineTransform		*rotTrans = [NSAffineTransform transform];
					[rotTrans rotateByDegrees:-1.0*[viewPtr boundsRotation]];
					viewBoundsToDraw.origin = [rotTrans transformPoint:viewBoundsToDraw.origin];
					viewBoundsToDraw.size = [rotTrans transformSize:viewBoundsToDraw.size];
					viewBoundsToDraw.size = VVMAKESIZE(fabs(viewBoundsToDraw.size.width), fabs(viewBoundsToDraw.size.height));
					//viewBoundsToDraw.origin = VVMAKEPOINT(viewBoundsToDraw.origin.x+viewBounds.origin.x, viewBoundsToDraw.origin.y+viewBounds.origin.y);
					//VVRectLog(@"\t\tviewBoundsToDraw is",viewBoundsToDraw);
					*/
					
					//	now tell the view to do its drawing!
					[viewPtr
						_drawRect:viewBoundsToDraw
						inContext:cgl_ctx];
					
					glMatrixMode(GL_MODELVIEW);
					glPopMatrix();
				}
			}
			//	now that i'm done drawing subviews, set scissor back to my full bounds and disable the test
			VVRECT		bounds = [self backingBounds];
			glScissor(bounds.origin.x,bounds.origin.y,bounds.size.width,bounds.size.height);
			glDisable(GL_SCISSOR_TEST);
		}
		[vvSubviews unlock];
		
		
		
		//	if appropriate, draw the border
		if (drawBorder)	{
			glColor4f(borderColor[0],borderColor[1],borderColor[2],borderColor[3]);
			glEnableClientState(GL_VERTEX_ARRAY);
			glDisableClientState(GL_TEXTURE_COORD_ARRAY);
			GLSTROKERECT([self backingBounds]);
		}
		
		//	flush!
		switch (flushMode)	{
			case VVFlushModeGL:
				glFlush();
				break;
			case VVFlushModeCGL:
				CGLFlushDrawable(cgl_ctx);
				break;
			case VVFlushModeNS:
				[context flushBuffer];
				break;
			case VVFlushModeApple:
				glFlushRenderAPPLE();
				break;
			case VVFlushModeFinish:
				glFinish();
				break;
		}
		
		//	lock around the fence, insert a fence in the command stream, and swap fences
		OSSpinLockLock(&fenceLock);
		if ((fenceMode!=VVFenceModeEveryRefresh) && (fenceMode!=VVFenceModeFinish) && (fenceA > 0) && (fenceB > 0))	{
			if (waitingForFenceA)	{
				glSetFenceAPPLE(fenceA);
				fenceADeployed = YES;
				//NSLog(@"\t\tdone drawing, inserting fenceA into stream");
				if (fenceMode == VVFenceModeDBSkip)
					waitingForFenceA = NO;
			}
			else	{
				glSetFenceAPPLE(fenceB);
				fenceBDeployed = YES;
				//NSLog(@"\t\tdone drawing, inserting fenceB into stream");
				waitingForFenceA = YES;
			}
		}
		OSSpinLockUnlock(&fenceLock);
		
		//	call 'finishedDrawing' so subclasses of me have a chance to perform post-draw cleanup
		[self finishedDrawing];
	}
	
	//else
	//	NSLog(@"\t\terr: sprite GL view fence prevented output!");
	
	pthread_mutex_unlock(&glLock);
}
- (void) initializeGL	{
	//NSLog(@"%s ... %p",__func__,self);
	if (deleted)
		return;
	CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
	//VVRECT				bounds = [self bounds];
	//long				cpSwapInterval = 1;
	//[[self openGLContext] setValues:(GLint *)&cpSwapInterval forParameter:NSOpenGLCPSwapInterval];
	
	OSSpinLockLock(&fenceLock);
	if (fenceA < 1)	{
		glGenFencesAPPLE(1,&fenceA);
		fenceADeployed = NO;
	}
	if (fenceB < 1)	{
		glGenFencesAPPLE(1,&fenceB);
		fenceBDeployed = NO;
	}
	OSSpinLockUnlock(&fenceLock);
	
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	//glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	//glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
	glHint(GL_CLIP_VOLUME_CLIPPING_HINT_EXT, GL_FASTEST);
	
	
	//	from http://developer.apple.com/library/mac/#documentation/GraphicsImaging/Conceptual/OpenGL-MacProgGuide/opengl_designstrategies/opengl_designstrategies.html%23//apple_ref/doc/uid/TP40001987-CH2-SW17
	//glDisable(GL_DITHER);
	//glDisable(GL_ALPHA_TEST);
	//glDisable(GL_STENCIL_TEST);
	//glDisable(GL_FOG);
	//glDisable(GL_TEXTURE_2D);
	glPixelZoom((GLuint)1.0,(GLuint)1.0);
	
	VVRECT		bounds = [self backingBounds];
	glViewport(0, 0, (GLsizei) bounds.size.width, (GLsizei) bounds.size.height);
	
	//	moved in from drawRect:
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	if (!flipped)	{
		//glScissor(bounds.origin.x, bounds.origin.x+bounds.size.width, bounds.origin.y, bounds.origin.y+bounds.size.height);
		//glScissor(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
		glOrtho(bounds.origin.x, bounds.origin.x+bounds.size.width, bounds.origin.y, bounds.origin.y+bounds.size.height, 1.0, -1.0);
	}
	else	{
		//glScissor(bounds.origin.x, bounds.origin.x+bounds.size.width, bounds.origin.y+bounds.size.height, bounds.origin.y);
		//glScissor(bounds.origin.x, bounds.origin.y+bounds.size.height, bounds.size.width, -1.0*bounds.size.height);
		//glScissor(bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height);
		glOrtho(bounds.origin.x, bounds.origin.x+bounds.size.width, bounds.origin.y+bounds.size.height, bounds.origin.y, 1.0, -1.0);
	}
	//	always here!
	//glDisable(GL_DEPTH_TEST);
	//glClearColor(clearColor[0],clearColor[1],clearColor[2],clearColor[3]);
	
	initialized = YES;
}
/*	this method exists so subclasses of me have an opportunity to do something after drawing 
	has completed.  this is particularly handy with the GL view, as drawing does not complete- and 
	therefore resources have to stay available- until after glFlush() has been called.		*/
- (void) finishedDrawing	{

}


@synthesize deleted;
@synthesize initialized;
- (void) setFlipped:(BOOL)n	{
	BOOL		changing = (n==flipped) ? NO : YES;
	flipped = n;
	if (changing)
		initialized = NO;
}
- (BOOL) flipped	{
	return flipped;
}
@synthesize localToBackingBoundsMultiplier;
@synthesize vvSubviews;
- (void) setSpritesNeedUpdate:(BOOL)n	{
	spritesNeedUpdate = n;
}
- (BOOL) spritesNeedUpdate	{
	return spritesNeedUpdate;
}
- (void) setSpritesNeedUpdate	{
	spritesNeedUpdate = YES;
}
- (NSEvent *) lastMouseEvent	{
	return lastMouseEvent;
}
- (VVSpriteManager *) spriteManager	{
	return spriteManager;
}
- (void) setClearColor:(NSColor *)c	{
	if ((deleted)||(c==nil))
		return;
	NSColorSpace	*devRGBColorSpace = [NSColorSpace deviceRGBColorSpace];
	NSColor			*calibratedColor = ((void *)[c colorSpace]==(void *)devRGBColorSpace) ? c :[c colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	CGFloat			tmpVals[4];
	[calibratedColor getComponents:(CGFloat *)tmpVals];
	
	pthread_mutex_lock(&glLock);
	//CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
	for (int i=0;i<4;++i)
		clearColor[i] = tmpVals[i];
	//glClearColor(clearColor[0],clearColor[1],clearColor[2],clearColor[3]);
	pthread_mutex_unlock(&glLock);
}
- (NSColor *) clearColor	{
	if (deleted)
		return nil;
	return [NSColor colorWithDeviceRed:clearColor[0] green:clearColor[1] blue:clearColor[2] alpha:clearColor[3]];
}
- (void) setClearColors:(GLfloat)r :(GLfloat)g :(GLfloat)b :(GLfloat)a	{
	pthread_mutex_lock(&glLock);
	clearColor[0] = r;
	clearColor[1] = g;
	clearColor[2] = b;
	clearColor[3] = a;
	pthread_mutex_unlock(&glLock);
}
@synthesize drawBorder;
- (void) setBorderColor:(NSColor *)c	{
	if ((deleted)||(c==nil))
		return;
	NSColorSpace	*devRGBColorSpace = [NSColorSpace deviceRGBColorSpace];
	NSColor			*calibratedColor = ((void *)[c colorSpace]==(void *)devRGBColorSpace) ? c :[c colorUsingColorSpaceName:NSDeviceRGBColorSpace];
	CGFloat			tmpColor[4];
	[calibratedColor getComponents:tmpColor];
	
	pthread_mutex_lock(&glLock);
	//CGLContextObj		cgl_ctx = [[self openGLContext] CGLContextObj];
	[calibratedColor getComponents:(CGFloat *)borderColor];
	for (int i=0; i<4; ++i)
		borderColor[i] = tmpColor[i];
	//glClearColor(clearColor[0],clearColor[1],clearColor[2],clearColor[3]);
	pthread_mutex_unlock(&glLock);
}
- (NSColor *) borderColor	{
	if (deleted)
		return nil;
	return [NSColor colorWithDeviceRed:borderColor[0] green:borderColor[1] blue:borderColor[2] alpha:borderColor[3]];
}
@synthesize mouseDownModifierFlags;
@synthesize mouseDownEventType;
@synthesize modifierFlags;
@synthesize mouseIsDown;
- (void) _setMouseIsDown:(BOOL)n	{
	mouseIsDown = n;
}
@synthesize flushMode;


@end

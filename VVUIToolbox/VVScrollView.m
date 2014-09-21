#import "VVScrollView.h"
#if !IPHONE
#import <OpenGL/CGLMacro.h>
#endif



#define LTBBM localToBackingBoundsMultiplier




@implementation VVScrollView


- (void) generalInit	{
	//NSLog(@"%s",__func__);
	_documentView = nil;
	
	lastSubviewsUnion = VVMAKESIZE(1,1);
	
	showHScroll = YES;
	//hLeftSprite = nil;
	//hRightSprite = nil;
	hScrollTrack = nil;
	hScrollBar = nil;
	
	showVScroll = YES;
	//vUpSprite = nil;
	//vDownSprite = nil;
	vScrollTrack = nil;
	vScrollBar = nil;
	
	[super generalInit];
}
- (void) initComplete	{
	[super initComplete];
	
	_documentView = [[VVView alloc] initWithFrame:[self bounds]];
	[_documentView setAutoresizingMask:VVViewResizeWidth|VVViewResizeHeight];
	[self addSubview:_documentView];
}
- (void) prepareToBeDeleted	{
	[super prepareToBeDeleted];
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(_documentView);
	[super dealloc];
}
- (void) updateSprites	{
	//NSLog(@"%s",__func__);
	[super updateSprites];
	
	VVRECT		ib = VVINTEGRALRECT([self bounds]);
	VVRECT		tmpRect = tmpRect = VVMAKERECT(0,0,1,1);
	
	if (hScrollTrack == nil)	{
		hScrollTrack = [spriteManager makeNewSpriteAtTopForRect:tmpRect];
		[hScrollTrack setDrawCallback:@selector(drawHSprite:)];
		[hScrollTrack setActionCallback:@selector(hSpriteAction:)];
		[hScrollTrack setDelegate:self];
		hScrollBar = [spriteManager makeNewSpriteAtTopForRect:tmpRect];
		[hScrollBar setDrawCallback:@selector(drawHSprite:)];
		[hScrollBar setActionCallback:@selector(hSpriteAction:)];
		[hScrollBar setDelegate:self];
		
		vScrollTrack = [spriteManager makeNewSpriteAtTopForRect:tmpRect];
		[vScrollTrack setDrawCallback:@selector(drawVSprite:)];
		[vScrollTrack setActionCallback:@selector(vSpriteAction:)];
		[vScrollTrack setDelegate:self];
		vScrollBar = [spriteManager makeNewSpriteAtTopForRect:tmpRect];
		[vScrollBar setDrawCallback:@selector(drawVSprite:)];
		[vScrollBar setActionCallback:@selector(vSpriteAction:)];
		[vScrollBar setDelegate:self];
	}
	
	int			sbw = 15;	//	scroll bar width
	
	//	make sure the document view is sized and positioned properly within me
	tmpRect = ib;
	if (showVScroll)
		tmpRect.size.width -= sbw;
	if (showHScroll)
		tmpRect.size.height -= sbw;
	tmpRect.origin.y += sbw;
	if (!VVEQUALRECTS(tmpRect,[_documentView frame]))	{
		//VVRectLog(@"\t\tsetting _documentView frame to",tmpRect);
		[_documentView setFrame:tmpRect];
	}
	//ib = tmpRect;
	
	//	up to now we've been working in local coords- now we start setting sprite positions, and this is in coords that take the local to backing bounds into account
	ib = VVMAKERECT(ib.origin.x*LTBBM, ib.origin.y*LTBBM, ib.size.width*LTBBM, ib.size.height*LTBBM);
	sbw *= LTBBM;
	
	VVRECT		contentFrame = [_documentView subviewFramesUnion];
	VVRECT		viewBounds = [_documentView bounds];
	double		scrollNormVal;
	double		trackLength;
	//VVRectLog(@"\t\tcontentFrame is",contentFrame);
	//VVRectLog(@"\t\tviewBounds is",viewBounds);
	
	[hScrollTrack setHidden:!showHScroll];
	[hScrollBar setHidden:!showHScroll];
	if (showHScroll)	{
		//	h scroll track
		tmpRect.origin = VVMAKEPOINT(0,0);
		tmpRect.size = VVMAKESIZE(ib.size.width-tmpRect.origin.x, sbw);
		if (showVScroll)
			tmpRect.size.width -= sbw;
		[hScrollTrack setRect:tmpRect];
		
		//	h scroll bar
		trackLength = [hScrollTrack rect].size.width;
		if (viewBounds.size.width < contentFrame.size.width)	{
			tmpRect.size = VVMAKESIZE(viewBounds.size.width/contentFrame.size.width*trackLength, sbw);
			tmpRect.origin = [hScrollTrack rect].origin;
			scrollNormVal = (viewBounds.origin.x-contentFrame.origin.x)/contentFrame.size.width;
			tmpRect.origin.x += trackLength*scrollNormVal;
			[hScrollBar setRect:tmpRect];
		}
		else	{
			[hScrollBar setRect:VVMAKERECT(-2,-2,1,1)];
		}
	}
	
	[vScrollTrack setHidden:!showVScroll];
	[vScrollBar setHidden:!showVScroll];
	if (showVScroll)	{
		//	v scroll track
		tmpRect.origin = VVMAKEPOINT(ib.size.width-sbw, 0);
		if (showVScroll)
			tmpRect.origin.y -= sbw;
		tmpRect.size.height = ib.size.height-tmpRect.origin.y;
		[vScrollTrack setRect:tmpRect];
		
		//	v scroll bar
		trackLength = [vScrollTrack rect].size.height;
		if (viewBounds.size.height < contentFrame.size.height)	{
			tmpRect.size = VVMAKESIZE(sbw, viewBounds.size.height/contentFrame.size.height*trackLength);
			tmpRect.origin = [vScrollTrack rect].origin;
			scrollNormVal = (viewBounds.origin.y-contentFrame.origin.y)/contentFrame.size.height;
			tmpRect.origin.y += trackLength*scrollNormVal;
			[vScrollBar setRect:tmpRect];
		}
		else	{
			[vScrollBar setRect:VVMAKERECT(-2,-2,1,1)];
		}
	}
}
- (void) _setFrameSize:(VVSIZE)n	{
	VVSIZE			oldSize = _frame.size;
	//VVSizeLog(@"\t\toldSize is",oldSize);
	VVSIZE			newSize = VVMAKESIZE(fmax(minFrameSize.width,n.width),fmax(minFrameSize.height,n.height));
	BOOL			changed = (VVEQUALSIZES(oldSize,newSize)) ? NO : YES;
	VVPOINT			normScrollVal = (changed) ? [self normalizedScrollVal] : VVZEROPOINT;
	
	[super _setFrameSize:n];
	
	if (changed)
		[self scrollToNormalizedVal:normScrollVal];
}


- (void) hSpriteAction:(VVSprite *)s	{
	//NSLog(@"%s",__func__);
	if ([s hidden])
		return;
	if (s == hScrollTrack)	{
		//NSLog(@"\t\th scroll track");
		//	figure out the normalized scroll val from the action location within the sprite of the scroll track
		VVRECT		trackRect = [s rect];
		//VVRectLog(@"\t\ttrackRect is",trackRect);
		VVPOINT		lastActionCoords = [s lastActionCoords];
		lastActionCoords = VVMAKEPOINT(lastActionCoords.x-trackRect.origin.x, lastActionCoords.y-trackRect.origin.y);
		//VVPointLog(@"\t\tlastActionCoords is",lastActionCoords);
		double		scrollNormVal = lastActionCoords.x/trackRect.size.width;
		scrollNormVal = fmin(1,fmax(0,scrollNormVal));
		//NSLog(@"\t\tscrollNormVal is %0.4f",scrollNormVal);
		//	from the dimensions of the content in the doc and the dimensions of the doc bounds, figure out the range of possible bounds origin vals for the scroll bar
		VVRECT		contentFrame = [_documentView subviewFramesUnion];
		VVRECT		viewBounds = [_documentView bounds];
		double		travelLoc = VVMINX(contentFrame);
		double		travelLen = contentFrame.size.width-viewBounds.size.width;
		viewBounds.origin.x = scrollNormVal * travelLen + travelLoc;
		//	apply the bounds to the document view, flag for sprite update
		[_documentView setBoundsOrigin:viewBounds.origin];
		[self setSpritesNeedUpdate];
	}
	else if (s == hScrollBar)	{
		//NSLog(@"\t\tscroll bar");
		VVRECT		trackRect = [hScrollTrack rect];
		VVPOINT		delta = [s mouseDownDelta];
		VVRECT		newBarFrame = [s rect];
		newBarFrame.origin = VVMAKEPOINT(newBarFrame.origin.x+delta.x, newBarFrame.origin.y+delta.y);
		double		scrollNormVal = (newBarFrame.origin.x-trackRect.origin.x) / (trackRect.size.width-newBarFrame.size.width);
		scrollNormVal = fmin(1,fmax(0,scrollNormVal));
		//NSLog(@"\t\tscrollNormVal is %0.4f",scrollNormVal);
		//	from the dimensions of the content in the doc and the dimensions of the doc bounds, figure out the range of possible bounds origin vals for the scroll bar
		VVRECT		contentFrame = [_documentView subviewFramesUnion];
		VVRECT		viewBounds = [_documentView bounds];
		double		travelLoc = VVMINX(contentFrame);
		double		travelLen = contentFrame.size.width-viewBounds.size.width;
		viewBounds.origin.x = scrollNormVal * travelLen + travelLoc;
		//	apply the bounds to the document view, flag for sprite update
		[_documentView setBoundsOrigin:viewBounds.origin];
		[self setSpritesNeedUpdate];
	}
}
- (void) drawHSprite:(VVSprite *)s	{
	//NSLog(@"%s",__func__);
#if IPHONE
	NSLog(@"\t\tINCOMPLETE: need to draw here, %s",__func__);
#else
	if ([s hidden])
		return;
	CGLContextObj		cgl_ctx = [s glDrawContext];
	VVRECT				tmpRect = [s rect];
	//tmpRect = VVMAKERECT(tmpRect.origin.x*LTBBM, tmpRect.origin.y*LTBBM, tmpRect.size.width*LTBBM, tmpRect.size.height*LTBBM);
	if (s == hScrollTrack)	{
		glColor4f(0,0,1,1);
		GLDRAWRECT(tmpRect);
	}
	else if (s == hScrollBar)	{
		glColor4f(1,1,1,1);
		GLDRAWRECT(tmpRect);
	}
#endif
}
- (void) vSpriteAction:(VVSprite *)s	{
	//NSLog(@"%s",__func__);
	if ([s hidden])
		return;
	if (s == vScrollTrack)	{
		//NSLog(@"\t\tv scroll track");
		//	figure out the normalized scroll val from the action location within the sprite of the scroll track
		VVRECT		trackRect = [s rect];
		//VVRectLog(@"\t\ttrackRect is",trackRect);
		VVPOINT		lastActionCoords = [s lastActionCoords];
		lastActionCoords = VVMAKEPOINT(lastActionCoords.x-trackRect.origin.x, lastActionCoords.y-trackRect.origin.y);
		//VVPointLog(@"\t\tlastActionCoords is",lastActionCoords);
		double		scrollNormVal = lastActionCoords.y/trackRect.size.height;
		scrollNormVal = fmin(1,fmax(0,scrollNormVal));
		//NSLog(@"\t\tscrollNormVal is %0.4f",scrollNormVal);
		//	from the dimensions of the content in the doc and the dimensions of the doc bounds, figure out the range of possible bounds origin vals for the scroll bar
		VVRECT		contentFrame = [_documentView subviewFramesUnion];
		VVRECT		viewBounds = [_documentView bounds];
		double		travelLoc = VVMINY(contentFrame);
		double		travelLen = contentFrame.size.height-viewBounds.size.height;
		viewBounds.origin.y = scrollNormVal * travelLen + travelLoc;
		//	apply the bounds to the document view, flag for sprite update
		[_documentView setBoundsOrigin:viewBounds.origin];
		[self setSpritesNeedUpdate];
	}
	else if (s == vScrollBar)	{
		//NSLog(@"\t\tscroll bar");
		VVRECT		trackRect = [vScrollTrack rect];
		VVPOINT		delta = [s mouseDownDelta];
		VVRECT		newBarFrame = [s rect];
		newBarFrame.origin = VVMAKEPOINT(newBarFrame.origin.x+delta.x, newBarFrame.origin.y+delta.y);
		double		scrollNormVal = (newBarFrame.origin.y-trackRect.origin.y) / (trackRect.size.height-newBarFrame.size.height);
		scrollNormVal = fmin(1,fmax(0,scrollNormVal));
		//NSLog(@"\t\tscrollNormVal is %0.4f",scrollNormVal);
		//	from the dimensions of the content in the doc and the dimensions of the doc bounds, figure out the range of possible bounds origin vals for the scroll bar
		VVRECT		contentFrame = [_documentView subviewFramesUnion];
		VVRECT		viewBounds = [_documentView bounds];
		double		travelLoc = VVMINY(contentFrame);
		double		travelLen = contentFrame.size.height-viewBounds.size.height;
		viewBounds.origin.y = scrollNormVal * travelLen + travelLoc;
		//	apply the bounds to the document view, flag for sprite update
		[_documentView setBoundsOrigin:viewBounds.origin];
		[self setSpritesNeedUpdate];
	}
}
- (void) drawVSprite:(VVSprite *)s	{
	//NSLog(@"%s",__func__);
#if IPHONE
	NSLog(@"\t\tINCOMPLETE: need to draw here, %s",__func__);
#else
	if ([s hidden])
		return;
	CGLContextObj		cgl_ctx = [s glDrawContext];
	VVRECT				tmpRect = [s rect];
	//tmpRect = VVMAKERECT(tmpRect.origin.x*LTBBM, tmpRect.origin.y*LTBBM, tmpRect.size.width*LTBBM, tmpRect.size.height*LTBBM);
	if (s == vScrollTrack)	{
		glColor4f(0,0,1,1);
		GLDRAWRECT(tmpRect);
	}
	else if (s == vScrollBar)	{
		glColor4f(1,1,1,1);
		GLDRAWRECT(tmpRect);
	}
#endif
}


- (VVView *) documentView	{
	return _documentView;
}


- (void) setShowHScroll:(BOOL)n	{
	BOOL		changed = (n==showHScroll) ? NO : YES;
	if (changed)	{
		showHScroll = n;
		[self setSpritesNeedUpdate];
	}
}
- (BOOL) showHScroll	{
	return showHScroll;
}
- (void) setShowVScroll:(BOOL)n	{
	BOOL		changed = (n==showVScroll) ? NO : YES;
	if (changed)	{
		showVScroll = n;
		[self setSpritesNeedUpdate];
	}
}
- (BOOL) showVScroll	{
	return showVScroll;
}
- (VVPOINT) normalizedScrollVal	{
	if (deleted || vScrollTrack==nil || vScrollBar==nil || hScrollTrack==nil || hScrollBar==nil)
		return VVZEROPOINT;
	VVPOINT			returnMe = VVZEROPOINT;
	VVRECT			trackRect;
	VVRECT			barRect;
	
	if (showHScroll)	{
		trackRect = [hScrollTrack rect];
		barRect = [hScrollBar rect];
		returnMe.x = (barRect.origin.x-trackRect.origin.x)/(trackRect.size.width-barRect.size.width);
	}
	else
		returnMe.x = 0.0;
	if (showVScroll)	{
		trackRect = [vScrollTrack rect];
		barRect = [vScrollBar rect];
		returnMe.y = (barRect.origin.y-trackRect.origin.y)/(trackRect.size.height-barRect.size.height);
	}
	else
		returnMe.y = 0.0;
	return returnMe;
}
- (void) scrollToNormalizedVal:(VVPOINT)n	{
	if (deleted || vScrollTrack==nil || vScrollBar==nil || hScrollTrack==nil || hScrollBar==nil)	{
		NSLog(@"\t\terr: bailing, %s",__func__);
		return;
	}
	VVPOINT			newPoint = VVMAKEPOINT(fmin(fmax(n.x,0.0),1.0), fmin(fmax(n.y,0.0),1.0));
	VVRECT			contentFrame = [_documentView subviewFramesUnion];
	VVRECT			viewBounds = [_documentView bounds];
	double			travelLoc;
	double			travelLen;
	
	//	if the view bounds (the "opening") is larger than the stuff that appears within it, just center
	if (viewBounds.size.width > contentFrame.size.width)	{
		viewBounds.origin.x = contentFrame.origin.x - (viewBounds.size.width-contentFrame.size.width)/2.0;
	}
	else	{
		travelLoc = VVMINX(contentFrame);
		travelLen = contentFrame.size.width-viewBounds.size.width;
		viewBounds.origin.x = (newPoint.x * travelLen) + travelLoc;
	}
	
	if (viewBounds.size.height > contentFrame.size.height)	{
		viewBounds.origin.y = contentFrame.origin.y - (viewBounds.size.height-contentFrame.size.height)/2.0;
	}
	else	{
		travelLoc = VVMINY(contentFrame);
		travelLen = contentFrame.size.height-viewBounds.size.height;
		viewBounds.origin.y = (newPoint.y * travelLen) + travelLoc;
	}
	
	[_documentView setBoundsOrigin:viewBounds.origin];
	[self setSpritesNeedUpdate];
}
- (void) scrollTopLeftToPoint:(VVPOINT)n	{
	VVRECT			contentFrame = [_documentView subviewFramesUnion];
	VVRECT			viewBounds = [_documentView bounds];
	viewBounds.origin = VVMAKEPOINT(n.x, n.y-viewBounds.size.height);
	
	VVPOINT			normScrollVal;
	normScrollVal.x = viewBounds.origin.x / (contentFrame.size.width-viewBounds.size.width);
	normScrollVal.y = viewBounds.origin.y / (contentFrame.size.height-viewBounds.size.height);
	[self scrollToNormalizedVal:normScrollVal];
}
- (void) scrollByAmount:(VVPOINT)delta	{
	//NSLog(@"%s ... (%0.2f, %0.2f",__func__,delta.x,delta.y);
	VVRECT			contentFrame = [_documentView subviewFramesUnion];
	//	assume 'delta' is in point coordinates- figure out how many "points" are in the full scrollable area (content view
	VVPOINT			normScrollVal = [self normalizedScrollVal];
	normScrollVal.x -= (delta.x/contentFrame.size.width);
	normScrollVal.y += (delta.y/contentFrame.size.height);
	[self scrollToNormalizedVal:normScrollVal];
}


- (VVRECT) documentVisibleRect	{
	if (_documentView==nil)
		return VVZERORECT;
	return [_documentView visibleRect];
}


@end

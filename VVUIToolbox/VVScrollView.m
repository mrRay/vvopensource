#import "VVScrollView.h"
#import <OpenGL/CGLMacro.h>




#define LTBBM localToBackingBoundsMultiplier




@implementation VVScrollView


- (void) generalInit	{
	//NSLog(@"%s",__func__);
	_documentView = nil;
	
	lastSubviewsUnion = NSMakeSize(1,1);
	
	//hLeftSprite = nil;
	//hRightSprite = nil;
	hScrollTrack = nil;
	hScrollBar = nil;
	
	//vUpSprite = nil;
	//vDownSprite = nil;
	vScrollTrack = nil;
	vScrollBar = nil;
	
	[super generalInit];
}
- (void) initComplete	{
	[super initComplete];
	
	_documentView = [[VVView alloc] initWithFrame:[self bounds]];
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
	
	NSRect		ib = NSIntegralRect([self bounds]);
	NSRect		tmpRect = tmpRect = NSMakeRect(0,0,1,1);
	
	if (hScrollTrack == nil)	{
		/*
		hLeftSprite = [spriteManager newSpriteAtTopForRect:tmpRect];
		[hLeftSprite setDrawCallback:@selector(drawHSprite:)];
		[hLeftSprite setActionCallback:@selector(hSpriteAction:)];
		[hLeftSprite setDelegate:self];
		hRightSprite = [spriteManager newSpriteAtTopForRect:tmpRect];
		[hRightSprite setDrawCallback:@selector(drawHSprite:)];
		[hRightSprite setActionCallback:@selector(hSpriteAction:)];
		[hRightSprite setDelegate:self];
		*/
		hScrollTrack = [spriteManager newSpriteAtTopForRect:tmpRect];
		[hScrollTrack setDrawCallback:@selector(drawHSprite:)];
		[hScrollTrack setActionCallback:@selector(hSpriteAction:)];
		[hScrollTrack setDelegate:self];
		hScrollBar = [spriteManager newSpriteAtTopForRect:tmpRect];
		[hScrollBar setDrawCallback:@selector(drawHSprite:)];
		[hScrollBar setActionCallback:@selector(hSpriteAction:)];
		[hScrollBar setDelegate:self];
		
		/*
		vUpSprite = [spriteManager newSpriteAtTopForRect:tmpRect];
		[vUpSprite setDrawCallback:@selector(drawVSprite:)];
		[vUpSprite setActionCallback:@selector(vSpriteAction:)];
		[vUpSprite setDelegate:self];
		vDownSprite = [spriteManager newSpriteAtTopForRect:tmpRect];
		[vDownSprite setDrawCallback:@selector(drawVSprite:)];
		[vDownSprite setActionCallback:@selector(vSpriteAction:)];
		[vDownSprite setDelegate:self];
		*/
		vScrollTrack = [spriteManager newSpriteAtTopForRect:tmpRect];
		[vScrollTrack setDrawCallback:@selector(drawVSprite:)];
		[vScrollTrack setActionCallback:@selector(vSpriteAction:)];
		[vScrollTrack setDelegate:self];
		vScrollBar = [spriteManager newSpriteAtTopForRect:tmpRect];
		[vScrollBar setDrawCallback:@selector(drawVSprite:)];
		[vScrollBar setActionCallback:@selector(vSpriteAction:)];
		[vScrollBar setDelegate:self];
	}
	
	int			sbw = 22;	//	scroll bar width
	
	//	make sure the document view is sized and positioned properly within me
	tmpRect = ib;
	tmpRect.size.width -= sbw;
	tmpRect.size.height -= sbw;
	tmpRect.origin.y += sbw;
	if (!NSEqualRects(tmpRect,[_documentView frame]))	{
		//NSRectLog(@"\t\tsetting _documentView frame to",tmpRect);
		[_documentView setFrame:tmpRect];
	}
	
	//	up to now we've been working in local coords- now we start setting sprite positions, and this is in coords that take the local to backing bounds into account
	ib = NSMakeRect(ib.origin.x*LTBBM, ib.origin.y*LTBBM, ib.size.width*LTBBM, ib.size.height*LTBBM);
	sbw *= LTBBM;
	
	NSRect		contentFrame = [_documentView subviewFramesUnion];
	NSRect		viewBounds = [_documentView bounds];
	double		scrollNormVal;
	double		trackLength;
	//NSRectLog(@"\t\tcontentFrame is",contentFrame);
	//NSRectLog(@"\t\tviewBounds is",viewBounds);
	
	//	h scroll track
	tmpRect.origin = NSMakePoint(0,0);
	tmpRect.size = NSMakeSize(ib.size.width-sbw-tmpRect.origin.x, sbw);
	[hScrollTrack setRect:tmpRect];
	
	//	h scroll bar
	trackLength = [hScrollTrack rect].size.width;
	if (viewBounds.size.width < contentFrame.size.width)	{
		tmpRect.size = NSMakeSize(viewBounds.size.width/contentFrame.size.width*trackLength, sbw);
		tmpRect.origin = [hScrollTrack rect].origin;
		scrollNormVal = (viewBounds.origin.x-contentFrame.origin.x)/contentFrame.size.width;
		tmpRect.origin.x += trackLength*scrollNormVal;
		[hScrollBar setRect:tmpRect];
	}
	else	{
		[hScrollBar setRect:NSMakeRect(-2,-2,1,1)];
	}
	
	//	v scroll track
	tmpRect.origin = NSMakePoint(ib.size.width-sbw, 0);
	tmpRect.size.height = ib.size.height-tmpRect.origin.y;
	[vScrollTrack setRect:tmpRect];
	
	//	v scroll bar
	trackLength = [vScrollTrack rect].size.height;
	if (viewBounds.size.height < contentFrame.size.height)	{
		tmpRect.size = NSMakeSize(sbw, viewBounds.size.height/contentFrame.size.height*trackLength);
		tmpRect.origin = [vScrollTrack rect].origin;
		scrollNormVal = (viewBounds.origin.y-contentFrame.origin.y)/contentFrame.size.height;
		tmpRect.origin.y += trackLength*scrollNormVal;
		[vScrollBar setRect:tmpRect];
	}
	else	{
		[vScrollBar setRect:NSMakeRect(-2,-2,1,1)];
	}
}
- (void) _setFrameSize:(NSSize)n	{
	NSSize			oldSize = _frame.size;
	//NSSizeLog(@"\t\toldSize is",oldSize);
	NSSize			newSize = NSMakeSize(fmax(minFrameSize.width,n.width),fmax(minFrameSize.height,n.height));
	BOOL			changed = (NSEqualSizes(oldSize,newSize)) ? NO : YES;
	NSPoint			normScrollVal = (changed) ? [self normalizedScrollVal] : NSZeroPoint;
	
	[super _setFrameSize:n];
	
	if (changed)
		[self scrollToNormalizedVal:normScrollVal];
}


- (void) hSpriteAction:(VVSprite *)s	{
	//NSLog(@"%s",__func__);
	if (s == hScrollTrack)	{
		//NSLog(@"\t\th scroll track");
		//	figure out the normalized scroll val from the action location within the sprite of the scroll track
		NSRect		trackRect = [s rect];
		//NSRectLog(@"\t\ttrackRect is",trackRect);
		NSPoint		lastActionCoords = [s lastActionCoords];
		lastActionCoords = NSMakePoint(lastActionCoords.x-trackRect.origin.x, lastActionCoords.y-trackRect.origin.y);
		//NSPointLog(@"\t\tlastActionCoords is",lastActionCoords);
		double		scrollNormVal = lastActionCoords.x/trackRect.size.width;
		scrollNormVal = fmin(1,fmax(0,scrollNormVal));
		//NSLog(@"\t\tscrollNormVal is %0.4f",scrollNormVal);
		//	from the dimensions of the content in the doc and the dimensions of the doc bounds, figure out the range of possible bounds origin vals for the scroll bar
		NSRect		contentFrame = [_documentView subviewFramesUnion];
		NSRect		viewBounds = [_documentView bounds];
		double		travelLoc = VVMINX(contentFrame);
		double		travelLen = contentFrame.size.width-viewBounds.size.width;
		viewBounds.origin.x = scrollNormVal * travelLen + travelLoc;
		//	apply the bounds to the document view, flag for sprite update
		[_documentView setBoundsOrigin:viewBounds.origin];
		[self setSpritesNeedUpdate];
	}
	else if (s == hScrollBar)	{
		//NSLog(@"\t\tscroll bar");
		NSRect		trackRect = [hScrollTrack rect];
		NSPoint		delta = [s mouseDownDelta];
		NSRect		newBarFrame = [s rect];
		newBarFrame.origin = NSMakePoint(newBarFrame.origin.x+delta.x, newBarFrame.origin.y+delta.y);
		double		scrollNormVal = (newBarFrame.origin.x-trackRect.origin.x) / (trackRect.size.width-newBarFrame.size.width);
		scrollNormVal = fmin(1,fmax(0,scrollNormVal));
		//NSLog(@"\t\tscrollNormVal is %0.4f",scrollNormVal);
		//	from the dimensions of the content in the doc and the dimensions of the doc bounds, figure out the range of possible bounds origin vals for the scroll bar
		NSRect		contentFrame = [_documentView subviewFramesUnion];
		NSRect		viewBounds = [_documentView bounds];
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
	CGLContextObj		cgl_ctx = [s glDrawContext];
	NSRect				tmpRect = [s rect];
	//tmpRect = NSMakeRect(tmpRect.origin.x*LTBBM, tmpRect.origin.y*LTBBM, tmpRect.size.width*LTBBM, tmpRect.size.height*LTBBM);
	if (s == hScrollTrack)	{
		glColor4f(0,0,1,1);
		GLDRAWRECT(tmpRect);
	}
	else if (s == hScrollBar)	{
		glColor4f(1,1,1,1);
		GLDRAWRECT(tmpRect);
	}
}
- (void) vSpriteAction:(VVSprite *)s	{
	//NSLog(@"%s",__func__);
	if (s == vScrollTrack)	{
		//NSLog(@"\t\tv scroll track");
		//	figure out the normalized scroll val from the action location within the sprite of the scroll track
		NSRect		trackRect = [s rect];
		//NSRectLog(@"\t\ttrackRect is",trackRect);
		NSPoint		lastActionCoords = [s lastActionCoords];
		lastActionCoords = NSMakePoint(lastActionCoords.x-trackRect.origin.x, lastActionCoords.y-trackRect.origin.y);
		//NSPointLog(@"\t\tlastActionCoords is",lastActionCoords);
		double		scrollNormVal = lastActionCoords.y/trackRect.size.height;
		scrollNormVal = fmin(1,fmax(0,scrollNormVal));
		//NSLog(@"\t\tscrollNormVal is %0.4f",scrollNormVal);
		//	from the dimensions of the content in the doc and the dimensions of the doc bounds, figure out the range of possible bounds origin vals for the scroll bar
		NSRect		contentFrame = [_documentView subviewFramesUnion];
		NSRect		viewBounds = [_documentView bounds];
		double		travelLoc = VVMINY(contentFrame);
		double		travelLen = contentFrame.size.height-viewBounds.size.height;
		viewBounds.origin.y = scrollNormVal * travelLen + travelLoc;
		//	apply the bounds to the document view, flag for sprite update
		[_documentView setBoundsOrigin:viewBounds.origin];
		[self setSpritesNeedUpdate];
	}
	else if (s == vScrollBar)	{
		//NSLog(@"\t\tscroll bar");
		NSRect		trackRect = [vScrollTrack rect];
		NSPoint		delta = [s mouseDownDelta];
		NSRect		newBarFrame = [s rect];
		newBarFrame.origin = NSMakePoint(newBarFrame.origin.x+delta.x, newBarFrame.origin.y+delta.y);
		double		scrollNormVal = (newBarFrame.origin.y-trackRect.origin.y) / (trackRect.size.height-newBarFrame.size.height);
		scrollNormVal = fmin(1,fmax(0,scrollNormVal));
		//NSLog(@"\t\tscrollNormVal is %0.4f",scrollNormVal);
		//	from the dimensions of the content in the doc and the dimensions of the doc bounds, figure out the range of possible bounds origin vals for the scroll bar
		NSRect		contentFrame = [_documentView subviewFramesUnion];
		NSRect		viewBounds = [_documentView bounds];
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
	CGLContextObj		cgl_ctx = [s glDrawContext];
	NSRect				tmpRect = [s rect];
	//tmpRect = NSMakeRect(tmpRect.origin.x*LTBBM, tmpRect.origin.y*LTBBM, tmpRect.size.width*LTBBM, tmpRect.size.height*LTBBM);
	if (s == vScrollTrack)	{
		glColor4f(0,0,1,1);
		GLDRAWRECT(tmpRect);
	}
	else if (s == vScrollBar)	{
		glColor4f(1,1,1,1);
		GLDRAWRECT(tmpRect);
	}
}


- (VVView *) documentView	{
	return _documentView;
}


- (NSPoint) normalizedScrollVal	{
	if (deleted || vScrollTrack==nil || vScrollBar==nil || hScrollTrack==nil || hScrollBar==nil)
		return NSZeroPoint;
	NSPoint			returnMe = NSZeroPoint;
	NSRect			trackRect;
	NSRect			barRect;
	
	trackRect = [hScrollTrack rect];
	barRect = [hScrollBar rect];
	returnMe.x = (barRect.origin.x-trackRect.origin.x)/(trackRect.size.width-barRect.size.width);
	trackRect = [vScrollTrack rect];
	barRect = [vScrollBar rect];
	returnMe.y = (barRect.origin.y-trackRect.origin.y)/(trackRect.size.height-barRect.size.height);
	return returnMe;
}
- (void) scrollToNormalizedVal:(NSPoint)n	{
	if (deleted || vScrollTrack==nil || vScrollBar==nil || hScrollTrack==nil || hScrollBar==nil)
		return;
	NSPoint			newPoint = NSMakePoint(fmin(fmax(n.x,0.0),1.0), fmin(fmax(n.y,0.0),1.0));
	NSRect			contentFrame = [_documentView subviewFramesUnion];
	NSRect			viewBounds = [_documentView bounds];
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
- (void) scrollTopLeftToPoint:(NSPoint)n	{
	NSRect			contentFrame = [_documentView subviewFramesUnion];
	NSRect			viewBounds = [_documentView bounds];
	viewBounds.origin = NSMakePoint(n.x, n.y-viewBounds.size.height);
	
	NSPoint			normScrollVal;
	normScrollVal.x = viewBounds.origin.x / (contentFrame.size.width-viewBounds.size.width);
	normScrollVal.y = viewBounds.origin.y / (contentFrame.size.height-viewBounds.size.height);
	[self scrollToNormalizedVal:normScrollVal];
}
- (void) scrollByAmount:(NSPoint)delta	{
	//NSLog(@"%s ... (%0.2f, %0.2f",__func__,delta.x,delta.y);
	NSRect			contentFrame = [_documentView subviewFramesUnion];
	//	assume 'delta' is in point coordinates- figure out how many "points" are in the full scrollable area (content view
	NSPoint			normScrollVal = [self normalizedScrollVal];
	normScrollVal.x -= (delta.x/contentFrame.size.width);
	normScrollVal.y += (delta.y/contentFrame.size.height);
	[self scrollToNormalizedVal:normScrollVal];
}


@end

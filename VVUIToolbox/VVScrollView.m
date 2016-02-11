#import "VVScrollView.h"
#if !TARGET_OS_IPHONE
#import <OpenGL/CGLMacro.h>
#endif



#define LTBBM localToBackingBoundsMultiplier
#define PI (3.1415926535897932384626433832795)

//	this function evaluates the x,y coords of points along the circumference of a circle.  starts evaluating at 'startAngleRadians', stops evaluation at 'endAngleRadians'.  'centerPoint' is the center of the circle, 'radius' defines its circumference, 'vertCount' is the number of vertices to evaluate.  the results are written into 'destBuffer' as a series of three GLfloat values per vertex.  returns a ptr to the memory in 'wPtr' after these additions.
GLfloat* VVEvaluateCircleVerts(double startAngleRadians, double endAngleRadians, VVPOINT centerPoint, double radius, int vertCount, GLfloat *destBuffer);




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
	
	vertsAroundEndCap = 12;	//	the number of verts used to draw half a circle
	scrollTrackVertCount = (vertsAroundEndCap * 2) + 1;	//	the track is just a line strip (two end caps plus one last vert to close the loop)
	int				vertsPerEndCap = vertsAroundEndCap + 1;	//	the '1' is the center point, rest are drawn as a fan strip
	scrollBarVertCount = (vertsPerEndCap * 2) + 4;	//	2 endcaps + 4 points to define a quad
	
	hScrollTrackVerts = malloc(sizeof(GLfloat)*scrollTrackVertCount*3);
	vScrollTrackVerts = malloc(sizeof(GLfloat)*scrollTrackVertCount*3);
	hScrollBarVerts = malloc(sizeof(GLfloat)*scrollBarVertCount*3);
	vScrollBarVerts =  malloc(sizeof(GLfloat)*scrollBarVertCount*3);
	
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
	free(hScrollTrackVerts);
	free(vScrollTrackVerts);
	free(hScrollBarVerts);
	free(vScrollBarVerts);
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
	}
	if (hScrollBar==nil)	{
		hScrollBar = [spriteManager makeNewSpriteAtTopForRect:tmpRect];
		[hScrollBar setDrawCallback:@selector(drawHSprite:)];
		[hScrollBar setActionCallback:@selector(hSpriteAction:)];
		[hScrollBar setDelegate:self];
	}
	if (vScrollTrack==nil)	{
		vScrollTrack = [spriteManager makeNewSpriteAtTopForRect:tmpRect];
		[vScrollTrack setDrawCallback:@selector(drawVSprite:)];
		[vScrollTrack setActionCallback:@selector(vSpriteAction:)];
		[vScrollTrack setDelegate:self];
	}
	if (vScrollBar==nil)	{
		vScrollBar = [spriteManager makeNewSpriteAtTopForRect:tmpRect];
		[vScrollBar setDrawCallback:@selector(drawVSprite:)];
		[vScrollBar setActionCallback:@selector(vSpriteAction:)];
		[vScrollBar setDelegate:self];
	}
	
	int			sbw = 12;	//	scroll bar width
	int			minSBL = 4*sbw;	//	min scroll bar length
	
	//	make sure the document view is sized and positioned properly within me
	tmpRect = ib;
	if (showVScroll)
		tmpRect.size.width -= sbw;
	if (showHScroll)	{
		tmpRect.size.height -= sbw;
		tmpRect.origin.y += sbw;
	}
	tmpRect = VVINTEGRALRECT(tmpRect);
	if (!VVEQUALRECTS(tmpRect,[_documentView frame]))	{
		//VVRectLog(@"\t\tsetting _documentView frame to",tmpRect);
		[_documentView setFrame:tmpRect];
	}
	//ib = tmpRect;
	
	//	up to now we've been working in local coords- now we start setting sprite positions, and this is in coords that take the local to backing bounds into account
	ib = VVMAKERECT(ib.origin.x*LTBBM, ib.origin.y*LTBBM, ib.size.width*LTBBM, ib.size.height*LTBBM);
	sbw *= LTBBM;
	
	VVRECT		contentFrame = [_documentView subviewFramesUnion];
	VVRECT		docViewBounds = [_documentView bounds];
	double		scrollNormVal;
	double		trackLength;
	//VVRectLog(@"\t\tcontentFrame is",contentFrame);
	//VVRectLog(@"\t\tdocViewBounds is",docViewBounds);
	
	//	horizontal scroll stuff!
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
		if (docViewBounds.size.width < contentFrame.size.width)	{
			tmpRect.size = VVMAKESIZE(fmax(minSBL, docViewBounds.size.width/contentFrame.size.width*trackLength), sbw);
			tmpRect.origin = [hScrollTrack rect].origin;
			scrollNormVal = (docViewBounds.origin.x-contentFrame.origin.x)/contentFrame.size.width;
			tmpRect.origin.x += trackLength*scrollNormVal;
			[hScrollBar setRect:tmpRect];
		}
		else	{
			[hScrollBar setRect:VVMAKERECT(-2,-2,1,1)];
		}
		
		//	populate the scroll bar and scroll track vertices using the fact that the (x,y) of a point on the edge of a circle at angle θ is (cos θ, sin θ)
		
		//	populate the scroll track vertices- this is a "line loop", so we just run around the outside edge
		{
			VVRECT		tmpRect = [hScrollTrack rect];
			tmpRect = VVINSETRECT(tmpRect,1.*LTBBM,1.*LTBBM);
			VVPOINT		centerPoint;
			GLfloat		*wPtr = hScrollTrackVerts;
			double		r = tmpRect.size.height/2.;
			//	run from -π/2 to π/2 to draw the right semicircle
			centerPoint = VVMAKEPOINT(VVMAXX(tmpRect)-(tmpRect.size.height/2.), VVMIDY(tmpRect));
			wPtr = VVEvaluateCircleVerts(PI/2., 3.*PI/2., centerPoint, r, vertsAroundEndCap, wPtr);
			//	run from π/2 to (3π)/2 to draw the left semicircle
			centerPoint = VVMAKEPOINT(VVMINX(tmpRect)+(tmpRect.size.height/2.), VVMIDY(tmpRect));
			wPtr = VVEvaluateCircleVerts(-1.*PI/2., PI/2., centerPoint, r, vertsAroundEndCap, wPtr);
			//	...i need to "close the loop" with one more vertex!
			centerPoint = VVMAKEPOINT(VVMAXX(tmpRect)-(tmpRect.size.height/2.), VVMIDY(tmpRect));
			*(wPtr+0) = (r)*cos(PI/2.) + centerPoint.x;
			*(wPtr+1) = (r)*sin(PI/2.) + centerPoint.y;
			*(wPtr+2) = 0.;
		}
		//	populate the scroll bar vertices- this is a "triangle fan" + "triangle fan" + "triangle strip"
		{
			
			VVRECT		tmpRect = [hScrollBar rect];
			//	inset the width of 'tmpRect' a bit- we want the polys we fill in to appear as if they were "just inside" the stroke around the track
			tmpRect = VVINSETRECT(tmpRect,3.*LTBBM,3.*LTBBM);
			VVPOINT		centerPoint;
			GLfloat		*wPtr = hScrollBarVerts;
			double		r = tmpRect.size.height/2.;
			//	first add centerpoint to fan
			centerPoint = VVMAKEPOINT(VVMAXX(tmpRect)-(tmpRect.size.height/2.), VVMIDY(tmpRect));
			*(wPtr+0) = centerPoint.x;
			*(wPtr+1) = centerPoint.y;
			*(wPtr+2) = 0.;
			wPtr += 3;
			//	now run from -π/2 to π/2 to finish the top semicircle (first triangle fan)
			wPtr = VVEvaluateCircleVerts(PI/2., 3.*PI/2., centerPoint, r, vertsAroundEndCap, wPtr);
			
			//	first add centerpoint to fan
			centerPoint = VVMAKEPOINT(VVMINX(tmpRect)+(tmpRect.size.height/2.), VVMIDY(tmpRect));
			*(wPtr+0) = centerPoint.x;
			*(wPtr+1) = centerPoint.y;
			*(wPtr+2) = 0.;
			wPtr += 3;
			//	now run from  π/2 to (3π)/2 to finish the bottom semicircle (second triangle fan)
			wPtr = VVEvaluateCircleVerts(-1.*PI/2., PI/2., centerPoint, r, vertsAroundEndCap, wPtr);
			
			//	draw a triangle strip between the two
			tmpRect.origin.x += (tmpRect.size.height/2.);
			tmpRect.size.width -= tmpRect.size.height;
			for (int i=0; i<4; ++i)	{
				switch (i)	{
				case 0:	//	top-left
					*(wPtr+0) = VVMINX(tmpRect);
					*(wPtr+1) = VVMAXY(tmpRect);
					*(wPtr+2) = 0.;
					break;
				case 1:	//	bottom-left
					*(wPtr+0) = VVMINX(tmpRect);
					*(wPtr+1) = VVMINY(tmpRect);
					*(wPtr+2) = 0.;
					break;
				case 2:	//	top-right
					*(wPtr+0) = VVMAXX(tmpRect);
					*(wPtr+1) = VVMAXY(tmpRect);
					*(wPtr+2) = 0.;
					break;
				case 3:	//	bottom-right
					*(wPtr+0) = VVMAXX(tmpRect);
					*(wPtr+1) = VVMINY(tmpRect);
					*(wPtr+2) = 0.;
					break;
				}
				wPtr += 3;
			}
		}
		
		
		
		
		
		
		//	populate the bar and track vertices (INCOMPLETE, USE VERT AS REFERENCE)
		
		//	run from -π/2 to π/2 to draw the right semicircle
		//	run from π/2 to (3π)/2 to draw the left semicircle
	}
	
	
	//	vertical scroll stuff!
	[vScrollTrack setHidden:!showVScroll];
	[vScrollBar setHidden:!showVScroll];
	if (showVScroll)	{
		//	v scroll track
		tmpRect.origin = VVMAKEPOINT(ib.size.width-sbw, 0);
		if (showHScroll)
			tmpRect.origin.y += sbw;
		tmpRect.size.width = sbw;
		tmpRect.size.height = ib.size.height-tmpRect.origin.y;
		[vScrollTrack setRect:tmpRect];
		
		//	v scroll bar
		trackLength = [vScrollTrack rect].size.height;
		if (docViewBounds.size.height < contentFrame.size.height)	{
			tmpRect.size = VVMAKESIZE(sbw, fmax(minSBL, (docViewBounds.size.height/contentFrame.size.height) * trackLength));
			tmpRect.origin = [vScrollTrack rect].origin;
			scrollNormVal = (docViewBounds.origin.y-contentFrame.origin.y)/contentFrame.size.height;
			tmpRect.origin.y += trackLength*scrollNormVal;
			[vScrollBar setRect:tmpRect];
		}
		else	{
			[vScrollBar setRect:VVMAKERECT(-2,-2,1,1)];
		}
		
		//	populate the scroll bar and scroll track vertices using the fact that the (x,y) of a point on the edge of a circle at angle θ is (cos θ, sin θ)
		
		//	populate the scroll track vertices- this is a "line loop", so we just run around the outside edge
		{
			VVRECT		tmpRect = [vScrollTrack rect];
			tmpRect = VVINSETRECT(tmpRect,1.*LTBBM,1.*LTBBM);
			VVPOINT		centerPoint;
			GLfloat		*wPtr = vScrollTrackVerts;
			double		r = tmpRect.size.width/2.;
			//	run from 0 to π to drop the top semicircle
			centerPoint = VVMAKEPOINT(VVMIDX(tmpRect), VVMINY(tmpRect)+(tmpRect.size.width/2.));
			wPtr = VVEvaluateCircleVerts(0., PI, centerPoint, r, vertsAroundEndCap, wPtr);
			//	run from π to 2π to draw the bottom semicircle
			centerPoint = VVMAKEPOINT(VVMIDX(tmpRect), VVMAXY(tmpRect)-(tmpRect.size.width/2.));
			wPtr = VVEvaluateCircleVerts(PI, 2.*PI, centerPoint, r, vertsAroundEndCap, wPtr);
			//	...i need to "close the loop" with one more vertex!
			centerPoint = VVMAKEPOINT(VVMIDX(tmpRect), VVMINY(tmpRect)+(tmpRect.size.width/2.));
			*(wPtr+0) = (r)*cos(0.) + centerPoint.x;
			*(wPtr+1) = (r)*sin(0.) + centerPoint.y;
			*(wPtr+2) = 0.;
		}
		//	populate the scroll bar vertices- this is a "triangle fan" + "triangle fan" + "triangle strip"
		{
			
			VVRECT		tmpRect = [vScrollBar rect];
			//	inset the width of 'tmpRect' a bit- we want the polys we fill in to appear as if they were "just inside" the stroke around the track
			tmpRect = VVINSETRECT(tmpRect,3.*LTBBM,3.*LTBBM);
			VVPOINT		centerPoint;
			GLfloat		*wPtr = vScrollBarVerts;
			double		r = tmpRect.size.width/2.;
			//	first add centerpoint to fan
			centerPoint = VVMAKEPOINT(VVMIDX(tmpRect), VVMINY(tmpRect)+(tmpRect.size.width/2.));
			*(wPtr+0) = centerPoint.x;
			*(wPtr+1) = centerPoint.y;
			*(wPtr+2) = 0.;
			wPtr += 3;
			//	now run from 0 to π to finish the top semicircle (first triangle fan)
			wPtr = VVEvaluateCircleVerts(0., PI, centerPoint, r, vertsAroundEndCap, wPtr);
			
			//	first add centerpoint to fan
			centerPoint = VVMAKEPOINT(VVMIDX(tmpRect), VVMAXY(tmpRect)-(tmpRect.size.width/2.));
			*(wPtr+0) = centerPoint.x;
			*(wPtr+1) = centerPoint.y;
			*(wPtr+2) = 0.;
			wPtr += 3;
			//	now run from π to 2π to finish the bottom semicircle (second triangle fan)
			wPtr = VVEvaluateCircleVerts(PI, 2.*PI, centerPoint, r, vertsAroundEndCap, wPtr);
			
			//	draw a triangle strip between the two
			tmpRect.origin.y += (tmpRect.size.width/2.);
			tmpRect.size.height -= tmpRect.size.width;
			for (int i=0; i<4; ++i)	{
				switch (i)	{
				case 0:	//	top-left
					*(wPtr+0) = VVMINX(tmpRect);
					*(wPtr+1) = VVMAXY(tmpRect);
					*(wPtr+2) = 0.;
					break;
				case 1:	//	bottom-left
					*(wPtr+0) = VVMINX(tmpRect);
					*(wPtr+1) = VVMINY(tmpRect);
					*(wPtr+2) = 0.;
					break;
				case 2:	//	top-right
					*(wPtr+0) = VVMAXX(tmpRect);
					*(wPtr+1) = VVMAXY(tmpRect);
					*(wPtr+2) = 0.;
					break;
				case 3:	//	bottom-right
					*(wPtr+0) = VVMAXX(tmpRect);
					*(wPtr+1) = VVMINY(tmpRect);
					*(wPtr+2) = 0.;
					break;
				}
				wPtr += 3;
			}
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
- (id) vvSubviewHitTest:(VVPOINT)superviewPoint	{
	id			returnMe = [super vvSubviewHitTest:superviewPoint];
	//	we want to make sure that if the user clicks on me or my document view, it's handled as if nothing was clicked
	if (returnMe==_documentView)
		returnMe = self;
	return returnMe;
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
		viewBounds = VVINTEGRALRECT(viewBounds);
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
		viewBounds = VVINTEGRALRECT(viewBounds);
		//	apply the bounds to the document view, flag for sprite update
		[_documentView setBoundsOrigin:viewBounds.origin];
		[self setSpritesNeedUpdate];
	}
}
- (void) drawHSprite:(VVSprite *)s	{
	//NSLog(@"%s",__func__);
#if TARGET_OS_IPHONE
	NSLog(@"\t\tINCOMPLETE: need to draw here, %s",__func__);
#else
	if ([s hidden])
		return;
	CGLContextObj		cgl_ctx = [s glDrawContext];
	//VVRECT				tmpRect = [s rect];
	//tmpRect = VVMAKERECT(tmpRect.origin.x*LTBBM, tmpRect.origin.y*LTBBM, tmpRect.size.width*LTBBM, tmpRect.size.height*LTBBM);
	if (s == hScrollTrack)	{
		glColor4f(0,0,0,1);
		
		glEnableClientState(GL_VERTEX_ARRAY);
		glDisableClientState(GL_TEXTURE_COORD_ARRAY);
		
		glVertexPointer(3, GL_FLOAT, 0, hScrollTrackVerts);
		glLineWidth(1.*LTBBM);
		glDrawArrays(GL_LINE_STRIP, 0, scrollTrackVertCount);
		/*
		glColor4f(0,0,1,1);
		GLDRAWRECT(tmpRect);
		*/
	}
	else if (s == hScrollBar)	{
		NSPoint			origin = [s rect].origin;
		if (origin.x>=0 && origin.y>=0)	{
			glColor4f(0,0,0,1);
		
			glEnableClientState(GL_VERTEX_ARRAY);
			glDisableClientState(GL_TEXTURE_COORD_ARRAY);
		
			int				offset = 0;
			int				vertCount = (vertsAroundEndCap + 1);
		
			glVertexPointer(3, GL_FLOAT, 0, (hScrollBarVerts + (offset*3)));
			glDrawArrays(GL_TRIANGLE_FAN, 0, vertCount);
			offset += vertCount;
		
			glVertexPointer(3, GL_FLOAT, 0, (hScrollBarVerts + (offset*3)));
			glDrawArrays(GL_TRIANGLE_FAN, 0, vertCount);
			offset += vertCount;
		
			glVertexPointer(3, GL_FLOAT, 0, (hScrollBarVerts + (offset*3)));
			glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		}
		
		/*
		glColor4f(1,1,1,1);
		GLDRAWRECT(tmpRect);
		*/
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
		viewBounds = VVINTEGRALRECT(viewBounds);
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
		viewBounds = VVINTEGRALRECT(viewBounds);
		//	apply the bounds to the document view, flag for sprite update
		[_documentView setBoundsOrigin:viewBounds.origin];
		[self setSpritesNeedUpdate];
	}
}
- (void) drawVSprite:(VVSprite *)s	{
	//NSLog(@"%s",__func__);
#if TARGET_OS_IPHONE
	NSLog(@"\t\tINCOMPLETE: need to draw here, %s",__func__);
#else
	if ([s hidden])
		return;
	CGLContextObj		cgl_ctx = [s glDrawContext];
	//VVRECT				tmpRect = [s rect];
	//tmpRect = VVMAKERECT(tmpRect.origin.x*LTBBM, tmpRect.origin.y*LTBBM, tmpRect.size.width*LTBBM, tmpRect.size.height*LTBBM);
	if (s == vScrollTrack)	{
		glColor4f(0,0,0,1);
		
		glEnableClientState(GL_VERTEX_ARRAY);
		glDisableClientState(GL_TEXTURE_COORD_ARRAY);
		
		glVertexPointer(3, GL_FLOAT, 0, vScrollTrackVerts);
		glLineWidth(1.*LTBBM);
		glDrawArrays(GL_LINE_STRIP, 0, scrollTrackVertCount);
		/*
		glColor4f(0,0,1,1);
		GLDRAWRECT(tmpRect);
		*/
	}
	else if (s == vScrollBar)	{
		NSPoint			origin = [s rect].origin;
		if (origin.x>=0 && origin.y>=0)	{
			glColor4f(0,0,0,1);
		
			glEnableClientState(GL_VERTEX_ARRAY);
			glDisableClientState(GL_TEXTURE_COORD_ARRAY);
		
			int				offset = 0;
			int				vertCount = (vertsAroundEndCap + 1);
		
			glVertexPointer(3, GL_FLOAT, 0, (vScrollBarVerts + (offset*3)));
			glDrawArrays(GL_TRIANGLE_FAN, 0, vertCount);
			offset += vertCount;
		
			glVertexPointer(3, GL_FLOAT, 0, (vScrollBarVerts + (offset*3)));
			glDrawArrays(GL_TRIANGLE_FAN, 0, vertCount);
			offset += vertCount;
		
			glVertexPointer(3, GL_FLOAT, 0, (vScrollBarVerts + (offset*3)));
			glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		}
		/*
		glColor4f(1,1,1,1);
		GLDRAWRECT(tmpRect);
		*/
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
	
	viewBounds = VVINTEGRALRECT(viewBounds);
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






GLfloat* VVEvaluateCircleVerts(double startAngleRadians, double endAngleRadians, VVPOINT centerPoint, double radius, int vertCount, GLfloat *destBuffer)
{
	if (destBuffer == NULL)
		return NULL;
	GLfloat		*wPtr = destBuffer;
	for (int i=0; i<vertCount; ++i)	{
		double		theta = ((double)i/(double)(vertCount-1))*(startAngleRadians-endAngleRadians) + startAngleRadians;
		*(wPtr+0) = (radius)*cos(theta) + centerPoint.x;
		*(wPtr+1) = (radius)*sin(theta) + centerPoint.y;
		*(wPtr+2) = 0.;
		wPtr += 3;
	}
	return wPtr;
}

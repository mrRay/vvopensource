#import <Foundation/Foundation.h>

//	macros for checking to see if something is nil, and if it's not releasing and setting it to nil
#define VVRELEASE(item) {if (item != nil)	{			\
	[item release];										\
	item = nil;											\
}}
#define VVAUTORELEASE(item) {if (item != nil)	{		\
	[item autorelease];									\
	item = nil;											\
}}




//	NSRect/Point/Size/etc and CGRect/Point/Size are functionally identical, but cast differently.  these macros provide a single interface for this functionality to simplify things.
#if IPHONE
#define VVPOINT CGPoint
#define VVMAKEPOINT CGPointMake
#define VVZEROPOINT CGPointZero
#define VVRECT CGRect
#define VVMAKERECT CGRectMake
#define VVZERORECT CGRectZero
#define VVINTERSECTSRECT CGRectIntersectsRect
#define VVINTERSECTIONRECT CGRectIntersection
#define VVINTEGRALRECT CGRectIntegral
#define VVUNIONRECT CGRectUnion
#define VVPOINTINRECT(a,b) CGRectContainsPoint((b),(a))
#define VVSIZE CGSize
#define VVMAKESIZE CGSizeMake
#else
#define VVPOINT NSPoint
#define VVMAKEPOINT NSMakePoint
#define VVZEROPOINT NSZeroPoint
#define VVRECT NSRect
#define VVMAKERECT NSMakeRect
#define VVZERORECT NSZeroRect
#define VVINTERSECTSRECT NSIntersectsRect
#define VVINTERSECTIONRECT NSIntersectionRect
#define VVINTEGRALRECT NSIntegralRect
#define VVUNIONRECT NSUnionRect
#define VVPOINTINRECT NSPointInRect
#define VVSIZE NSSize
#define VVMAKESIZE NSMakeSize
#endif




//	macros for calculating rect coords
/*
#define VVMINX(r) (r.origin.x)
#define VVMAXX(r) (r.origin.x+r.size.width)
#define VVMINY(r) (r.origin.y)
#define VVMAXY(r) (r.origin.y+r.size.height)
#define VVMIDX(r) (r.origin.x+(r.size.width/2.0))
#define VVMIDY(r) (r.origin.y+(r.size.height/2.0))

#define VVMINX(r) (fmin(r.origin.x,(r.origin.x+r.size.width)))
#define VVMAXX(r) (fmax(r.origin.x,(r.origin.x+r.size.width)))
#define VVMINY(r) (fmin(r.origin.y,(r.origin.y+r.size.height)))
#define VVMAXY(r) (fmax(r.origin.y,(r.origin.y+r.size.height)))
*/
#define VVMINX(r) ((r.size.width>=0) ? (r.origin.x) : (r.origin.x+r.size.width))
#define VVMAXX(r) ((r.size.width>=0) ? (r.origin.x+r.size.width) : (r.origin.x))
#define VVMINY(r) ((r.size.height>=0) ? (r.origin.y) : (r.origin.y+r.size.height))
#define VVMAXY(r) ((r.size.height>=0) ? (r.origin.y+r.size.height) : (r.origin.y))
#define VVMIDX(r) (r.origin.x+(r.size.width/2.0))
#define VVMIDY(r) (r.origin.y+(r.size.height/2.0))
#define VVTOPLEFT(r) (VVMAKEPOINT(VVMINX(r),VVMAXY(r)))
#define VVTOPRIGHT(r) (VVMAKEPOINT(VVMAXX(r),VVMAXY(r)))
#define VVBOTLEFT(r) (VVMAKEPOINT(VVMINX(r),VVMINY(r)))
#define VVBOTRIGHT(r) (VVMAKEPOINT(VVMAXX(r),VVMINY(r)))
#define VVCENTER(r) (VVMAKEPOINT(VVMIDX(r),VVMIDY(r)))
#define VVADDPOINT(a,b) (VVMAKEPOINT((a.x+b.x),(a.y+b.y)))
#define VVSUBPOINT(a,b) (VVMAKEPOINT((a.x-b.x),(a.y-b.y)))
#define VVADDSIZE(a,b) (VVMAKESIZE(a.width+b.width, a.height+b.height))
#define VVSUBSIZE(a,b) (VVMAKESIZE(a.width-b.width, a.height-b.height))
#define VVEQUALRECTS(a,b) ((a.origin.x==b.origin.x && a.origin.y==b.origin.y && a.size.width==b.size.width && a.size.height==b.size.height) ? YES : NO)
#define VVEQUALSIZES(a,b) ((a.width==b.width)&&(a.height==b.height))
#define VVEQUALPOINTS(a,b) ((a.x==b.x)&&(a.y==b.y))
#define VVISZERORECT(a) ((a.size.width==0.0 && a.size.height==0.0) ? YES : NO)

//	macro for clipping a val to the normalized range (0.0 - 1.0)
#define CLIPNORM(n) (((n)<0.0)?0.0:(((n)>1.0)?1.0:(n)))
#define CLIPTORANGE(n,l,h) (((n)<(l))?(l):(((n)>(h))?(h):(n)))






//	macros for making a CGRect from an NSRect
#define NSMAKECGRECT(n) CGRectMake(n.origin.x, n.origin.y, n.size.width, n.size.height)
#define NSMAKECGPOINT(n) CGPointMake(n.x, n.y)
#define NSMAKECGSIZE(n) CGSizeMake(n.width, n.height)
//	macros for making an NSRect from a CGRect
#define CGMAKENSRECT(n) NSMakeRect(n.origin.x, n.origin.y, n.size.width, n.size.height)
#define CGMAKENSSIZE(n) NSMakeSize(n.width,n.height)

//	macro for quickly printing out the dimensions of a rect (and a name/id so you can distinguish between them)
#define NSRectLog(n,r) NSLog(@"%@, (%0.2f,%0.2f) : %0.2fx%0.2f",n,r.origin.x,r.origin.y,r.size.width,r.size.height)
#define NSPointLog(n,r) NSLog(@"%@, (%0.2f,%0.2f)",n,r.x,r.y)
#define NSSizeLog(n,s) NSLog(@"%@, %0.2fx%0.2f",n,s.width,s.height)

#define VVRectLog(n,r) NSLog(@"%@, (%0.2f,%0.2f) : %0.2fx%0.2f",n,r.origin.x,r.origin.y,r.size.width,r.size.height)
#define VVPointLog(n,r) NSLog(@"%@, (%0.2f,%0.2f)",n,r.x,r.y)
#define VVSizeLog(n,s) NSLog(@"%@, %0.2fx%0.2f",n,s.width,s.height)

//	macros for quickly making numbers and values
#define NUMINT(i) [NSNumber numberWithInt:i]
#define NUMUINT(i) [NSNumber numberWithUnsignedInteger:i]
#define NUMLONG(i) [NSNumber numberWithLong:i]
#define NUMU64(i) [NSNumber numberWithUnsignedLongLong:i]
#define NUM64(i) [NSNumber numberWithLongLong:i]
#define NUMFLOAT(f) [NSNumber numberWithFloat:f]
#define NUMBOOL(b) [NSNumber numberWithBool:b]
#define NUMDOUBLE(d) [NSNumber numberWithDouble:d]
#define VALSIZE(s) [NSValue valueWithSize:s]
#define VALRECT(r) [NSValue valueWithRect:r]

//	macro for quickly archiving and object
#define ARCHIVE(a) [NSKeyedArchiver archivedDataWithRootObject:a]
#define UNARCHIVE(a) [NSKeyedUnarchiver unarchiveObjectWithData:a]

//	macro for quickly making colors
#define VVDEVCOLOR(r,g,b,a) [NSColor colorWithDeviceRed:r green:g blue:b alpha:a]
#define VVCALCOLOR(r,g,b,a) [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a]

//	nice little macro for strings
#define VVSTRING(n) ((NSString *)[NSString stringWithString:n])
#define VVFMTSTRING(f, ...) ((NSString *)[NSString stringWithFormat:f, ##__VA_ARGS__])
#define VVDATASTRING(n) ((NSData *)[[NSString stringWithString:n] dataUsingEncoding:NSUTF8StringEncoding])
#define VVDATAFMTSTRING(f, ...) ((NSData *)[[NSString stringWithFormat:f, ##__VA_ARGS__] dataUsingEncoding:NSUTF8StringEncoding])

//	macros for quickly making arrays because.....well, it's the wiimote, and i'm fucking tired of typing.  so there.
#define OBJARRAY(f) [NSArray arrayWithObject:f]
#define OBJSARRAY(f, ...) [NSArray arrayWithObjects:f, ##__VA_ARGS__, nil]
#define MUTARRAY [NSMutableArray arrayWithCapacity:0]

//	macros for quickly making dicts
#define OBJDICT(o,k) [NSDictionary dictionaryWithObject:o forKey:k]
#define OBJSDICT(o, ...) [NSDictionary dictionaryWithObjectsAndKeys:o,#__VA_ARGS__, nil]
#define MUTDICT [NSMutableDictionary dictionaryWithCapacity:0]

//	calculating the distance between two NSPoints or similar structs
#define POINTDISTANCE(a,b) fabs(sqrtf((a.x-b.x)*(a.x-b.x) + (a.y-b.y)*(a.y-b.y)))




//	not actually a macro- a function to replace NSRunAlertPanel, which is deprecated in 10.10
NSInteger VVRunAlertPanel(NSString *title, NSString *msg, NSString *btnA, NSString *btnB, NSString *btnC);




//	this macro is from the GL red book
#define BUFFER_OFFSET(bytes) ((GLubyte*)NULL + (bytes))
//	this is a macro for drawing an NSRect in opengl
#define GLDRAWRECT(r)														\
{																			\
	GLfloat 	vvMacroVertices[]={											\
		r.origin.x, r.origin.y, 0.0,										\
		r.origin.x, r.origin.y+r.size.height, 0.0,							\
		r.origin.x+r.size.width, r.origin.y+r.size.height, 0.0,				\
		r.origin.x+r.size.width, r.origin.y, 0.0};							\
	glVertexPointer(3,GL_FLOAT,0,vvMacroVertices);							\
	glDrawArrays(GL_QUADS,0,4);												\
}


#define GLDRAWRECT_TRISTRIP(r)												\
{																			\
	GLfloat 	vvMacroVertices[]={											\
		r.origin.x, r.origin.y, 0.0,										\
		r.origin.x, r.origin.y+r.size.height, 0.0,							\
		r.origin.x+r.size.width, r.origin.y+r.size.height, 0.0,				\
		r.origin.x+r.size.width, r.origin.y, 0.0};							\
	glVertexPointer(3,GL_FLOAT,0,vvMacroVertices);							\
	glDrawArrays(GL_TRIANGLE_STRIP,0,4);									\
}



#define GLDRAWRECT_TRISTRIP_COLOR(rect,r,g,b,a)									\
{																				\
	GLfloat		vvMacroVertices[]={												\
		rect.origin.x, rect.origin.y, 0.0,										\
		rect.origin.x, rect.origin.y+rect.size.height, 0.0,						\
		rect.origin.x+rect.size.width, rect.origin.y, 0.0,						\
		rect.origin.x+rect.size.width, rect.origin.y+rect.size.height, 0.0};	\
	GLfloat		vvMacroColors[]={												\
		r, g, b, a,																\
		r, g, b, a,																\
		r, g, b, a,																\
		r, g, b, a		};														\
	glEnableVertexAttribArray(GLKVertexAttribPosition);							\
	glEnableVertexAttribArray(GLKVertexAttribColor);							\
	glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, vvMacroVertices);		\
	glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, 0, vvMacroColors);			\
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);										\
	glDisableVertexAttribArray(GLKVertexAttribPosition);						\
	glDisableVertexAttribArray(GLKVertexAttribColor);							\
}



//	this is a macro for stroking an NSRect in opengl
#define GLSTROKERECT(r)														\
{																			\
	GLfloat 	vvMacroVertices[]={											\
		r.origin.x+0.5, r.origin.y+0.5, 0.0,								\
		r.origin.x+r.size.width-0.5, r.origin.y+0.5, 0.0,					\
		r.origin.x+r.size.width-0.5, r.origin.y+0.5, 0.0,					\
		r.origin.x+r.size.width-0.5, r.origin.y+r.size.height-0.5, 0.0,		\
		r.origin.x+r.size.width-0.5, r.origin.y+r.size.height-0.5, 0.0,		\
		r.origin.x+0.5, r.origin.y+r.size.height-0.5, 0.0,					\
		r.origin.x+0.5, r.origin.y+r.size.height-0.5, 0.0,					\
		r.origin.x+0.5, r.origin.y+0.5, 0.0};								\
	glVertexPointer(3,GL_FLOAT,0,vvMacroVertices);							\
	glDrawArrays(GL_LINES,0,8);												\
}
/*
#define GLSTROKERECT(r)														\
{																			\
	GLfloat 	vvMacroVertices[]={											\
		r.origin.x, r.origin.y, 0.0,										\
		r.origin.x+r.size.width, r.origin.y, 0.0,							\
		r.origin.x+r.size.width, r.origin.y, 0.0,							\
		r.origin.x+r.size.width, r.origin.y+r.size.height, 0.0,				\
		r.origin.x+r.size.width, r.origin.y+r.size.height, 0.0,				\
		r.origin.x, r.origin.y+r.size.height, 0.0,							\
		r.origin.x, r.origin.y+r.size.height, 0.0,							\
		r.origin.x, r.origin.y, 0.0};										\
	glVertexPointer(3,GL_FLOAT,0,vvMacroVertices);							\
	glDrawArrays(GL_LINES,0,8);												\
}
*/
#define GLSTROKERECT_COLOR(tmpLocalRect,r,g,b,a)							\
{																			\
	GLfloat 	vvMacroVertices[]={											\
		tmpLocalRect.origin.x+0.5, tmpLocalRect.origin.y+0.5, 0.0,			\
		tmpLocalRect.origin.x+tmpLocalRect.size.width-0.5, tmpLocalRect.origin.y+0.5, 0.0,										\
		tmpLocalRect.origin.x+tmpLocalRect.size.width-0.5, tmpLocalRect.origin.y+0.5, 0.0,										\
		tmpLocalRect.origin.x+tmpLocalRect.size.width-0.5, tmpLocalRect.origin.y+tmpLocalRect.size.height-0.5, 0.0,				\
		tmpLocalRect.origin.x+tmpLocalRect.size.width-0.5, tmpLocalRect.origin.y+tmpLocalRect.size.height-0.5, 0.0,				\
		tmpLocalRect.origin.x+0.5, tmpLocalRect.origin.y+tmpLocalRect.size.height-0.5, 0.0,										\
		tmpLocalRect.origin.x+0.5, tmpLocalRect.origin.y+tmpLocalRect.size.height-0.5, 0.0,										\
		tmpLocalRect.origin.x+0.5, tmpLocalRect.origin.y+0.5, 0.0};			\
	GLfloat		vvMacroColors[]={											\
		r, g, b, a,															\
		r, g, b, a,															\
		r, g, b, a,															\
		r, g, b, a,															\
		r, g, b, a,															\
		r, g, b, a,															\
		r, g, b, a,															\
		r, g, b, a,		};													\
	glEnableVertexAttribArray(GLKVertexAttribPosition);						\
	glEnableVertexAttribArray(GLKVertexAttribColor);						\
	glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 0, vvMacroVertices);									\
	glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, 0, vvMacroColors);										\
	glDrawArrays(GL_LINES, 0, 8);											\
	glDisableVertexAttribArray(GLKVertexAttribPosition);					\
	glDisableVertexAttribArray(GLKVertexAttribColor);						\
}

//	this is a macro for drawing a line connecting two points
#define GLDRAWLINE(p,q)									\
{														\
	GLfloat		vvMacroVertices[]={						\
		p.x, p.y, 0.0,									\
		q.x, q.y, 0.0};									\
	glVertexPointer(3,GL_FLOAT,0,vvMacroVertices);		\
	glDrawArrays(GL_LINES,0,2);							\
}



//	this is a macro for drawing a diamond specified by a point and radius in opengl
#define GLDRAWDIAMOND(p,r)								\
{														\
	GLfloat		vvMacroVertices[] = {					\
		p.x-r, p.y, 0.0,								\
		p.x, p.y+r, 0.0,								\
		p.x+r, p.y, 0.0,								\
		p.x, p.y-r, 0.0};								\
	glVertexPointer(3,GL_FLOAT,0,vvMacroVertices);		\
	glDrawArrays(GL_QUADS,0,4);							\
}



//	this is a macro for stroking an diamond around a point in opengl
#define GLSTROKEDIAMOND(p,r)							\
{														\
	GLfloat		vvMacroVertices[] = {					\
		p.x-r, p.y, 0.0,								\
		p.x, p.y+r, 0.0,								\
		p.x, p.y+r, 0.0,								\
		p.x+r, p.y, 0.0,								\
		p.x+r, p.y, 0.0,								\
		p.x, p.y-r, 0.0,								\
		p.x, p.y-r, 0.0,								\
		p.x-r, p.y, 0.0};								\
	glVertexPointer(3,GL_FLOAT,0,vvMacroVertices);		\
	glDrawArrays(GL_LINE_LOOP,0,8);							\
}

//	NOTE: this macro will not function correctly if you forget to glEnable(texTarget) or glEnableClientState() for GL_VERTEX_ARRAY and GL_TEXTURE_COORD_ARRAY.
//	'texName' is the texture name (from glGenTextures())
//	'texTarget' is the target (GL_TEXTURE_RECTANGLE_EXT or GL_TEXTURE_2D
//	'texFlipped' is BOOL- whether or not tex is flipped vertically
//	'srcRect' is the coords of the tex to draw.  REMEMBER: GL_TEXTURE_2D coords are NORMALIZED!
//	'dstRect' are the coords of the rect to draw the tex in.
#define GLDRAWTEXQUADMACRO(texName,texTarget,texFlipped,src,dst)										\
{																										\
	GLuint		localMacroTexTarget=texTarget;															\
	NSRect		localMacroSrc=src;																		\
	NSRect		localMacroDst=dst;																		\
	BOOL		localMacroFlip=texFlipped;																\
	GLfloat		vvMacroVerts[]={																		\
		VVMINX(localMacroDst), VVMINY(localMacroDst), 0.0,												\
		VVMAXX(localMacroDst), VVMINY(localMacroDst), 0.0,												\
		VVMAXX(localMacroDst), VVMAXY(localMacroDst), 0.0,												\
		VVMINX(localMacroDst), VVMAXY(localMacroDst), 0.0};												\
	GLfloat		vvMacroTexs[]={																			\
		VVMINX(localMacroSrc),	(localMacroFlip ? VVMAXY(localMacroSrc) : VVMINY(localMacroSrc)),		\
		VVMAXX(localMacroSrc),	(localMacroFlip ? VVMAXY(localMacroSrc) : VVMINY(localMacroSrc)),		\
		VVMAXX(localMacroSrc),	(localMacroFlip ? VVMINY(localMacroSrc) : VVMAXY(localMacroSrc)),		\
		VVMINX(localMacroSrc),	(localMacroFlip ? VVMINY(localMacroSrc) : VVMAXY(localMacroSrc))};		\
	glVertexPointer(3,GL_FLOAT,0,vvMacroVerts);															\
	glTexCoordPointer(2,GL_FLOAT,0,vvMacroTexs);														\
	glBindTexture(localMacroTexTarget,texName);															\
	glDrawArrays(GL_QUADS,0,4);																			\
	glBindTexture(localMacroTexTarget,0);																\
}




//	this is a macro for using an NSColor to set a GL color!
#define NSTOGLCLEARCOLOR(c)	{			\
	if (c!=nil)	{						\
		CGFloat		comps[4];			\
		[c getComponents:comps];		\
		glClearColor(comps[0],comps[1],comps[2],comps[3]);		\
	}									\
}
#define NSTOGLCOLOR(c)	{				\
	if (c!=nil)	{						\
		CGFloat		comps[4];			\
		[c getComponents:comps];		\
		glColor4f(comps[0],comps[1],comps[2],comps[3]);		\
	}									\
}




#define APPKIT_TMPBLOCK_MAINTHREAD	{	\
	if (![NSThread isMainThread])	\
		dispatch_async(dispatch_get_main_queue(), tmpBlock);	\
	else	\
		tmpBlock();	\
}


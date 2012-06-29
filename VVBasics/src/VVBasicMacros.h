
//	macros for checking to see if something is nil, and if it's not releasing and setting it to nil
#define VVRELEASE(item) {if (item != nil)	{			\
	[item release];										\
	item = nil;											\
}}
#define VVAUTORELEASE(item) {if (item != nil)	{		\
	[item autorelease];									\
	item = nil;											\
}}


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
#define VVTOPLEFT(r) (NSMakePoint(VVMINX(r),VVMAXY(r)))
#define VVTOPRIGHT(r) (NSMakePoint(VVMAXX(r),VVMAXY(r)))
#define VVBOTLEFT(r) (NSMakePoint(VVMINX(r),VVMINY(r)))
#define VVBOTRIGHT(r) (NSMakePoint(VVMAXX(r),VVMINY(r)))
#define VVCENTER(r) (NSMakePoint(VVMIDX(r),VVMIDY(r)))
#define VVADDPOINT(a,b) (NSMakePoint((a.x+b.x),(a.y+b.y)))
#define VVSUBPOINT(a,b) (NSMakePoint((a.x-b.x),(a.y-b.y)))







//	macros for making a CGRect from an NSRect
#define NSMAKECGRECT(n) CGRectMake(n.origin.x, n.origin.y, n.size.width, n.size.height)
#define NSMAKECGPOINT(n) CGPointMake(n.x, n.y)
#define NSMAKECGSIZE(n) CGSizeMake(n.width, n.height)
//	macros for making an NSRect from a CGRect
#define CGMAKENSRECT(n) NSMakeRect(n.origin.x, n.origin.y, n.size.width, n.size.height)
#define CGMAKENSSIZE(n) NSMakeSize(n.width,n.height)

//	macro for quickly printing out the dimensions of a rect (and a name/id so you can distinguish between them)
#define NSRectLog(n,r) NSLog(@"%@, (%f,%f) : %fx%f",n,r.origin.x,r.origin.y,r.size.width,r.size.height)
#define NSPointLog(n,r) NSLog(@"%@, (%f,%f)",n,r.x,r.y)
#define NSSizeLog(n,s) NSLog(@"%@, %fx%f",n,s.width,s.height)

//	macros for quickly making numbers and values
#define NUMINT(i) [NSNumber numberWithInt:i]
#define NUMUINT(i) [NSNumber numberWithUnsignedInteger:i]
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



//	this is a macro for stroking an NSRect in opengl
#define GLSTROKERECT(r)														\
{																			\
	GLfloat 	vvMacroVertices[]={											\
		r.origin.x-0.5, r.origin.y-0.5, 0.0,								\
		r.origin.x+r.size.width+0.5, r.origin.y-0.5, 0.0,					\
		r.origin.x+r.size.width+0.5, r.origin.y-0.5, 0.0,					\
		r.origin.x+r.size.width+0.5, r.origin.y+r.size.height-0.5, 0.0,		\
		r.origin.x+r.size.width+0.5, r.origin.y+r.size.height-0.5, 0.0,		\
		r.origin.x-0.5, r.origin.y+r.size.height-0.5, 0.0,					\
		r.origin.x-0.5, r.origin.y+r.size.height-0.5, 0.0,					\
		r.origin.x-0.5, r.origin.y-0.5, 0.0};								\
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
		VVMINX(localMacroSrc),	(!localMacroFlip ? VVMAXY(localMacroSrc) : VVMINY(localMacroSrc)),		\
		VVMAXX(localMacroSrc),	(!localMacroFlip ? VVMAXY(localMacroSrc) : VVMINY(localMacroSrc)),		\
		VVMAXX(localMacroSrc),	(!localMacroFlip ? VVMINY(localMacroSrc) : VVMAXY(localMacroSrc)),		\
		VVMINX(localMacroSrc),	(!localMacroFlip ? VVMINY(localMacroSrc) : VVMAXY(localMacroSrc))};		\
	glVertexPointer(3,GL_FLOAT,0,vvMacroVerts);															\
	glTexCoordPointer(2,GL_FLOAT,0,vvMacroTexs);														\
	glBindTexture(localMacroTexTarget,texName);															\
	glDrawArrays(GL_QUADS,0,4);																			\
	glBindTexture(localMacroTexTarget,0);																\
}


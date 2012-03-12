
//	macros for checking to see if something is nil, and if it's not releasing and setting it to nil
#define VVRELEASE(item) {if (item != nil)	{			\
	[item release];										\
	item = nil;											\
}}
#define VVAUTORELEASE(item) {if (item != nil)	{		\
	[item autorelease];									\
	item = nil;											\
}}



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


//	this is a macro for drawing a texture of a specified size in a rect
#define GLDRAWTEXSIZEDINRECT(t,s,r)											\
{																			\
	GLfloat			vvMacroVertices[]={										\
		r.origin.x, r.origin.y, 0.0,										\
		r.origin.x+r.size.width, r.origin.y, 0.0,							\
		r.origin.x+r.size.width, r.origin.y+r.size.height, 0.0,				\
		r.origin.x, r.origin.y+r.size.height, 0.0};							\
	GLfloat			vvMacroTexCoords[]={									\
		0.0,s.height,														\
		s.width,s.height,													\
		s.width,0.0,														\
		0.0,0.0};															\
	glVertexPointer(3,GL_FLOAT,0,vvMacroVertices);							\
	glTexCoordPointer(2,GL_FLOAT,0,vvMacroTexCoords);						\
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT,t);								\
	glDrawArrays(GL_QUADS,0,4);												\
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT,0);								\
}

#define GLDRAWFLIPPEDTEXSIZEDINRECT(t,s,r)									\
{																			\
	GLfloat			vvMacroVertices[]={										\
		r.origin.x, r.origin.y, 0.0,										\
		r.origin.x+r.size.width, r.origin.y, 0.0,							\
		r.origin.x+r.size.width, r.origin.y+r.size.height, 0.0,				\
		r.origin.x, r.origin.y+r.size.height, 0.0};							\
	GLfloat			vvMacroTexCoords[]={									\
		0.0, 0.0,															\
		s.width, 0.0,														\
		s.width, s.height,													\
		0.0, s.height};														\
	glVertexPointer(3,GL_FLOAT,0,vvMacroVertices);							\
	glTexCoordPointer(2,GL_FLOAT,0,vvMacroTexCoords);						\
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT,t);								\
	glDrawArrays(GL_QUADS,0,4);												\
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT,0);								\
}

#define GLDRAWTEXSIZEDINRECTATZ(t,s,r,z)									\
{																			\
	GLfloat			vvMacroVertices[]={										\
		r.origin.x, r.origin.y, z,											\
		r.origin.x+r.size.width, r.origin.y, z,								\
		r.origin.x+r.size.width, r.origin.y+r.size.height, z,				\
		r.origin.x, r.origin.y+r.size.height, z};							\
	GLfloat			vvMacroTexCoords[]={									\
		0.0,s.height,														\
		s.width,s.height,													\
		s.width,0.0,														\
		0.0,0.0};															\
	glVertexPointer(3,GL_FLOAT,0,vvMacroVertices);							\
	glTexCoordPointer(2,GL_FLOAT,0,vvMacroTexCoords);						\
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT,t);								\
	glDrawArrays(GL_QUADS,0,4);												\
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT,0);								\
}

#define GLDRAWFLIPPEDTEXSIZEDINRECTATZ(t,s,r,z)								\
{																			\
	GLfloat			vvMacroVertices[]={										\
		r.origin.x, r.origin.y, z,											\
		r.origin.x+r.size.width, r.origin.y, z,								\
		r.origin.x+r.size.width, r.origin.y+r.size.height, z,				\
		r.origin.x, r.origin.y+r.size.height, z};							\
	GLfloat			vvMacroTexCoords[]={									\
		0.0, 0.0,															\
		s.width, 0.0,														\
		s.width, s.height,													\
		0.0, s.height};														\
	glVertexPointer(3,GL_FLOAT,0,vvMacroVertices);							\
	glTexCoordPointer(2,GL_FLOAT,0,vvMacroTexCoords);						\
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT,t);								\
	glDrawArrays(GL_QUADS,0,4);												\
	glBindTexture(GL_TEXTURE_RECTANGLE_EXT,0);								\
}


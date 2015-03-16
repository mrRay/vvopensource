#import "ISFAttrib.h"




@implementation ISFAttrib


- (NSString *) description	{
	NSString		*typeString = nil;
	switch (attribType)	{
		case ISFAT_Event:
			typeString = @"Event";
			break;
		case ISFAT_Bool:
			typeString = @"Bool";
			break;
		case ISFAT_Long:
			typeString = @"Long";
			break;
		case ISFAT_Float:
			typeString = @"Float";
			break;
		case ISFAT_Point2D:
			typeString = @"Point2D";
			break;
		case ISFAT_Color:
			typeString = @"Color";
			break;
		case ISFAT_Image:
			typeString = @"Image";
			break;
		case ISFAT_Cube:
			typeString = @"Cube";
			break;
	}
	return [NSString stringWithFormat:@"<ISFAttrib %@ named %@>",typeString,attribName];
}
+ (id) createWithName:(NSString *)n description:(NSString *)desc label:(NSString *)l type:(ISFAttribValType)t values:(ISFAttribVal)min :(ISFAttribVal) max :(ISFAttribVal)def :(ISFAttribVal)iden :(NSArray *)lArray :(NSArray *)vArray	{
	id		returnMe = [[ISFAttrib alloc] initWithName:n description:desc label:l type:t values:min:max:def:iden:lArray:vArray];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}

- (id) initWithName:(NSString *)n description:(NSString *)desc label:(NSString *)l type:(ISFAttribValType)t values:(ISFAttribVal)min :(ISFAttribVal) max :(ISFAttribVal)def :(ISFAttribVal)iden :(NSArray *)lArray :(NSArray *)vArray	{
	if (n==nil)
		goto BAIL;
	if (self = [super init])	{
		attribName = [n retain];
		attribDescription = (desc==nil) ? nil : [desc retain];
		attribLabel = (l==nil) ? nil : [l retain];
		attribType = t;
		labelArray = nil;
		valArray = nil;
		switch (attribType)	{
			case ISFAT_Event:
				currentVal.eventVal = def.eventVal;
				minVal.eventVal = min.eventVal;
				maxVal.eventVal = max.eventVal;
				defaultVal.eventVal = def.eventVal;
				identityVal.eventVal = iden.eventVal;
				break;
			case ISFAT_Bool:
				currentVal.boolVal = def.boolVal;
				minVal.boolVal = min.boolVal;
				maxVal.boolVal = max.boolVal;
				defaultVal.boolVal = def.boolVal;
				identityVal.boolVal = iden.boolVal;
				break;
			case ISFAT_Long:
				currentVal.longVal = def.longVal;
				minVal.longVal = min.longVal;
				maxVal.longVal = max.longVal;
				defaultVal.longVal = def.longVal;
				identityVal.longVal = iden.longVal;
				labelArray = (lArray==nil) ? nil : [lArray mutableCopy];
				valArray = (vArray==nil) ? nil : [vArray mutableCopy];
				break;
			case ISFAT_Float:
				currentVal.floatVal = def.floatVal;
				minVal.floatVal = min.floatVal;
				maxVal.floatVal = max.floatVal;
				defaultVal.floatVal = def.floatVal;
				identityVal.floatVal = iden.floatVal;
				break;
			case ISFAT_Point2D:
				for (int i=0; i<2; ++i)	{
					currentVal.point2DVal[i] = def.point2DVal[i];
					minVal.point2DVal[i] = min.point2DVal[i];
					maxVal.point2DVal[i] = max.point2DVal[i];
					defaultVal.point2DVal[i] = def.point2DVal[i];
					identityVal.point2DVal[i] = iden.point2DVal[i];
				}
				break;
			case ISFAT_Color:
				for (int i=0; i<4; ++i)	{
					currentVal.colorVal[i] = def.colorVal[i];
					minVal.colorVal[i] = min.colorVal[i];
					maxVal.colorVal[i] = max.colorVal[i];
					defaultVal.colorVal[i] = def.colorVal[i];
					identityVal.colorVal[i] = iden.colorVal[i];
				}
				//NSLog(@"\t\tcurrentVal is %0.2f-%0.2f-%0.2f-%0.2f",currentVal.colorVal[0],currentVal.colorVal[1],currentVal.colorVal[2],currentVal.colorVal[3]);
				break;
			case ISFAT_Image:
				currentVal.imageVal = def.imageVal;
				//minVal.imageVal = min.imageVal;
				//maxVal.imageVal = max.imageVal;
				//defaultVal.imageVal = def.imageVal;
				//identityVal.imageVal = iden.imageVal;
				break;
			case ISFAT_Cube:
				currentVal.imageVal = def.imageVal;
				break;
		}
		isFilterInputImage = NO;
		userInfo = nil;
		for (int i=0; i<4; ++i)
			uniformLocation[i] = -1;
		return self;
	}
	BAIL:
	[self release];
	return nil;
}
- (void) dealloc	{
	if (attribName != nil)	{
		[attribName release];
		attribName = nil;
	}
	if (attribDescription != nil)	{
		[attribDescription release];
		attribDescription = nil;
	}
	if (attribLabel != nil)	{
		[attribLabel release];
		attribLabel = nil;
	}
	if (labelArray != nil)	{
		[labelArray release];
		labelArray = nil;
	}
	if (valArray != nil)	{
		[valArray release];
		valArray = nil;
	}
	if (userInfo != nil)	{
		[userInfo release];
		userInfo = nil;
	}
	[super dealloc];
}

- (NSString *) attribName	{
	return attribName;
}
- (NSString *) attribDescription	{
	return attribDescription;
}
- (NSString *) attribLabel	{
	return attribLabel;
}
- (ISFAttribValType) attribType	{
	return attribType;
}

- (ISFAttribVal) currentVal	{
	return currentVal;
}
- (void) setCurrentVal:(ISFAttribVal)n	{
	switch (attribType)	{
		case ISFAT_Event:
			currentVal.eventVal = n.eventVal;
			break;
		case ISFAT_Bool:
			currentVal.boolVal = n.boolVal;
			break;
		case ISFAT_Long:
			currentVal.longVal = n.longVal;
			break;
		case ISFAT_Float:
			currentVal.floatVal = n.floatVal;
			break;
		case ISFAT_Point2D:
			for (int i=0; i<2; ++i)
				currentVal.point2DVal[i] = n.point2DVal[i];
			break;
		case ISFAT_Color:
			for (int i=0; i<4; ++i)
				currentVal.colorVal[i] = n.colorVal[i];
			break;
		case ISFAT_Image:
			currentVal.imageVal = n.imageVal;
			break;
		case ISFAT_Cube:
			currentVal.imageVal = n.imageVal;
			break;
	}
}
- (ISFAttribVal) minVal	{
	return minVal;
}
- (ISFAttribVal) maxVal	{
	return maxVal;
}
- (ISFAttribVal) defaultVal	{
	return defaultVal;
}
- (ISFAttribVal) identityVal	{
	return identityVal;
}
- (NSMutableArray *) labelArray	{
	return labelArray;
}
- (NSMutableArray *) valArray	{
	return valArray;
}


- (void) setIsFilterInputImage:(BOOL)n	{
	isFilterInputImage = n;
}
- (BOOL) isFilterInputImage	{
	return isFilterInputImage;
}


- (void) setUserInfo:(id)n	{
	if (userInfo != nil)
		[userInfo release];
	userInfo = (n==nil) ? nil : [n retain];
}
- (id) userInfo	{
	return userInfo;
}
- (void) setUniformLocation:(int)n forIndex:(int)i	{
	//NSLog(@"%s ... %@, [%d] %d",__func__,attribName,i,n);
	if (i>=0 && i<4)
		uniformLocation[i] = n;
}
- (int) uniformLocationForIndex:(int)i	{
	if (i>=0 && i<4)
		return uniformLocation[i];
	return -1;
}
- (void) clearUniformLocations	{
	for (int i=0; i<4; ++i)
		uniformLocation[i] = -1;
}


@end

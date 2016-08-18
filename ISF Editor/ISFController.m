//
//  ISFController.m
//  ISF Syphon Filter Tester
//
//  Created by bagheera on 11/2/13.
//  Copyright (c) 2013 zoidberg. All rights reserved.
//

#import "ISFController.h"
#import "VVKQueueCenter.h"
#import "ISFEditorAppDelegate.h"




#define ISFITEMHEIGHT 50
#define ISFITEMSPACE 10




@implementation ISFController


- (id) init	{
	//NSLog(@"%s",__func__);
	if (self = [super init])	{
		scene = nil;
		targetFile = nil;
		itemArray = [[MutLockArray alloc] init];
		return self;
	}
	[self release];
	return nil;
}
- (void) awakeFromNib	{
	[self setRenderSize:NSMakeSize(640,360)];
	[self _pushRenderingResolutionToUI];
}
- (void) dealloc	{
	//NSLog(@"%s",__func__);
	VVRELEASE(scene);
	VVRELEASE(targetFile);
	VVRELEASE(itemArray);
	[VVKQueueCenter removeObserver:self];
	[super dealloc];
}
- (void) setSharedGLContext:(NSOpenGLContext *)n	{
	//NSLog(@"%s",__func__);
	if (n==nil)
		return;
	@synchronized (self)	{
		VVRELEASE(scene);
		scene = [[ISFGLScene alloc] initWithSharedContext:n pixelFormat:[GLScene defaultPixelFormat] sized:NSMakeSize(320,240)];
		[scene setThrowExceptions:YES];
	}
}


- (IBAction) widthFieldUsed:(id)sender	{
	NSString	*tmpString = [widthField stringValue];
	NSNumber	*tmpNum = (tmpString==nil) ? nil : [tmpString numberByEvaluatingString];
	if (tmpNum==nil)
		return;
	NSSize		tmpSize = [self renderSize];
	tmpSize.width = [tmpNum intValue];
	[self setRenderSize:tmpSize];
	[self _pushUIToRenderingResolution];
}
- (IBAction) heightFieldUsed:(id)sender	{
	NSString	*tmpString = [heightField stringValue];
	NSNumber	*tmpNum = (tmpString==nil) ? nil : [tmpString numberByEvaluatingString];
	if (tmpNum==nil)
		return;
	NSSize		tmpSize = [self renderSize];
	tmpSize.height = [tmpNum intValue];
	[self setRenderSize:tmpSize];
	[self _pushUIToRenderingResolution];
}
- (IBAction) doubleResClicked:(id)sender	{
	NSSize		tmpSize = [self renderSize];
	tmpSize = NSMakeSize(ceil(tmpSize.width*2.0), ceil(tmpSize.height*2.0));
	[self setRenderSize:tmpSize];
	[self _pushRenderingResolutionToUI];
}
- (IBAction) halveResClicked:(id)sender	{
	NSSize		tmpSize = [self renderSize];
	tmpSize = NSMakeSize(ceil(tmpSize.width/2.0), ceil(tmpSize.height/2.0));
	[self setRenderSize:tmpSize];
	[self _pushRenderingResolutionToUI];
}
- (void) _pushUIToRenderingResolution	{
	NSString		*tmpString = nil;
	uint32_t		tmpInt = 0;
	NSSize			newSize;
	tmpString = [widthField stringValue];
	tmpInt = (tmpString==nil || [tmpString numberByEvaluatingString]==nil) ? 640 : [[tmpString numberByEvaluatingString] intValue];
	newSize.width = tmpInt;
	
	tmpString = [heightField stringValue];
	tmpInt = (tmpString==nil || [tmpString numberByEvaluatingString]==nil) ? 360 : [[tmpString numberByEvaluatingString] intValue];
	newSize.height = tmpInt;
	
	[self setRenderSize:newSize];
}
- (void) _pushRenderingResolutionToUI	{
	if (![NSThread isMainThread])	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[self _pushRenderingResolutionToUI];
			return;
		});
		return;
	}
	NSSize		tmpSize = [self renderSize];
	[widthField setStringValue:VVFMTSTRING(@"%d",(int)tmpSize.width)];
	[heightField setStringValue:VVFMTSTRING(@"%d",(int)tmpSize.height)];
}
@synthesize renderSize;


- (void) loadFile:(NSString *)f	{
	//NSLog(@"%s ... %@",__func__,f);
	if (f != nil)	{
		VVRELEASE(targetFile);
		targetFile = [f retain];
	}
	
	NSFileManager		*fm = [NSFileManager defaultManager];
	//	if the passed file doesn't exist, just bail immediately
	if (![fm fileExistsAtPath:f])
		return;
	[VVKQueueCenter removeObserver:self];
	[VVKQueueCenter addObserver:self forPath:f];
	NSString		*vertShaderName = [[f stringByDeletingPathExtension] stringByAppendingPathExtension:@"vs"];
	if (![fm fileExistsAtPath:vertShaderName])	{
		vertShaderName = [[f stringByDeletingPathExtension] stringByAppendingPathExtension:@"vert"];
		if ([fm fileExistsAtPath:vertShaderName])
			[VVKQueueCenter addObserver:self forPath:vertShaderName];
	}
	
	
	@try	{
		//	i only want to fetch the shaders if the file isn't nil!
		[appDelegate setFetchShaders:(f==nil)?NO:YES];
		//if (f==nil)
		//	NSLog(@"\t\tfetchShaders is NO in %s",__func__);
		//else
		//	NSLog(@"\t\tfetchShaders is YES in %s",__func__);
		
		[scene _renderLock];
		sceneIsFilter = [ISFFileManager _isAFilter:f];
		[scene useFile:f];
	}
	@catch (NSException *err)	{
		dispatch_async(dispatch_get_main_queue(), ^{
			NSString	*tmpString = [err reason];
			VVRunAlertPanel([err name],tmpString,@"Oh snap!",nil,nil);
		});
	}
	[scene _renderUnlock];
	[self populateUI];
	[appDelegate _isfFileReloaded];
}
- (void) file:(NSString *)p changed:(u_int)fflag	{
	//NSLog(@"%s ... %@",__func__,p);
	
	NSString		*tmpPath = p;
	//NSLog(@"\t\ttmpPath is %@",tmpPath);
	if (tmpPath != nil)	{
		[tmpPath retain];
		//[self loadFile:p];
		dispatch_async(dispatch_get_main_queue(), ^{
			NSString	*newPath = [[tmpPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"fs"];
			[self loadFile:newPath];
		});
		[tmpPath release];
		tmpPath = nil;
	}
}
- (VVBuffer *) renderFXOnThisBuffer:(VVBuffer *)n passDict:(NSMutableDictionary *)d	{
	if (n==nil)
		return nil;
	
	if ([scene filePath]==nil)
		return nil;
	//	apply the passed buffer to the scene as "inputImage"
	//[scene setFilterInputImageBuffer:n];
	[scene setBuffer:n forInputImageKey:@"inputImage"];
	//	run through the inputs, getting their values and pushing them to the scene
	[itemArray rdlock];
	for (ISFUIItem *itemPtr in [itemArray array])	{
		id		tmpVal = [itemPtr getNSObjectValue];
		if (tmpVal != nil)	{
			//NSLog(@"\t\t%@ - %@",[itemPtr name],tmpVal);
			[scene setNSObjectVal:tmpVal forInputKey:[itemPtr name]];
		}
	}
	[itemArray unlock];
	
	VVBuffer		*returnMe = nil;
	
	returnMe = [scene
		allocAndRenderToBufferSized:((sceneIsFilter) ? [n srcRect].size : [self renderSize])
		prefer2DTex:NO
		passDict:d];
	//returnMe = [scene allocAndRenderToBufferSized:[n srcRect].size prefer2DTex:NO passDict:d];
	
	return returnMe;
}
//	only used to render for recording
- (void) renderIntoBuffer:(VVBuffer *)b atTime:(double)t	{
	if (b==nil)
		return;
	if ([scene filePath]==nil)
		return;
	//	run through the inputs, getting their values and pushing them to the scene
	[itemArray rdlock];
	for (ISFUIItem *itemPtr in [itemArray array])	{
		id		tmpVal = [itemPtr getNSObjectValue];
		if (tmpVal != nil)	{
			//NSLog(@"\t\t%@ - %@",[itemPtr name],tmpVal);
			[scene setNSObjectVal:tmpVal forInputKey:[itemPtr name]];
		}
	}
	[itemArray unlock];
	
	[scene renderToBuffer:b sized:[b srcRect].size renderTime:t passDict:nil];
}


- (void) populateUI	{
	//NSLog(@"%s",__func__);
	[itemArray wrlock];
	for (ISFUIItem *itemPtr in [itemArray array])	{
		[itemPtr removeFromSuperview];
	}
	[itemArray removeAllObjects];
	[itemArray unlock];
	
	if (scene==nil || [scene filePath]==nil)	{
		//NSLog(@"\t\tbailing, scene hasn't loaded a file, %s",__func__);
		return;
	}
	
	NSSize			newDocViewSize = [self calculateDocViewSize];
	NSView			*dv = [uiScrollView documentView];
	//NSRect			docVisRect = [uiScrollView documentVisibleRect];
	
	MutLockArray		*sceneInputs = [scene inputs];
	if (sceneInputs!=nil)	{
		//	resize the doc view to hold everything
		//[dv setFrame:NSMakeRect(0, 0, docVisRect.size.width, (ISFITEMHEIGHT+ISFITEMSPACE)*[sceneInputs count])];
		[dv setFrame:NSMakeRect(0, 0, newDocViewSize.width, newDocViewSize.height)];
		//docVisRect = [uiScrollView documentVisibleRect];
		
		//	set the size of the temp rect used to create UI items
		NSRect			tmpRect;
		tmpRect.size.width = [dv frame].size.width;
		tmpRect.size.height = ISFITEMHEIGHT;
		tmpRect.origin.x = 0.0;
		//tmpRect.origin.y = VVMAXY([dv frame]) - tmpRect.size.height - ISFITEMSPACE;
		tmpRect.origin.y = 0;
		
		[sceneInputs rdlock];
		NSEnumerator		*it = [[sceneInputs array] reverseObjectEnumerator];
		ISFAttrib			*attrib = nil;
		while (attrib = [it nextObject])	{
			//NSLog(@"\t\tinput %@",[attrib attribName]);
			ISFAttribValType		attribType = [attrib attribType];
			ISFUIItem					*newElement = nil;
			switch (attribType)	{
			case ISFAT_Event:
			case ISFAT_Bool:
			case ISFAT_Long:
			case ISFAT_Float:
			case ISFAT_Color:
			case ISFAT_Image:
			case ISFAT_Audio:
			case ISFAT_AudioFFT:
				if (![attrib isFilterInputImage])	{
					tmpRect.size.height = ISFITEMHEIGHT;
					newElement = [[ISFUIItem alloc] initWithFrame:tmpRect attrib:attrib];
					[dv addSubview:newElement];
					[itemArray lockAddObject:newElement];
					[newElement release];
					tmpRect.origin.y += (tmpRect.size.height + ISFITEMSPACE);
				}
				break;
			case ISFAT_Point2D:
				//tmpRect.size.height = 2.*ISFITEMHEIGHT;
				tmpRect.size.height = ISFITEMHEIGHT;
				newElement = [[ISFUIItem alloc] initWithFrame:tmpRect attrib:attrib];
				[dv addSubview:newElement];
				[itemArray lockAddObject:newElement];
				[newElement release];
				tmpRect.origin.y += (tmpRect.size.height + ISFITEMSPACE);
				break;
			case ISFAT_Cube:
				NSLog(@"\t\tskipping creation of UI item for cube input %@",attrib);
				break;
			}
		}
		[sceneInputs unlock];
	}
}
- (NSSize) calculateDocViewSize	{
	NSSize				returnMe = NSMakeSize([uiScrollView documentVisibleRect].size.width, 0);
	MutLockArray		*sceneInputs = [scene inputs];
	if (sceneInputs!=nil)	{
		[sceneInputs rdlock];
		for (ISFAttrib *attrib in [sceneInputs array])	{
			ISFAttribValType		attribType = [attrib attribType];
			switch (attribType)	{
			case ISFAT_Event:
			case ISFAT_Bool:
			case ISFAT_Long:
			case ISFAT_Float:
			case ISFAT_Color:
			case ISFAT_Image:
			case ISFAT_Audio:
			case ISFAT_AudioFFT:
				returnMe.height += (ISFITEMHEIGHT + ISFITEMSPACE);
				break;
			case ISFAT_Point2D:
				//returnMe.height += ((2. * ISFITEMHEIGHT) + ISFITEMSPACE);
				returnMe.height += (ISFITEMHEIGHT + ISFITEMSPACE);
				break;
			case ISFAT_Cube:
				break;
			}
		}
		[sceneInputs unlock];
	}
	return returnMe;
}


- (void) passNormalizedMouseClickToPoints:(NSPoint)p	{
	//NSLog(@"%s ... (%0.2f, %0.2f)",__func__,p.x,p.y);
	NSMutableArray		*points = [scene inputsOfType:ISFAT_Point2D];
	for (ISFAttrib *attrib in points)	{
		NSString			*attribName = [attrib attribName];
		ISFAttribVal		minVal = [attrib minVal];
		ISFAttribVal		maxVal = [attrib maxVal];
		NSPoint				tmpPoint;
		if (minVal.point2DVal[0]==maxVal.point2DVal[0] && minVal.point2DVal[1]==maxVal.point2DVal[1])	{
			NSSize		lastRenderSize = [scene renderSize];
			tmpPoint = NSMakePoint(p.x*lastRenderSize.width, p.y*lastRenderSize.height);
		}
		else
			tmpPoint = NSMakePoint(p.x*(maxVal.point2DVal[0]-minVal.point2DVal[0])+minVal.point2DVal[0], p.y*(maxVal.point2DVal[1]-minVal.point2DVal[1])+minVal.point2DVal[1]);
		//NSLog(@"\t\tpassing point (%0.2f, %0.2f) to attrib %@",tmpPoint.x,tmpPoint.y,attrib);
		[itemArray rdlock];
		for (ISFUIItem *itemPtr in [itemArray array])	{
			if ([[itemPtr name] isEqualToString:attribName])	{
				[itemPtr setNSObjectValue:[NSValue valueWithPoint:tmpPoint]];
				break;
			}
		}
		[itemArray unlock];
	}
}


- (ISFGLScene *) scene	{
	return scene;
}
- (NSString *) targetFile	{
	return targetFile;
}
- (void) reloadTargetFile	{
	if (targetFile==nil)
		return;
	[self loadFile:[[targetFile copy] autorelease]];
}


@end

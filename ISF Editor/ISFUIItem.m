//
//  ISFUIItem.m
//  ISF Syphon Filter Tester
//
//  Created by bagheera on 11/2/13.
//  Copyright (c) 2013 zoidberg. All rights reserved.
//

#import "ISFUIItem.h"
#import <DDMathParser/DDMathParser.h>
//#import <VVAudioKit/VVAudioKit.h>
#import "AudioController.h"




@implementation ISFUIItem


+ (void) initialize	{
	[[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
}
- (id) initWithFrame:(NSRect)f attrib:(ISFAttrib *)a	{
	if (a==nil)	{
		[self release];
		return nil;
	}
	if (self = [super initWithFrame:f])	{
		name = [[a attribName] retain];
		type = [a attribType];
		eventButton = nil;
		eventNeedsSending = NO;
		boolButton = nil;
		longPUB = nil;
		slider = nil;
		xField = nil;
		yField = nil;
		colorField = nil;
		audioSourcePUB = nil;
		userInfoDict = nil;
		syphonClient = nil;
		syphonLastSelectedName = nil;
		
		if ([a attribLabel]==nil)
			[self setTitle:[a attribName]];
		else
			[self setTitle:[NSString stringWithFormat:@"%@ (%@)",[a attribLabel],[a attribName]]];
		
		NSRect		tmpRect = NSMakeRect(15,0,f.size.width-30,25);
		switch (type)	{
		case ISFAT_Event:
			eventButton = [[NSButton alloc] initWithFrame:tmpRect];
			[[self contentView] addSubview:eventButton];
			[eventButton setTarget:self];
			[eventButton setAction:@selector(uiItemUsed:)];
			break;
		case ISFAT_Bool:
			boolButton = [[NSButton alloc] initWithFrame:tmpRect];
			[[self contentView] addSubview:boolButton];
			[boolButton setButtonType:NSSwitchButton];
			[boolButton setIntValue:([a currentVal].boolVal) ? NSOnState : NSOffState];
			break;
		case ISFAT_Long:
			longPUB = [[NSPopUpButton alloc] initWithFrame:tmpRect];
			[[self contentView] addSubview:longPUB];
			NSMenu		*tmpMenu = [longPUB menu];
			[tmpMenu removeAllItems];
			NSArray		*labelArray = [a labelArray];
			NSArray		*valArray = [a valArray];
			if (labelArray!=nil && valArray!=nil && [labelArray count]==[valArray count])	{
				NSEnumerator		*labelIt = [labelArray objectEnumerator];
				NSEnumerator		*valIt = [valArray objectEnumerator];
				NSString			*labelString;
				NSNumber			*valNumber;
				while ((valNumber=[valIt nextObject]) && (labelString=[labelIt nextObject]))	{
					NSMenuItem		*newItem = [tmpMenu addItemWithTitle:labelString action:nil keyEquivalent:@""];
					if (newItem != nil)
						[newItem setTag:[valNumber longValue]];
				}
			}
			else	{
				ISFAttribVal		minVal = [a minVal];
				ISFAttribVal		maxVal = [a maxVal];
				for (int i=fminl(minVal.longVal,maxVal.longVal); i<=fmaxl(minVal.longVal,maxVal.longVal); ++i)	{
					NSMenuItem	*newItem = [tmpMenu addItemWithTitle:VVFMTSTRING(@"%d",i) action:nil keyEquivalent:@""];
					if (newItem != nil)
						[newItem setTag:i];
				}
			}
			[longPUB selectItemAtIndex:[a defaultVal].longVal];
			break;
		case ISFAT_Float:
			slider = [[NSSlider alloc] initWithFrame:tmpRect];
			[[self contentView] addSubview:slider];
			[slider setMinValue:[a minVal].floatVal];
			[slider setMaxValue:[a maxVal].floatVal];
			[slider setFloatValue:[a currentVal].floatVal];
			break;
		case ISFAT_Point2D:
			/*
			tmpRect.size.height = 30;
			ySlider = [[NSSlider alloc] initWithFrame:tmpRect];
			[[self contentView] addSubview:ySlider];
			
			//[ySlider setMinValue:[a minVal].point2DVal[1]];
			//[ySlider setMaxValue:[a maxVal].point2DVal[1]];
			[ySlider setFloatValue:[a currentVal].point2DVal[1]];
			[ySlider setTarget:self];
			[ySlider setAction:@selector(uiItemUsed:)];
			
			tmpRect.origin.y += 30;
			xSlider = [[NSSlider alloc] initWithFrame:tmpRect];
			[[self contentView] addSubview:xSlider];
			//[xSlider setMinValue:[a minVal].point2DVal[0]];
			//[xSlider setMaxValue:[a maxVal].point2DVal[0]];
			[xSlider setFloatValue:[a currentVal].point2DVal[0]];
			[xSlider setTarget:self];
			[xSlider setAction:@selector(uiItemUsed:)];
			
			pointVal = NSMakePoint([a currentVal].point2DVal[0], [a currentVal].point2DVal[1]);
			*/
			
			tmpRect.size.width = 100;
			xField = [[NSTextField alloc] initWithFrame:tmpRect];
			[xField setTarget:self];
			[xField setAction:@selector(uiItemUsed:)];
			[[self contentView] addSubview:xField];
			tmpRect.origin.x += (tmpRect.size.width + 10);
			yField = [[NSTextField alloc] initWithFrame:tmpRect];
			[yField setTarget:self];
			[yField setAction:@selector(uiItemUsed:)];
			[[self contentView] addSubview:yField];
			[xField setNextKeyView:yField];
			
			ISFAttribVal	tmpVal = [a currentVal];
			[xField setStringValue:VVFMTSTRING(@"%0.2f",tmpVal.point2DVal[0])];
			[yField setStringValue:VVFMTSTRING(@"%0.2f",tmpVal.point2DVal[1])];
			pointVal = NSMakePoint(tmpVal.point2DVal[0], tmpVal.point2DVal[1]);
			
			break;
		case ISFAT_Color:
			colorField = [[NSColorWell alloc] initWithFrame:tmpRect];
			[[self contentView] addSubview:colorField];
			GLfloat		tmpFloat[4];
			for (int i=0; i<4; ++i)
				tmpFloat[i] = [a currentVal].colorVal[i];
			[colorField setColor:[NSColor colorWithDeviceRed:tmpFloat[0] green:tmpFloat[1] blue:tmpFloat[2] alpha:tmpFloat[3]]];
			break;
		case ISFAT_Image:
			{
				longPUB = [[NSPopUpButton alloc] initWithFrame:tmpRect];
				[[self contentView] addSubview:longPUB];
				[longPUB setTarget:self];
				[longPUB setAction:@selector(uiItemUsed:)];
				
				NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
				//	load the syphon stuff, fake a click on the syphon PUB
				syphonClient = nil;
				syphonLastSelectedName = [def objectForKey:@"syphonLastSelectedName"];
				if (syphonLastSelectedName != nil)
					[syphonLastSelectedName retain];
				[self _reloadSyphonPUB];
				//	register for notifications when syphon servers change
				for (NSString *notificationName in [NSArray arrayWithObjects:SyphonServerAnnounceNotification, SyphonServerUpdateNotification, SyphonServerRetireNotification,nil]) {
					[[NSNotificationCenter defaultCenter]
						addObserver:self
						selector:@selector(_syphonServerChangeNotification:)
						name:notificationName
						object:nil];
				}
			}
			break;
		case ISFAT_Cube:
			{
				//	intentionally blank, don't do anything with cube
			}
			break;
		case ISFAT_Audio:
		case ISFAT_AudioFFT:
			{
				[[NSNotificationCenter defaultCenter]
					addObserver:self
					selector:@selector(audioControllerDeviceChangeNotification:)
					name:kAudioControllerInputNameChangedNotification
					object:nil];
				[[NSNotificationCenter defaultCenter] addObserver:self 
														selector:@selector(audioInputsChangedNotification:)
														name:AVCaptureDeviceWasConnectedNotification
														object:nil];			
				[[NSNotificationCenter defaultCenter] addObserver:self 
														selector:@selector(audioInputsChangedNotification:)
														name:AVCaptureDeviceWasDisconnectedNotification
														object:nil];
				audioSourcePUB = [[NSPopUpButton alloc] initWithFrame:tmpRect];
				[audioSourcePUB removeAllItems];
				[audioSourcePUB selectItem:nil];
				[[self contentView] addSubview:audioSourcePUB];
				[audioSourcePUB setTarget:self];
				[audioSourcePUB setAction:@selector(uiItemUsed:)];
				//	if there's a max or float flag, apply it by storing it in a dictionary with me
				long		maxVal = [a maxVal].audioVal;
				if (maxVal>0)	{
					[self setUserInfoDict:@{@"MAX":NUMLONG(maxVal)}];
				}
				
				//NSUserDefaults		*def = [NSUserDefaults standardUserDefaults];
				//	fake a click on the audio stuff
				[self _reloadAudioPUB];
				//	register to receive notifications that the list of audio sources has changed
				//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioInputsChangedNotification:) name:VVAudioInputNodeArrayChangedNotification object:nil];
			}
			break;
		}
		return self;
	}
	return nil;
}
- (void) dealloc	{
	//NSLog(@"%s ... %@",__func__,name);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	switch (type)	{
	case ISFAT_Event:
		[eventButton removeFromSuperview];
		[eventButton release];
		break;
	case ISFAT_Bool:
		[boolButton removeFromSuperview];
		[boolButton release];
		break;
	case ISFAT_Long:
		[longPUB removeFromSuperview];
		[longPUB release];
		break;
	case ISFAT_Float:
		[slider removeFromSuperview];
		[slider release];
		break;
	case ISFAT_Point2D:
		/*
		[xSlider removeFromSuperview];
		[xSlider release];
		[ySlider removeFromSuperview];
		[ySlider release];
		*/
		[xField removeFromSuperview];
		[xField release];
		[yField removeFromSuperview];
		[yField release];
		break;
	case ISFAT_Color:
		[colorField removeFromSuperview];
		[colorField release];
		break;
	case ISFAT_Image:
		[[NSNotificationCenter defaultCenter] removeObserver:self];
		[longPUB removeFromSuperview];
		[longPUB release];
		break;
	case ISFAT_Cube:
		break;
	case ISFAT_Audio:
	case ISFAT_AudioFFT:
		[[NSNotificationCenter defaultCenter] removeObserver:self];
		[audioSourcePUB removeFromSuperview];
		[audioSourcePUB release];
		break;
	}
	
	VVRELEASE(name);
	VVRELEASE(syphonClient);
	VVRELEASE(syphonLastSelectedName);
	[self setUserInfoDict:nil];
	[super dealloc];
}


- (void) audioControllerDeviceChangeNotification:(NSNotification *)note	{
	[self _reloadAudioPUB];
}
- (void) _reloadSyphonPUB	{
	//NSLog(@"%s",__func__);
	//	first reload the pop up button
	SyphonServerDirectory	*sd = [SyphonServerDirectory sharedDirectory];
	NSArray		*servers = (sd==nil) ? nil : [sd servers];
	if (servers!=nil)	{
		NSMenu		*pubMenu = [longPUB menu];
		[pubMenu removeAllItems];
		[pubMenu addItemWithTitle:@"-" action:nil keyEquivalent:@""];
		for (NSDictionary *serverDict in servers)	{
			NSString		*serverName = [NSString stringWithFormat:@"%@-%@",[serverDict objectForKey:SyphonServerDescriptionAppNameKey],[serverDict objectForKey:SyphonServerDescriptionNameKey]];
			NSMenuItem		*serverItem = [[NSMenuItem alloc]
				initWithTitle:serverName
				action:nil
				keyEquivalent:@""];
			[serverItem setEnabled:YES];
			[serverItem setRepresentedObject:[[serverDict copy] autorelease]];
			[pubMenu addItem:serverItem];
			[serverItem release];
		}
	}
	//	try to select the last-selected syphon server
	NSString		*tmpString = nil;
	@synchronized (self)	{
		tmpString = (syphonLastSelectedName==nil) ? nil : [syphonLastSelectedName retain];
	}
	if (tmpString==nil)
		[longPUB selectItemAtIndex:0];
	else	{
		[longPUB selectItemWithTitle:tmpString];
		[tmpString release];
		tmpString = nil;
	}
	[self uiItemUsed:longPUB];
}
- (void) _reloadAudioPUB	{
	NSArray			*newMenuItems = [_globalAudioController arrayOfAudioMenuItems];
	if (newMenuItems == nil)
		return;
	NSMenu			*newMenu = [[NSMenu alloc] initWithTitle:@""];
	[newMenu setAutoenablesItems:NO];
	for (NSMenuItem *itemPtr in newMenuItems)	{
		[newMenu addItem:itemPtr];
	}
	[audioSourcePUB setMenu:newMenu];
	[newMenu release];
	NSString		*audioInputName = [_globalAudioController inputName];
	[audioSourcePUB selectItemWithTitle:audioInputName];
	/*
	NSArray			*newInputsNames = [VVAudioInputNode availableAudioInputNames];
	//NSLog(@"\t\tnew input names %@",newInputsNames);
	[audioSourcePUB removeAllItems];
	[audioSourcePUB addItemWithTitle:@"<-System Default->"];
	[audioSourcePUB addItemsWithTitles:newInputsNames];
	
	NSString		*audioInputName = [_globalAudioController inputName];
	[audioSourcePUB selectItemWithTitle:audioInputName];
	*/
	
	
	/*
	NSString		*lastSelectedTitle = nil;
	if ([audioSourcePUB indexOfSelectedItem]>0 && [audioSourcePUB indexOfSelectedItem]!=NSNotFound)	{
		lastSelectedTitle = [audioSourcePUB titleOfSelectedItem];
	}
	NSArray			*newInputsNames = [VVAudioInputNode availableAudioInputNames];
	//NSLog(@"\t\tnew input names %@",newInputsNames);
	[audioSourcePUB removeAllItems];
	[audioSourcePUB addItemWithTitle:@"<-System Default->"];
	[audioSourcePUB addItemsWithTitles:newInputsNames];
	
	if (lastSelectedTitle != nil)	{
		[audioSourcePUB selectItemWithTitle:lastSelectedTitle];
	}
	else	{
		//	if nothing was selected try using the system default
		[audioSourcePUB selectItemAtIndex:0];
		[self uiItemUsed:audioSourcePUB];
	}
	*/
}
- (void) audioInputsChangedNotification:(NSNotification *)note	{
	[self _reloadAudioPUB];
}
- (void) _syphonServerChangeNotification:(NSNotification *)note	{
	[self _reloadSyphonPUB];
}
- (void) uiItemUsed:(id)sender	{
	switch (type)	{
	case ISFAT_Event:
		eventNeedsSending = YES;
		break;
	case ISFAT_Bool:
	case ISFAT_Long:
	case ISFAT_Float:
	case ISFAT_Point2D:
		/*
		if (sender == xSlider)	{
			pointVal.x = [xSlider floatValue];
		}
		else if (sender == ySlider)	{
			pointVal.y = [ySlider floatValue];
		}
		NSPointLog(@"\t\tpointVal is",pointVal);
		*/
		if (sender == xField)	{
			pointVal.x = [[[xField stringValue] numberByEvaluatingString] floatValue];
		}
		else if (sender == yField)	{
			pointVal.y = [[[yField stringValue] numberByEvaluatingString] floatValue];
		}
		break;
	case ISFAT_Color:
		break;
	case ISFAT_Image:
		{
			NSUInteger				selectedIndex = [longPUB indexOfSelectedItem];
			NSMenuItem		*selectedItem = [longPUB selectedItem];
			if (selectedItem!=nil && selectedIndex>0 && selectedIndex!=NSNotFound)	{
				@synchronized (self)	{
					if (syphonLastSelectedName!=nil)
						[syphonLastSelectedName release];
					syphonLastSelectedName = [[selectedItem title] retain];
				}
				
				NSDictionary		*serverDict = [selectedItem representedObject];
				@synchronized (self)	{
					if (syphonClient != nil)
						[syphonClient release];
					syphonClient = nil;
					if (serverDict != nil)	{
						syphonClient = [[SyphonClient alloc]
							initWithServerDescription:serverDict
							options:nil
							newFrameHandler:nil];
					}
				}
			}
			else	{
				if (syphonClient != nil)	{
					[syphonClient release];
					syphonClient = nil;
				}
			}
			break;
		}
	case ISFAT_Cube:
		break;
	case ISFAT_Audio:
	case ISFAT_AudioFFT:
		{
			//	get the name from the PUB
			NSString		*audioInputName = [audioSourcePUB titleOfSelectedItem];
			NSMenuItem		*selectedItem = [audioSourcePUB selectedItem];
			NSString		*audioUniqueID = [selectedItem representedObject];
			//	if the default is selected, use it
			if ([audioInputName isEqualToString:@"<-System Default->"])	{
				//audioInputName = [VVAudioInputNode defaultInputName];
			}
			//	tell the global audio singleton to use the input with the chosen name
			[_globalAudioController loadDeviceWithUniqueID:audioUniqueID];
		}
		break;
	}
}


- (NSString *) name	{
	return name;
}
- (id) getNSObjectValue	{
	//NSLog(@"%s ... %@",__func__,self);
	switch (type)	{
	case ISFAT_Event:
		if (eventNeedsSending)	{
			eventNeedsSending = NO;
			return [NSNumber numberWithBool:YES];
		}
		return [NSNumber numberWithBool:NO];
	case ISFAT_Bool:
		return [NSNumber numberWithBool:([boolButton intValue]==NSOnState)?YES:NO];
	case ISFAT_Long:
		return [NSNumber numberWithInt:(int)[[longPUB selectedItem] tag]];
	case ISFAT_Float:
		return [NSNumber numberWithFloat:[slider floatValue]];
	case ISFAT_Point2D:
		//return [NSValue valueWithPoint:NSMakePoint([[[xField stringValue] numberByEvaluatingString] floatValue], [[[yField stringValue] numberByEvaluatingString] floatValue])];
		//NSLog(@"\t\treturning %@",[NSValue valueWithPoint:pointVal]);
		return [NSValue valueWithPoint:pointVal];
	case ISFAT_Color:
		return [colorField color];
	case ISFAT_Image:
		{
			VVBuffer	*tmpBuffer = (syphonClient!=nil && [syphonClient hasNewFrame]) ? [_globalVVBufferPool allocBufferForSyphonClient:syphonClient] : nil;
			return [tmpBuffer autorelease];
		}
		break;
	case ISFAT_Cube:
		break;
	case ISFAT_Audio:
	case ISFAT_AudioFFT:
		{
			NSDictionary	*tmpDict = [self userInfoDict];
			NSNumber		*maxNum = (tmpDict==nil) ? nil : [tmpDict objectForKey:@"MAX"];
			long			maxVal = (maxNum==nil) ? 0 : [maxNum longValue];
			VVBuffer		*tmpBuffer = nil;
			if (maxVal <= 0)	{
				if (type == ISFAT_Audio)
					tmpBuffer = [_globalAudioController allocAudioImageBuffer];
				else
					tmpBuffer = [_globalAudioController allocAudioFFTImageBuffer];
			}
			else	{
				if (type == ISFAT_Audio)
					tmpBuffer = [_globalAudioController allocAudioImageBufferWithWidth:maxVal];
				else
					tmpBuffer = [_globalAudioController allocAudioFFTImageBufferWithWidth:maxVal];
			}
			return [tmpBuffer autorelease];
		}
		break;
	}
	return nil;
}
- (void) setNSObjectValue:(id)n	{
	//NSLog(@"%s ... %@, %@",__func__,self,n);
	if (n==nil)
		return;
	switch (type)	{
	case ISFAT_Event:
		break;
	case ISFAT_Bool:
		[boolButton setIntValue:([n boolValue]) ? NSOnState : NSOffState];
		break;
	case ISFAT_Long:
		[longPUB selectItemAtIndex:[n intValue]];
		break;
	case ISFAT_Float:
		[slider setFloatValue:[n floatValue]];
		break;
	case ISFAT_Point2D:
		pointVal = [n pointValue];
		
		/*
		[xSlider setFloatValue:pointVal.x];
		[ySlider setFloatValue:pointVal.y];
		*/
		[xField setStringValue:VVFMTSTRING(@"%0.2f",pointVal.x)];
		[yField setStringValue:VVFMTSTRING(@"%0.2f",pointVal.y)];
		
		break;
	case ISFAT_Color:
		[colorField setColor:n];
		break;
	case ISFAT_Image:
		break;
	case ISFAT_Cube:
		break;
	case ISFAT_Audio:
	case ISFAT_AudioFFT:
		break;
	}
}
- (NSString *) description	{
	return [NSString stringWithFormat:@"<ISFUIItem %@>",name];
}
@synthesize userInfoDict;
@synthesize type;


@end

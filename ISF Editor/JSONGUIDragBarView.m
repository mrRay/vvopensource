#import "JSONGUIDragBarView.h"
#import "ISFPropInputTableCellView.h"
#import "ISFPropPassTableCellView.h"
#import <VVBufferPool/VVBufferPool.h>




#define ARCHIVE(a) [NSKeyedArchiver archivedDataWithRootObject:a]
#define UNARCHIVE(a) [NSKeyedUnarchiver unarchiveObjectWithData:a]




@implementation JSONGUIDragBarView


- (void) generalInit	{
	[super generalInit];
	VVSprite		*tmpSprite = [spriteManager makeNewSpriteAtBottomForRect:NSMakeRect(0,0,1,1)];
	[tmpSprite setDelegate:self];
	[tmpSprite setDrawCallback:@selector(drawBGSprite:)];
	[tmpSprite setActionCallback:@selector(bgSpriteAction:)];
	bgSpriteHolder = [[ObjectHolder alloc] initWithZWRObject:tmpSprite];
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	VVRELEASE(bgSpriteHolder);
	[super dealloc];
}
- (void) drawBGSprite:(VVSprite *)s	{
	/*
	[[NSColor redColor] set];
	NSRectFill([s rect]);
	*/
	
	[[NSColor colorWithDeviceRed:0. green:0. blue:0. alpha:0.05] set];
	NSRectFill([s rect]);
	
	NSImage		*logo = [NSImage imageNamed:NSImageNameShareTemplate];
	NSSize		logoSize = [logo size];
	NSRect		logoRect = [VVSizingTool
		rectThatFitsRect:NSMakeRect(0,0,logoSize.width,logoSize.height)
		inRect:NSInsetRect([self bounds],2,2)
		sizingMode:VVSizingModeFit];
	[logo drawInRect:logoRect];
}
- (void) bgSpriteAction:(VVSprite *)s	{
	//NSLog(@"%s",__func__);
	if ([s lastActionType]==VVSpriteEventDrag)	{
		NSPoint		mdd = [s mouseDownDelta];
		if (fabs(mdd.x)>30 || fabs(mdd.y)>30)	{
			
			NSString			*dragType = @"com.Vidvox.ISFEditor.JSONGUIPboard";
			NSPasteboardItem	*pbItem = [[NSPasteboardItem alloc] init];
			NSDraggingItem		*dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:pbItem];
			[dragItem setImageComponentsProvider:^(void)	{
				//NSLog(@"%s",__func__);
				NSArray			*returnMe = nil;
				NSImage			*dragImage = [[[NSImage alloc] initWithData:[[self superview] dataWithPDFInsideRect:[[self superview] bounds]]] autorelease];
				
				//	when i draw the drag image, an origin of (0,0) will draw it at the origin of self
				
				
				NSPoint			mouseDown = NSZeroPoint;
				NSPoint			convertedMouseDown = [self convertPoint:mouseDown toView:[self superview]];
				NSRect			dragImageFrame = NSMakeRect(0,0,0,0);
				dragImageFrame.origin = VVADDPOINT(VVSUBPOINT(NSZeroPoint, convertedMouseDown), mdd);
				//dragImageFrame.origin = NSMakePoint(0,0);
				dragImageFrame.size = [dragImage size];
				if (dragImage==nil)
					NSLog(@"\t\terr: couldn't make drag image, %s",__func__);
				else	{
					NSDraggingImageComponent	*component = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey];
					if (component==nil)
						NSLog(@"\t\terr: couldn't make component for key %@ in %s",dragType,__func__);
					else	{
						[component setContents:dragImage];
						[component setFrame:dragImageFrame];
						returnMe = OBJARRAY(component);
					}
				}
				return (NSArray *)returnMe;
			}];
			NSDraggingSession	*session = [self beginDraggingSessionWithItems:OBJARRAY(dragItem) event:[self lastMouseEvent] source:self];
			if (session==nil)
				NSLog(@"\t\terr: dragging session nil in %s",__func__);
			else	{
				NSPasteboard		*pb = [session draggingPasteboard];
				if (pb==nil)
					NSLog(@"\t\terr: dragging pb nil in %s",__func__);
				else	{
					//	populate the pasteboard using the ABSOLUTE index of the item being dragged
					[pb clearContents];
					id				mySuperview = [self superview];
					NSInteger		myIndex = NSNotFound;
					if ([mySuperview isKindOfClass:[ISFPropInputTableCellView class]])	{
						JSONGUIInput	*myInput = [mySuperview input];
						myIndex = [[myInput top] indexOfInput:myInput];
						myIndex += 2;	//	the first two rows in the table are the "top" view and the "group" view for inputs
					}
					else if ([mySuperview isKindOfClass:[ISFPropPassTableCellView class]])	{
						JSONGUIPass		*myPass = [mySuperview pass];
						myIndex = [[myPass top] indexOfPass:myPass];
						myIndex += 2;	//	the first two rows in the table are the "top" view and the "group" view for inputs
						myIndex += [[[[myPass top] inputsGroup] contents] lockCount];	//	compensate for the inputs
						++myIndex;	//	compensate for the "group" view for passes
					}
					if (myIndex == NSNotFound)
						NSLog(@"\t\terr: index is NSNotFound in %s",__func__);
					else
						[pb setData:ARCHIVE(NUMLONG(myIndex)) forType:dragType];
					/*
					NSNumber			*draggedTabIndex = [NSNumber numberWithInt:[[dragTabWindow dragTabViewControllers] lockIndexOfIdenticalPtr:[t NRUserInfo]]];
					NSData				*tmpData = [NSKeyedArchiver archivedDataWithRootObject:draggedTabIndex];
					[pb setData:tmpData forType:dragType];
					*/
				}
			}
			VVRELEASE(dragItem);
			VVRELEASE(pbItem);
		}
	}
}
- (void) updateSprites	{
	[super updateSprites];
	[[bgSpriteHolder object] setRect:[self bounds]];
}

/*===================================================================================*/
#pragma mark --------------------- dragging source protocol
/*------------------------------------*/

- (NSDragOperation) draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context	{
	
	switch (context)	{
	case NSDraggingContextOutsideApplication:
		return NSDragOperationNone;
		break;
	case NSDraggingContextWithinApplication:
		return NSDragOperationMove;
		break;
	default:
		return NSDragOperationNone;
		break;
	}
	
}

@end

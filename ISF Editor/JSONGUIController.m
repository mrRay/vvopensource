#import "JSONGUIController.h"
#import "ISFController.h"
#import "DocController.h"
#import "JSONGUIArrayGroup.h"
#import "JSONGUIInput.h"
#import "JSONGUIPass.h"

#import "ISFPropErrTableCellView.h"
#import "ISFPropGroupTableCellView.h"
#import "ISFPropInputTableCellView.h"
#import "ISFPropPassTableCellView.h"
#import "ISFPropTopTableCellView.h"




#define LOCK OSSpinLockLock
#define UNLOCK OSSpinLockUnlock




id			_globalJSONGUIController = nil;




@implementation JSONGUIController


- (id) init	{
	self = [super init];
	if (self != nil)	{
		alreadyAwake = NO;
		_globalJSONGUIController = self;
		dictLock = OS_SPINLOCK_INIT;
		isfDict = nil;
		top = nil;
	}
	return self;
}
- (void) awakeFromNib	{
	if (!alreadyAwake)	{
		[tableView registerForDraggedTypes:OBJARRAY(@"com.Vidvox.ISFEditor.JSONGUIPboard")];
	}
	
	alreadyAwake = YES;
}
- (void) refreshUI	{
	//NSLog(@"%s",__func__);
	
	//	get the JSON string from the ISF controller
	//ISFGLScene		*scene = [isfController scene];
	//NSString		*importPath = [scene filePath];
	NSString		*importPath = [docController fragFilePath];
	NSString		*fragString = [NSString stringWithContentsOfFile:importPath encoding:NSUTF8StringEncoding error:nil];
	NSRange			openCommentRange = [fragString rangeOfString:@"/*" options:NSLiteralSearch];
	//	if i couldn't find the open comment range, bail
	if (openCommentRange.location == NSNotFound)	{
		NSLog(@"\t\terr: couldn't find open comment in file, bailing %s",__func__);
		NSLog(@"\t\terr: import path was %@",importPath);
		return;
	}
	NSRange			closeCommentSearchRange = NSMakeRange(openCommentRange.location+openCommentRange.length, 0);
	closeCommentSearchRange.length = [fragString length] - closeCommentSearchRange.location;
	NSRange			closeCommentRange = [fragString rangeOfString:@"*/" options:NSLiteralSearch range:closeCommentSearchRange];
	//	if i couldn't find the close comment range, bail
	if (closeCommentRange.location == NSNotFound)	{
		NSLog(@"\t\terr: couldn't find close comment in file, bailing %s",__func__);
		NSLog(@"\t\terr: import path was %@",importPath);
		return;
	}
	NSRange			jsonRange = NSMakeRange(openCommentRange.location+openCommentRange.length, 0);
	jsonRange.length = closeCommentRange.location - jsonRange.location;
	NSString		*jsonString = [fragString substringWithRange:jsonRange];
	
	/*
	NSString		*jsonString = [[[[isfController scene] jsonString] retain] autorelease];
	*/
	
	//	parse it, turning it into objects- safely replace my local cache of objects
	LOCK(&dictLock);
	VVRELEASE(isfDict);
	isfDict = [[jsonString mutableObjectFromJSONString] retain];
	
	//	now parse the dict by creating JSONGUI* instances from it
	top = [[JSONGUITop alloc] initWithISFDict:isfDict];
	//NSLog(@"\t\ttop is %@",top);
	//NSLog(@"\t\tinputs are %@",[top inputsGroup]);
	//NSLog(@"\t\tpasses are %@",[top passesGroup]);
	
	UNLOCK(&dictLock);
	
	//	update the outline view
	[outlineView reloadData];
	[tableView reloadData];
}


- (NSInteger) numberOfRowsInTableView:(NSTableView *)tv	{
	//	base properties + 2 group cells + contents of both groups
	return 1 + 2 + [[[top inputsGroup] contents] lockCount] + [[[top passesGroup] contents] lockCount];
}
- (NSView *) tableView:(NSTableView *)tv viewForTableColumn:(NSTableColumn *)tc row:(NSInteger)row	{
	NSView			*returnMe = nil;
	NSInteger		indexOfInputsGroupCell = 1;
	NSInteger		indexOfPassesGroupCell = indexOfInputsGroupCell + [[[top inputsGroup] contents] lockCount] + 1;
	//NSLog(@"\t\tindexOfInputsGroupCell is %d, indexOfPassesGroupCell is %d",indexOfInputsGroupCell,indexOfPassesGroupCell);
	//	if this is the row for the 'top' item
	if (row==0)	{
		returnMe = [tv makeViewWithIdentifier:@"TopCell" owner:self];
		[(ISFPropTopTableCellView *)returnMe refreshWithTop:top];
	}
	//	else if this is a row for a group ("inputs" or "passes")
	else if (row==indexOfInputsGroupCell || row==indexOfPassesGroupCell)	{
		returnMe = [tv makeViewWithIdentifier:@"GroupCell" owner:self];
		[(ISFPropGroupTableCellView *)returnMe refreshWithGroup:(row==indexOfInputsGroupCell) ? [top inputsGroup] : [top passesGroup]];
	}
	//	else if this is a pass
	else if (row>indexOfPassesGroupCell)	{
		JSONGUIPass		*pass = [[[top passesGroup] contents] lockObjectAtIndex:row-(indexOfPassesGroupCell+1)];
		returnMe = [tv makeViewWithIdentifier:@"PassCell" owner:self];
		[(ISFPropPassTableCellView *)returnMe refreshWithTop:top pass:pass];
	}
	//	else this is an input
	else	{
		JSONGUIInput	*input = [[[top inputsGroup] contents] lockObjectAtIndex:row-(indexOfInputsGroupCell+1)];
		NSString		*typeString = [(JSONGUIInput *)input objectForKey:@"TYPE"];
		returnMe = [self makeTableCellViewForISFTypeString:typeString];
		[(ISFPropInputTableCellView *)returnMe refreshWithInput:input];
	}
	
	return returnMe;
}
- (CGFloat) tableView:(NSTableView *)tv heightOfRow:(NSInteger)row	{
	CGFloat			returnMe = 17.;
	NSView			*tmpView = nil;
	NSInteger		indexOfInputsGroupCell = 1;
	NSInteger		indexOfPassesGroupCell = indexOfInputsGroupCell + [[[top inputsGroup] contents] lockCount] + 1;
	//	if this is the row for the 'top' item
	if (row==0)	{
		tmpView = [tv makeViewWithIdentifier:@"TopCell" owner:self];
		returnMe = [tmpView frame].size.height;
	}
	//	else if this is a row for a group ("inputs" or "passes")
	else if (row==indexOfInputsGroupCell || row==indexOfPassesGroupCell)	{
		tmpView = [tv makeViewWithIdentifier:@"GroupCell" owner:self];
		returnMe = [tmpView frame].size.height;
	}
	//	else if this is a pass
	else if (row>indexOfPassesGroupCell)	{
		tmpView = [tv makeViewWithIdentifier:@"PassCell" owner:self];
		returnMe = [tmpView frame].size.height;
	}
	//	else this is an input
	else	{
		JSONGUIInput	*input = [[[top inputsGroup] contents] lockObjectAtIndex:row-(indexOfInputsGroupCell+1)];
		NSString		*typeString = [(JSONGUIInput *)input objectForKey:@"TYPE"];
		tmpView = [self makeTableCellViewForISFTypeString:typeString];
		returnMe = [tmpView frame].size.height;
	}
	
	return returnMe;
}
- (BOOL)tableView:(NSTableView *)tv shouldSelectRow:(NSInteger)rowIndex	{
	return NO;
}
- (NSDragOperation) tableView:(NSTableView *)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op	{
	//NSLog(@"%s",__func__);
	NSPasteboard	*pboard = [info draggingPasteboard];
	id				draggedObj = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:@"com.Vidvox.ISFEditor.JSONGUIPboard"]];
	//	if i couldn't find the dragged obj, bail
	if (draggedObj == nil)
		return NO;
	if (![draggedObj isKindOfClass:[NSNumber class]])	{
		NSLog(@"\t\terr: expected a number for drag in %s, but instead got %@",__func__,NSStringFromClass([draggedObj class]));
		return NO;
	}
	//NSLog(@"\t\tdraggedObj is %@",draggedObj);
	
	//	the dragged object is the absolute index of the item being dragged
	NSInteger		srcIndex = [draggedObj longValue];
	//	calculate some reference indexes that i'll need to locate the item being dragged
	NSInteger		indexOfInputsGroupCell = 1;
	NSInteger		indexOfPassesGroupCell = indexOfInputsGroupCell + [[[top inputsGroup] contents] lockCount] + 1;
	//NSInteger		indexOfLastPassCell = indexOfPassesGroupCell + [[[top passesGroup] contents] lockCount];
	//	if the item being dragged is an input...
	if (srcIndex>indexOfInputsGroupCell && srcIndex<indexOfPassesGroupCell)	{
		//	make sure that the proposed row is acceptable for inputs
		if (row<=indexOfInputsGroupCell || row>=indexOfPassesGroupCell)
			return NSDragOperationNone;
		else	{
			if (op == NSTableViewDropOn)
				[tableView setDropRow:row+1 dropOperation:NSTableViewDropAbove];
		}
	}
	//	else if the item being dragged is a pass...
	else if (srcIndex>indexOfPassesGroupCell)	{
		//	make sure the proposed row is acceptable for passes
		if (row<=indexOfPassesGroupCell)
			return NSDragOperationNone;
		else	{
			if (op == NSTableViewDropOn)
				[tableView setDropRow:row+1 dropOperation:NSTableViewDropAbove];
		}
	}
	//	else we don't know what the item being dragged is- bail
	else	{
		NSLog(@"\t\terr: unable to determine drag source item, %s",__func__);
		return NSDragOperationNone;
	}
	
	
	
	
	return NSDragOperationEvery;
}
- (BOOL) tableView:(NSTableView *)tv acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)op	{
	//NSLog(@"%s",__func__);
	NSPasteboard	*pboard = [info draggingPasteboard];
	id				draggedObj = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:@"com.Vidvox.ISFEditor.JSONGUIPboard"]];
	//	if i couldn't find the dragged obj, bail
	if (draggedObj == nil)
		return NO;
	if (![draggedObj isKindOfClass:[NSNumber class]])	{
		NSLog(@"\t\terr: expected a number for drag in %s, but instead got %@",__func__,NSStringFromClass([draggedObj class]));
		return NO;
	}
	//NSLog(@"\t\tdraggedObj is %@",draggedObj);
	
	//	the dragged object is the absolute index of the item being dragged
	NSInteger		srcIndex = [draggedObj longValue];
	NSInteger		dstIndex = row;
	if (srcIndex == dstIndex)
		return YES;
	
	//NSLog(@"\t\tin table, srcIndex is %ld, dstIndex is %ld",(long)srcIndex,(long)dstIndex);
	//	get the object being dragged
	id				draggedGUIObject = [self objectAtRowIndex:srcIndex];
	//NSLog(@"\t\tdraggedGUIObject is %@",draggedGUIObject);
	if (draggedGUIObject == nil)
		return NO;
	
	//	calculate some reference indexes that i'll need to locate the item being dragged
	NSInteger		indexOfInputsGroupCell = 1;
	NSInteger		indexOfPassesGroupCell = indexOfInputsGroupCell + [[[top inputsGroup] contents] lockCount] + 1;
	
	//	actually move the thing
	if ([draggedGUIObject isKindOfClass:[JSONGUIInput class]])	{
		MutLockArray		*theArray = [[[draggedGUIObject top] inputsGroup] contents];
		[theArray wrlock];
		if (srcIndex < dstIndex)	{
			[theArray insertObject:draggedGUIObject atIndex:dstIndex-indexOfInputsGroupCell-1];
			[theArray removeObjectAtIndex:srcIndex-indexOfInputsGroupCell-1];
		}
		else	{
			[theArray removeObjectAtIndex:srcIndex-indexOfInputsGroupCell-1];
			[theArray insertObject:draggedGUIObject atIndex:dstIndex-indexOfInputsGroupCell-1];
		}
		[theArray unlock];
		
		//	i have to recreate the JSON & export it
		[self recreateJSONAndExport];
		return YES;
	}
	else if ([draggedGUIObject isKindOfClass:[JSONGUIPass class]])	{
		MutLockArray		*theArray = [[[draggedGUIObject top] passesGroup] contents];
		[theArray wrlock];
		if (srcIndex < dstIndex)	{
			[theArray insertObject:draggedGUIObject atIndex:dstIndex-indexOfPassesGroupCell-1];
			[theArray removeObjectAtIndex:srcIndex-indexOfPassesGroupCell-1];
		}
		else	{
			[theArray removeObjectAtIndex:srcIndex-indexOfPassesGroupCell-1];
			[theArray insertObject:draggedGUIObject atIndex:dstIndex-indexOfPassesGroupCell-1];
		}
		[theArray unlock];
		
		//	i have to recreate the JSON & export it
		[self recreateJSONAndExport];
		return YES;
	}
	else	{
		return NO;
	}
	
}


- (NSView *) makeTableCellViewForISFTypeString:(NSString *)typeString	{
	NSView		*returnMe = nil;
	
	if (typeString==nil)
		returnMe = nil;
	else if (![typeString isKindOfClass:[NSString class]])
		returnMe = nil;
	else if ([typeString isEqualToString:@"event"])
		returnMe = [tableView makeViewWithIdentifier:@"EventCell" owner:self];
	else if ([typeString isEqualToString:@"bool"])
		returnMe = [tableView makeViewWithIdentifier:@"BoolCell" owner:self];
	else if ([typeString isEqualToString:@"long"])
		returnMe = [tableView makeViewWithIdentifier:@"LongCell" owner:self];
	else if ([typeString isEqualToString:@"float"])
		returnMe = [tableView makeViewWithIdentifier:@"FloatCell" owner:self];
	else if ([typeString isEqualToString:@"point2D"])
		returnMe = [tableView makeViewWithIdentifier:@"Point2DCell" owner:self];
	else if ([typeString isEqualToString:@"color"])
		returnMe = [tableView makeViewWithIdentifier:@"ColorCell" owner:self];
	else if ([typeString isEqualToString:@"image"])
		returnMe = [tableView makeViewWithIdentifier:@"ImageCell" owner:self];
	else if ([typeString isEqualToString:@"audio"])
		returnMe = [tableView makeViewWithIdentifier:@"AudioCell" owner:self];
	else if ([typeString isEqualToString:@"audioFFT"])
		returnMe = [tableView makeViewWithIdentifier:@"AudioFFTCell" owner:self];
	
	return returnMe;
}
- (NSDictionary *) isfDict	{
	LOCK(&dictLock);
	NSDictionary		*returnMe = (isfDict==nil) ? nil : [[isfDict retain] autorelease];
	UNLOCK(&dictLock);
	return returnMe;
}
- (NSMutableDictionary *) createNewISFDict	{
	NSMutableDictionary		*returnMe = MUTDICT;
	NSMutableArray			*tmpArray = nil;
	//NSMutableDictionary		*tmpDict = nil;
	
	//	populate the dict i'll be returning with the base dict i was populated from
	[returnMe addEntriesFromDictionary:[[top isfDict] dict]];
	//	remove the stuff that i'll be populating dynamically (leaving whatever non-spec stuff the user put in there)
	[returnMe removeObjectForKey:@"INPUTS"];
	[returnMe removeObjectForKey:@"PERSISTENT_BUFFERS"];
	[returnMe removeObjectForKey:@"PASSES"];
	//	now populate the INPUTS
	tmpArray = [top makeInputsArray];
	if (tmpArray != nil)
		[returnMe setObject:tmpArray forKey:@"INPUTS"];
	//	populate the PASSES
	tmpArray = [top makePassesArray];
	if (tmpArray != nil)
		[returnMe setObject:tmpArray forKey:@"PASSES"];
	//	populate the PERSISTENT_BUFFERS
	//tmpDict = [top makeBuffersDict];
	//if (tmpDict != nil)
	//	[returnMe setObject:tmpDict forKey:@"PERSISTENT_BUFFERS"];
	
	//	make sure we're flagged as ISFVSN 2.0
	[returnMe setObject:@"2" forKey:@"ISFVSN"];
	
	return returnMe;
}
- (id) objectAtRowIndex:(NSInteger)n	{
	if (n<0 || n==NSNotFound)
		return nil;
	id				returnMe = nil;
	//	calculate some reference indexes that i'll need to locate the item being dragged
	NSInteger		indexOfInputsGroupCell = 1;
	NSInteger		indexOfPassesGroupCell = indexOfInputsGroupCell + [[[top inputsGroup] contents] lockCount] + 1;
	NSInteger		indexOfLastPassCell = indexOfPassesGroupCell + [[[top passesGroup] contents] lockCount];
	//	if the item being dragged is an input...
	if (n>indexOfInputsGroupCell && n<indexOfPassesGroupCell)	{
		returnMe = [[[top inputsGroup] contents] lockObjectAtIndex:n-indexOfInputsGroupCell-1];
	}
	//	else if the item being dragged is a pass...
	else if (n>indexOfPassesGroupCell && n<=indexOfLastPassCell)	{
		returnMe = [[[top passesGroup] contents] lockObjectAtIndex:n-indexOfPassesGroupCell-1];
	}
	//	else we don't know what the item being dragged is- bail
	else	{
		NSLog(@"\t\terr: unable to determine drag source item, %s",__func__);
	}
	return [[returnMe retain] autorelease];
}


- (void) recreateJSONAndExport	{
	//NSLog(@"%s",__func__);
	NSDictionary		*newDict = [self createNewISFDict];
	if (newDict == nil)	{
		NSLog(@"\t\terr: newly-created ISF dict nil, %s",__func__);
		return;
	}
	
	//[docController loadFile:nil];
	
	ISFGLScene		*scene = [isfController scene];
	NSString		*exportString = [NSString stringWithFormat:@"/*\n%@\n*/%@",[newDict prettyJSONString],[scene fragShaderSource]];
	//NSLog(@"\t\texportString is %@",exportString);
	NSString		*exportPath = [scene filePath];
	NSError			*nsErr = nil;
	if (exportPath!=nil && exportString!=nil)	{
		if (![exportString writeToFile:exportPath atomically:YES encoding:NSUTF8StringEncoding error:&nsErr])	{
			NSLog(@"\t\tERR exporting to file %@ in %s.  %@",exportPath,__func__,nsErr);
		}
		else	{
			//	tell the doc controller to load the file again (the ISF controller reloaded the file already b/c it's watching the file for changes)
			[isfController reloadTargetFile];
			[docController loadFile:exportPath];
		}
	}
}


- (IBAction) saveCurrentValsAsDefaults:(id)sender	{
	//NSLog(@"%s",__func__);
	//	get the scene & inputs & top, bail if we can't
	ISFGLScene		*scene = [isfController scene];
	MutLockArray	*inputs = [scene inputs];
	LOCK(&dictLock);
	JSONGUITop		*_top = (top==nil) ? nil : [[top retain] autorelease];
	UNLOCK(&dictLock);
	if (inputs==nil || _top==nil)
		return;
	//	run through the inputs- we want to get the current val of applicable inputs, and apply it to the relevation JSONGUI* object
	[inputs rdlock];
	for (ISFAttrib *attrib in [inputs array])	{
		ISFAttribVal	attribVal = [attrib currentVal];
		JSONGUIInput	*input = [_top getInputNamed:[attrib attribName]];
		switch ([attrib attribType])	{
		case ISFAT_Event:
		case ISFAT_Image:
		case ISFAT_Cube:
		case ISFAT_Audio:
		case ISFAT_AudioFFT:
			//	do nothing for these types- they can't have a "currentVal"
			break;
		case ISFAT_Bool:
			[input setObject:NUMBOOL(attribVal.boolVal) forKey:@"DEFAULT"];
			break;
		case ISFAT_Long:
			[input setObject:NUMLONG(attribVal.longVal) forKey:@"DEFAULT"];
			break;
		case ISFAT_Float:
			[input setObject:NUMFLOAT(attribVal.floatVal) forKey:@"DEFAULT"];
			break;
		case ISFAT_Point2D:
			[input setObject:@[NUMFLOAT(attribVal.point2DVal[0]), NUMFLOAT(attribVal.point2DVal[1])] forKey:@"DEFAULT"];
			break;
		case ISFAT_Color:
			[input setObject:@[NUMFLOAT(attribVal.colorVal[0]), NUMFLOAT(attribVal.colorVal[1]), NUMFLOAT(attribVal.colorVal[2]), NUMFLOAT(attribVal.colorVal[3])] forKey:@"DEFAULT"];
			break;
		}
	}
	[inputs unlock];
	//	save everything!
	[self recreateJSONAndExport];
}


@end

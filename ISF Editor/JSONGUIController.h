#import <Foundation/Foundation.h>
#import <VVBasics/VVBasics.h>
#import "JSONGUITop.h"



//	we parse a JSON blob, unserialize it into objects, and retain them.
/*
//	if there is an object at the CLASS key in a dict for something, this enum lets you know whether this dict describes the top-level ISF dict, a single input, or a single pass
typedef NS_ENUM(NSInteger, ISFDictClassType)	{
	ISFDictClassType_Top,
	ISFDictClassType_Input,
	ISFDictClassType_Pass
};
*/




extern id			_globalJSONGUIController;




@interface JSONGUIController : NSObject	{
	BOOL						alreadyAwake;	//	when we make table cell views, awakeFromNib gets called repeatedly
	
	IBOutlet id					docController;
	IBOutlet id					isfController;
	IBOutlet NSOutlineView		*outlineView;
	IBOutlet NSTableView		*tableView;
	
	VVLock					dictLock;
	NSDictionary			*isfDict;
	JSONGUITop				*top;
}

- (void) refreshUI;

- (NSDictionary *) isfDict;
- (NSMutableDictionary *) createNewISFDict;
- (id) objectAtRowIndex:(NSInteger)n;

- (void) recreateJSONAndExport;

- (IBAction) saveCurrentValsAsDefaults:(id)sender;

@end

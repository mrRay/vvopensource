#import <Foundation/Foundation.h>
#import <VVBasics/VVBasics.h>
@class JSONGUITop;




//	we have to pass an array around (group-type cell in the outline view), but we need to discern between arrays of inputs and arrays of passes at the group level (because the group needs to be capable of making additional instances of its contents)
typedef NS_ENUM(NSInteger, ISFArrayClassType)	{
	ISFArrayClassType_Input,
	ISFArrayClassType_Pass
};




@interface JSONGUIArrayGroup : NSObject	{
	ISFArrayClassType			groupType;	//	what "type" of group this cell is describing (inputs/passes/etc)
	MutLockArray				*contents;	//	array of group contents (JSONGUIInput or JSONGUIPass instances)
	ObjectHolder				*top;
}

- (id) initWithType:(ISFArrayClassType)targetType top:(JSONGUITop *)theTop;

@property (readonly) ISFArrayClassType groupType;
@property (readonly) MutLockArray *contents;
- (JSONGUITop *) top;

@end

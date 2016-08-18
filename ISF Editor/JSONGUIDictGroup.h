#import <Foundation/Foundation.h>
#import <VVBasics/VVBasics.h>
@class JSONGUITop;




//	we have to pass an array around (group-type cell in the outline view), but we need to discern between arrays of inputs and arrays of passes at the group level (because the group needs to be capable of making additional instances of its contents)
typedef NS_ENUM(NSInteger, ISFDictClassType)	{
	ISFDictClassType_PersistentBuffer
};




@interface JSONGUIDictGroup : NSObject	{
	ISFDictClassType		groupType;
	MutLockDict				*contents;
	ObjectHolder			*top;
}

- (id) initWithType:(ISFDictClassType)targetType top:(JSONGUITop *)theTop;

- (id) objectForKey:(NSString *)k;

@property (readonly) ISFDictClassType groupType;
@property (readonly) MutLockDict *contents;
- (JSONGUITop *) top;

@end

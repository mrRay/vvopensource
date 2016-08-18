#import <Foundation/Foundation.h>
#import <VVBasics/VVBasics.h>
#import "JSONGUIArrayGroup.h"
#import "JSONGUIDictGroup.h"
#import "JSONGUIPersistentBuffer.h"
#import "JSONGUIPass.h"
@class JSONGUIInput;




@interface JSONGUITop : NSObject	{
	MutLockDict			*isfDict;
	
	JSONGUIArrayGroup		*inputsGroup;
	JSONGUIArrayGroup		*passesGroup;
	JSONGUIDictGroup		*buffersGroup;
}

- (id) initWithISFDict:(NSDictionary *)n;

- (MutLockDict *) isfDict;
- (JSONGUIArrayGroup *) inputsGroup;
- (JSONGUIArrayGroup *) passesGroup;
- (JSONGUIDictGroup *) buffersGroup;

- (JSONGUIInput *) getInputNamed:(NSString *)n;
- (NSArray *) getPassesRenderingToBufferNamed:(NSString *)n;
- (JSONGUIPersistentBuffer *) getPersistentBufferNamed:(NSString *)n;
- (NSInteger) indexOfInput:(JSONGUIInput *)n;
- (NSInteger) indexOfPass:(JSONGUIPass *)n;
//- (NSArray *) persistentBufferNames;
- (NSString *) createNewInputName;

- (NSMutableArray *) makeInputsArray;
- (NSMutableArray *) makePassesArray;
- (NSMutableDictionary *) makeBuffersDict;

@end

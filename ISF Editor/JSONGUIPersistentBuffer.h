#import <Foundation/Foundation.h>
#import <VVBasics/VVBasics.h>
@class JSONGUITop;




@interface JSONGUIPersistentBuffer : NSObject	{
	MutLockDict			*dict;
	NSString			*name;
	ObjectHolder		*top;
}

- (id) initWithName:(NSString *)n top:(JSONGUITop *)t;

- (id) objectForKey:(NSString *)k;
- (void) setObject:(id)n forKey:(NSString *)k;
- (NSString *) name;
- (JSONGUITop *) top;

- (NSDictionary *) createExportDict;

@end

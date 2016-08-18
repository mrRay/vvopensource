#import <Foundation/Foundation.h>
#import <VVBasics/VVBasics.h>
@class JSONGUITop;




@interface JSONGUIPass : NSObject	{
	MutLockDict			*dict;
	ObjectHolder		*top;
}

- (id) initWithDict:(NSDictionary *)n top:(JSONGUITop *)t;

- (id) objectForKey:(NSString *)k;
- (void) setObject:(id)n forKey:(NSString *)k;
- (JSONGUITop *) top;

- (NSMutableDictionary *) createExportDict;

@end

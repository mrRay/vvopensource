#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>



@interface ISFRenderPass : NSObject	{
	NSString		*targetName;
}

+ (id) create;

@property (retain,readwrite) NSString *targetName;

@end

#import <TargetConditionals.h>
#if !TARGET_OS_IPHONE
#import <Cocoa/Cocoa.h>
#else
#import <UIKit/UIKit.h>
#endif
#import <VVBasics/VVBasics.h>



@interface ISFRenderPass : NSObject	{
	NSString		*targetName;
}

+ (id) create;

@property (retain,readwrite) NSString *targetName;

@end

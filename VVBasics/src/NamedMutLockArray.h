
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "VVBasicMacros.h"
#import "MutLockArray.h"




@interface NamedMutLockArray : MutLockArray {
	NSString		*name;
}

@property (assign, readwrite) NSString *name;

@end

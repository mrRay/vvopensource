
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif
#import "VVBasicMacros.h"
#import "MutLockArray.h"




/*
	//	only difference between this and MutLockArray is the "name" variable.
*/




@interface NamedMutLockArray : MutLockArray {
	NSString		*name;
}

- (NSComparisonResult) nameCompare:(NamedMutLockArray *)comp;

@property (assign, readwrite) NSString *name;

@end

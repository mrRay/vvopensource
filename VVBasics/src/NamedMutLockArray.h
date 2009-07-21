
#import <Cocoa/Cocoa.h>
#import "VVBasicMacros.h"
#import "MutLockArray.h"




/*
	//	only difference between this and MutLockArray is the "name" variable.
*/




@interface NamedMutLockArray : MutLockArray {
	NSString		*name;
}

@property (assign, readwrite) NSString *name;

@end

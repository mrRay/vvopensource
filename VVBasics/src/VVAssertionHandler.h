
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif




#define USE_CUSTOM_ASSERTION_HANDLER																			\
{																												\
	NSThread				*__currentThread = [NSThread currentThread];										\
	NSDictionary			*__threadDict = (__currentThread==nil) ? nil : [__currentThread threadDictionary];	\
	if (__threadDict != nil)	{																				\
		VVAssertionHandler		*__newAH = [[VVAssertionHandler alloc] init];									\
		if (__newAH != nil)	{																					\
			[__threadDict setValue:__newAH forKey:@"NSAssertionHandler"];										\
			[__newAH release];																					\
			__newAH = nil;																						\
		}																										\
	}																											\
}



@interface VVAssertionHandler : NSAssertionHandler {

}

@end

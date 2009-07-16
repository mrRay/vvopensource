
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif




/*
	this class exists to make it easier to work with instances of any class in 
	arrays/dicts/etc. without retaining them; the ObjectHolder gets retained, 
	but it doesn't actually retain the object it references.  methods called on 
	the ObjectHolder which it doesn't respond to are automatically forwarded to 
	its object.
*/




@interface ObjectHolder : NSObject {
	BOOL		deleted;
	id			object;
}

+ (id) createWithObject:(id)o;
- (id) initWithObject:(id)o;

- (id) object;

@end

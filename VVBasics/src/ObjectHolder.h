
#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif




/*
	created for working with the MutNRLockArray class.
	
	basically, you create an instance of this class and give it a reference to an 
	instance of an object.  the instance is NOT retained- but you're now free to 
	pass ObjectHolder to stuff which will otherwise retain/release it without 
	worrying about whether the passed instance is retained/released.
	
	if you call a method on an instance of ObjectHolder and the ObjectHolder 
	class doesn't respond to that method, the instance will try to call the 
	method on its object.  this means that working with ObjectHolder should- 
	theoretically, at any rate- be transparent...
*/




@interface ObjectHolder : NSObject {
	BOOL		deleted;
	id			object;
}

+ (id) createWithObject:(id)o;
- (id) initWithObject:(id)o;

- (id) object;

@end

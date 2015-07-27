#import <Foundation/Foundation.h>


/*
 
 - an instance of this class always needs to be the delegate of the [NSXPCListener serviceListener].  
 there should only be one instance of this class per XPC service, and there shouldn't be any 
 instances of this class in your main app!
 
 - in your XPC service, you need to add as many service delegate classes as you like to this class 
 before you start the listener.
 
 */


@interface MCXServiceDelegate : NSObject <NSXPCListenerDelegate>	{
	__block NSMutableDictionary		*tmpServiceDelegates;	//	used to temporarily store service delegates
}

/*	this method may only be called before you "resume" the service listener which an instance of 
 this class must be a delegate of!  the passed service delegate is retained, and it is assumed that 
 the corresponding remote object you supply will conform to the protocols specified by the delegate 
 you pass in here!		*/
- (void) addServiceDelegate:(id<NSXPCListenerDelegate>)d forClassNamed:(NSString *)c;

@end

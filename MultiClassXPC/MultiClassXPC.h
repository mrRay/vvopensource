#import <Cocoa/Cocoa.h>




/*		by default, an XPC service managed with the NSXPC API appears to be optimized/configured to 
 only work with instances of a single class.  that is to say, an XPC service is, well...a *service*- 
 by design, it has a single interface.  this is fine, but sometimes you want to run several different 
 classes- each with their own interface- in the same XPC service.  i couldn't find a clean, simple 
 way to quickly set up multiple classes to run independently of one another in the same XPC service 
 (if i missed something, please let me know), so i made this framework.
 
 MultiClassXPC.framework aims to make it easier to create instances of multiple classes that are all 
 hosted in the same XPC service.  an overview follows, and an example app + service is provided that 
 demonstrates using MultiClassXPC to run multiple classes in the same XPC service.
 
 
 HOW TO USE THIS FRAMEWORK:
 
 - link against MultiClassXPC.framework in both your host app and your XPC service; make sure the 
 runpaths are configured properly, and that the framework is copied into the sample app (don't have 
 to copy it to the XPC service too)
 
 - in your host app, make an instance of MCXServiceManager for each XPC service you want to create.  
 wait until -[MCXServiceManager classesAvailable] returns YES, and then you can retrieve a dict 
 containing NSXPCListenerEndpoint objects stored with the name of the classes which they connect to.  
 the objects you write in your main app that need to connect to their counterparts in the XPC service 
 can use these listener endpoints to create connections much as you would if you were using the NSXPC 
 API.
 
 - the "remote" objects that will run in your main app will use the listener endpoints vended by 
 instances of MCXServiceManager to create NSXPCConnections in a manner similar to how you'd work with 
 the more traditional single-class-XPC-service configuration.  in the invalidation and error handlers 
 of the NSXPCConnections you create, make sure that you call -[MCXServiceManager 
 listenerErrHandlerTripped] immediately.  this forces the MCXServiceManager to purge its cache of 
 listener endpoints and relaunch the XPC service.
 
 - your XPC service needs to contain the classes you want to run in the XPC service, as well as a service 
 delegate for each class you want to run in the XPC service.  in your service's .m file, you need to 
 make a MCXServiceDelegate and attach that to the service listener, then make the service delegates 
 for your classes and pass them to the MCXServiceDelegate before you resume the service listener.
 
 
 */





#import "MCXProtocols.h"
//#import "MCXService.h"
#import "MCXServiceManager.h"
#import "MCXServiceDelegate.h"


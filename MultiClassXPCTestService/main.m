#import <Foundation/Foundation.h>
#import <MultiClassXPC/MultiClassXPC.h>
#import "ServiceDelegateA.h"
#import "ServiceDelegateB.h"




int main(int argc, const char *argv[])
{
	NSLog(@"%s",__func__);
	NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	
	//	create the listener & the service delegate for MultiClassXPC
	NSXPCListener				*serviceListener = [NSXPCListener serviceListener];
	MCXServiceDelegate			*mcxServiceDelegate = [[MCXServiceDelegate alloc] init];
	[serviceListener setDelegate:mcxServiceDelegate];
	
	//	add the service delegates for your classes to the service delegate
	ServiceDelegateA			*delegateA = [[ServiceDelegateA alloc] init];
	ServiceDelegateB			*delegateB = [[ServiceDelegateB alloc] init];
	[mcxServiceDelegate addServiceDelegate:delegateA forClassNamed:@"ClassAMCXRemote"];
	[mcxServiceDelegate addServiceDelegate:delegateB forClassNamed:@"ClassBMCXRemote"];
	[delegateA release];
	[delegateB release];
	
	//	resume the service listener!
	[serviceListener resume];
	
	[pool release];
	pool = nil;
	return 0;
}
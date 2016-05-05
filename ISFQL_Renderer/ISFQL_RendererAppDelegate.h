//
//  AppDelegate.h
//  ISFQL_Renderer
//
//  Created by testAdmin on 4/29/16.
//  Copyright © 2016 vidvox. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ISFQLRendererAgent.h"
#import <VVBufferPool/VVBufferPool.h>




extern VVBuffer		*_globalColorBars;




/*	this is the delegate of a cocoa app which is being used as a LaunchAgent (a per-user process in 
	the GUI space that is loaded as a mach service on login, and is launched as needed).  this class 
	basically just spawns a thread, sets up an XPC service listener on the thread, and responds to 
	XPC connection attempts by creating an ISFQLRendererAgent (which renders a frame and passes it back)
*/




@interface ISFQL_RendererAppDelegate : NSObject <NSApplicationDelegate,NSXPCListenerDelegate,ISFQLRendererAgentDelegate>	{
	OSSpinLock		ttlLock;
	NSTimer			*ttlTimer;	//	makes sure the app only lives 5 seconds after it's not in use any longer
}

- (void) resetTTLTimer;

@end


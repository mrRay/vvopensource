//
//  MyOSCManager.h
//  VVOSC
//
//  Created by bagheera on 10/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVOSC/VVOSC.h>
#import "OSCInPortRetainsRaw.h"


//	key for notification which is fired whenever a new output is created
#define VVOSCOutPortsChangedNotification @"VVOSCOutPortsChangedNotification"


/*
	this class exists solely to specify a subclass of OSCInPort which
	formats and retains strings of the raw packet data received
*/


@interface MyOSCManager : OSCManager {

}

- (id) inPortClass;

@end

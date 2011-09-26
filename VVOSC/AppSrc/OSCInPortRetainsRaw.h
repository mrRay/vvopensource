//
//  OSCInPortRetainsRaw.h
//  VVOSC
//
//  Created by bagheera on 10/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVOSC/VVOSC.h>


/*
	this subclass exists for the sole purpose of creating and retaining strings
	which describe OSCPackets that i received.  it does this for display purposes.
	
	this probably isn't the fastest way in the world to do this- but this was mad easy.
*/


@interface OSCInPortRetainsRaw : OSCInPort {
	NSMutableArray		*packetStringArray;	//	array of dicts with strings that describe the received packets
}

- (NSMutableArray *) packetStringArray;
- (void) setPacketStringArray:(NSArray *)a;

@end

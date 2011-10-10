//
//  ElementBox.h
//  VVOpenSource
//
//  Created by bagheera on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVOSC/VVOSC.h>




@interface ElementBox : NSBox <OSCNodeDelegateProtocol,OSCNodeQueryDelegateProtocol> {
	BOOL		deleted;
	id			myUIItem;	//	the actual UI item (button/slider/etc)
	OSCNode		*myNode;	//	the OSCNode this UI item represents.  this is NOT RETAINED LOCALLY- the OSCAddressSpace creates it, and i'm this node's delegate so i get notified if something else deletes it (by setting its address to nil in the address space).
}

- (id) initWithFrame:(NSRect)f;
- (void) prepareToBeDeleted;

- (void) setType:(OSCValueType)n andName:(NSString *)a;

- (IBAction) sliderUsed:(id)sender;
- (IBAction) textUsed:(id)sender;
- (IBAction) buttonUsed:(id)sender;

@end

//
//  ElementBox.h
//  VVOpenSource
//
//  Created by bagheera on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVOSC/VVOSC.h>




/*
	this subclass of NSBox can be configured to display a toggle (boolean), a slider (float), or a text field (string).  when you set its type and name, it automatically creates the appropriate UI item.
	
	more importantly, it also creates an instance of OSCNode and adds it to the OSC address space.  this instance isn't retained locally (it's a weak ref), but this is a simple example and we know it won't get deleted out from under us so there's no need to retain it or use a zeroing weak ref.
	
	when the UI item is used, an OSCMessage is created and dispatched to the OSC node.
*/




@interface ElementBox : NSBox <OSCNodeDelegateProtocol,OSCNodeQueryDelegate> {
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

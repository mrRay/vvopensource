//
//  ManualOSCSender.h
//  VVOpenSource
//
//  Created by bagheera on 9/28/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVOSC/VVOSC.h>




@interface ManualOSCSender : NSObject {
	IBOutlet NSTextField		*oscAddressField;
	
	IBOutlet OSCManager			*oscManager;
}

- (IBAction) listNodesClicked:(id)sender;
- (IBAction) documentationClicked:(id)sender;
- (IBAction) acceptedTypesClicked:(id)sender;
- (IBAction) currentValClicked:(id)sender;

@end

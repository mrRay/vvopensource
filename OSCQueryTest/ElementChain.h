//
//  ElementChain.h
//  VVOpenSource
//
//  Created by bagheera on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVOSC/VVOSC.h>
#import "ElementBox.h"




/*
		this class is a view that contains an array of ElementBox instances.  as these elements are 
		added and removed, they're also added and removed to me as subviews, and this instance of 
		ElementChain will resize itself and arrange the subviews veritcally (like a filter chain).
*/




@interface ElementChain : NSView {
	MutLockArray		*elementArray;
}

- (void) _generalInit;

- (void) clearAllElements;
- (void) addElement:(ElementBox *)n;

- (void) _resizeSelf;
- (void) _resizeElementItems;

- (int) count;

@end

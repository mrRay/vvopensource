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

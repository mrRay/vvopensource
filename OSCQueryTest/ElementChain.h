//
//  ElementChain.h
//  VVOpenSource
//
//  Created by bagheera on 9/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>




@interface ElementChain : NSView {
	MutLockArray		*elementArray;
}

- (void) _generalInit;

@end

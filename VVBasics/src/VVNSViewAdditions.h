//
//  VVNSViewAdditions.h
//  VVOpenSource
//
//  Created by bagheera on 8/1/13.
//
//

#import <Cocoa/Cocoa.h>




@interface NSView (VVNSViewAdditions)

- (NSPoint) winCoordsOfLocalPoint:(NSPoint)n;
- (NSPoint) displayCoordsOfLocalPoint:(NSPoint)n;

@end

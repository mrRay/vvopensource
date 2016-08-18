//
//  NSPopUpButtonAdditions.h
//  ISF Syphon Filter Tester
//
//  Created by bagheera on 1/13/14.
//  Copyright (c) 2014 zoidberg. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSPopUpButton (NSPopUpButtonAdditions)

- (NSMenuItem *) addAndReturnItemWithTitle:(NSString *)t;

@end

//
//  MutNRLockDict.h
//  VVOpenSource
//
//  Created by David Lublin on 12/22/09.
//  Copyright 2009 Vidvox. All rights reserved.
//

#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif

#import "MutLockDict.h"
#import "ObjectHolder.h"



///	Subclass of MutLockDict; this class does NOT retain the objects in its array!
/*
this class exists because i frequently find myself in situations where i want to add an instance of an object to an array/dict/[any class which retains the passed instance], but i don't actually want the item to be retained.

Instead of adding (and therefore retaining) objects to an array like my superclass, this class makes an ObjectHolder for objects which are added to it (so they don't get retained), and adds the ObjectHolder to me.  when other classes ask me for the index of an object, or ask for the object at a particular index, i'll find the relevant ObjectHolder and then return the object it's storing.
*/


@interface MutNRLockDict : MutLockDict {

}


- (void) setObject:(id)o forKey:(NSString *)s;
- (void) setValue:(id)v forKey:(NSString *)s;
- (id) objectForKey:(NSString *)k;
- (void) addEntriesFromDictionary:(id)otherDictionary;
- (NSArray *) allValues;

@end

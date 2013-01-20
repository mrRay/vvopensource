//
//  AppDelegate.h
//  VVViewTestApp
//
//  Created by bagheera on 11/11/12.
//
//

#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import "RedView.h"
#import "BlueView.h"
#import "GreenView.h"
#import "TestGLView.h"




@interface AppDelegate : NSObject <NSApplicationDelegate>	{
	IBOutlet TestGLView		*spriteView;
	
	RedView						*redView;
	BlueView					*blueView;
	GreenView					*greenView;
}

@end

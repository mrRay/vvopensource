//
//  TestGLView.h
//  VVOpenSource
//
//  Created by bagheera on 11/12/12.
//
//

#import <Foundation/Foundation.h>
#import <VVBasics/VVBasics.h>




@interface TestGLView : VVSpriteGLView	{

}

+ (NSOpenGLPixelFormat *) defaultPixelFormat;
+ (GLuint) glDisplayMaskForAllScreens;

@end

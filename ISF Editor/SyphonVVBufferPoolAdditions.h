//
//  SyphonVVBufferPoolAdditions.h
//  ISF Syphon Filter Tester
//
//  Created by bagheera on 11/25/13.
//  Copyright (c) 2013 zoidberg. All rights reserved.
//

#import <Cocoa/Cocoa.h>
//#import <VVGLKit/VVGLKit.h>
#import <VVBufferPool/VVBufferPool.h>
#import <VVISFKit/VVISFKit.h>
#import <Syphon/Syphon.h>




//	i'm defining this arbitrary constant as the value "100".  the VVBufferBackID type declared in the VVBufferPool framework is a convenience variable- it doesn't affect the functionality of the backend at all, and exists to make it easier to quickly create ad-hoc bridges between this framework and other graphic APIs.
#define VVBufferBackID_Syphon 100




@interface VVBufferPool (VVBufferPoolAdditions)


- (VVBuffer *) allocBufferForSyphonClient:(SyphonClient *)c;


@end












@interface VVBuffer (VVBufferAdditions)


- (SyphonImage *) syphonImage;
//- (void) setSyphonImage:(SyphonImage *)n;


@end


void VVBuffer_ReleaseSyphonImage(id b, void *c);


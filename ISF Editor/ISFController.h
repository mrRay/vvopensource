//
//  ISFController.h
//  ISF Syphon Filter Tester
//
//  Created by bagheera on 11/2/13.
//  Copyright (c) 2013 zoidberg. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVBufferPool/VVBufferPool.h>
#import <VVISFKit/VVISFKit.h>
#import "ISFUIItem.h"




@interface ISFController : NSObject	{
	IBOutlet id				appDelegate;
	IBOutlet NSScrollView	*uiScrollView;
	
	IBOutlet NSTextField	*widthField;
	IBOutlet NSTextField	*heightField;
	NSSize					renderSize;
	
	ISFGLScene		*scene;
	BOOL			sceneIsFilter;
	
	NSString				*targetFile;
	
	MutLockArray			*itemArray;
}

- (void) setSharedGLContext:(NSOpenGLContext *)n;

- (IBAction) widthFieldUsed:(id)sender;
- (IBAction) heightFieldUsed:(id)sender;
- (IBAction) doubleResClicked:(id)sender;
- (IBAction) halveResClicked:(id)sender;
- (void) _pushUIToRenderingResolution;
- (void) _pushRenderingResolutionToUI;
@property (assign,readwrite) NSSize renderSize;

- (void) loadFile:(NSString *)f;
- (VVBuffer *) renderFXOnThisBuffer:(VVBuffer *)n passDict:(NSMutableDictionary *)d;
//	only used to render for recording!
- (void) renderIntoBuffer:(VVBuffer *)b atTime:(double)t;

- (void) populateUI;

- (void) passNormalizedMouseClickToPoints:(NSPoint)p;

- (ISFGLScene *) scene;
- (NSString *) targetFile;
- (void) reloadTargetFile;

@end

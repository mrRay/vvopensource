//
//  ISFEditorAppDelegate.h
//  ISF Syphon Filter Tester
//
//  Created by bagheera on 11/2/13.
//  Copyright (c) 2013 zoidberg. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>
#import <VVISFKit/VVISFKit.h>
#import <DDMathParser/DDMathParser.h>
#import "ISFController.h"
#import "VVKQueueCenter.h"
//#import "RecOptsController.h"
#import "DynamicVideoSource.h"
#import <VideoToolbox/VideoToolbox.h>
//#import <VideoToolbox/VTProfessionalVideoWorkflow.h>
#import "DocController.h"
#import "ISFConverter.h"
#import "ISFPDownloader.h"
#import <Syphon/Syphon.h>
#import "MouseView.h"




@interface ISFEditorAppDelegate : NSObject <NSApplicationDelegate,DynamicVideoSourceDelegate>	{
	IBOutlet NSWindow			*mainWindow;
	
	NSOpenGLContext				*sharedContext;
	
	SyphonServer				*syphonServer;
	NSOpenGLContext				*syphonServerContext;
	
	CVDisplayLinkRef			displayLink;
	VVBuffer					*lastSourceBuffer;
	int							outputSource;	//	-1 if the post-ISF-filter output.  if between 0 and 99, it's the index of the rendering pass to display.  if it's between 100 and 199, it's the index of the image input to display (minus 100).  if it's between 200 and 299, it's the index of the audio input to display (minus 200)
	BOOL						outputFreeze;
	NSMutableDictionary			*outputDict;
	IBOutlet NSPopUpButton		*outputSourcePUB;
	IBOutlet NSButton			*outputFreezeToggle;
	IBOutlet MouseView			*outputView;
	IBOutlet NSTextField		*outputResLabel;
	
	IBOutlet NSPopUpButton		*videoSourcePUB;
	DynamicVideoSource			*videoSource;
	
	MutLockArray				*filterList;
	IBOutlet NSTableView		*filterTV;
	
	//IBOutlet NSButton			*textureToggle;
	IBOutlet NSMatrix			*textureMatrix;
	
	IBOutlet ISFController		*isfController;
	BOOL						fetchShaders;
	BOOL						respondToTableSelectionChanges;
	BOOL						respondToFileChanges;
	
	IBOutlet DocController		*docController;
	IBOutlet ISFConverter		*isfConverter;
	IBOutlet ISFPDownloader		*downloader;
}

- (IBAction) importFromISFSite:(id)sender;
- (IBAction) importFromGLSLSandbox:(id)sender;
- (IBAction) importFromShadertoy:(id)sender;

- (IBAction) openSystemISFFolderClicked:(id)sender;
- (IBAction) loadUserISFsClicked:(id)sender;
- (IBAction) loadSystemISFsClicked:(id)sender;

- (IBAction) outputSourcePUBUsed:(id)sender;
- (IBAction) outputFreezeToggleUsed:(id)sender;
- (IBAction) outputShowAlphaToggleUsed:(id)sender;
- (IBAction) videoSourcePUBUsed:(id)sender;

- (IBAction) installISFMediaFilesUsed:(id)sender;
- (IBAction) installISFQuickLookUsed:(id)sender;

- (void) reloadFileFromTableView;

//	called by the isf converter- when it's done converting a file, it wants to display the converted shader
- (void) exportCompleteSelectFileAtPath:(NSString *)p;

- (void) _isfFileReloaded;
- (void) _loadFilterList;

- (void) _renderCallback;

- (void) renderIntoBuffer:(VVBuffer *)b atTime:(double)t;	//	used to render for recording
- (void) reloadSelectedISF;
- (NSString *) targetFile;

@property (assign,readwrite) BOOL fetchShaders;
@property (assign,readwrite) BOOL respondToTableSelectionChanges;
@property (assign,readwrite) BOOL respondToFileChanges;
- (NSMutableArray *) createSyntaxErrorsForForbiddenTermsInRawISFFile;

@end




CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);

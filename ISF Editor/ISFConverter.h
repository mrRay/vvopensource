#import <Foundation/Foundation.h>
#import <VVBasics/VVBasics.h>
#import <VVBufferPool/VVBufferPool.h>
#import "RegexKitLite.h"
//#import <JSONKit/JSONKit.h>




@interface ISFConverter : NSObject	{
	IBOutlet id					appDelegate;
	IBOutlet NSWindow			*mainWindow;
	
	IBOutlet NSWindow			*glslWindow;
	IBOutlet NSTextField		*glslURLField;
	
	IBOutlet NSWindow			*shadertoyWindow;
	IBOutlet NSTextField		*shadertoyURLField;
}

- (void) openGLSLSheet;
- (void) closeGLSLSheet;
- (void) openShadertoySheet;
- (void) closeShadertoySheet;

- (IBAction) glslCancelClicked:(id)sender;
- (IBAction) glslOKClicked:(id)sender;
- (IBAction) glslTextFieldUsed:(id)sender;

- (IBAction) shadertoyCancelClicked:(id)sender;
- (IBAction) shadertoyOKClicked:(id)sender;
- (IBAction) shadertoyTextFieldUsed:(id)sender;

- (NSString *) _convertGLSLSandboxString:(NSString *)rawFragString supplementalJSONDictEntries:(NSDictionary *)suppEntries;
- (NSString *) _converShaderToySourceArray:(NSArray *)rawFragStrings supplementalJSONDictEntries:(NSMutableDictionary *)suppEntries varSwapNameDicts:(NSArray *)varSwapNameDicts;

@end

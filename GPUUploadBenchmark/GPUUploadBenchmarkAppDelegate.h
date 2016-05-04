#import <Cocoa/Cocoa.h>
#import <VVBufferPool/VVBufferPool.h>
#import <DDMathParser/DDMathParser.h>




typedef enum	{
	UploadMethod_PBO = 0,
	UploadMethod_TexRange = 1
} UploadMethod;

typedef enum	{
	UploadTexTarget_Rect = 0,
	UploadTexTarget_2D = 1,
	UploadTexTarget_NPOT2D = 2
} UploadTexTarget;

typedef enum	{
	UploadPixelFormat_RGBA = 0,
	UploadPixelFormat_BGRA = 1
} UploadPixelFormat;

typedef enum	{
	UploadInternalFormat_RGBA = 0,
	UploadInternalFormat_RGBA8 = 1
} UploadInternalFormat;

typedef enum	{
	UploadPixelType_UB = 0,
	UploadPixelType_8888_REV = 1,
	UploadPixelType_8888 = 2
} UploadPixelType;




@interface GPUUploadBenchmarkAppDelegate : NSObject <NSApplicationDelegate>	{
	NSOpenGLContext			*sharedContext;
	
	IBOutlet NSTextField	*widthField;
	IBOutlet NSTextField	*heightField;
	
	IBOutlet NSMatrix		*pboVsRangeMatrix;
	IBOutlet NSMatrix		*targetMatrix;
	IBOutlet NSMatrix		*pixelFormatMatrix;
	IBOutlet NSMatrix		*internalFormatMatrix;
	IBOutlet NSMatrix		*pixelTypeMatrix;
	
	IBOutlet NSTextField	*resultsLabel;
	
	
	IBOutlet VVBufferGLView	*checkGLView;
	IBOutlet NSImageView	*checkImgView;
	
	
	BOOL					testInProgress;
	NSUInteger				testCount;
	VVStopwatch				*testSwatch;
	NSSize					testRes;
	UploadMethod			testMethod;
	UploadTexTarget			testTexTarget;
	UploadPixelFormat		testColorFormat;
	UploadInternalFormat	testInternalFormat;
	UploadPixelType			testPixelType;
	VVBuffer				*testSrcBuffer;	//	CPU-based, created when you start a test or check.  this is copied into a buffer of the appropriate target/format, which is then uploaded.
	
	PBOCPUGLStreamer		*pboStreamer;
	TexRangeCPUGLStreamer	*trStreamer;
}

- (IBAction) startTestClicked:(id)sender;
- (IBAction) checkClicked:(id)sender;

- (void) workMethod;

- (void) _populateTestSrcBuffer;
- (VVBuffer *) _allocBufferToUpload;

@end


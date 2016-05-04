#import <Cocoa/Cocoa.h>
#import <VVBufferPool/VVBufferPool.h>
#import <DDMathParser/DDMathParser.h>
#import <VVISFKit/VVISFKit.h>



typedef enum	{
	DownloadMethod_PBO = 0,
	DownloadMethod_TexRange = 1
} DownloadMethod;

typedef enum	{
	DownloadTexTarget_Rect = 0,
	DownloadTexTarget_2D = 1,
	DownloadTexTarget_NPOT2D = 2
} DownloadTexTarget;

typedef enum	{
	DownloadPixelFormat_RGBA = 0,
	DownloadPixelFormat_BGRA = 1
} DownloadPixelFormat;

typedef enum	{
	DownloadInternalFormat_RGBA = 0,
	DownloadInternalFormat_RGBA8 = 1
} DownloadInternalFormat;

typedef enum	{
	DownloadPixelType_UB = 0,
	DownloadPixelType_8888_REV = 1,
	DownloadPixelType_8888 = 2
} DownloadPixelType;




@interface GPUDownloadBenchmarkAppDelegate : NSObject <NSApplicationDelegate>	{
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
	DownloadMethod			testMethod;
	DownloadTexTarget		testTexTarget;
	DownloadPixelFormat		testColorFormat;
	DownloadInternalFormat	testInternalFormat;
	DownloadPixelType		testPixelType;
	VVBuffer				*testSrcBuffer;	//	this is copied into a buffer of the appropriate target/format, which is then downloaded
	
	ISFGLScene				*srcImgScene;
	PBOGLCPUStreamer		*pboStreamer;
	TexRangeGLCPUStreamer	*trStreamer;
}

- (IBAction) startTestClicked:(id)sender;
- (IBAction) checkClicked:(id)sender;

- (void) workMethod;

- (VVBuffer *) _allocBufferToDownload;

@end


#import <UIKit/UIKit.h>
#import <VVBufferPool/VVBufferPool.h>
#import <VVISFKit/VVISFKit.h>




@interface ViewController : UIViewController	{
	
	ISFGLScene			*isfScene;
	
	double				tmpVal;
	IBOutlet VVBufferGLKView	*bufferView;
}


@end


#import <Foundation/Foundation.h>




typedef enum _VVOSVersion	{
	VVOSVersionError=0,
	//VVJaguar = 0x1020,
	//VVPanther = 0x1030,
	VVTiger = 4,
	VVLeopard = 5,
	VVSnowLeopard = 6,
	VVLion = 7,
	VVMountainLion = 8,
	VVMavericks = 9
} VVOSVersion;


extern OSSpinLock		_majorSysVersionLock;
extern VVOSVersion		_majorSysVersion;




@interface VVSysVersion : NSObject	{

}

+ (NSString *) _strControlEntry:(NSString *)ctlKey;
+ (VVOSVersion) majorSysVersion;

@end

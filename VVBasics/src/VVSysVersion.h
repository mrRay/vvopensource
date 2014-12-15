#import <Foundation/Foundation.h>
#import <libkern/OSAtomic.h>




///	typdef describing the different versions of os x distinguished by this API
/**
\ingroup VVBasics
*/
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
typedef NS_ENUM(NSInteger, VVOSVersion)	{
	VVOSVersionError=0,
	//VVJaguar = 0x1020,
	//VVPanther = 0x1030,
	VVTiger = 4,	//!<	10.4
	VVLeopard = 5,	//!<	10.5
	VVSnowLeopard = 6,	//!<	10.6
	VVLion = 7,	//!<	10.7
	VVMountainLion = 8,	//!<	10.8
	VVMavericks = 9,	//!<	10.9
	VVYosemite = 10	//!<	10.10
};
#else
typedef enum VVOSVersion	{
	VVOSVersionError=0,
	//VVJaguar = 0x1020,
	//VVPanther = 0x1030,
	VVTiger = 4,	//!<	10.4
	VVLeopard = 5,	//!<	10.5
	VVSnowLeopard = 6,	//!<	10.6
	VVLion = 7,	//!<	10.7
	VVMountainLion = 8,	//!<	10.8
	VVMavericks = 9,	//!<	10.9
	VVYosemite = 10	//!<	10.10
} VVOSVersion;
#endif




extern OSSpinLock		_majorSysVersionLock;
extern VVOSVersion		_majorSysVersion;
extern int				_minorSysVersion;




///	class-based API for quickly determining which version of os x you're using at runtime
/**
\ingroup VVBasics
*/
@interface VVSysVersion : NSObject	{

}

+ (NSString *) _strControlEntry:(NSString *)ctlKey;
///	returns the major version of os x currently being run
/**
@param return the "major" version of os x only!
*/
+ (VVOSVersion) majorSysVersion;
///	returns the minor version of os x currently being run (the point-version)
+ (int) minorSysVersion;

@end

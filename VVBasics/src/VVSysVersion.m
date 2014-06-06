#import "VVSysVersion.h"
#include <sys/types.h>
#include <sys/sysctl.h>




/*
		this approach for determining which system we're running (an alternative to the now-deprecated Gestalt()) on was copied from a stack overflow post from the following URL:
		http://stackoverflow.com/questions/11055146/how-to-know-what-mac-os-the-app-is-running-on
*/
//static NSString* const kVarSysInfoVersionFormat	 = @"%@.%@.%@ (%@)";
static NSString* const kVarSysInfoKeyOSVersion = @"kern.osrelease";
//static NSString* const kVarSysInfoKeyOSBuild   = @"kern.osversion";

OSSpinLock		_majorSysVersionLock;
VVOSVersion		_majorSysVersion = VVOSVersionError;
int				_minorSysVersion = -1;



@implementation VVSysVersion


+ (void) initialize	{
	//NSLog(@"%s",__func__);
	if (_majorSysVersion == VVOSVersionError)	{
		_majorSysVersionLock = OS_SPINLOCK_INIT;
		[self majorSysVersion];
	}
}
+ (NSString *) _strControlEntry:(NSString *)ctlKey {
	//NSLog(@"%s ... %@",__func__,ctlKey);
	size_t			size = 0;
	if ( sysctlbyname([ctlKey UTF8String], NULL, &size, NULL, 0) == -1 )
		return nil;
	
	char			*machine = calloc( 1, size );
	
	sysctlbyname([ctlKey UTF8String], machine, &size, NULL, 0);
	NSString		*ctlValue = [NSString stringWithCString:machine encoding:[NSString defaultCStringEncoding]];
	
	free(machine);
	
	return ctlValue;
}
+ (VVOSVersion) majorSysVersion	{
	//NSLog(@"%s",__func__);
	VVOSVersion		returnMe = VVOSVersionError;
	//	try to get the major sys version, if it's a non-err val, i can return immediately
	OSSpinLockLock(&_majorSysVersionLock);
	returnMe = _majorSysVersion;
	OSSpinLockUnlock(&_majorSysVersionLock);
	if (returnMe != VVOSVersionError)
		return returnMe;
	
	NSString		*darwinVer = [self _strControlEntry:kVarSysInfoKeyOSVersion];
	if (darwinVer == nil)	{
		NSLog(@"\t\tERR: darwinVer nil, %s",__func__);
		return VVOSVersionError;
	}
	NSArray			*darwinChunks = [darwinVer componentsSeparatedByCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
	if (darwinChunks == nil)	{
		NSLog(@"\t\tERR: darwinChunks nil, %s",__func__);
		return VVOSVersionError;
	}
	
	OSSpinLockLock(&_majorSysVersionLock);
	_majorSysVersion = (unsigned int)([[darwinChunks objectAtIndex:0] integerValue] - 4);
	_minorSysVersion = [[darwinChunks objectAtIndex:1] integerValue];
	returnMe = _majorSysVersion;
	OSSpinLockUnlock(&_majorSysVersionLock);
	
	return returnMe;
}
+ (int) minorSysVersion	{
	int		returnMe = 0;
	
	OSSpinLockLock(&_majorSysVersionLock);
	returnMe = _minorSysVersion;
	OSSpinLockUnlock(&_majorSysVersionLock);
	if (_minorSysVersion < 0)	{
		
		[self majorSysVersion];
		
		OSSpinLockLock(&_majorSysVersionLock);
		returnMe = _minorSysVersion;
		OSSpinLockUnlock(&_majorSysVersionLock);
	}
	return returnMe;
}


@end

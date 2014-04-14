#import "VVSysVersion.h"
#include <sys/types.h>
#include <sys/sysctl.h>




static NSString* const kVarSysInfoVersionFormat	 = @"%@.%@.%@ (%@)";
static NSString* const kVarSysInfoKeyOSVersion = @"kern.osrelease";
static NSString* const kVarSysInfoKeyOSBuild   = @"kern.osversion";

OSSpinLock		_majorSysVersionLock;
VVOSVersion		_majorSysVersion = VVOSVersionError;




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
	returnMe = _majorSysVersion;
	OSSpinLockUnlock(&_majorSysVersionLock);
	
	return returnMe;
}


@end

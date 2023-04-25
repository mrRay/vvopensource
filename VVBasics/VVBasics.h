#import <TargetConditionals.h>
#import <VVBasics/VVBasicMacros.h>

#import <VVBasics/VVThreadLoop.h>
#import <VVBasics/VVAssertionHandler.h>
#import <VVBasics/VVStopwatch.h>
#import <VVBasics/VVMStopwatch.h>
#import <VVBasics/ObjectHolder.h>
#import <VVBasics/MutLockArray.h>
#import <VVBasics/MutLockDict.h>
#import <VVBasics/MutNRLockArray.h>
#import <VVBasics/MutNRLockDict.h>
#import <VVBasics/VVLogger.h>

#if !TARGET_OS_IPHONE
	#import <VVBasics/VVCURLDL.h>
	//#import "VVCrashReporter.h"
	//#import "NSHostAdditions.h"
	#import <VVBasics/VVSysVersion.h>
#endif

/*
	the following stuff is for doxygen
*/

/**
\defgroup VVBasics VVBasics framework
*/
/*!
\page VVBasics
\ingroup VVBasics

\htmlonly

<style type="text/css">
big	{
	font-size: 14pt;
	text-align: left;
}
p	{
	font-size:10pt;
}
li	{
	font-size: 10pt;
	text-indent: 25pt;
}
</style>

<big>Introduction</big>
<p>
VVBasics is an Objective-c framework with a number of classes which perform functions that i need regularly- but, for whatever reason, aren't provided by the stock frameworks.  Expect pretty much everything to link against this framework for one reason or another- macros, useful classes, etc- and expect this framework to continuously grow as I start to open-source more and more of my bag of tricks.
</p>

\endhtmlonly
*/

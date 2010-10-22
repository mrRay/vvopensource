
#import "VVBasicMacros.h"

#import "VVThreadLoop.h"
#import "VVStopwatch.h"
#import "ObjectHolder.h"
#import "MutLockArray.h"
#import "MutLockDict.h"
#import "MutNRLockArray.h"
#import "MutNRLockDict.h"
#import "NamedMutLockArray.h"

#if !IPHONE
	#import "VVCURLDL.h"
	#import "VVSprite.h"
	#import "VVSpriteManager.h"
	#import "VVSpriteView.h"
	#import "VVSpriteControl.h"
	#import "VVSpriteControlCell.h"
	#import "VVSpriteGLView.h"
	#import "VVCrashReporter.h"
#endif

/*
	the following stuff is for doxygen
*/

/*!
\mainpage

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

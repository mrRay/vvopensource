



#import "OSCValue.h"
#import "OSCMessage.h"
#import "OSCBundle.h"
#import "OSCPacket.h"

#import "OSCInPort.h"
#import "OSCOutPort.h"

#import "OSCManager.h"
#import "OSCZeroConfManager.h"

#import "OSCNode.h"
#import "OSCAddressSpace.h"

#import "OSCStringAdditions.h"




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
VVOSC is an Objective-c framework for assembling, sending, and receiving OSC (Open Sound Control) messages on OS X.  A simple sample application (gui) which sends and receives OSC messages is also included to aid in the debugging of your software.  There's also an SDK which allows you to develop iPhone applications which use VVOSC.
</p>


<big>Features and Capabilities</big>
<p>
<li>Includes a sample GUI app for debugging OSC applications and hardware</li>
<li>Packet parsing (client)</li>
<li>Packet construction (server)</li>
<li>Creates bundles</li>
<li>Supports nested bundles</li>
<li>Supports the following data types: i (int32), f (float32), s/S (OSC-string), r (32-bit RGBA color), T (true), F (false)</li>
</p>


<big>Installation</big>
<p>
<A HREF="installation.html">How to Install and work with VVOSC</A>
</p>


<big>Sample code</big>

<div style="width: 100%; border: 1px #000 solid; background-color: #F0F0F0; padding: 5px; margin: 5px; color: black; font-family: Courier; font-size: 10pt; font-style: normal;">
//    create an OSCManager- set myself up as its delegate<BR>
manager = [[OSCManager alloc] init];<BR>
[manager setDelegate:self];<BR>
<BR>
//    create an input port for receiving OSC data<BR>
[manager createNewInputForPort:1234];<BR>
<BR>
//    create an output so i can send OSC data to myself<BR>
outPort = [manager createNewOutputToAddress:@"127.0.0.1" atPort:1234];<BR>
<BR>
//    make an OSC message<BR>
newMsg = [OSCMessage createWithAddress:@"/Address/Path/1"];<BR>
<BR>
//    add a bunch arguments to the message<BR>
[newMsg addInt:12];<BR>
[newMsg addFloat:12.34];<BR>
[newMsg addColor:[NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:1.0]];<BR>
[newMsg addBOOL:YES];<BR>
[newMsg addString:@"Hello World!"];<BR>
<BR>
//    send the OSC message<BR>
[outPort sendThisMessage:newMsg];<BR>
</div>


<BR>
<big>To-Do List:</big>
<li>support timestamps</li>
<li>support wildcards (better use of address paths)</li>
<li>add support for the following data types: b,h,t,d,c,m,N,I</li>
<li>make it run faster (>100hz)</li>


\endhtmlonly
*/






/*!
\page Installation Installing and Integrating VVOSC with your project

\section INSTALL-APP If you just want the OSC test app:
-# open the VVOSC project in xcode
-# make "VVOSCTester" your active target, make sure the build mode is set to "Release"
-# build the project, the test app should be in "./build/Release".

\section INSTALL-DEV If you want to use VVOSC to develop software...
you're either going to be working with the framework or the SDK (you don't need both).  if you're only making mac applications, you only need the framework.  if you're going to be making iphone apps, you'll need the SDK.

\section BUILD-FRAMEWORK Building the VVOSC framework (for OS X apps)
-# open the VVOSC project in xcode.  make "VVOSC Framework" your active target, make sure the build mode is set to "Release".
-# build the project.  "VVOSC.framework" should now exist in "./build/Release/".

\section USE-FRAMEWORK Using the VVOSC framework
-# open your project file in xcode, drag the compiled "VVOSC.framework" into it.
-# from xcode's project menu, add a new "copy files" build phase to your target.
-# expand your target, drag "VVOSC.framework" (from your xcode project) into the copy files build phase you just created.
-# double-click on the copy files build phase you made.  under the "general" tab, select "Frameworks" from the destination pop-up button (you're trying to make sure "VVOSC.framework" gets copied into your application package's "Frameworks" folder).
-# use the framework in your source code with "#import <VVOSC/VVOSC.h>

\section BUILD-SDK Building the VVOSC SDK (for iPhones)
-# if you haven't already, install Apple's iPhone SDK.  if you don't, this target won't compile!
-# open the VVOSC project in xcode.  select the "Compile VVOSC SDK" target, make sure the build mode is set to "Release".
-# build the project.  the SDK has now been compiled, and is in your build directory.
-# select the "Install VVOSC SDK" target and build it; this just copies the compiled SDK to "~/Library/SDKs/VVOSC/".

\section USE-SDK Using the VVOSC SDK
-# open your project file in xcode.  double-click your application/target in the left-hand list of your project window (or select it and get its info).  click on the "build" tab.
-# find the "Additional SDKs" option, and add "$HOME/Library/SDKs/VVOSC/$(PLATFORM_NAME).sdk"
-# find the "Other Linker Flags" option, and add "-ObjC -lVVOSC".
-# use the SDK in your source code with "#import <VVOSC/VVOSC.h>"

*/
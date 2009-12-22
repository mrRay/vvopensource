

#import "OSCConstants.h"

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




///	Delegates of OSCManager and OSCInPort should support this protocol
/*!
When instances of OSCInPort and OSCManager receive OSC data, they pass it to their delegate with this method.  If you want to receive OSC data, your OSCManager's delegate must respond to this method!
*/
@protocol OSCDelegateProtocol
///	This method is called whenever your in port/manager receives an OSCMessage.
- (void) receivedOSCMessage:(OSCMessage *)m;
@end




//	OSCManager delegate protocol
@protocol OSCManagerDelegate
- (void) setupChanged;
- (NSString *) inPortLabelBase;
@end




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

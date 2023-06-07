

#import <VVOSC/OSCConstants.h>

#import <VVOSC/OSCValue.h>
#import <VVOSC/OSCMessage.h>
#import <VVOSC/OSCBundle.h>
#import <VVOSC/OSCPacket.h>

#import <VVOSC/OSCOutPort.h>
#import <VVOSC/OSCInPort.h>

#import <VVOSC/OSCManager.h>
#import <VVOSC/OSCZeroConfManager.h>

#import <VVOSC/OSCNode.h>
#import <VVOSC/OSCAddressSpace.h>

#import <VVOSC/OSCStringAdditions.h>




/*
	the following stuff is for doxygen
*/


/**
\defgroup VVOSC VVOSC framework
*/
/*!
\page VVOSC
\ingroup VVOSC
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
VVOSC is an Objective-c framework for assembling, sending, and receiving OSC (Open Sound Control) messages on OS X.  A simple sample application (gui) which sends and receives OSC messages is also included to aid in the debugging of your software.  There's also an SDK which allows you to develop iPhone applications which use VVOSC.  All the source code is available on the project homepage: <A HREF="https://github.com/mrRay/vvopensource">https://github.com/mrRay/vvopensource</A>
</p>


<big>Features and Capabilities</big>
<p>
<li>Includes a sample GUI app for debugging OSC applications and hardware that also demonstrates use of the framework</li>
<li>Packet parsing (client) + construction (server)</li>
<li>Creates bundles/nested bundles, safely parse bundles/nested bundles</li>
<li>Detects other OSC destinations via bonjour/zero-conf networking and automatically creates output ports so you can send data to them.</li>
<li>Input ports automagically advertise their presence via bonjour/zero-conf networking.  This is as close to no-setup as it gets!</li>
<li>Supports the following data types: i (int32), f (float32), s/S (OSC-string), b (OSC blob), h (64-bit int), d (64-bit float/double), r (32-bit RGBA color), m (MIDI message), T (tru), F (false), N(nil), I (infinity), t (OSC-timetag)</li>
<li>Processing frequency defaults to 100hz, but may be adjusted dynamically and has been tested up to 1khz</li>
<li>Multithreaded- each input port runs on its own thread- and threadsafe.</li>
<li>Optional OSC address space classes (OSCNode & OSCAddressSpace) may be used to quickly and easily construct a threadsafe address space for controlling your software.  Address space includes POSIX regex-based pattern matching for dispatching a single message to multiple addresses.</li>
<li>Built on a handful of small, easy-to-grok classes written specifically for OS X.  Very easy to understand, modify, subclass, or extend.</li>
<li>Project includes targets that build and install an SDK for using VVOSC in iOS apps</li>
</p>

<big>Breaks from the OSC specification</big>
</p>
<li>"char" data type not supported yet, you can use "string" in the meantime.</li>
<li>It's possible to create an OSCValue from an NSString containing UTF8 characters, which VVOSC will try to send- and if the software receiving this data doesn't freak out, this allows you to UTF8 characters.  In other words, VVOSC doesn't explicitly prevent the use of non-ASCII characters, so it's possible to use it to create incompatible OSC data!</li>
<li>The OSC specification describes a limited subset of regex to be used in wildcard/pattern matching for OSC dispatch.  VVOSC's message dispatch is presently a POSIX regex engine simply because it was faster and easier to get going (it's built into the OS) than rolling my own.  The specific engine used may change if message dispatch becomes a speed issue in the future; presumably, this ambiguity is why the OSC spec describes a specific and limited subset of regex!</li>
<li>The OSC spec describes the optional type characters [ and ] to delineate arrays and basic node-based structures for ad-hoc data types.  Support for arrays has been added, but lacking any published examples of dictionaries, this isn't supported yet- if someone wants to send me a specific example i can use to support this protocol properly, please let me know!</li>
<li>While VVOSC parses, stores, and allows you to set OSC time tags (and even create and pass time tags as values), it doesn't perform any delay or scheduling if it receives an OSC bundle with a time tag which is later than the current time.  Parsed time tags are available to your applications as the 'timeTag' variable of a passed OSCMessage, which is stored as an NSDate (which, internally, is a double which basically represents 64-bit NTP time, as I understand it).</li>
</p>


<big>Sample code- Getting Started</big>

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
<big>Sample code- the OSC Address Space (optional)</big>
<div style="width: 100%; border: 1px #000 solid; background-color: #F0F0F0; padding: 5px; margin: 5px; color: black; font-family: Courier; font-size: 10pt; font-style: normal;">
//	get the OSC address space<BR>
OSCAddressSpace		*as = [OSCAddressSpace mainAddressSpace];<BR>
<BR>
//	find/create a node in the address space<BR>
OSCNode				*myNode = [as findNodeForAddress:@"/A/B/C" createIfMissing:YES];<BR>
<BR>
//	add myself to the node's delegates so i get informed of data passed to the node<BR>
[myNode setDelegate:self];<BR>
<BR>
- (void) node:(id)n receivedOSCMessage:(OSCMessage *)msg	{<BR>
	&nbsp;&nbsp;&nbsp;&nbsp;//	this method is called whenever the node receives OSC data because I'm one of the node's delegates<BR>
}<BR>
<BR>
//	dispatch an OSC message received from an OSCInPort to the address space<BR>
[as dispatchMessage:receivedMessage];<BR>
</div>


\endhtmlonly
*/

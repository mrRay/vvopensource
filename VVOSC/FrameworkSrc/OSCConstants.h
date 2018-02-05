
/*!
\file OSCConstants.h
\brief Constants and Macros used by one or more of the OSC classes in this framework
*/




///	Most common means of passing OSC data to your application.  Delegates of OSCManager and OSCInPort should support this protocol.
/*!
When instances of OSCInPort and OSCManager receive OSC data, they pass it to their delegate by calling this method.  If you want to receive OSC data, your OSCManager's delegate must respond to this method!
*/
@class OSCMessage;
@protocol OSCDelegateProtocol
///	This method is called whenever your in port/manager receives an OSCMessage.
- (void) receivedOSCMessage:(OSCMessage *)m;
@end




///	OSCValueType
/*!
\ingroup VVOSC
OSCValues have distinct types; these are used to describe the type of an OSCValue.
*/
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
typedef NS_ENUM(NSInteger, OSCValueType)	{
#else
typedef enum OSCValueType	{
#endif
	OSCValUnknown = 0,
	OSCValInt = 1,	//!<Integer -2147483648 to 2147483647
	OSCValFloat = 2,	//!<Float
	OSCValString = 3,	//!<String
	OSCValTimeTag = 4,	//!<TimeTag
	OSCVal64Int = 5,	//!<64-bit integer -9223372036854775808 to 9223372036854775807
	OSCValDouble = 6,	//!<64-bit float (double)
	OSCValChar = 7,	//!<Char
	OSCValColor = 8,	//!<Color
	OSCValMIDI = 9,	//!<MIDI
	OSCValBool = 10,	//!<BOOL
	OSCValNil = 11,	//!<nil/NULL
	OSCValInfinity = 12,	//!<Infinity
	OSCValArray = 13,	//!<Array- contains other OSCValues
	OSCValBlob = 14,	//!<Blob- random binary data
	OSCValSMPTE = 15	//!<SMPTE time- AD-HOC DATA TYPE! ONLY SUPPORTED BY THIS FRAMEWORK! 32-bit value max time is "7:23:59:59.255". first 4 bits define FPS (OSCSMPTEFPS). next 3 bits define days. next 5 bits define hours. next 6 bits define minutes. next 6 bits define seconds. last 8 bits define frame.
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
};
#else
} OSCValueType;
#endif


///	OSCSMPTEFPS
/*!
\ingroup VVOSC
OSCValues of type OSCValSMPTE have 4 bits used to describe the timecode fps.  This enum lists the various timecode framerates.  Note that OSC describes values- this is timecode, and framerates of 29.97 etc. are typically achieved in a number of means completely independent of the timecode, which is just a means of referring to frames.
*/
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
typedef NS_ENUM(NSInteger, OSCSMPTEFPS)	{
#else
typedef enum OSCSMPTEFPS	{
#endif
	OSCSMPTEFPSUnknown = 0,
	OSCSMPTEFPS24 = 1,	//!<24fps
	OSCSMPTEFPS25 = 2,	//!<25fps
	OSCSMPTEFPS30 = 3,	//!<30fps
	OSCSMPTEFPS48 = 4,	//!<48fps
	OSCSMPTEFPS50 = 5,	//!<50fps
	OSCSMPTEFPS60 = 6,	//!<60fps
	OSCSMPTEFPS120 = 7	//!<120fps
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
};
#else
} OSCSMPTEFPS;
#endif


///	OSCMIDIType
/*!
\ingroup VVOSC
The OSC spec has a data type for MIDI messages- these describe the various different "midiStatus" types if an OSCValue instance is a MIDI-type value.  Refer to the documentation for the VVMIDI framework (especially VVMIDI.h) for a more in-depth description of how MIDI works.
*/
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
typedef NS_ENUM(NSInteger, OSCMIDIType)	{
#else
typedef enum OSCMIDIType	{
#endif
	OSCMIDINoteOffVal = 0x80,	//!<Note off
	OSCMIDINoteOnVal = 0x90,	//!<Note on
	OSCMIDIAfterTouchVal = 0xA0,	//!<After-touch
	OSCMIDIControlChangeVal = 0xB0,	//!<Control Change
	OSCMIDIProgramChangeVal = 0xC0,	//!<Pgm Change
	OSCMIDIChannelPressureVal = 0xD0,	//!<Pressure Val
	OSCMIDIPitchWheelVal = 0xE0,	//!<Pitch Wheel Val
	OSCMIDIBeginSysexDumpVal = 0xF0,	//!<Sysex begin
	OSCMIDIMTCQuarterFrameVal = 0xF1,	//!<Quarter-frame
	OSCMIDISongPosPointerVal = 0xF2,	//!<Song Pos. Pointer
	OSCMIDISongSelectVal = 0xF3,	//!<Song select val
	OSCMIDIUndefinedCommon1Val = 0xF4,	//!<Undefined Common1
	OSCMIDIUndefinedCommon2Val = 0xF5,	//!<Undefined Common2
	OSCMIDITuneRequestVal = 0xF6,	//!<Tune Request
	OSCMIDIEndSysexDumpVal = 0xF7,	//!<Sysex End
	OSCMIDIClockVal = 0xF8,	//!<MIDI Clock val
	OSCMIDITickVal = 0xF9,	//!<MIDI Tick val
	OSCMIDIStartVal = 0xFA,	//!<Start
	OSCMIDIContinueVal = 0xFB,	//!<Continue
	OSCMIDIStopVal = 0xFC,	//!<Stop
	OSCMIDIUndefinedRealtime1Val = 0xFD,	//!<Undefined realtime
	OSCMIDIActiveSenseVal = 0xFE,	//!<Active Sense
	OSCMIDIResetVal = 0xFF	//!<Reset
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
};
#else
} OSCMIDIType;
#endif


///	OSCNodeType
/*!
\ingroup VVOSC
The OSC spec describes an address space capable of pattern matching and message dispatch.  Building this sort of model is easier in many practical regards if the various endpoints in the address space may be given a dedicated type- this allows a degree of filtering, sorting, and automatic behavior.  OSCNodeType enumerates the different kinds of OSCNode instances.
*/
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
typedef NS_ENUM(NSInteger, OSCNodeType)	{
#else
typedef enum OSCNodeType	{
#endif
	OSCNodeTypeUnknown,	//!<Unknown
	OSCNodeDirectory,	//!<Directory- this OSCNode probably has sub-nodes
	OSCNodeTypeNumber,	//!<The node describes a number
	OSCNodeType2DPoint,	//!<The node describes a 2D point
	OSCNodeTypeColor,
	OSCNodeTypeString,
	OSCNodeTypeData,
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
};
#else
} OSCNodeType;
#endif



#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
typedef NS_ENUM(NSInteger, OSCNodeAccess)	{
#else
typedef enum OSCNodeAccess	{
#endif
	OSCNodeAccess_None = 0,
	OSCNodeAccess_Read = 1,
	OSCNodeAccess_Write = 2,
	OSCNodeAccess_RW = 3
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
};
#else
} OSCNodeAccess;
#endif


//	this macro just rounds a number up to the nearest multiple of 4
#define ROUNDUP4(A) ((((A)%4)!=0) ? (4-((A)%4)+(A)) : (A))


//	this is the name of the notification that gets posted whenever the address space is told to refresh its menu
#define OSCAddressSpaceUpdateMenus @"OSCAddressSpaceUpdateMenus"

///	This notification gets fired whenever the input ports in an OSC manager are about to be changed
#define OSCInPortsAboutToChangeNotification @"OSCInPortsAboutToChangeNotification"
///	This notification gets fired whenever the input ports in an OSC manager get changed
#define OSCInPortsChangedNotification @"OSCInPortsChangedNotification"
///	This notification gets fired whenever the output ports in an OSC manager are about to be changed
#define OSCOutPortsAboutToChangeNotification @"OSCOutPortsAboutToChangeNotification"
///	This notification gets fired whenever the output ports in an OSC manager get changed
#define OSCOutPortsChangedNotification @"OSCOutPortsChangedNotification"








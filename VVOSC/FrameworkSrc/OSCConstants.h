
/*!
\file OSCConstants.h
\brief Constants and Macros used by one or more of the OSC classes in this framework
*/

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
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
};
#else
} OSCNodeType;
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




///	OSCMessageType
/*!
\ingroup VVOSC
	Nearly all OSC messages you'll encounter are "control" messages- they're sending zero or more values to an OSC address.  Other OSC message types exist to support the experimental query protocol.
*/
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
typedef NS_ENUM(NSInteger, OSCMessageType)	{
#else
typedef enum OSCMessageType	{
#endif
	OSCMessageTypeUnknown=0,	//!<if a message's type cannot be determined, this type is used.  rarely encountered, might mean parsing error or malformed packet.
	OSCMessageTypeControl,		//!<"normal" OSC message- an address, and zero or more values.  does NOT require a reply!  if software doesn't support the query protocol, it sends control messages.
	OSCMessageTypeQuery,		//!<standard query types are listed below (OSCQueryType)- they require a reply of some sort from the address space.  if a reply isn't forthcoming, a (programmatically-set) timeout error will be sent.
	OSCMessageTypeReply,		//!<a reply presumes that the query was executed successfully and an answer that is presumed to be useful is being returned
	OSCMessageTypeError,		//!<an error presumes that either the query was malformed or there was an error executing it
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
};
#else
} OSCMessageType;
#endif

///	OSCQueryType
/*!
\ingroup VVOSC
	These are the different kinds of queries in the experimental OSC query protocol
*/
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
typedef NS_ENUM(NSInteger, OSCQueryType)	{
#else
typedef enum OSCQueryType	{
#endif
	OSCQueryTypeUnknown=0,				//!<the query type couldn't be parsed or something went wrong
	OSCQueryTypeNamespaceExploration,	//!<return a list of any sub-nodes "inside" the destination address node as strings
	OSCQueryTypeDocumentation,			//!<return strings that provide documentation for the support and behavior of the destination address node
	OSCQueryTypeTypeSignature,			//!<return a single type-tag string describing the destination address node's expected INPUT value types.
	OSCQueryTypeCurrentValue,			//!<return the value of the node (type of the value returned can be obtained with a "return type signature" query)
	OSCQueryTypeReturnTypeSignature		//!<return a single type-tag string describing the destination address node's expected OUTPUT value types
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
};
#else
} OSCQueryType;
#endif

//	these strings are used in the spec and are defined here for convenience
#define kOSCQueryTypeReplyString @"#reply"
#define kOSCQueryTypeErrorString @"#error"
//#define kOSCQueryTypeNamespaceExplorationString @""
#define kOSCQueryTypeDocumentationString @"#documentation"
#define kOSCQueryTypeTypeSignatureString @"#type-signature"
#define kOSCQueryTypeCurrentValueString @"#current-value"
#define kOSCQueryTypeReturnTypeSignatureString @"#return-type-string"
/*
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
typedef NS_ENUM(NSInteger, OSCErrorType)	{
#else
typedef enum OSCErrorType	{
#endif
	OSCErrorTypeUnknown,
	OSCErrorTypeRelocated,
	OSCErrorTypeCorrupt,
	OSCErrorTypeMismatch,
	OSCErrorTypeInfeasible,
	OSCErrorTypeMissing,
	OSCErrorTypeFailed,
	OSCErrorTypeVolatile,		//	described in supplementary PDF, not sure what it means!
#if MACS_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_7
};
#else
} OSCErrorType;
#endif
*/





/*!
\file OSCConstants.h
\brief Constants and Macros used by one or more of the OSC classes in this framework
*/

///	OSCValueType
/*!
OSCValues have distinct types; these are used to describe the type of an OSCValue.
*/
typedef enum	{
	OSCValInt = 1,	//!<Integer, -2147483648 to 2147483647
	OSCValFloat = 2,	//!<Float
	OSCValString = 3,	//!<String
	OSCValTimeTag = 4,	//!<TimeTag
	OSCVal64Int = 5,	//!<64-bit integer, -9223372036854775808 to 9223372036854775807
	OSCValDouble = 6,	//!<64-bit float (double)
	OSCValChar = 7,	//!<Char
	OSCValColor = 8,	//!<Color
	OSCValMIDI = 9,	//!<MIDI
	OSCValBool = 10,	//!<BOOL
	OSCValNil = 11,	//!<nil/NULL
	OSCValInfinity = 12,	//!<Infinity
	OSCValBlob = 13	//!<Blob- random binary data
} OSCValueType;


///	OSCMIDIType
/*!
The OSC spec has a data type for MIDI messages- these describe the various different "midiStatus" types if an OSCValue instance is a MIDI-type value.  Refer to the documentation for the VVMIDI framework (especially VVMIDI.h) for a more in-depth description of how MIDI works.
*/
typedef enum	{
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
} OSCMIDIType;


///	OSCNodeType
/*!
The OSC spec describes an address space capable of pattern matching and message dispatch.  Building this sort of model is easier in many practical regards if the various endpoints in the address space may be given a dedicated type- this allows a degree of filtering, sorting, and automatic behavior.  OSCNodeType enumerates the different kinds of OSCNode instances.
*/
typedef enum	{
	OSCNodeTypeUnknown,
	OSCNodeDirectory,
	OSCNodeTypeFloat,
	OSCNodeType2DPoint,
	OSCNodeType3DPoint,
	OSCNodeTypeRect,
	OSCNodeTypeColor,
	OSCNodeTypeString,
} OSCNodeType;


//	this macro just rounds a number up to the nearest multiple of 4
#define ROUNDUP4(A) ((((A)%4)!=0) ? (4-((A)%4)+(A)) : (A))


//	this is the name of the notification that gets posted whenever the address space is told to refresh its menu
#define AddressSpaceUpdateMenus @"AddressSpaceUpdateMenus"

///	This notification gets fired whenever the input ports in an OSC manager get changed
#define OSCInPortsChangedNotification @"OSCInPortsChangedNotification"
///	This notification gets fired whenever the output ports in an OSC manager get changed
#define OSCOutPortsChangedNotification @"OSCOutPortsChangedNotification"




/*			these constants extist to provide support for an experimental protocol for OSC queries described here: http://opensoundcontrol.org/publication/query-system-open-sound-control			*/

//	there are several different kinds of OSC messages
typedef enum	{
	OSCMessageTypeUnknown=0,	//	if a message's type cannot be determined, this type is used.  rarely encountered.
	OSCMessageTypeControl,	//	"normal" OSC message- an address, and zero or more values.  does NOT require a reply!
	OSCMessageTypeQuery,	//	standard query types are listed below (OSCQueryType)- requires a reply of some sort from the address space!
	OSCMessageTypeReply,	//	a reply presumes that the query was executed successfully and an answer that is presumed to be useful is being returned
	OSCMessageTypeError,		//	an error presumes taht either the query was malformed or there was an error executing it
} OSCMessageType;
//	these are the basic query types
typedef enum	{
	OSCQueryTypeUnknown=0,
	OSCQueryTypeNamespaceExploration,
	OSCQueryTypeDocumentation,
	OSCQueryTypeTypeSignature,
	OSCQueryTypeCurrentValue,
	OSCQueryTypeReturnTypeString
} OSCQueryType;
//	these strings are used in the spec and are defined here for convenience
#define kOSCQueryTypeReplyString @"#reply"
#define kOSCQueryTypeErrorString @"#error"
//#define kOSCQueryTypeNamespaceExplorationString @""
#define kOSCQueryTypeDocumentationString @"#documentation"
#define kOSCQueryTypeTypeSignatureString @"#type-signature"
#define kOSCQueryTypeCurrentValueString @"#current-value"
#define kOSCQueryTypeReturnTypeStringString @"#return-type-string"
/*
typedef enum	{
	OSCErrorTypeUnknown,
	OSCErrorTypeRelocated,
	OSCErrorTypeCorrupt,
	OSCErrorTypeMismatch,
	OSCErrorTypeInfeasible,
	OSCErrorTypeMissing,
	OSCErrorTypeFailed,
	OSCErrorTypeVolatile,		//	described in supplementary PDF, not sure what it means!
} OSCErrorType;
*/




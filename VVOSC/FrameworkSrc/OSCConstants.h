
/*!
\file OSCConstants.h
\brief Constants and Macros used by one or more of the OSC classes in this framework
*/

///	OSCValueType
/*!
OSCValues have distinct types; these constants are used to describe the type of an OSCValue.
*/
typedef enum	{
	OSCValInt = 1,	//!<Integer
	OSCValFloat = 2,	//!<Float
	OSCValString = 3,	//!<String
	OSCValTimeTag = 4,	//!<TimeTag
	OSCValChar = 5,	//!<Char
	OSCValColor = 6,	//!<Color
	OSCValMIDI = 7,	//!<MIDI
	OSCValBool = 8,	//!<BOOL
	OSCValNil = 9,	//!<nil/NULL
	OSCValInfinity = 10,	//!<Infinity
	OSCValBlob = 11	//!<Blob- random binary data
} OSCValueType;




//	this macro just rounds a number up to the nearest multiple of 4
#define ROUNDUP4(A) ((((A)%4)!=0) ? (4-((A)%4)+(A)) : (A))

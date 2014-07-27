#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <VVBufferPool/VVBufferPool.h>








///	Load a Quartz Composer composition and parse it as a text file (QC comps are basically big plists) to retrieve data about the composition without invoking the Quartz Composer runtime, which can be slow.
/**
\ingroup VVBufferPool

OTHER NOTES ON THE LAYOUT OF QUARTZ COMPOSER DOCUMENTS:

- a QC file at its top level is a dictionary
- the "inputParameters" key of the top-level dictionary points to another dictionary
	- each key of "inputParameters" corresponds to a top-level published input
	- the item corresponding to each key is the default value of the input port. this
		does not describe the full splitter settings (no max/min/etc.), just the default value!
	- boolean, number, and string inputs work exactly as expected
	- colors are represented by a dict, keys "red", "green", "blue", and "alpha"
	- "structure" inputs- which do not have a default value- are not listed here!
		this means that i can't use this dict to populate inputs!
	- the value of "index" inputs (menus) is represented as the selected index (no strings!)
- the "portAttributes" key of the top-level dictionary points to another dictionary
	- each key of the "portAttributes" dict represents a top-level published input or output
	- the keys of "portAttributes" are the names of the published inputs and output
	- every item in "portAttributes" is a dictionary.
		- the "name" key of this dict points to a string
		- the value of the "name" string is either "Input" (if it's an input), or "Output" (if it's an output)
- the "rootPatch" key of the top-level dictionary points to another dictionary
	- the "state" key of "rootPatch" points to another dictionary.
	- the "state" dictionary has 3 keys of interest:
		- the "publishedInputPorts" key points to an array
			- each item in "publishedInputPorts" is a dict
				- the "key" key in the dict points to a string, which is the name of the published input
				- the "node" key in the dict points to a string, which is the name of the node
		- the "publishedOutputPorts" key points to an array, and is just like "publishedInputPorts"
		- the "nodes" key points to an array
			- each item in "nodes" is a dict
				- the "key" key in the dict points to a string, which is the name of the node
				- the "class" key in the dict points to a string, which is the name of the class
				- the "state" key in the dict points to another dict, which describes the state of the input

*/
@interface VVQCComposition : NSObject {
	NSString				*compositionPath;
	NSMutableDictionary		*publishedInputsDict;
	NSMutableArray			*inputKeys;
	NSMutableDictionary		*publishedOutputsDict;
	NSString				*category;
	NSString				*description;
	NSArray					*protocols;
	BOOL					hasLiveInput;
}

///	returns NO if the path begins with a period (invisible), doesn't have an extension, or doesn't end in "qtz" (case-insensitive)
+ (BOOL) pathLooksLikeALegitComposition:(NSString *)p;
///	Creates and returns an auto-released instance of VVQCComposition from a file at the given path
+ (id) compositionWithFile:(NSString *)p;
///	Init an instance of VVQCComposition from a file at the given path
- (id) initWithFile:(NSString *)p;

- (NSDictionary *) findSplitterForPublishedInputNamed:(NSString *)n inStateDict:(NSDictionary *)d;
- (NSDictionary *) findSplitterForPublishedOutputNamed:(NSString *)n inStateDict:(NSDictionary *)d;

- (NSMutableArray *) arrayOfItemDictsOfClass:(NSString *)className;
- (void) _addItemDictsOfClass:(NSString *)c inStateDict:(NSDictionary *)d toArray:(NSMutableArray *)a;
- (BOOL) findVideoInputInStateDict:(NSDictionary *)d;
- (void) cleanUpStateDict:(NSMutableDictionary *)d;
//- (id) valueForInputKey:(NSString *)k;

///	Retruns an NSDictionary describing the top-level published inputs in the composition
- (NSDictionary *) publishedInputsDict;
///	Returns an NSDictionary describing the top-level published output in the composition
- (NSDictionary *) publishedOutputsDict;
///	Returns the name of the composition
- (NSString *) compositionName;
///	Returns the path of the composition
- (NSString *) compositionPath;
///	Returns an array of strings.  Each string is the name of a published input splitter- the strings are ordered according to their order in the QC editor.
- (NSArray *) inputKeys;
///	Returns the category of the composition
- (NSString *) category;
///	Returns the description of the composition
- (NSString *) description;
///	Returns an array of NSStrings describing the protocol that this composition conforms to
- (NSArray *) protocols;
///	Returns YES if this composition has a live input
- (BOOL) hasLiveInput;
- (BOOL) hasFXInput;
- (BOOL) isCompositionMode;
- (BOOL) isTransitionMode;	//	If it has a QCCompositionProtocolGraphicTransition
- (BOOL) isMusicVisualizer;	//	If it has a QCCompositionProtocolMusicVisualizer
- (BOOL) isTXTSrc;
- (BOOL) isIMGSrc;

@end

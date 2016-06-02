#import "MTCMIDIManager.h"

@implementation MTCMIDIManager

//	these methods exist so subclasses of me can override them to change the name of the default midi destinations/receivers
- (NSString *) receivingNodeName	{
	return @"To MTC Tester";
}
- (NSString *) sendingNodeName	{
	return @"From MTC Tester";
}

@end

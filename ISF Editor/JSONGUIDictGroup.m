#import "JSONGUIDictGroup.h"
#import "JSONGUIPersistentBuffer.h"
#import "JSONGUITop.h"
#import <VVISFKit/VVISFKit.h>
#import <DDMathParser/DDMathParser.h>




@implementation JSONGUIDictGroup


- (id) initWithType:(ISFDictClassType)targetType top:(JSONGUITop *)theTop	{
	self = [super init];
	if (self != nil)	{
		//	initialize the basic vars
		groupType = targetType;
		contents = [[MutLockDict alloc] init];
		top = [[ObjectHolder alloc] initWithZWRObject:theTop];
		
		//	get the raw ISF dict from the top-level object- this is what we're going to parse to populate our contents
		MutLockDict		*isfDict = [theTop isfDict];
		
		switch (targetType)	{
		//	this dict is going to contain persistent buffers
		case ISFDictClassType_PersistentBuffer:
			{
				//	get the PERSISTENT_BUFFERS object from the top-level ISF dict, parse it- we just need a name
				NSDictionary		*pBuffersDict = [isfDict objectForKey:@"PERSISTENT_BUFFERS"];
				if (pBuffersDict != nil)	{
					if ([pBuffersDict isKindOfClass:[NSArray class]])	{
						for (NSString *pbName in (NSArray *)pBuffersDict)	{
							//	make a persistent buffer object from the name (it will populate itself)
							JSONGUIPersistentBuffer		*newBuffer = [[[JSONGUIPersistentBuffer alloc] initWithName:pbName top:theTop] autorelease];
							if (newBuffer != nil)
								[contents lockSetObject:newBuffer forKey:pbName];
						}
					}
					else if ([pBuffersDict isKindOfClass:[NSDictionary class]])	{
						for (NSString *pbName in [pBuffersDict allKeys])	{
							//	make a persistent buffer object from the name (it will populate itself)
							JSONGUIPersistentBuffer		*newBuffer = [[[JSONGUIPersistentBuffer alloc] initWithName:pbName top:theTop] autorelease];
							if (newBuffer != nil)
								[contents lockSetObject:newBuffer forKey:pbName];
						}
					}
				}
				//	run through all the PASSES, looking for a pass dict with a PERSISTENT flag
				NSArray			*passesArray = [isfDict objectForKey:@"PASSES"];
				for (NSDictionary *passDict in passesArray)	{
					id				persistentObj = [passDict objectForKey:@"PERSISTENT"];
					NSNumber		*persistentNum = nil;
					if ([persistentObj isKindOfClass:[NSString class]])	{
						persistentNum = [(NSString *)persistentObj parseAsBoolean];
						if (persistentNum == nil)
							persistentNum = [(NSString *)persistentObj numberByEvaluatingString];
					}
					else if ([persistentObj isKindOfClass:[NSNumber class]])
						persistentNum = [[persistentObj retain] autorelease];
					//	if there's a valid "PERSISTENT" flag in this pass dict and it's indicating a positive
					if (persistentNum!=nil && [persistentNum intValue]>0)	{
						//	get the name of the target
						NSString			*targetName = [passDict objectForKey:@"TARGET"];
						if (targetName!=nil && [targetName isKindOfClass:[NSString class]])	{
							//	make a persistent buffer object (it will populate itself)
							JSONGUIPersistentBuffer		*newBuffer = [[[JSONGUIPersistentBuffer alloc] initWithName:targetName top:theTop] autorelease];
							if (newBuffer != nil)
								[contents lockSetObject:newBuffer forKey:targetName];
						}
					}
				}
			}
			break;
		}
	}
	return self;
}
- (void) dealloc	{
	VVRELEASE(contents);
	VVRELEASE(top);
	[super dealloc];
}
- (id) objectForKey:(NSString *)k	{
	if (k==nil)
		return nil;
	return [[[contents lockObjectForKey:k] retain] autorelease];
}
@synthesize groupType;
@synthesize contents;
- (JSONGUITop *) top	{
	return [top object];
}
- (NSString *) description	{
	switch (groupType)	{
	case ISFDictClassType_PersistentBuffer:
		return @"<JSONGUIDictGroup- p.buffers>";
	}
	return @"<JSONGUIDictGroup- ?>";
}


@end

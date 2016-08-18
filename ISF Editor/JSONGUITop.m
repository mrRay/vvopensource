#import "JSONGUITop.h"
#import "JSONGUIPass.h"
#import "JSONGUIInput.h"




@implementation JSONGUITop


- (id) initWithISFDict:(NSDictionary *)n	{
	self = [super init];
	if (self != nil)	{
		isfDict = nil;
		inputsGroup = nil;
		passesGroup = nil;
		buffersGroup = nil;
		if (n==nil)	{
			[self release];
			return nil;
		}
		isfDict = [[MutLockDict alloc] init];
		[isfDict lockAddEntriesFromDictionary:n];
		
		//	make the groups- the groups create instances of inputs/passes/persistent buffers as needed (which do all their own parsing)
		inputsGroup = [[JSONGUIArrayGroup alloc] initWithType:ISFArrayClassType_Input top:self];
		passesGroup = [[JSONGUIArrayGroup alloc] initWithType:ISFArrayClassType_Pass top:self];
		buffersGroup = [[JSONGUIDictGroup alloc] initWithType:ISFDictClassType_PersistentBuffer top:self];
	}
	return self;
}
- (void) dealloc	{
	VVRELEASE(inputsGroup);
	VVRELEASE(passesGroup);
	VVRELEASE(buffersGroup);
	[super dealloc];
}
- (MutLockDict *) isfDict	{
	return [[isfDict retain] autorelease];
}
- (JSONGUIArrayGroup *) inputsGroup	{
	return [[inputsGroup retain] autorelease];
}
- (JSONGUIArrayGroup *) passesGroup	{
	return [[passesGroup retain] autorelease];
}
- (JSONGUIDictGroup *) buffersGroup	{
	return [[buffersGroup retain] autorelease];
}
- (NSString *) description	{
	return @"<JSONGUITop>";
}



- (JSONGUIInput *) getInputNamed:(NSString *)n	{
	if (n==nil)
		return nil;
	JSONGUIInput		*returnMe = nil;
	MutLockArray		*inputArray = [inputsGroup contents];
	[inputArray rdlock];
	for (JSONGUIInput *input in [inputArray array])	{
		NSString		*inputName = [input objectForKey:@"NAME"];
		if (inputName!=nil && [inputName isEqualToString:n])
			returnMe = [[input retain] autorelease];
	}
	[inputArray unlock];
	return returnMe;
}
- (NSArray *) getPassesRenderingToBufferNamed:(NSString *)n	{
	if (n==nil)
		return nil;
	NSMutableArray		*returnMe = nil;
	MutLockArray		*passes = [passesGroup contents];
	[passes rdlock];
	for (JSONGUIPass *passPtr in [passes array])	{
		NSString		*passTarget = [passPtr objectForKey:@"TARGET"];
		if (passTarget!=nil && [passTarget isEqualToString:n])	{
			//returnMe = [[passTarget retain] autorelease];
			if (returnMe == nil)
				returnMe = MUTARRAY;
			[returnMe addObject:passPtr];
		}
	}
	[passes unlock];
	
	return returnMe;
}
- (JSONGUIPersistentBuffer *) getPersistentBufferNamed:(NSString *)n	{
	if (n==nil)
		return nil;
	return [[[[buffersGroup contents] lockObjectForKey:n] retain] autorelease];
}
- (NSInteger) indexOfInput:(JSONGUIInput *)n	{
	NSInteger		returnMe = NSNotFound;
	if (n != nil)	{
		returnMe = [[inputsGroup contents] lockIndexOfObject:n];
	}
	return returnMe;
}
- (NSInteger) indexOfPass:(JSONGUIPass *)n	{
	//NSLog(@"%s ... %@",__func__,n);
	//NSLog(@"\t\tcontents are %@",[passesGroup contents]);
	NSInteger		returnMe = NSNotFound;
	if (n != nil)	{
		returnMe = [[passesGroup contents] lockIndexOfObject:n];
	}
	return returnMe;
}
/*
- (NSArray *) persistentBufferNames	{
	NSMutableArray		*returnMe = MUTARRAY;
	MutLockArray		*passes = [passesGroup contents];
	MutLockDict			*persistentBuffers = [buffersGroup contents];
	
	return returnMe;
}
*/
- (NSString *) createNewInputName	{
	NSString		*returnMe = nil;
	NSInteger		count = 1;
	do	{
		//	make a new name
		if (count == 1)
			returnMe = @"tmpInputName";
		else
			returnMe = [NSString stringWithFormat:@"tmpInputName%d",(int)count];
		//	check to see if the name is already in use- if it is, set it to nil and it'll loop
		if ([self getInputNamed:returnMe]!=nil)
			returnMe = nil;
		//	increment the count
		++count;
	} while (returnMe == nil);
	return returnMe;
}


- (NSMutableArray *) makeInputsArray	{
	NSMutableArray		*returnMe = nil;
	
	if (inputsGroup != nil)	{
		MutLockArray		*inputsArray = [inputsGroup contents];
		[inputsArray rdlock];
		for (JSONGUIInput *input in [inputsArray array])	{
			NSDictionary		*newDict = [input createExportDict];
			if (newDict != nil)	{
				if (returnMe == nil)
					returnMe = MUTARRAY;
				[returnMe addObject:newDict];
			}
		}
		[inputsArray unlock];
	}
	
	return returnMe;
}
- (NSMutableArray *) makePassesArray	{
	NSMutableArray		*returnMe = nil;
	
	if (passesGroup != nil)	{
		MutLockArray		*passesArray = [passesGroup contents];
		[passesArray rdlock];
		for (JSONGUIPass *pass in [passesArray array])	{
			NSDictionary		*newDict = [pass createExportDict];
			if (newDict != nil)	{
				if (returnMe == nil)
					returnMe = MUTARRAY;
				[returnMe addObject:newDict];
			}
		}
		[passesArray unlock];
	}
	
	return returnMe;
}
- (NSMutableDictionary *) makeBuffersDict	{
	NSMutableDictionary		*returnMe = nil;
	
	if (buffersGroup != nil)	{
		MutLockDict		*buffersDict = [buffersGroup contents];
		[buffersDict rdlock];
		for (NSString *bufferKey in [buffersDict allKeys])	{
			JSONGUIPersistentBuffer		*pbuffer = [buffersDict objectForKey:bufferKey];
			NSDictionary		*pbufferDict = [pbuffer createExportDict];
			if (pbufferDict!=nil)	{
				if (returnMe == nil)
					returnMe = MUTDICT;
				[returnMe setObject:pbufferDict forKey:bufferKey];
			}
		}
		[buffersDict unlock];
	}
	
	return returnMe;
}


@end

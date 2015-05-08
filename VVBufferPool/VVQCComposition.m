#import "VVQCComposition.h"
#import <VVBasics/VVBasics.h>




@implementation VVQCComposition


+ (BOOL) pathLooksLikeALegitComposition:(NSString *)p	{
	BOOL			returnMe = NO;
	if (p==nil)
		return returnMe;
	NSString		*extension = [p pathExtension];
	if (extension == nil)
		return returnMe;
	if ([[[p lastPathComponent] firstChar] isEqualToString:@"."])
		return returnMe;
	if ([extension length] != 3)
		return returnMe;
	if ([extension compare:@"qtz" options:NSCaseInsensitiveSearch range:NSMakeRange(0,3)] != NSOrderedSame)
		return returnMe;
	returnMe = YES;
	return returnMe;
}
+ (id) compositionWithFile:(NSString *)p	{
	VVQCComposition		*returnMe = nil;
	returnMe = [[VVQCComposition alloc] initWithFile:p];
	if (returnMe == nil)	{
		return nil;
	}
	return [returnMe autorelease];
}
- (id) initWithFile:(NSString *)p	{
	if (self = [super init])	{
		//	initialize everything to nil, so if i get released i won't have any issues
		compositionPath = nil;
		publishedInputsDict = nil;
		inputKeys = nil;
		publishedOutputsDict = nil;
		category = nil;
		description = nil;
		protocols = nil;
		
		//	if the passed path is nil, if it doesn't have an extension, if it starts with a period, or doesn't end in "qtz"- bail
		if (![VVQCComposition pathLooksLikeALegitComposition:p])
			goto BAIL;
		
		//	now that i know i'm a qtz and i know i'm not invisible, proceed with loading!
		
		NSDictionary			*fileDict = nil;
		NSDictionary			*rootPatchDict = nil;
		NSDictionary			*stateDict = nil;
		NSArray					*portsArray = nil;
		NSEnumerator			*it = nil;
		NSDictionary			*portDict = nil;
		NSString				*tmpString = nil;
		NSDictionary			*inputSplitterDict = nil;
		NSMutableDictionary		*newPublishedPortDict = nil;
		
		self = [super init];
		compositionPath = [p retain];
		publishedInputsDict = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
		inputKeys = [[NSMutableArray arrayWithCapacity:0] retain];
		publishedOutputsDict = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	
		category = nil;
		description = nil;
		hasLiveInput = NO;
		//	make a dict from the path
		fileDict = [NSDictionary dictionaryWithContentsOfFile:compositionPath];
		if (fileDict == nil)
			goto BAIL;
		[fileDict retain];
		//	get the category and description strings
		category = [fileDict objectForKey:QCCompositionAttributeCategoryKey];
		if (category != nil)	{
			//NSLog(@"\t\tcategory is %@",category);
			[category retain];
		}
		description = [fileDict objectForKey:QCCompositionAttributeDescriptionKey];
		if (description != nil)	{
			//NSLog(@"\t\tdescription is %@",description);
			[description retain];
		}
		//	get the root patch dict
		rootPatchDict = [fileDict objectForKey:@"rootPatch"];
		if (rootPatchDict == nil)
			goto BAIL;
		[rootPatchDict retain];
		//	get the state dict
		stateDict = [rootPatchDict objectForKey:@"state"];
		if (stateDict == nil)
			goto BAIL;
		[stateDict retain];
		
		protocols = [fileDict objectForKey:@"protocols"];
		if (protocols != nil)	{
			[protocols retain];
		}
		
		//	get the array of dicts which represent published inputs
		portsArray = [stateDict objectForKey:@"publishedInputPorts"];
		if (portsArray != nil)	{
			//	run through all the dicts in the array; each dict describes a published input port's node
			it = [portsArray objectEnumerator];
			while (portDict = [it nextObject])	{
				//	determine the published name of the port
				tmpString = [portDict objectForKey:@"key"];
				if (tmpString != nil)	{
					//	store the published name in the array of input keys (this preserves the order from the QC comp)
					[inputKeys addObject:tmpString];
					//	make a new dict for my use, add it to me
					newPublishedPortDict = [NSMutableDictionary dictionaryWithCapacity:0];
					[publishedInputsDict setObject:newPublishedPortDict forKey:tmpString];
					//	find the node dict which corresponds to the input splitter
					inputSplitterDict = [self
						findSplitterForPublishedInputNamed:tmpString
						inStateDict:stateDict];
					//	if there's a node dict...
					if (inputSplitterDict != nil)	{
						//	add the contents of the node dict's 'state' dict to it
						[newPublishedPortDict addEntriesFromDictionary:[inputSplitterDict objectForKey:@"state"]];
						//	clear out some of the useless values
						[self cleanUpStateDict:newPublishedPortDict];
					}
					//	...if there's no node dict, user published a non-splitter input! ignore that shit!
					/*
					else	{
						//	set up the dict so it looks like a standard number input
						[newPublishedPortDict setObject:VVSTRING(@"QCNumberPort") forKey:@"portClass"];
						[newPublishedPortDict setObject:[NSNumber numberWithFloat:1.0] forKey:@"defaultVal"];
					}
					*/
				}
				
			}
		}
		
		
		//	get the array of dicts which represent published outputs
		portsArray = [stateDict objectForKey:@"publishedOutputPorts"];
		if (portsArray != nil)	{
			//	run through all the dicts in the array; each dict describes a published output port's node
			it = [portsArray objectEnumerator];
			while (portDict = [it nextObject])	{
				//	determine the published name of the port
				tmpString = [portDict objectForKey:@"key"];
				if (tmpString != nil)	{
					//	make a new dict for my use, add it to me
					newPublishedPortDict = [NSMutableDictionary dictionaryWithCapacity:0];
					[publishedOutputsDict setObject:newPublishedPortDict forKey:tmpString];
					//	find the node dict which corresponds to the input splitter
					inputSplitterDict = [self
						findSplitterForPublishedOutputNamed:tmpString
						inStateDict:stateDict];
					//	if there's a node dict...
					if (inputSplitterDict != nil)	{
						//	add the contents of the node dict's 'state' dict to it
						[newPublishedPortDict addEntriesFromDictionary:[inputSplitterDict objectForKey:@"state"]];
						//	clear out some of the useless values
						[self cleanUpStateDict:newPublishedPortDict];
					}
					//	...if there's no node dict, user published a non-splitter output! ignore that shit!
				}
				
			}
		}
		
		
		//	run through the file dict's "inputParameters" (default vals)
		NSDictionary			*inputParametersDict = [fileDict objectForKey:@"inputParameters"];
		NSEnumerator			*keyIt;
		NSString				*keyPtr;
		
		keyIt = [[inputParametersDict allKeys] objectEnumerator];
		while (keyPtr = [keyIt nextObject])	{
			//	find my copy of the dict which represents the input port
			newPublishedPortDict = [publishedInputsDict objectForKey:keyPtr];
			if (newPublishedPortDict != nil)	{
				[newPublishedPortDict
					setObject:[inputParametersDict objectForKey:keyPtr]
					forKey:@"defaultVal"];
			}
		}
		
		//	while i've got the dict around, check to see if there's a live input in it...
		hasLiveInput = [self findVideoInputInStateDict:stateDict];
		
		//	start releasing dicts i created earlier, and explicitly retained to prevent problems
		VVRELEASE(fileDict);
		VVRELEASE(rootPatchDict);
		VVRELEASE(stateDict);
		return self;
	}
	
	BAIL:
	if (self != nil)
		[self release];
	return nil;
}
- (void) dealloc	{
	//NSLog(@"VVQCComposition:dealloc:");
	VVRELEASE(compositionPath);
	VVRELEASE(publishedInputsDict);
	VVRELEASE(inputKeys);
	VVRELEASE(publishedOutputsDict);
	VVRELEASE(category);
	VVRELEASE(description);
	VVRELEASE(protocols);
	[super dealloc];
}

- (NSDictionary *) findSplitterForPublishedInputNamed:(NSString *)n inStateDict:(NSDictionary *)d	{
	//NSLog(@"VVQCComposition:findSplitterForPublishedInputNamed:inStateDict: ... %@",n);
	if (d == nil)	{
		return nil;
	}
	
	NSDictionary		*nodeDict = nil;
	NSEnumerator		*it = nil;
	id					anObj = nil;
	NSDictionary		*inputPortDict = nil;
	NSString			*nodeName = nil;
	NSString			*nodePortName = nil;
	
	anObj = [d objectForKey:@"publishedInputPorts"];
	if (anObj == nil)
		return nil;
	//	run through all the dicts in the input ports array
	it = [anObj objectEnumerator];
	while (inputPortDict = [it nextObject])	{
		if ([[inputPortDict objectForKey:@"key"] isEqualToString:n])
			break;
	}
	//	if i couldn't find the dict in the input port array for the published input, return nil
	if (inputPortDict == nil)
		return nil;
	//	get the name of the node corresponding to this input object, and the port name of the node
	nodeName = [inputPortDict objectForKey:@"node"];
	nodePortName = [inputPortDict objectForKey:@"port"];
	//	bail if i can't find the node name or the node port name
	if ((nodeName == nil) || (nodePortName == nil))
		return nil;
	//	find the node with the corresponding node name
	anObj = [d objectForKey:@"nodes"];
	if (anObj == nil)
		return nil;
	it = [anObj objectEnumerator];
	while (anObj = [it nextObject])	{
		if ([[anObj objectForKey:@"key"] isEqualToString:nodeName])	{
			nodeDict = anObj;
			break;
		}
	}
	//	if the node's class is 'QCSplitter', i can just return it
	if ([[nodeDict objectForKey:@"class"] isEqualToString:@"QCSplitter"])
		return nodeDict;
	//	if the node isn't a 'QCSplitter'....
	else	{
		//	all nodes have a state dict; if this is a group, the state dict will have a "nodes" array
		anObj = [nodeDict objectForKey:@"state"];
		//	if the state dict is nil, bail
		if (anObj == nil)	{
			return nil;
		}
		//	if the state dict has an object at its 'nodes' key, it's a group- parse down
		if ([anObj objectForKey:@"nodes"] != nil)	{
			anObj = [self
				findSplitterForPublishedInputNamed:nodePortName
				inStateDict:anObj];
			return anObj;
		}
		//	if it doesn't, it's an actual object- return nil
		else	{
			return nil;
		}
		
		/*
		//	if the node has a state dict, it's a group patch of some sort- repeat this process
		anObj = [nodeDict objectForKey:@"state"];
		if (anObj != nil)	{
			anObj = [self
				findSplitterForPublishedInputNamed:nodePortName
				inStateDict:anObj];
			return anObj;
		}
		//	else if there's no state dict, return nil!
		else	{
			return nil;
		}
		*/
	}
	
	return nil;
}
- (NSDictionary *) findSplitterForPublishedOutputNamed:(NSString *)n inStateDict:(NSDictionary *)d	{
	if (d == nil)	{
		return nil;
	}
	
	NSDictionary		*nodeDict = nil;
	NSEnumerator		*it = nil;
	id					anObj = nil;
	NSDictionary		*inputPortDict = nil;
	NSString			*nodeName = nil;
	NSString			*nodePortName = nil;
	
	anObj = [d objectForKey:@"publishedOutputPorts"];
	if (anObj == nil)
		return nil;
	//	run through all the dicts in the input ports array
	it = [anObj objectEnumerator];
	while (inputPortDict = [it nextObject])	{
		if ([[inputPortDict objectForKey:@"key"] isEqualToString:n])
			break;
	}
	//	if i couldn't find the dict in the input port array for the published input, return nil
	if (inputPortDict == nil)
		return nil;
	//	get the name of the node corresponding to this input object, and the port name of the node
	nodeName = [inputPortDict objectForKey:@"node"];
	nodePortName = [inputPortDict objectForKey:@"port"];
	//	bail if i can't find the node name or the node port name
	if ((nodeName == nil) || (nodePortName == nil))
		return nil;
	//	find the node with the corresponding node name
	anObj = [d objectForKey:@"nodes"];
	if (anObj == nil)
		return nil;
	it = [anObj objectEnumerator];
	while (anObj = [it nextObject])	{
		if ([[anObj objectForKey:@"key"] isEqualToString:nodeName])	{
			nodeDict = anObj;
			break;
		}
	}
	//	if the node's class is 'QCSplitter', i can just return it
	if ([[nodeDict objectForKey:@"class"] isEqualToString:@"QCSplitter"])
		return nodeDict;
	//	if the node isn't a 'QCSplitter'....
	else	{
		//	if the node has a state dict, it's a group patch of some sort- repeat this process
		anObj = [nodeDict objectForKey:@"state"];
		if (anObj != nil)	{
			anObj = [self
				findSplitterForPublishedOutputNamed:nodePortName
				inStateDict:anObj];
			return anObj;
		}
		//	else if there's no state dict, return nil!
		else	{
			return nil;
		}
	}
	
	return nil;
}
- (NSMutableArray *) arrayOfItemDictsOfClass:(NSString *)className	{
	//NSLog(@"%s ... %@",__func__,className);
	if (className == nil)
		return nil;
	NSDictionary		*fileDict = [NSDictionary dictionaryWithContentsOfFile:compositionPath];
	if (fileDict==nil)	{
		NSLog(@"\t\terr: bailing, fileDict nil %s",__func__);
		return nil;
	}
	NSDictionary		*rootPatchDict = [fileDict objectForKey:@"rootPatch"];
	if (rootPatchDict==nil)	{
		NSLog(@"\t\terr: bailing, rootPatchDict nil %s",__func__);
		return nil;
	}
	NSDictionary		*stateDict = [rootPatchDict objectForKey:@"state"];
	if (stateDict==nil)	{
		NSLog(@"\t\terr: bailing, stateDict nil %s",__func__);
		return nil;
	}
	NSMutableArray		*returnMe = MUTARRAY;
	[self _addItemDictsOfClass:className inStateDict:stateDict toArray:returnMe];
	return returnMe;
}
- (void) _addItemDictsOfClass:(NSString *)c inStateDict:(NSDictionary *)d toArray:(NSMutableArray *)a	{
	if (c==nil || a==nil)
		return;
	//	run through all the nodes in the state dict
	NSArray			*nodesArray = [d objectForKey:@"nodes"];
	if (nodesArray!=nil && [nodesArray count]>0)	{
		for (NSDictionary *nodeDict in nodesArray)	{
			//	check to see if this node's what i'm looking for- if it is, add a copy of the node dict (get rid of its sub-nodes!) to the array
			NSString		*nodeClass = [nodeDict objectForKey:@"class"];
			if (nodeClass!=nil && [nodeClass isEqualToString:c])	{
				NSMutableDictionary		*mutCopy = [nodeDict mutableCopy];
				[mutCopy removeObjectForKey:@"nodes"];
				[a addObject:mutCopy];
				[mutCopy release];
			}
			
			//	call this method recursively on the 'state' dict of this node
			NSDictionary	*nodeStateDict = [nodeDict objectForKey:@"state"];
			if (nodeStateDict != nil)
				[self _addItemDictsOfClass:c inStateDict:nodeStateDict toArray:a];
		}
	}
}
- (BOOL) findVideoInputInStateDict:(NSDictionary *)d	{
	//NSLog(@"VVQCComposition:findVideoInputInStateDict:");
	if ((d == nil) || ([d count] < 1))	{
		return NO;
	}
	/*
		state dicts have an array at "nodes".
		each node is a dict- if the dict has a "state" dict, the state dict has an array at "nodes".
		recursively call this method, return a YES if a video input was found.
	*/
	
	BOOL			foundAnInput = NO;
	NSArray			*nodesArray;
	NSEnumerator	*nodeIt;
	NSDictionary	*nodeDict;
	NSString		*nodeClass;
	//NSString		*nodeKey;
	//NSDictionary	*nodeConnectionsDict;
	//NSEnumerator	*connectionIt;
	//NSDictionary	*connectionDict;
	NSDictionary	*nodeStateDict;
	//NSString		*nodeConnSourceNode;
	//NSString		*nodeConnSourcePort;
	
	nodesArray = [d objectForKey:@"nodes"];
	if ((nodesArray != nil) && ([nodesArray count] > 0))	{
		nodeIt = [nodesArray objectEnumerator];
		while ((nodeDict = [nodeIt nextObject]) && (!foundAnInput))	{
			//	if the node's class is 'QCVideoInput', i've found an input
			nodeClass = [nodeDict objectForKey:@"class"];
			if ((nodeClass != nil) && ([nodeClass isEqualToString:@"QCVideoInput"]))	{
				return YES;
				/*
				//	check to see if the input's connected to anything: find the node's key...
				nodeKey = [nodeDict objectForKey:@"key"];
				if (nodeKey != nil)	{
					//	run through the items in the state dict's "connections" dictionary...
					nodeConnectionsDict = [d objectForKey:@"connections"];
					if ((nodeConnectionsDict != nil) && ([nodeConnectionsDict count] > 0))	{
						connectionIt = [nodeConnectionsDict objectEnumerator];
						while (connectionDict = [connectionIt nextObject])	{
							nodeConnSourceNode = [connectionDict objectForKey:@"sourceNode"];
							nodeConnSourcePort = [connectionDict objectForKey:@"sourcePort"];
							//	if the connection dictionary's "sourceNode" matches the key of the input node....
							if ((nodeConnSourceNode != nil) && ([nodeConnSourceNode isEqualToString:nodeKey]))	{
								//	if the connection dictionary's "sourcePort" is "outputImage"- the input's in use, return YES
								if ((nodeConnSourcePort != nil) && ([nodeConnSourcePort isEqualToString:@"outputImage"]))	{
									return YES;
								}
							}
						}
					}
				}
				*/
			}
			//	if the ndoe has a state dict, call this method recursively, searching for the video input
			nodeStateDict = [nodeDict objectForKey:@"state"];
			if ((nodeStateDict != nil) && ([nodeStateDict count] > 0))	{
				foundAnInput = [self findVideoInputInStateDict:nodeStateDict];
			}
		}
	}
	
	return foundAnInput;
}
- (void) cleanUpStateDict:(NSMutableDictionary *)d	{
	if (d == nil)	{
		return;
	}
	//[d removeObjectForKey:@"userInfo"];	//	the 'userInfo' NSData object encodes an NSDictionary which has the "name" of the splitter and its x/y location within the QC composition
	[d removeObjectForKey:@"version"];
	[d removeObjectForKey:@"nodes"];
	[d removeObjectForKey:@"publishedInputPorts"];
	[d removeObjectForKey:@"publishedOutputPorts"];
	[d removeObjectForKey:@"ivarInputPortStates"];
	[d removeObjectForKey:@"systemInputPortStates"];
	[d removeObjectForKey:@"connections"];
	
	/*	there's a 'userInfo' object which is an NSData blob- the NSData is an unkeyed archive for an 
	NSDictionary- i want to decode this dict and move some of its contents to the state dict		*/
	NSData			*blob = [d objectForKey:@"userInfo"];
	if (blob != nil)	{
		NSDictionary	*decoded = [NSUnarchiver unarchiveObjectWithData:blob];
		if (decoded != nil)	{
			[d addEntriesFromDictionary:decoded];
		}
		
		[d removeObjectForKey:@"userInfo"];
		[d removeObjectForKey:@"position"];
	}
}
/*
- (id) valueForInputKey:(NSString *)k	{
	return nil;
}
*/


- (NSDictionary *) publishedInputsDict	{
	return [[publishedInputsDict retain] autorelease];
}
- (NSDictionary *) publishedOutputsDict	{
	return [[publishedOutputsDict retain] autorelease];
}
- (NSString *) compositionName	{
	if (compositionPath == nil)
		return nil;
	NSString		*lastPathComponent = [compositionPath lastPathComponent];
	if (lastPathComponent == nil)
		return nil;
	return [lastPathComponent stringByDeletingPathExtension];
}


- (NSString *) compositionPath	{
	return [[compositionPath retain] autorelease];
}
- (NSArray *) inputKeys	{
	return [[inputKeys retain] autorelease];
	/*
	if (publishedInputsDict == nil)
		return nil;
	return [publishedInputsDict allKeys];
	*/
}
- (NSString *) category	{
	return category;
}
- (NSString *) description	{
	return description;
}
- (NSArray *) protocols	{
	return protocols;
}
- (BOOL) hasLiveInput	{
	return hasLiveInput;
}
- (BOOL) hasFXInput	{
	NSArray			*inputStrings = [publishedInputsDict allKeys];
	if ((inputStrings!=nil) && ([inputStrings count]>0))	{
		for (NSString *tmpString in inputStrings)	{
			if ([tmpString denotesFXInput])	{
				NSDictionary	*portDict = [publishedInputsDict objectForKey:tmpString];
				if (portDict != nil)	{
					NSString	*portClass = [portDict objectForKey:@"portClass"];
					if ((portClass!=nil)&&([portClass isEqualToString:@"QCGLImagePort"]))
						return YES;
				}
			}
		}
	}
	return NO;
}
- (BOOL) isCompositionMode	{
	//NSLog(@"%s ... %@",__func__,compositionPath);
	NSArray			*inputStrings = [publishedInputsDict allKeys];
	if ((inputStrings!=nil) && ([inputStrings count]>0))	{
		BOOL		hasTopInput = NO;
		BOOL		hasBottomInput = NO;
		//	Setting this to yes for the time being because system QC comps use the time of the patch
		BOOL		hasOpacity = NO;		
		for (NSString *tmpString in inputStrings)	{
			if ([tmpString denotesCompositionTopImage])	{
				//NSLog(@"\t\ttop image named %@ found",tmpString);
				hasTopInput = YES;
			}
			else if ([tmpString denotesCompositionBottomImage])	{
				//NSLog(@"\t\tbottom image named %@ found",tmpString);
				hasBottomInput = YES;
			}
			else if ([tmpString denotesCompositionOpacity])	{
				//NSLog(@"\t\topacity named %@ found",tmpString);
				hasOpacity = YES;
			}
		}
		if (hasTopInput && hasBottomInput && hasOpacity)	{
			//NSLog(@"\t\t***************** COMP MODE!");
			return YES;
		}
	}
	return NO;
}
- (BOOL) isTransitionMode	{
	if (protocols==nil)
		return NO;
	
	for (NSString *protocol in protocols)	{
		if ([protocol isEqualToString:QCCompositionProtocolGraphicTransition])
			return YES;
		//else if ([protocol isEqualToString:QCCompositionProtocolImageTransition])
		//	return YES;
	}
	
	return NO;
}
- (BOOL) isMusicVisualizer	{
	if (protocols==nil)
		return NO;
	
	for (NSString *protocol in protocols)	{
		if ([protocol isEqualToString:QCCompositionProtocolMusicVisualizer])
			return YES;
	}
	
	return NO;
}
- (BOOL) isTXTSrc	{
	NSArray			*inputStrings = [publishedInputsDict allKeys];
	if ((inputStrings!=nil) && ([inputStrings count]>0))	{
		BOOL		hasFileInput = NO;
		for (NSString *tmpString in inputStrings)	{
			if ([tmpString denotesTXTFileInput])	{
				hasFileInput = YES;
				break;
			}
		}
		if (hasFileInput)	{
			return YES;
		}
	}
	return NO;
}
- (BOOL) isIMGSrc	{
	NSArray			*inputStrings = [publishedInputsDict allKeys];
	if ((inputStrings!=nil) && ([inputStrings count]>0))	{
		BOOL		hasFileInput = NO;
		for (NSString *tmpString in inputStrings)	{
			if ([tmpString denotesIMGFileInput])	{
				hasFileInput = YES;
				break;
			}
		}
		if (hasFileInput)	{
			return YES;
		}
	}
	return NO;
}


@end

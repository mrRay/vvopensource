#import <Foundation/Foundation.h>
#import <VVUIToolbox/VVUIToolbox.h>



//	must always be in an instance of either ISFPropInputTableCellView or ISFPropPassTableCellView
@interface JSONGUIDragBarView : VVSpriteView <NSDraggingSource>	{
	ObjectHolder		*bgSpriteHolder;
}

@end

//
//  ISFQL_RendererProtocols.h
//  ISFQL
//
//  Created by testAdmin on 4/30/16.
//  Copyright © 2016 vidvox. All rights reserved.
//

#ifndef ISFQL_RendererProtocols_h
#define ISFQL_RendererProtocols_h




@protocol ISFQLAgentService
- (void) renderThumbnailForPath:(NSString *)n sized:(NSSize)s;
@end




@protocol ISFQLService
- (void) renderedBitmapData:(NSData *)d sized:(NSSize)s;
@end




#endif /* ISFQL_RendererProtocols_h */

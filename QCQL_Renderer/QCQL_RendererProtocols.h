//
//  QCQL_RendererProtocols.h
//  QCQL
//
//  Created by testAdmin on 4/30/16.
//  Copyright © 2016 vidvox. All rights reserved.
//

#ifndef QCQL_RendererProtocols_h
#define QCQL_RendererProtocols_h




@protocol QCQLAgentService
- (void) renderThumbnailForPath:(NSString *)n sized:(NSSize)s;
@end




@protocol QCQLService
- (void) renderedBitmapData:(NSData *)d sized:(NSSize)s;
@end




#endif /* QCQL_RendererProtocols_h */

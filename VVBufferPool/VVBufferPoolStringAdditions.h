#import <Foundation/Foundation.h>




@interface NSString (VVBufferPoolStringAdditions)

- (BOOL) containsString:(NSString *)s;
- (BOOL) containsString:(NSString *)s options:(NSStringCompareOptions)mask;

- (NSString *) firstChar;
- (BOOL) denotesFXPrimaryInput;
- (BOOL) denotesFXInput;
- (BOOL) denotesCompositionTopImage;
- (BOOL) denotesCompositionBottomImage;
- (BOOL) denotesCompositionOpacity;
- (BOOL) denotesTXTFileInput;
- (BOOL) denotesIMGFileInput;

@end

#import <Foundation/Foundation.h>

// MARK: Interfaces

@interface NSIndexSet (Subset)
- (NSIndexSet *)indexesIntersectingRange:(NSRange)range;
- (NSIndexSet *)indexesIntersectingIndexSet:(NSIndexSet *)indexSet;
@end

#import "NSIndexSet+Subset.h"

@implementation NSIndexSet (Subset)

- (NSIndexSet *)indexesIntersectingRange:(NSRange)range
{
	return [self indexesInRange:range
						options:0
					passingTest:^(NSUInteger idx, BOOL *stop)
			{
				return YES;
			}];
}

- (NSIndexSet *)indexesIntersectingIndexSet:(NSIndexSet *)indexSet
{
	NSMutableIndexSet *intersection = [NSMutableIndexSet indexSet];
	[self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop)
	 {
		 if ([indexSet containsIndex:idx])
		 {
			 [intersection addIndex:idx];
		 }
	 }];
	return [intersection copy];
}

@end

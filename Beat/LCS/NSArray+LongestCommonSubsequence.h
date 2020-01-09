//
//  NSArray+LongestCommonSubsequence.h
//  LCS-Objective-C
//
//  Created by Håvard Fossli on 23.06.2016.
//
//

#import <Foundation/Foundation.h>

@interface NSArray (LongestCommonSubsequence)

- (NSIndexSet *)indexesOfCommonElementsWithArray:(NSArray *)array
                                    addedIndexes:(NSIndexSet **)addedIndexes
                                  removedIndexes:(NSIndexSet **)removedIndexes;

@end

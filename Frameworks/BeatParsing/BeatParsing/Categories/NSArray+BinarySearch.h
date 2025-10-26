//
//  NSArray+BinarySearch.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 30.10.2024.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSArray (BinarySearch)

/// Performs a binary search for given **integer** value in the object, expecting it to be descending. Written for checking `position` of `Line` objects, but can be used elsewhere as well.
- (NSUInteger)binarySearchForItem:(id)targetItem matchingIntegerValueFor:(NSString*)key;
- (NSUInteger)binarySearchWithLocation:(NSInteger)location inLocationOfRangeValueFor:(NSString*)key;

@end

NS_ASSUME_NONNULL_END

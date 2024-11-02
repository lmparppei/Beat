//
//  NSArray+BinarySearch.h
//  BeatParsing
//
//  Created by Lauri-Matti Parppei on 30.10.2024.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSArray (BinarySearch)

/// Performs a binary search for given **integer** value in the object.
- (NSUInteger)binarySearchForItem:(id)targetItem integerValueFor:(NSString*)key;

@end

NS_ASSUME_NONNULL_END

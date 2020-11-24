//
//  NSMutableArray+MoveItem.h
//  TableReorganizeTest
//
//  Created by Lauri-Matti Parppei on 24.11.2020.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSMutableArray (MoveItem)
- (void)moveObjectAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;
@end

NS_ASSUME_NONNULL_END

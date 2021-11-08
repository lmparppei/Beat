//
//  BeatTextStorage.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 4.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol BeatTextStorageDelegate <NSTextStorageDelegate>
- (void)didPerformEdit:(NSRange)range;
@end

@interface BeatTextStorage : NSTextStorage {
	NSMutableAttributedString *storage;
}
@property (weak) id<BeatTextStorageDelegate> delegate;
-(NSDictionary<NSAttributedStringKey,id> *)beatAttributesAtIndex:(NSUInteger)location effectiveRange:(NSRangePointer)range;
-(NSDictionary<NSAttributedStringKey,id> *)beatAttributesAtIndex:(NSUInteger)location longestEffectiveRange:(NSRangePointer)range inRange:(NSRange)rangeLimit;

@end

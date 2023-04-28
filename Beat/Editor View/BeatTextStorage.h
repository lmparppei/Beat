//
//  BeatTextStorage.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 4.10.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatParsing/BeatParsing.h>

@protocol BeatTextStorageDelegate <NSTextStorageDelegate>
@property (nonatomic, readonly, weak) ContinuousFountainParser *parser;
- (void)didPerformEdit:(NSRange)range;
@end

@interface BeatParagraph : NSObject
@property (nonatomic) NSRect rect;
@end

@interface BeatTextStorage : NSTextStorage {
	NSMutableAttributedString *storage;
}
@property (weak) id<BeatTextStorageDelegate> delegate;
@end

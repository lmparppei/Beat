//
//  BeatTimeline.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.9.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatEditorDelegate.h>
#import "BeatTimelineItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface BeatTimeline : NSView <BeatSceneOutlineView, BeatTimelineItemDelegate, NSTextFieldDelegate>

@property (nonatomic) bool visible;

@property (nonatomic, weak) IBOutlet NSMenu *sceneMenu;

@property (nonatomic) NSMutableArray<BeatTimelineItem*> *selectedItems;

@property (nonatomic) NSArray<OutlineScene*>* outline;
@property (weak) IBOutlet id<BeatEditorDelegate> delegate;
@property (nonatomic) NSColor *backgroundColor;
@property (weak) IBOutlet NSLayoutConstraint *heightConstraint;

// Storylines
@property (nonatomic) NSMutableArray<NSString*>* storylines;
@property (nonatomic) NSMutableArray *visibleStorylines;
@property (nonatomic) OutlineScene * _Nullable clickedItem;

- (void)setup;
- (void)show;
- (void)hide;
- (void)reload;
- (void)refreshWithDelay;
- (void)scrollToSceneIndex:(NSInteger)index;
- (CGFloat)playheadPosition;

@end

NS_ASSUME_NONNULL_END

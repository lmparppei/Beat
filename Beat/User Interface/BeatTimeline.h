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

@protocol BeatTimelineDelegate <BeatEditorDelegate>

@property (nonatomic, readonly, weak) OutlineScene *currentScene;

- (NSRange)selectedRange;

- (void)addStoryline:(NSString*)storyline to:(OutlineScene*)scene;
- (void)removeStoryline:(NSString*)storyline from:(OutlineScene*)scene;
- (void)setColor:(NSString *) color forScene:(OutlineScene *) scene;
- (bool)caretAtEnd;
- (void)registerEditorView:(id)view;

@end

@interface BeatTimeline : NSView <BeatSceneOutlineView, BeatTimelineItemDelegate, NSTextFieldDelegate>

@property (nonatomic) bool visible;

@property (nonatomic, weak) IBOutlet NSMenu *sceneMenu;

@property (nonatomic) NSMutableArray<BeatTimelineItem*> *selectedItems;

@property (nonatomic) NSArray* outline;
@property (weak) IBOutlet id<BeatTimelineDelegate> delegate;
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
- (void)scrollToScene:(NSInteger)index;
- (CGFloat)playheadPosition;

@end

NS_ASSUME_NONNULL_END

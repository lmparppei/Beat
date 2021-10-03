//
//  BeatTimeline.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 3.9.2020.
//  Copyright © 2020 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OutlineScene.h"
#import "BeatTimelineItem.h"

NS_ASSUME_NONNULL_BEGIN

@protocol BeatTimelineDelegate <NSObject>

@property (nonatomic, readonly, weak) OutlineScene *currentScene;

- (NSRange)selectedRange;
- (NSMutableArray*)getOutlineItems;
- (NSArray*)getOutline; // ???
- (OutlineScene*)getCurrentScene;
- (void)didSelectTimelineItem:(NSInteger)index;
- (void)addStoryline:(NSString*)storyline to:(OutlineScene*)scene;
- (void)removeStoryline:(NSString*)storyline from:(OutlineScene*)scene;
- (void) setColor:(NSString *) color forScene:(OutlineScene *) scene;
- (bool)caretAtEnd;
@end

@interface BeatTimeline : NSView <BeatTimelineItemDelegate, NSTextFieldDelegate>

@property (nonatomic, weak) IBOutlet NSMenu *sceneMenu;

@property (nonatomic) NSMutableArray<BeatTimelineItem*> *selectedItems;

@property (nonatomic) NSArray* outline;
@property (weak) id<BeatTimelineDelegate> delegate;
@property (nonatomic) NSColor *backgroundColor;
@property (nonatomic) OutlineScene *currentScene;
@property NSLayoutConstraint *heightConstraint;

// Storylines
@property (nonatomic) NSMutableArray *storylines;
@property (nonatomic) NSMutableArray *visibleStorylines;
@property (nonatomic) OutlineScene * _Nullable clickedItem;

- (void)show;
- (void)hide;
- (void)reload;
- (void)refreshWithDelay;
- (void)scrollToScene:(NSInteger)index;
- (CGFloat)playheadPosition;

@end

NS_ASSUME_NONNULL_END

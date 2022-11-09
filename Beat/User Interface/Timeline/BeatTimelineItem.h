//
//  BeatTimelineItem.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 1.11.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatParsing/BeatParsing.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BeatTimelineItemType) {
	TimelineScene = 1,
	TimelineSection,
	TimelineLowerSection,
	TimelineSynopsis,
	TimelineStoryline
};

@protocol BeatTimelineItemDelegate <NSObject>
@property (nonatomic) NSColor *backgroundColor;
@property (nonatomic, weak) IBOutlet NSMenu *sceneMenu;
@property (nonatomic) OutlineScene *clickedItem;
@property (nonatomic) NSMutableArray *storylines;
@property (nonatomic) NSMutableArray *selectedItems;

- (void)addStoryline:(NSString*)storyline to:(OutlineScene*)scene;
- (void)removeStoryline:(NSString*)storyline from:(OutlineScene*)scene;
- (void)newStorylineFor:(OutlineScene*)scene item:(id)item;
- (void)setSceneColor:(NSString*)color for:(OutlineScene*)scene;

// Selection handling
- (void)setSelected:(id)item;
- (void)addSelected:(id)item;
- (void)deselect:(id)item;
- (void)selectTo:(id)item;

- (CGFloat)timelineHeight;

@end

@interface BeatTimelineItem : NSView
@property (weak) OutlineScene *representedItem;
@property (nonatomic) bool selected;
@property (nonatomic) BeatTimelineItemType type;

- (id)initWithDelegate:(id<BeatTimelineItemDelegate>)delegate;
- (void)setItem:(OutlineScene*)scene rect:(NSRect)rect reset:(bool)reset;
- (void)setItem:(OutlineScene*)scene rect:(NSRect)rect reset:(bool)reset storyline:(bool)storyline forceColor:(NSColor* __nullable)forcedColor;
- (void)select;
- (void)deselect;
@end

NS_ASSUME_NONNULL_END

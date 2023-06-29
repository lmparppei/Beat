//
//  TimelineView.h
//  TouchBarTest
//
//  Created by Lauri-Matti Parppei on 27.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatParsing/BeatParsing.h>
#import <BeatCore/BeatCore.h>

@interface TouchTimelineView : NSView  <BeatSceneOutlineView, NSGestureRecognizerDelegate>
@property (nonatomic) bool visible;
@property CGFloat magnification;
@property bool allowsMagnification;
@property (nonatomic, weak) id<BeatEditorDelegate> delegate;
@property NSUInteger selectedItem;
- (void)selectItem:(NSInteger)index;
- (NSUInteger)getSelectedItem;
- (void)setData:(NSMutableArray*)array;

@end


//
//  TimelineView.h
//  TouchBarTest
//
//  Created by Lauri-Matti Parppei on 27.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol TouchTimelineDelegate <NSObject>
- (void)didSelectTouchTimelineItem:(NSInteger)index;
@end

@interface TouchTimelineView : NSView  <NSGestureRecognizerDelegate>

@property CGFloat magnification;
@property bool allowsMagnification;
@property (weak) id <TouchTimelineDelegate> delegate;
@property NSUInteger selectedItem;
- (void)selectItem:(NSInteger)index;
- (NSUInteger)getSelectedItem;
- (void)setData:(NSMutableArray*)array;

@end


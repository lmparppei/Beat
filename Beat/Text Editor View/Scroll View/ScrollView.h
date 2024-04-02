//
//  ScrollView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 13/09/2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <BeatCore/BeatEditorDelegate.h>
@class DynamicColor;

@interface ScrollView : NSScrollView

@property (weak) IBOutlet id<BeatEditorDelegate> editorDelegate;

@property (weak) IBOutlet NSView *buttonView;
@property (weak) IBOutlet NSView *timerView;

@property (nonatomic) NSView *taggingView;

@property (nonatomic, weak) DynamicColor *marginColor;
@property (nonatomic) CGFloat buttonDefaultY;
@property (nonatomic) NSTimer *mouseMoveTimer;
@property (nonatomic) NSTimer *timerMouseMoveTimer;

@property (nonatomic) NSArray *editorButtons;

- (void)timerDidStart;
- (void)layoutButtons;

@end

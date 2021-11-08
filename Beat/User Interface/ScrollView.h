//
//  ScrollView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 13/09/2019.
//  Copyright © 2019 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BeatEditorDelegate.h"
@class DynamicColor;

@interface ScrollView : NSScrollView

@property (weak) IBOutlet id<BeatEditorDelegate> editorDelegate;

// Buttons to hide
@property (weak) IBOutlet NSButton *outlineButton;
@property (weak) IBOutlet NSButton *cardsButton;
@property (weak) IBOutlet NSButton *timelineButton;
@property (weak) IBOutlet NSButton *previewButton;
@property (weak) IBOutlet NSButton *quickSettingsButton;
@property (weak) IBOutlet NSView *timerView;

@property (weak) IBOutlet NSLayoutConstraint *outlineButtonY;

@property (nonatomic) NSView *taggingView;

@property (nonatomic, weak) DynamicColor *marginColor;
@property (nonatomic) CGFloat buttonDefaultY;
@property (nonatomic) NSTimer *mouseMoveTimer;
@property (nonatomic) NSTimer *timerMouseMoveTimer;

@property (nonatomic) NSArray *editorButtons;

- (void)timerDidStart;
- (void)layoutButtons;

@end

//
//  ScrollView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 13/09/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DynamicColor.h"

@interface ScrollView : NSScrollView

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
@property (nonatomic) CGFloat insetWidth;
@property (nonatomic) CGFloat buttonDefaultY;
@property (nonatomic) CGFloat magnificationLevel;
@property (nonatomic) NSTimer *mouseMoveTimer;
@property (nonatomic) NSTimer *timerMouseMoveTimer;

@property (nonatomic) NSArray *editorButtons;

- (void)timerDidStart;
- (void)layoutButtons;

@end

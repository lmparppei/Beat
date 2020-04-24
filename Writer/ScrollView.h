//
//  ScrollView.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 13/09/2019.
//  Copyright © 2019 KAPITAN!. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DynamicColor.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScrollView : NSScrollView

// Buttons to hide
@property IBOutlet NSButton *outlineButton;
@property IBOutlet NSButton *cardsButton;
@property IBOutlet NSButton *timelineButton;

@property IBOutlet NSLayoutConstraint *outlineButtonY;

@property (nonatomic) DynamicColor *marginColor;
@property (nonatomic) CGFloat insetWidth;
@property (nonatomic) NSTimer *mouseMoveTimer;

@end

NS_ASSUME_NONNULL_END

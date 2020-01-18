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
@property IBOutlet NSButton *outlineButton;
@property IBOutlet NSButton *cardsButton;

@property IBOutlet NSLayoutConstraint *outlineButtonY;
@property IBOutlet NSLayoutConstraint *cardsButtonY;

@property (nonatomic) DynamicColor *marginColor;
@property (nonatomic) CGFloat insetWidth;

@end

NS_ASSUME_NONNULL_END

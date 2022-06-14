//
//  BeatEditorButton.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 20.3.2021.
//  Copyright © 2021 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
IB_DESIGNABLE
@interface BeatEditorButton : NSButton
@property (nonatomic) IBInspectable NSColor *startColor;
@property (nonatomic) IBInspectable BOOL onOffButton;
-(void)updateAppearance;
@end

NS_ASSUME_NONNULL_END

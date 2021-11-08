//
//  RoundedButton.h
//  Beat
//
//  Created by Lauri-Matti Parppei on 29.5.2020.
//  Copyright © 2020 Lauri-Matti Parppei. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface RoundedButton : NSButtonCell
@property IBInspectable NSColor *borderColor;
@property bool *transparentBackground;
@property NSColor *textColor;
@property bool clicked;
@end

NS_ASSUME_NONNULL_END

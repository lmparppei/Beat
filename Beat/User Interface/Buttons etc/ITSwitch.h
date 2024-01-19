//
//  ITSwitch.h
//  ITSwitch-Demo
//
//  Created by Ilija Tovilo on 01/02/14.
//  Modified by Beat by L-M Parppei sometime 10 years later.
//  Copyright (c) 2014 Ilija Tovilo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/**
 *  ITSwitch is a replica of UISwitch for Mac OS X
 */
IB_DESIGNABLE
@interface ITSwitch : NSControl

/**
 *  @property checked - Gets or sets the switches state
 */
@property (nonatomic, assign) IBInspectable BOOL checked;

/// Beat setting value key
@property (nonatomic, assign) IBInspectable NSString* _Nullable settingKey;
/// Set `true` this setting is a document setting and not a user default
@property (nonatomic, assign) IBInspectable bool documentSetting;
@property (nonatomic, assign) IBInspectable bool redrawDocument;

/**
 *  @property tintColor - Gets or sets the switches tint
 */
@property (nonatomic, strong) IBInspectable NSColor* _Nullable tintColor;

/**
 *  @property disabledBorderColor - Define the switch's border color for disabled state.
 */
@property (nonatomic, strong) IBInspectable NSColor* _Nullable disabledBorderColor;

- (id _Nonnull)initWithFrame:(NSRect)frame settingKey:(NSString* _Nullable)key documentSetting:(bool)documentSetting;

@end
